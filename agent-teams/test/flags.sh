#!/usr/bin/env bash
# Every flag a command actually parses must appear in docs/commands.md.
#
# This exists because the help text already drifted: `init` grew --squad,
# --subagents and --no-reference-skills, and `launch` grew --model-for and
# --tier-for, without any of them reaching `--help`. A reference document is
# only worth reading if something checks it, so this is that something.
#
# Run from the skill root:  bash test/flags.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/bin/agent-teams"
doc="$here/docs/commands.md"

[ -f "$src" ] || { echo "missing $src" >&2; exit 2; }
[ -f "$doc" ] || { echo "missing $doc" >&2; exit 2; }

missing=0
checked=0

for fn in $(grep -o '^cmd_[a-z]*' "$src"); do
  cmd="${fn#cmd_}"
  body=$(awk -v f="$fn" '$0 ~ "^"f"\\(\\)" {on=1} on{print} on && /^}$/ {exit}' "$src")
  # Only the option-parsing region — stop at the heredoc that prints help, so
  # prose inside the help text is never mistaken for a parsed flag.
  parse=$(printf '%s\n' "$body" | sed -n '1,/<<.EOF./p')

  # The command's OWN section of the doc, from its `### ...` heading to the next one.
  # Grepping the whole file instead lets a flag pass because some other command
  # happens to document a flag of the same name — --force and --json both did.
  section=$(awk -v c="$cmd" '
      /^### / { on = (index($0, "`" c "`") > 0) }
      on { print }' "$doc")

  if [ -z "$section" ]; then
    echo "COMMAND NOT DOCUMENTED: agent-teams $cmd"
    missing=$((missing + 1))
    continue
  fi

  for flag in $(printf '%s\n' "$parse" | grep -o '^[[:space:]]*--[a-z-]*)' | tr -d ' )' | sort -u); do
    [ "$flag" = "--help" ] && continue
    checked=$((checked + 1))
    if ! printf '%s\n' "$section" | grep -q -- "$flag"; then
      echo "UNDOCUMENTED: agent-teams $cmd $flag"
      missing=$((missing + 1))
    fi
  done
done

# Every flag that takes a value must guard against a missing one, or `shift 2`
# runs off the end of the argument list. This was a real bug in --model-for.
unguarded=0
while IFS= read -r line; do
  case "$line" in
    *at_need_arg*) ;;
    *) echo "UNGUARDED VALUE FLAG: $(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
       unguarded=$((unguarded + 1)) ;;
  esac
done <<EOF
$(grep -n '^[[:space:]]*\(-[A-Za-z]|\)\?--[a-z-]*)' "$src" | grep 'shift 2')
EOF

echo "---"
echo "flags checked:      $checked"
echo "undocumented:       $missing"
echo "unguarded value:    $unguarded"

[ "$missing" -eq 0 ] && [ "$unguarded" -eq 0 ] || exit 1
echo "ok"
