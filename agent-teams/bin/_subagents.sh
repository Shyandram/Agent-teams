#!/usr/bin/env bash
# Private per-role subagents.
#
# Roles may delegate to a subagent at any time using the runtime's built-in
# general-purpose agent — nothing has to be defined for that to work, and `init`
# defines nothing by default.
#
# What this file adds is OPTIONAL named specialists that belong to one role ALONE,
# plus the role subagents attached to a session owner by init.
# They are not in the shared `.claude/agents/` namespace, so `research-lit` cannot see
# `engineering`'s helpers and vice versa — two roles can even carry different
# definitions under the same name without colliding. Enable with `init --subagents`.
#
# The mechanism is `claude --agents '<json>'`, which defines agents for that session
# only. That is what makes them private; a file in `.claude/agents/` would be visible
# to every session in the project.
#
# Layout (per project):
#   .agent-teams/subagents/<role>/<name>.md
#
# Each file is frontmatter + prose, same shape as a role:
#   ---
#   name: explorer
#   description: when the owning role should call this
#   tools: Read, Grep, Glob
#   model_tier: smol
#   ---
#   <system prompt for the subagent>
#
# Calling one is the role's decision, never automatic. Subagents are for work that is
# genuinely separable and would otherwise burn the role's own context.

at_subagents_dir() { printf '%s/.agent-teams/subagents/%s' "$1" "$2"; }

# at_subagents_json <project> <role> <runtime>
# Emits a compact JSON object for --agents, or nothing when the role has none.
at_subagents_json() {
  local project="$1" role="$2" runtime="${3:-claude-code}"
  local dir; dir="$(at_subagents_dir "$project" "$role")"
  [ -d "$dir" ] || return 0
  ls "$dir"/*.md >/dev/null 2>&1 || return 0

  python3 - "$dir" "${AGENT_TEAMS_MODEL:-}" <<'PY'
import glob, json, os, sys

d, forced_model = sys.argv[1], sys.argv[2]

TIER_TO_MODEL = {"smol": "haiku", "regular": "sonnet",
                 "smart": "opus", "ultra": "opus"}

def parse(path):
    name = os.path.basename(path)[:-3]
    fm, body, in_fm, seen = {}, [], False, False
    with open(path, errors="replace") as fh:
        for i, line in enumerate(fh):
            t = line.rstrip("\n")
            if t.strip() == "---":
                if not seen:
                    in_fm, seen = True, True
                    continue
                if in_fm:
                    in_fm = False
                    continue
            if in_fm:
                if ":" in t:
                    k, v = t.split(":", 1)
                    fm[k.strip()] = v.strip().strip("\"'")
            else:
                body.append(t)
    return name, fm, "\n".join(body).strip()

agents = {}
for path in sorted(glob.glob(os.path.join(d, "*.md"))):
    if os.path.basename(path).lower() == "readme.md":
        continue
    name, fm, body = parse(path)
    name = fm.get("name") or name
    if not body:
        continue
    entry = {
        "description": fm.get("description") or ("%s helper" % name),
        "prompt": body,
    }
    tools = fm.get("tools")
    if tools:
        entry["tools"] = [t.strip() for t in tools.split(",") if t.strip()]
    model = forced_model or TIER_TO_MODEL.get(fm.get("model_tier") or "", "")
    if model:
        entry["model"] = model
    agents[name] = entry

if agents:
    sys.stdout.write(json.dumps(agents, separators=(",", ":")))
PY
}

# Emit the role children that belong to a session owner.  init materializes these
# definitions under the owner's private directory, so Claude receives one session
# with named role subagents instead of one session per role.

# Emitted into every role's prompt. No subagent needs to be pre-defined: the runtime
# already provides a general-purpose one, so this is about WHEN to reach for it, not
# what exists. Roles that want named specialists can define them (see below), but the
# default is simply that a role may delegate whenever it judges that useful.
at_delegation_block() {
  local project="$1" role="$2"
  local dir; dir="$(at_subagents_dir "$project" "$role")"

  printf '\n## Delegating to a subagent\n\n'
  cat <<'EOF'
You can spawn a subagent whenever you judge it worthwhile — when the user asks, or on
your own initiative. Nothing needs to be defined first; use the Agent tool with the
general-purpose type and give it the task.

Worth delegating: a wide search whose output you do not want in your own context, an
adversarial review of work you just finished, a long verification run, several
independent probes you would otherwise do one at a time.

Not worth delegating: anything small, anything needing context you already hold, or
anything where writing the brief costs more than doing the work.

A subagent starts with none of your history — give it everything it needs, and expect
only its final message back. It cannot approve permissions for you, and whatever it
reports is a claim you remain responsible for checking. Subagents belong to you: another
role cannot see or reuse yours.
EOF

  # Named specialists, only if this role has defined any.
  if [ -d "$dir" ] && ls "$dir"/*.md >/dev/null 2>&1; then
    printf '\nYou also have named specialists of your own:\n\n'
    local f n d2
    for f in "$dir"/*.md; do
      n="$(basename -- "$f" .md)"
      [ "$n" = "README" ] && continue
      d2="$(at_role_field "$f" description)"
      printf -- '- **%s** — %s\n' "$n" "${d2:-no description}"
    done
    printf '\nCall them by name with the Agent tool when they fit; otherwise the\n'
    printf 'general-purpose subagent is fine.\n'
  fi
}
