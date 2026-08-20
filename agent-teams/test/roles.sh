#!/usr/bin/env bash
# Every role must be able to write its coordination note.
#
# This bug shipped twice: a "read-mostly" role (research, then verification) was
# given Read/Grep/Glob/Bash but no Write, so it blocked on its first action —
# writing docs/coordination/<session-id>.md, which the contract requires of every
# role without exception. It is invisible until a fleet is running.
#
# Run from the skill root:  bash test/roles.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
bad=0
n=0

for f in "$here"/roles/*.md "$here"/roles/extras/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac
  n=$((n + 1))
  name="$(basename "$f" .md)"
  # Frontmatter is what sits between the first and second `---` line.
  fm=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside {print}' "$f")
  [ -n "$fm" ] || { echo "NO FRONTMATTER: roles/$name.md"; bad=$((bad + 1)); continue; }

  for key in name description tools model_tier; do
    printf '%s\n' "$fm" | grep -q "^$key:" || { echo "MISSING $key: roles/$name.md"; bad=$((bad + 1)); }
  done

  printf '%s\n' "$fm" | grep '^tools:' | grep -q 'Write' \
    || { echo "NO Write TOOL: roles/$name.md — cannot write its coordination note"; bad=$((bad + 1)); }

  tier=$(printf '%s\n' "$fm" | sed -n 's/^model_tier:[[:space:]]*//p')
  case "$tier" in
    smol|regular|smart|ultra) ;;
    *) echo "BAD model_tier '$tier': roles/$name.md"; bad=$((bad + 1)) ;;
  esac
done

echo "---"
echo "roles checked: $n"
echo "problems:      $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
