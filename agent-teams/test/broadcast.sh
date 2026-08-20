#!/usr/bin/env bash
# End-to-end: broadcast → priority read → partial acks → completing receipt.
#
# This replays the sequence by hand rather than trusting the pieces: the failure
# this guards against is a receipt that fires on every read (flooding the sender),
# never fires (sender never learns), or counts the sender as one of the readers.
#
# Run from the skill root:  bash test/broadcast.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
at="$here/bin/agent-teams"
tmp="${TMPDIR:-/tmp}/at-bc-test.$$"
mkdir -p "$tmp" || exit 2
trap 'rm -rf "$tmp"' EXIT

bad=0
check() {  # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "  ok   $1"
  else
    echo "  FAIL $1 — expected '$2', got '$3'"; bad=$((bad + 1))
  fi
}

cd "$tmp" || exit 2
bash "$at" init --kind app-dev --name bctest >/dev/null 2>&1 || { echo "init failed"; exit 2; }
# Roles: lead, engineering, qa.

bash "$at" broadcast "the spec changed" --from lead >/dev/null 2>&1
id=$(python3 -c '
import json; print(json.load(open(".agent-teams/broadcast.json"))[0]["id"])' 2>/dev/null)
[ -n "$id" ] || { echo "  FAIL broadcast was not written"; exit 1; }

waiting() {
  bash "$at" acks --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(",".join(sorted(d[0]["pending"])) if d else "?")'
}
# The receipt goes to the SENDER — `lead` here, not "human".
receipts() {
  bash "$at" inbox lead --all --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(sum(1 for m in d.get("inbox") or [] if "read receipt" in (m.get("text") or "")))'
}

check "sender is not expected to ack its own broadcast" "engineering,qa" "$(waiting)"

# The broadcast must be visible to a role BEFORE its own messages.
bash "$at" send engineering "a personal note" --from qa >/dev/null 2>&1
order=$(bash "$at" inbox engineering 2>&1 | grep -n "BROADCAST\|personal note" | head -2 \
        | cut -d: -f1 | tr '\n' ' ')
first=${order%% *}
second=$(printf '%s' "$order" | awk '{print $2}')
if [ -n "$first" ] && [ -n "$second" ] && [ "$first" -lt "$second" ]; then
  echo "  ok   broadcast is printed above personal messages"
else
  echo "  FAIL broadcast did not print first (lines: $order)"; bad=$((bad + 1))
fi

bash "$at" inbox engineering --mark-read >/dev/null 2>&1
check "partial ack leaves the rest pending" "qa" "$(waiting)"
check "no receipt before the last reader"   "0"  "$(receipts)"

bash "$at" inbox qa --mark-read >/dev/null 2>&1
check "all readers acked"                "" "$(waiting)"
check "receipt fires on the completing read" "1" "$(receipts)"

bash "$at" inbox qa --mark-read >/dev/null 2>&1
bash "$at" inbox engineering --mark-read >/dev/null 2>&1
check "receipt is idempotent across re-reads" "1" "$(receipts)"

# The monitor must see an unacked broadcast; that claim was false once already.
bash "$at" broadcast "second announcement" --from lead >/dev/null 2>&1
pend=$(bash "$at" status --json 2>/dev/null | python3 -c '
import json,sys; print(len(json.load(sys.stdin).get("pending_broadcasts") or []))')
check "monitor reports the unacked broadcast" "1" "$pend"

echo "---"
echo "problems: $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
