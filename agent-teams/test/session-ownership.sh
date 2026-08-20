#!/usr/bin/env bash
# Session ownership is hierarchical: children are subagents, not processes.
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
. "$here/bin/_common.sh"

tmp="$(mktemp -d /private/tmp/agent-teams-session-test.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/team.yaml" <<'YAML'
version: 1
general: general
roles:
  - name: general
    session: true
  - name: researcher
    parent: general
    session: false
  - name: verifier
    parent: researcher
    session: false
YAML

bad=0
for pair in "general:general" "researcher:general" "verifier:general"; do
  role="${pair%%:*}"; want="${pair#*:}"
  got="$(at_team_session_owner "$tmp/team.yaml" "$role")"
  [ "$got" = "$want" ] || { echo "OWNER MISMATCH: $role -> $got (want $want)"; bad=$((bad + 1)); }
done

echo "---"
echo "ownership checks: 3"
echo "problems:         $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
