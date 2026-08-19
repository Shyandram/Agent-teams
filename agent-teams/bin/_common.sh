#!/usr/bin/env bash
# Shared helpers for the agent-teams CLI.
#
# Portability contract: bash 3.2 (stock macOS), POSIX coreutils, awk, sed.
# Deliberately NOT required: jq, yq, timeout(1), GNU-only flags.
# See docs/SPIKE-FINDINGS.md for why each of those is avoided.

# ---------- paths ----------
AT_SKILL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
AT_ROLES_DIR="$AT_SKILL_DIR/roles"
AT_TEMPLATES_DIR="$AT_SKILL_DIR/templates"
AT_RUNTIMES_DIR="$AT_SKILL_DIR/runtimes"
AT_MONITOR_DIR="$AT_SKILL_DIR/monitor"

# ---------- colour / logging (stderr only, so stdout stays pipeable) ----------
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  AT_RESET=$'\033[0m'; AT_DIM=$'\033[2m'; AT_BOLD=$'\033[1m'
  AT_RED=$'\033[31m'; AT_GREEN=$'\033[32m'; AT_YELLOW=$'\033[33m'; AT_CYAN=$'\033[36m'
else
  AT_RESET=; AT_DIM=; AT_BOLD=; AT_RED=; AT_GREEN=; AT_YELLOW=; AT_CYAN=
fi

at_say()  { printf '%s\n' "$*" >&2; }
at_info() { printf '%s%s%s\n' "$AT_DIM" "$*" "$AT_RESET" >&2; }
at_ok()   { printf '%s✓%s %s\n' "$AT_GREEN" "$AT_RESET" "$*" >&2; }
at_warn() { printf '%s!%s %s\n' "$AT_YELLOW" "$AT_RESET" "$*" >&2; }
at_err()  { printf '%serror%s %s\n' "$AT_RED" "$AT_RESET" "$*" >&2; }
at_die()  { at_err "$*"; exit 1; }

# ---------- project resolution ----------
at_resolve_project() {
  local d="${1:-$PWD}"
  [ -d "$d" ] || at_die "no such directory: $d"
  (cd -- "$d" && pwd)
}

at_dot()      { printf '%s/.agent-teams' "$1"; }
at_team_yaml(){ printf '%s/.agent-teams/team.yaml' "$1"; }
at_logs()     { printf '%s/.agent-teams/logs' "$1"; }
at_sessions() { printf '%s/.agent-teams/sessions' "$1"; }
at_prompts()  { printf '%s/.agent-teams/prompts' "$1"; }

# ---------- time ----------
at_iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ---------- tmux ----------
at_have_tmux() { command -v tmux >/dev/null 2>&1; }

at_tmux_session() {
  # Stable, filesystem-safe tmux session name derived from the project path.
  # `tr -c` would also rewrite the trailing newline into '_', so strip it first.
  local base
  base=$(basename -- "$1")
  base=$(printf '%s' "$base" | tr -c 'A-Za-z0-9_-' '_')
  printf 'at_%s' "$(printf '%s' "$base" | cut -c1-32)"
}

# ---------- workspace trust ----------
# Verified in docs/SPIKE-FINDINGS.md: a background Claude session in an untrusted
# directory blocks forever on its first write, even with --permission-mode acceptEdits.
# We check, we report, we refuse — we never flip the flag ourselves.
at_project_is_trusted() {
  local project="$1" cfg="$HOME/.claude.json"
  [ -f "$cfg" ] || return 1
  # Trust inherits to subdirectories (verified empirically: a subdir of a trusted
  # project runs unblocked), so walk up ancestors rather than matching exactly.
  python3 - "$cfg" "$project" <<'PY' 2>/dev/null
import json, os, sys
try:
    with open(sys.argv[1]) as fh:
        cfg = json.load(fh)
except Exception:
    sys.exit(1)
projects = cfg.get("projects") or {}
path = os.path.abspath(sys.argv[2])
while True:
    entry = projects.get(path)
    if entry and entry.get("hasTrustDialogAccepted") is True:
        sys.exit(0)
    parent = os.path.dirname(path)
    if parent == path:
        sys.exit(1)
    path = parent
PY
}

at_require_trust() {
  local project="$1"
  if at_project_is_trusted "$project"; then return 0; fi
  at_err "project directory is not trusted by Claude Code:"
  at_say "    $project"
  at_say ""
  at_say "  Background agents there will block forever on their first write,"
  at_say "  waiting for a permission prompt nobody can answer."
  at_say ""
  at_say "  Fix it once, interactively:"
  at_say "      cd '$project' && claude"
  at_say "  accept the trust prompt, then exit. Re-run this command afterwards."
  at_say ""
  at_say "  (This skill will not set that flag for you: it is a security control.)"
  return 1
}

# ---------- template rendering ----------
# Expands {{VAR}} from the environment. Unset vars render empty, and
# at_check_placeholders catches anything left behind.
at_render() {
  awk '
    {
      line = $0
      while (match(line, /\{\{[A-Za-z_][A-Za-z0-9_]*\}\}/)) {
        key = substr(line, RSTART + 2, RLENGTH - 4)
        line = substr(line, 1, RSTART - 1) ENVIRON[key] substr(line, RSTART + RLENGTH)
      }
      print line
    }
  '
}

