#!/usr/bin/env bash
# Inter-role messaging — the piece every comparable system has and this one lacked.
#
# Deliberately file-based JSON, not a service:
#   - works identically for claude-code, codex, and pi roles (it is just files)
#   - survives session death, disconnect, and runtime restarts
#   - needs no daemon, port, or database
#
# Layout, all under the project's .agent-teams/:
#   inbox/<role>.json    messages waiting for that role
#   outbox/<role>.json   what that role has sent (audit trail)
#
# A message is:
#   {"id","from","to","ts","urgent":bool,"kind":"message|steer","text","read":bool}
#
# Roles are told (in their emitted prompt) to check their inbox at natural breakpoints
# and after finishing a unit of work. There is no push: a background agent cannot be
# interrupted mid-turn, so delivery is at the next poll. `steer` on a tmux-layout role
# additionally types into the pane, which IS immediate.

at_inbox_dir()  { printf '%s/.agent-teams/inbox' "$1"; }
at_outbox_dir() { printf '%s/.agent-teams/outbox' "$1"; }

# at_mb_append <project> <to-role> <from> <kind> <urgent> <text>
at_mb_append() {
  local project="$1" to="$2" from="$3" kind="$4" urgent="$5" text="$6"
  mkdir -p "$(at_inbox_dir "$project")" "$(at_outbox_dir "$project")" || return 1
  python3 - "$(at_inbox_dir "$project")/$to.json" "$(at_outbox_dir "$project")/$from.json" \
           "$to" "$from" "$kind" "$urgent" "$text" <<'PY'
import json, os, sys, time, uuid
inbox, outbox, to, frm, kind, urgent, text = sys.argv[1:8]

def load(p):
    try:
        with open(p) as fh:
            d = json.load(fh)
        return d if isinstance(d, list) else []
    except Exception:
        return []

msg = {
    "id": uuid.uuid4().hex[:8],
    "from": frm, "to": to,
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "urgent": urgent == "1",
    "kind": kind,
    "text": text,
    "read": False,
}

# Append rather than rewrite: two roles may write different inboxes concurrently, and
# each inbox has exactly one writer per message, so last-write-wins is acceptable here.
msgs = load(inbox)
msgs.append(msg)
tmp = inbox + ".tmp"
with open(tmp, "w") as fh:
    json.dump(msgs[-200:], fh, indent=2)   # cap so a chatty team cannot grow unbounded
os.replace(tmp, inbox)

sent = load(outbox)
sent.append(msg)
tmp = outbox + ".tmp"
with open(tmp, "w") as fh:
    json.dump(sent[-200:], fh, indent=2)
os.replace(tmp, outbox)

print(msg["id"])
PY
}

# at_mb_read <project> <role> [--all] [--json]
at_mb_read() {
  local project="$1" role="$2" all="${3:-}" fmt="${4:-}"
  local f; f="$(at_inbox_dir "$project")/$role.json"
  # A role with no mailbox yet must still emit valid JSON — returning nothing here
  # produced `{"broadcast":[...],"inbox":}` from `inbox --json`, which no parser reads.
  [ -f "$f" ] || { [ "$fmt" = "--json" ] && printf '[]\n'; return 0; }
  python3 - "$f" "$all" "$fmt" <<'PY'
import json, sys
path, allf, fmt = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    msgs = json.load(open(path))
except Exception:
    msgs = []
if allf != "--all":
    msgs = [m for m in msgs if not m.get("read")]
if fmt == "--json":
    json.dump(msgs, sys.stdout, indent=2); print()
else:
    for m in msgs:
        mark = "!" if m.get("urgent") else ("*" if not m.get("read") else " ")
        print("%s [%s] %s -> %s (%s)  %s" % (
            mark, m.get("id"), m.get("from"), m.get("to"),
            m.get("kind"), m.get("ts")))
        for line in (m.get("text") or "").split("\n"):
            print("      " + line)
PY
}

# at_mb_mark_read <project> <role>
at_mb_mark_read() {
  local project="$1" role="$2"
  local f; f="$(at_inbox_dir "$project")/$role.json"
  [ -f "$f" ] || return 0
  python3 - "$f" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    msgs = json.load(open(path))
except Exception:
    sys.exit(0)
n = 0
for m in msgs:
    if not m.get("read"):
        m["read"] = True; n += 1
tmp = path + ".tmp"
json.dump(msgs, open(tmp, "w"), indent=2)
os.replace(tmp, path)
print(n)
PY
}

at_mb_unread_count() {
  local project="$1" role="$2"
  local f; f="$(at_inbox_dir "$project")/$role.json"
  [ -f "$f" ] || { printf '0'; return 0; }
  python3 -c '
import json,sys
try: msgs=json.load(open(sys.argv[1]))
except Exception: msgs=[]
print(sum(1 for m in msgs if not m.get("read")))' "$f" 2>/dev/null || printf '0'
}

