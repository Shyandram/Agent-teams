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
  - name: idea1-general
    parent: general
    session: true
    approval: proposed
  - name: idea2-general
    parent: general
    session: true
    approval: proposed
  - name: idea3-general
    parent: general
    session: true
    approval: proposed
YAML

bad=0
for pair in "general:general" "researcher:general" "verifier:general" "idea1-general:general" "idea2-general:general" "idea3-general:general"; do
  role="${pair%%:*}"; want="${pair#*:}"
  got="$(at_team_session_owner "$tmp/team.yaml" "$role")"
  [ "$got" = "$want" ] || { echo "OWNER MISMATCH: $role -> $got (want $want)"; bad=$((bad + 1)); }
done

owners=0
while IFS=$'\037' read -r role _a _b _c _d _e _f _g _h; do
  [ -n "$role" ] || continue
  [ "$(at_team_session_owner "$tmp/team.yaml" "$role")" = "$role" ] && owners=$((owners + 1))
done <<EOF
$(at_team_roles "$tmp/team.yaml")
EOF
[ "$owners" -eq 1 ] || { echo "PROPOSED OWNER COUNT: $owners (want 1)"; bad=$((bad + 1)); }

sed 's/approval: proposed/approval: approved/g' "$tmp/team.yaml" >"$tmp/team-approved.yaml"
mv "$tmp/team-approved.yaml" "$tmp/team.yaml"
owners=0
while IFS=$'\037' read -r role _a _b _c _d _e _f _g _h; do
  [ -n "$role" ] || continue
  [ "$(at_team_session_owner "$tmp/team.yaml" "$role")" = "$role" ] && owners=$((owners + 1))
done <<EOF
$(at_team_roles "$tmp/team.yaml")
EOF
[ "$owners" -eq 4 ] || { echo "APPROVED OWNER COUNT: $owners (want 4)"; bad=$((bad + 1)); }

echo "---"
echo "ownership checks: 8 + owner-count transitions"
echo "problems:         $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