at_check_placeholders() {
  local f="$1"
  if grep -q '{{[A-Za-z_]' "$f" 2>/dev/null; then
    at_warn "unfilled placeholders remain in $f:"
    grep -o '{{[A-Za-z_][A-Za-z0-9_]*}}' "$f" | sort -u | sed 's/^/      /' >&2
    return 1
  fi
  return 0
}

# ---------- team.yaml reader (no yq dependency) ----------
# Emits: role<TAB>runtime<TAB>model_tier<TAB>permission_mode<TAB>sandbox
at_team_roles() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk '
    function flush() {
      if (role != "") {
        printf "%s\t%s\t%s\t%s\t%s\n",
          role,
          (runtime  != "" ? runtime  : dflt_rt),
          (tier     != "" ? tier     : "regular"),
          (perm     != "" ? perm     : ""),
          (sandbox  != "" ? sandbox  : "")
      }
      role = ""; runtime = ""; tier = ""; perm = ""; sandbox = ""
    }
    function val(s) { sub(/^[^:]*:[[:space:]]*/, "", s); gsub(/^["\047]|["\047][[:space:]]*$/, "", s); sub(/[[:space:]]*#.*$/, "", s); gsub(/[[:space:]]+$/, "", s); return s }
    /^default_runtime:/ { dflt_rt = val($0); next }
    /^roles:[[:space:]]*$/ { in_roles = 1; next }
    in_roles && /^[^[:space:]#]/ { flush(); in_roles = 0 }
    !in_roles { next }
    /^[[:space:]]*-[[:space:]]*name:/ { flush(); s = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); role = val(s); next }
    /^[[:space:]]*runtime:/         { runtime = val($0); next }
    /^[[:space:]]*model_tier:/      { tier    = val($0); next }
    /^[[:space:]]*permission_mode:/ { perm    = val($0); next }
    /^[[:space:]]*sandbox:/         { sandbox = val($0); next }
    END { flush() }
  ' "$f"
}

at_team_scalar() {
  # $1=file $2=key
  awk -v k="$2" '
    index($0, k ":") == 1 {
      s = $0; sub(/^[^:]*:[[:space:]]*/, "", s)
      gsub(/^["\047]|["\047][[:space:]]*$/, "", s)
      sub(/[[:space:]]*#.*$/, "", s); gsub(/[[:space:]]+$/, "", s)
      print s; exit
    }
  ' "$1" 2>/dev/null
}

# ---------- role frontmatter reader ----------
at_role_field() {
  # $1=role file $2=field
  awk -v k="$2" '
    NR == 1 && $0 ~ /^---[[:space:]]*$/ { fm = 1; next }
    fm && $0 ~ /^---[[:space:]]*$/ { exit }
    fm && index($0, k ":") == 1 {
      s = $0; sub(/^[^:]*:[[:space:]]*/, "", s)
      gsub(/^["\047]|["\047][[:space:]]*$/, "", s)
      print s; exit
    }
  ' "$1" 2>/dev/null
}

at_role_body() {
  awk '
    NR == 1 && $0 ~ /^---[[:space:]]*$/ { fm = 1; next }
    fm && $0 ~ /^---[[:space:]]*$/ { fm = 0; body = 1; next }
    body { print }
    !fm && !body && NR == 1 { print }
  ' "$1" 2>/dev/null
}

at_role_file() {
  # Resolve a role name to its source file, checking extras/ too.
  local name="$1"
  if [ -f "$AT_ROLES_DIR/$name.md" ]; then printf '%s' "$AT_ROLES_DIR/$name.md"; return 0; fi
  if [ -f "$AT_ROLES_DIR/extras/$name.md" ]; then printf '%s' "$AT_ROLES_DIR/extras/$name.md"; return 0; fi
  return 1
}

# ---------- runtime adapters ----------
at_runtime_sh() {
  local r="$1" f="$AT_RUNTIMES_DIR/$1.sh"
  [ -f "$f" ] || at_die "unknown runtime '$r' (expected one of: $(ls "$AT_RUNTIMES_DIR" 2>/dev/null | sed 's/\.sh$//' | tr '\n' ' '))"
  printf '%s' "$f"
}

# ---------- presets ----------
at_preset_roles() {
  case "$1" in
    research)   printf 'lead,research,analysis,engineering,qa' ;;
    app-dev)    printf 'lead,engineering,ux,qa,devops' ;;
    full-stack) printf 'lead,engineering,ux,qa,devops,product-marketing,legal' ;;
    *) return 1 ;;
  esac
}

# ---------- misc ----------
at_confirm() {
  [ "${AGENT_TEAMS_YES:-}" = "1" ] && return 0
  printf '%s [y/N] ' "$1" >&2
  local ans; read -r ans || return 1
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

at_json_escape() {
  python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read().rstrip("\n")))'
}
