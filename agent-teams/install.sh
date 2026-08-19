#!/usr/bin/env bash
# Install the agent-teams skill into Claude Code, Codex, and/or pi.
#
#   bash install.sh                 # install into every runtime found
#   bash install.sh --claude        # only Claude Code
#   bash install.sh --codex         # only Codex
#   bash install.sh --pi            # only pi
#   bash install.sh --copy          # copy instead of symlink
#   bash install.sh --uninstall     # remove what this script installed
#   bash install.sh --dry-run
#
# Symlinks by default, so editing the skill here updates every runtime at once.
# Use --copy for a frozen snapshot, or when the target is on another filesystem.

set -uo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NAME="agent-teams"

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
else
  R=; B=; D=; GREEN=; YELLOW=; RED=
fi
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$R" "$*" >&2; }
skip() { printf '  %s—%s %s\n' "$D" "$R" "$*" >&2; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$R" "$*" >&2; }
err()  { printf '  %s✗%s %s\n' "$RED" "$R" "$*" >&2; }

DO_CLAUDE=0 DO_CODEX=0 DO_PI=0 ANY=0
MODE=link UNINSTALL=0 DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)    DO_CLAUDE=1; ANY=1; shift ;;
    --codex)     DO_CODEX=1;  ANY=1; shift ;;
    --pi)        DO_PI=1;     ANY=1; shift ;;
    --copy)      MODE=copy; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --dry-run)   DRY=1; shift ;;
    -h|--help)   sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown option '$1'"; exit 2 ;;
  esac
done

# No explicit target: do every runtime that is present.
if [ "$ANY" -eq 0 ]; then
  command -v claude >/dev/null 2>&1 && DO_CLAUDE=1
  command -v codex  >/dev/null 2>&1 && DO_CODEX=1
  command -v pi     >/dev/null 2>&1 && DO_PI=1
  if [ $((DO_CLAUDE + DO_CODEX + DO_PI)) -eq 0 ]; then
    err "none of claude, codex, or pi found on PATH."
    printf '     See %s/docs/installation.md to install a runtime first.\n' "$SRC" >&2
    exit 1
  fi
fi

# install_to <label> <target-dir> <parent-must-exist-hint>
install_to() {
  local label="$1" target="$2"
  local parent; parent="$(dirname -- "$target")"

  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -L "$target" ] || [ -d "$target" ]; then
      [ "$DRY" -eq 1 ] && { skip "would remove $target"; return 0; }
      rm -rf -- "$target" && ok "$label: removed $target" || err "$label: could not remove $target"
    else
      skip "$label: nothing installed at $target"
    fi
    return 0
  fi

  if [ "$DRY" -eq 1 ]; then
    skip "would $MODE $SRC -> $target"
    return 0
  fi

  mkdir -p -- "$parent" || { err "$label: cannot create $parent"; return 1; }

  # Refuse to clobber a real directory that we did not create.
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "$label: $target exists and is not a symlink — left alone"
    printf '     Remove it yourself, then re-run.\n' >&2
    return 1
  fi
  rm -f -- "$target" 2>/dev/null

  if [ "$MODE" = "copy" ]; then
    cp -R -- "$SRC" "$target" || { err "$label: copy failed"; return 1; }
    rm -rf -- "$target/.git" 2>/dev/null
    ok "$label: copied to $target"
  else
    ln -s -- "$SRC" "$target" || { err "$label: symlink failed"; return 1; }
    ok "$label: linked $target -> $SRC"
  fi
}

printf '\n%sagent-teams%s — %s\n' "$B" "$R" \
  "$([ "$UNINSTALL" -eq 1 ] && echo uninstall || echo "install ($MODE)")" >&2
printf '  source: %s\n\n' "$SRC" >&2

RC=0

# ---------------------------------------------------------------- Claude Code
if [ "$DO_CLAUDE" -eq 1 ]; then
  install_to "claude" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/$NAME" || RC=1
fi

# ---------------------------------------------------------------------- Codex
# Verified: Codex reads the same SKILL.md format from ~/.codex/skills/<name>/.
# (.system, .curated and .experimental are reserved tiers; user skills sit at the top.)
if [ "$DO_CODEX" -eq 1 ]; then
  install_to "codex" "${CODEX_HOME:-$HOME/.codex}/skills/$NAME" || RC=1
fi

# ------------------------------------------------------------------------- pi
# UNTESTED — pi was not installed when this skill was built. pi consumes "packages"
# that expose a skills/ convention directory, so we stage a minimal package that
# points at this skill and print the command to register it.
if [ "$DO_PI" -eq 1 ]; then
  PKG="${PI_HOME:-$HOME/.pi}/agent/packages/$NAME"
  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -d "$PKG" ]; then
      [ "$DRY" -eq 1 ] && skip "would remove $PKG" || { rm -rf -- "$PKG"; ok "pi: removed $PKG"; }
      printf '     Also run: %spi remove %s%s\n' "$D" "$PKG" "$R" >&2
    else
      skip "pi: nothing installed at $PKG"
    fi
  elif [ "$DRY" -eq 1 ]; then
    skip "would stage pi package at $PKG"
  else
    mkdir -p -- "$PKG/skills" || { err "pi: cannot create $PKG"; RC=1; }
    if [ -d "$PKG/skills" ]; then
      cat >"$PKG/package.json" <<JSON
{
  "name": "$NAME",
  "version": "1.0.0",
  "description": "Role-based multi-agent teams across Claude Code, Codex, and pi.",
  "keywords": ["pi-package"],
  "pi": { "skills": "./skills" }
}
JSON
      rm -f -- "$PKG/skills/$NAME"
      if [ "$MODE" = "copy" ]; then cp -R -- "$SRC" "$PKG/skills/$NAME"
      else ln -s -- "$SRC" "$PKG/skills/$NAME"; fi
      ok "pi: staged package at $PKG"
      warn "pi support is UNTESTED. Register it with:"
      printf '       pi install %s\n' "$PKG" >&2
    fi
  fi
fi

# --------------------------------------------------------------------- report
printf '\n' >&2
if [ "$UNINSTALL" -eq 1 ]; then
  printf '%sDone.%s\n\n' "$B" "$R" >&2
  exit $RC
fi

if [ "$DRY" -eq 1 ]; then
  printf '%sDry run — nothing written.%s\n\n' "$D" "$R" >&2
  exit 0
fi

cat >&2 <<EOF
${B}Next${R}
  1. Verify the CLI runs:
       bash $SRC/bin/agent-teams doctor

  2. Start a new session so the runtime picks the skill up, then ask it to
     "set up an agent team for this project".

  3. Scaffold a project directly if you prefer:
       bash $SRC/bin/agent-teams init --kind app-dev

${D}Symlinked installs track this directory, so edits here apply everywhere.${R}
EOF
exit $RC
