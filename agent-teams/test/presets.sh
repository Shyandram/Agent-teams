#!/usr/bin/env bash
# Preset composition must agree in three places: the definition, `init --help`,
# and docs/commands.md.
#
# It did not. Adding `verification` to the three -wide presets updated the
# definition only, leaving the help text listing the old roles and all three
# counts wrong (6/7/8 against a real 7/8/9). test/flags.sh cannot catch this —
# it checks flags, and preset composition is prose.
#
# Run from the skill root:  bash test/presets.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/bin/agent-teams"
common="$here/bin/_common.sh"
doc="$here/docs/commands.md"

bad=0

# Scope both extractions to the one function that owns each fact — `research)` also
# appears in an unrelated case statement, and a bare `$1 == "research"` matches prose
# in the --aim help line.
preset_fn=$(awk '/^at_preset_roles\(\)/ {on=1} on {print} on && /^}$/ {exit}' "$common")
init_help=$(awk '/^cmd_init\(\)/ {on=1} on {print} on && /^}$/ {exit}' "$src")

for preset in solo app-dev research app-dev-wide research-wide full-stack; do
  roles=$(printf '%s\n' "$preset_fn" \
          | sed -n "s/^[[:space:]]*$preset)[[:space:]]*printf '\([^']*\)'.*/\1/p")
  if [ -z "$roles" ]; then
    echo "NO DEFINITION: $preset"; bad=$((bad + 1)); continue
  fi

  # Count comma-separated roles.
  n=$(printf '%s' "$roles" | tr ',' '\n' | grep -c .)

  # The count `init --help` advertises, e.g. "(7)" on the preset's line. The row is
  # "  <preset>   <roles...>   (N)", possibly wrapped, so scan forward for the count.
  help_n=$(printf '%s\n' "$init_help" | awk -v p="$preset" '
      $0 ~ "^  " p "  +[a-z+]" {
        do { if (match($0, /\([0-9]+\)/)) { print substr($0, RSTART+1, RLENGTH-2); exit } }
        while (getline > 0)
        exit }')

  if [ "$help_n" != "$n" ]; then
    echo "COUNT MISMATCH: $preset — definition has $n roles, init --help says ${help_n:-none}"
    bad=$((bad + 1))
  fi

  # Every role in the definition must appear on the preset's row in commands.md.
  row=$(grep -- "| \`$preset\` |" "$doc")
  if [ -z "$row" ]; then
    echo "NOT IN DOC: $preset"; bad=$((bad + 1)); continue
  fi
  for r in $(printf '%s' "$roles" | tr ',' ' '); do
    case "$row" in
      *"$r"*) ;;
      *) echo "DOC MISSING ROLE: $preset is missing '$r' in commands.md"; bad=$((bad + 1)) ;;
    esac
  done
  case "$row" in
    *"| $n |"*) ;;
    *) echo "DOC COUNT MISMATCH: $preset has $n roles; commands.md row disagrees"
       bad=$((bad + 1)) ;;
  esac
done

echo "---"
echo "presets checked: 6"
echo "problems:        $bad"
[ "$bad" -eq 0 ] || exit 1
echo "ok"