# =====================================================================
# Broadcast channel — one shared board, read before anything else.
#
# Why this is not "send to everyone's inbox":
#   - Fanning a broadcast into N inboxes makes N copies, and nobody can then answer
#     "has everyone seen it?" — the question that actually matters for an announcement.
#   - One record with an `acks` map answers it directly, and stays one message no
#     matter how many instances join later.
#
# Layout:  .agent-teams/broadcast.json
#   [{"id","from","ts","urgent","text","acks":{"<role>":"<ts>"}}]
#
# Roles are told to drain this BEFORE their personal inbox: a broadcast is by
# definition the thing that changes what everyone should be doing, so reading it
# second means acting on stale instructions first.
# =====================================================================

at_bc_file() { printf '%s/.agent-teams/broadcast.json' "$1"; }

# at_bc_append <project> <from> <urgent> <text>  -> echoes the id
at_bc_append() {
  local project="$1" from="$2" urgent="$3" text="$4"
  mkdir -p "$project/.agent-teams" || return 1
  python3 - "$(at_bc_file "$project")" "$from" "$urgent" "$text" <<'PY'
import json, os, sys, time, uuid
path, frm, urgent, text = sys.argv[1:5]
try:
    msgs = json.load(open(path))
    if not isinstance(msgs, list): msgs = []
except Exception:
    msgs = []
msg = {
    "id": uuid.uuid4().hex[:8],
    "from": frm,
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "urgent": urgent == "1",
    "text": text,
    "acks": {},
}
msgs.append(msg)
tmp = path + ".tmp"
json.dump(msgs[-200:], open(tmp, "w"), indent=2)
os.replace(tmp, path)
print(msg["id"])
PY
}

# at_bc_unread_count <project> <role>
at_bc_unread_count() {
  local project="$1" role="$2"
  local f; f="$(at_bc_file "$project")"
  [ -f "$f" ] || { printf '0'; return 0; }
  python3 -c '
import json,sys
try: msgs=json.load(open(sys.argv[1]))
except Exception: msgs=[]
role=sys.argv[2]
print(sum(1 for m in msgs if role not in (m.get("acks") or {}) and m.get("from")!=role))' \
    "$f" "$role" 2>/dev/null || printf '0'
}

# at_bc_read <project> <role> [--all] [--json]
at_bc_read() {
  local project="$1" role="$2" all="${3:-}" fmt="${4:-}"
  local f; f="$(at_bc_file "$project")"
  [ -f "$f" ] || { [ "$fmt" = "--json" ] && printf '[]\n'; return 0; }
  python3 - "$f" "$role" "$all" "$fmt" <<'PY'
import json, sys
path, role, allf, fmt = sys.argv[1:5]
try:
    msgs = json.load(open(path))
except Exception:
    msgs = []
if allf != "--all":
    msgs = [m for m in msgs if role not in (m.get("acks") or {}) and m.get("from") != role]
if fmt == "--json":
    json.dump(msgs, sys.stdout, indent=2); print()
else:
    for m in msgs:
        acks = m.get("acks") or {}
        mark = "!" if m.get("urgent") else "*"
        seen = "read by %d" % len(acks) if acks else "unread by everyone"
        print("%s [%s] BROADCAST from %s (%s)  %s" % (
            mark, m.get("id"), m.get("from"), m.get("ts"), seen))
        for line in (m.get("text") or "").split("\n"):
            print("      " + line)
PY
}

# at_bc_ack <project> <role> -> echoes "<n-acked> <sender:id ...>"
#
# Records the receipt, and reports which broadcasts this ack COMPLETED — the last
# reader is what the sender actually wants to know about. Acking every read back to
# the sender would put N messages in their inbox per announcement.
at_bc_ack() {
  local project="$1" role="$2" roster="$3"
  local f; f="$(at_bc_file "$project")"
  [ -f "$f" ] || { printf '0'; return 0; }
  python3 - "$f" "$role" "$roster" <<'PY'
import json, os, sys, time
path, role, roster = sys.argv[1:4]
everyone = [r for r in roster.split(",") if r]
try:
    msgs = json.load(open(path))
except Exception:
    sys.exit(0)
now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
n, completed = 0, []
for m in msgs:
    acks = m.setdefault("acks", {})
    if m.get("from") == role or role in acks:
        continue
    acks[role] = now
    n += 1
    # Everyone except the sender must have read it for the receipt to fire.
    expected = [r for r in everyone if r != m.get("from")]
    if expected and all(r in acks for r in expected):
        completed.append("%s:%s" % (m.get("from"), m.get("id")))
tmp = path + ".tmp"
json.dump(msgs, open(tmp, "w"), indent=2)
os.replace(tmp, path)
print(n)
print(" ".join(completed))
PY
}
