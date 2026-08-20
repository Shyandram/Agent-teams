#!/usr/bin/env bash
# Runtime adapter: pi (Pi Agent Harness, @earendil-works/pi-coding-agent).
#
# ⚠️  UNTESTED. pi was not installed on the machine where this skill was built, so every
# code path below is written from documentation and source reading, never observed.
# Treat it as a starting point, not a working adapter. `detect` fails loudly and
# honestly rather than pretending.
#
# What research established (docs/RUNTIMES.md has the detail):
#   - binary `pi`, installed via: npm install -g --ignore-scripts @earendil-works/pi-coding-agent
#   - state lives in ~/.pi/agent/ (settings.json, auth.json)
#   - non-interactive: `pi -p/--print`, structured: `pi --mode json`, `pi --mode rpc`
#   - login is the IN-SESSION slash command `/login`; there is NO `pi login` subcommand.
#     `pi auth check` reads credential state.
#   - pi does NOT wrap the codex CLI. It reimplements Codex's OAuth with the same client
#     id and calls the Responses API directly, which is why models appear as
#     `openai-codex/<model>`.
#
# Two unrelated third-party team packages exist; neither is required by this adapter:
#   - `pi-agents-team`        (KristjanPikhof) — orchestrator + ephemeral RPC workers
#   - `@tmustier/pi-agent-teams` (tmustier)    — persistent leader + named teammates
# This skill drives plain `pi` sessions and keeps its own coordination protocol.

set -u
AT_SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bin/_common.sh
. "$AT_SELF_DIR/../bin/_common.sh"

rt_detect() {
  command -v pi >/dev/null 2>&1 || {
    echo "pi CLI not on PATH (install: npm install -g --ignore-scripts @earendil-works/pi-coding-agent)"
    return 1
  }
  if [ ! -f "$HOME/.pi/agent/auth.json" ]; then
    echo "pi CLI present but not authenticated (start 'pi' and run the /login slash command)"
    return 1
  fi
  echo "pi adapter is UNTESTED — verify a single role before trusting a fleet"
  return 0
}

rt_map_tier() {
  case "$1" in
    smol)    printf 'openai-codex/gpt-5.1-codex-mini' ;;
    regular) printf '' ;;
    smart)   printf '' ;;
    ultra)   printf '' ;;
    *)       printf '' ;;
  esac
}

# rt_launch <role> <prompt_file> <task> <log> <project> <layout> [tmux_target] [_] [model_tier]
rt_launch() {
  local role="$1" prompt_file="$2" task="$3" log="$4" project="$5" layout="$6"
  local tmux_target="${7:-}" _unused="${8:-}" model="${9:-}"
  # Arg 9 is an already-resolved model name; empty means "use the provider default".

  # pi has no documented system-prompt flag, so the role is folded into the prompt,
  # exactly as for Codex.
  local full_prompt
  full_prompt="$(cat "$prompt_file" 2>/dev/null)
---
TASK: $task"

  local model_args=""
  [ -n "$model" ] && model_args="--model $model"

  if [ "$layout" = "tmux" ]; then
    local sess="${tmux_target%%:*}" win="${tmux_target#*:}"
    local pf="$project/.agent-teams/prompts/.pi-$role.txt"
    printf '%s\n' "$full_prompt" >"$pf"
    # Generated launcher: safe against apostrophes in the prompt.
    local launcher="$project/.agent-teams/prompts/.launch-$role.sh"
    if [ -n "$model" ]; then
      at_write_launcher "$launcher" pi --model "$model" "$full_prompt" || return 1
    else
      at_write_launcher "$launcher" pi "$full_prompt" || return 1
    fi
    tmux new-window -d -t "$sess" -n "$win" -c "$project" "$launcher" || return 1
    tmux set-option -w -t "$tmux_target" remain-on-exit on 2>/dev/null || true
    tmux pipe-pane -o -t "$tmux_target" "cat >> '$log'" 2>/dev/null || true
    printf '%s' "$tmux_target"
    return 0
  fi

  # shellcheck disable=SC2086
  ( cd "$project" && pi --print --mode json $model_args "$full_prompt" \
      >>"$log" 2>&1 </dev/null ) &
  printf 'pid:%s' "$!"
}

rt_status() {
  # No documented session-listing interface. The generic pid/log collector in the
  # monitor covers pi roles; emit nothing rather than guess at a format.
  return 0
}

rt_stop() {
  local sid="$1" kill_flag="${2:-}"
  case "$sid" in
    pid:*)
      local pid="${sid#pid:}"
      if [ "$kill_flag" = "--kill" ]; then kill -9 "$pid" 2>/dev/null || true
      else kill -TERM "$pid" 2>/dev/null || true; fi
      ;;
  esac
  return 0
}

case "${1:-}" in
  detect)   rt_detect ;;
  map_tier) shift; rt_map_tier "$@" ;;
  launch)   shift; rt_launch "$@" ;;
  status)   shift; rt_status "$@" ;;
  stop)     shift; rt_stop "$@" ;;
  *) echo "usage: pi.sh {detect|map_tier|launch|status|stop}" >&2; exit 2 ;;
esac
