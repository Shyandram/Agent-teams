#!/usr/bin/env bash
# Runtime adapter: Claude Code.
# Contract: docs/INTERFACES.md section 6.  Behaviour verified: docs/SPIKE-FINDINGS.md.

set -u
AT_SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bin/_common.sh
. "$AT_SELF_DIR/../bin/_common.sh"

rt_detect() {
  command -v claude >/dev/null 2>&1 || { echo "claude CLI not on PATH"; return 1; }
  # `claude agents --json` needs no TTY and fails closed when unauthenticated,
  # which makes it a cheap liveness+auth probe.
  if ! claude agents --json >/dev/null 2>&1 </dev/null; then
    echo "claude CLI present but not authenticated (run: claude auth)"
    return 1
  fi
  return 0
}

rt_map_tier() {
  # Pure tier -> model mapping. Overrides (AGENT_TEAMS_MODEL, team.yaml `model:`,
  # --model-for/--tier-for) are resolved by at_resolve_model before this is reached,
  # so precedence lives in exactly one place.
  case "$1" in
    smol)    printf 'haiku' ;;
    regular) printf 'sonnet' ;;
    smart)   printf 'opus' ;;
    ultra)   printf 'opus' ;;
    *)       printf 'sonnet' ;;
  esac
}

# rt_launch <role> <prompt_file> <task> <log> <project> <layout> [tmux_target] [perm_mode] [model_tier]
rt_launch() {
  local role="$1" prompt_file="$2" task="$3" log="$4" project="$5" layout="$6"
  local tmux_target="${7:-}" perm="${8:-acceptEdits}" model="${9:-}" agents="${10:-}"
  # Arg 9 is an already-resolved model name (the launcher applies the precedence
  # chain in at_resolve_model). Fall back only if invoked directly.
  [ -n "$model" ] || model="$(rt_map_tier regular)"

  if [ "$layout" = "tmux" ]; then
    # Interactive session in its own tmux window: survives disconnect, can be taken over.
    #
    # Do NOT pipe this through `tee`. Piping makes stdout a pipe rather than a TTY, which
    # puts the CLI into non-interactive mode: it runs the prompt once, exits, and tmux
    # tears the window down — the exact opposite of what this layout is for. Log with
    # `pipe-pane` instead, which copies output without touching the TTY.
    local sess="${tmux_target%%:*}" win="${tmux_target#*:}"

    # Never interpolate values into a quoted command string for tmux: an apostrophe in
    # the task would break it, and a crafted one could inject commands into the pane.
    # Write a launcher whose arguments bash itself has quoted, and run that.
    local launcher="$project/.agent-teams/prompts/.launch-$role.sh"
    if [ -n "$agents" ]; then
      at_write_launcher "$launcher" claude \
        --append-system-prompt-file "$prompt_file" \
        --permission-mode "$perm" --model "$model" \
        --agents "$agents" -n "at:$role" "$task" || return 1
    else
      at_write_launcher "$launcher" claude \
        --append-system-prompt-file "$prompt_file" \
        --permission-mode "$perm" --model "$model" \
        -n "at:$role" "$task" || return 1
    fi
    tmux new-window -d -t "$sess" -n "$win" -c "$project" "$launcher" || return 1
    # Keep the window on failure so the error is readable rather than vanishing.
    tmux set-option -w -t "$tmux_target" remain-on-exit on 2>/dev/null || true
    tmux pipe-pane -o -t "$tmux_target" "cat >> '$log'" 2>/dev/null || true
    printf '%s' "$tmux_target"
    return 0
  fi

  # Background: returns immediately, printing "backgrounded · <short-id> · <name>".
  # NOTE: --session-id is NOT honoured for --bg (verified: the session gets a fresh id),
  # so we must read the id back rather than assign one.
  local out
  if [ -n "$agents" ]; then
    out=$(cd "$project" && claude --bg "$task" \
            --append-system-prompt-file "$prompt_file" \
            --permission-mode "$perm" \
            --model "$model" \
            --agents "$agents" \
            -n "at:$role" 2>&1 </dev/null) || { printf '%s\n' "$out" >>"$log"; return 1; }
  else
    out=$(cd "$project" && claude --bg "$task" \
            --append-system-prompt-file "$prompt_file" \
            --permission-mode "$perm" \
            --model "$model" \
            -n "at:$role" 2>&1 </dev/null) || { printf '%s\n' "$out" >>"$log"; return 1; }
  fi
  printf '%s\n' "$out" >>"$log"

  local short
  short=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' \
            | awk '/backgrounded/ { print $3; exit }')

  # Resolve the full session UUID, which is what the transcript path needs.
  # Authoritative source is `claude agents --json`; fall back to the short id.
  local full
  full=$(claude agents --json --all --cwd "$project" 2>/dev/null </dev/null \
    | python3 -c '
import json, sys
short = sys.argv[1]
try:
    rows = json.load(sys.stdin)
except Exception:
    rows = []
for r in rows if isinstance(rows, list) else []:
    if r.get("id") == short:
        print(r.get("sessionId") or short); break
' "$short" 2>/dev/null)

  printf '%s' "${full:-$short}"
}

# rt_status <project> -> role<TAB>state<TAB>session_id
rt_status() {
  local project="$1"
  claude agents --json --all --cwd "$project" 2>/dev/null </dev/null \
    | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for r in rows if isinstance(rows, list) else []:
    name = (r.get("name") or "")
    role = name[3:] if name.startswith("at:") else name
    state = r.get("state") or r.get("status") or "unknown"
    print("\t".join([role, state, r.get("id") or ""]))
'
}

rt_stop() {
  local sid="$1" kill_flag="${2:-}"
  [ -n "$sid" ] || return 0

  # `claude stop` accepts the short id; a full UUID works too. State can take a few
  # seconds to settle, so callers should not re-read status immediately.
  claude stop "$sid" >/dev/null 2>&1 </dev/null || true

  # A background agent may have relocated into a git worktree, which `stop` retains on
  # purpose so unmerged work is not lost. --kill means "clean up too".
  if [ "$kill_flag" = "--kill" ]; then
    claude rm "$sid" >/dev/null 2>&1 </dev/null || true
  fi
  return 0
}

case "${1:-}" in
  detect)   rt_detect ;;
  map_tier) shift; rt_map_tier "$@" ;;
  launch)   shift; rt_launch "$@" ;;
  status)   shift; rt_status "$@" ;;
  stop)     shift; rt_stop "$@" ;;
  *) echo "usage: claude-code.sh {detect|map_tier|launch|status|stop}" >&2; exit 2 ;;
esac
