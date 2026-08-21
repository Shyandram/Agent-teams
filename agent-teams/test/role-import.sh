#!/usr/bin/env bash
# External role import is explicit, local, and reviewable.
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d /private/tmp/agent-teams-role-import.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/reference"
cat >"$tmp/reference/SKILL.md" <<'EOF'
---
name: source-role
description: A reference role for testing import.
model_tier: smart
---

Use primary evidence and record the source of every claim.
EOF

bash "$here/bin/agent-teams" init -C "$tmp" --kind solo --force >/dev/null 2>&1
bash "$here/bin/agent-teams" role import "$tmp/reference/SKILL.md" -C "$tmp" --as evidence-researcher --add >/dev/null 2>&1

bad=0
[ -f "$tmp/.agent-teams/roles/evidence-researcher.md" ] || { echo "MISSING IMPORT"; bad=$((bad + 1)); }
grep -q '^source: ' "$tmp/.agent-teams/roles/evidence-researcher.md" || { echo "MISSING SOURCE"; bad=$((bad + 1)); }
grep -q '^  - name: evidence-researcher$' "$tmp/.agent-teams/team.yaml" || { echo "NOT ADDED"; bad=$((bad + 1)); }

echo "---"
echo "role import checks: 3"
echo "problems:           $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
