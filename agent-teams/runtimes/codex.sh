#!/usr/bin/env bash
# Runtime adapter: OpenAI Codex CLI.
# Contract: docs/INTERFACES.md section 6.  Behaviour verified: docs/SPIKE-FINDINGS.md.
#
# Codex has NO --system-prompt flag. Role text is prepended to the task prompt, and the
# project's AGENTS.md is picked up natively by Codex's own AGENTS.md discovery.

set -u
AT_SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bin/_common.sh
. "$AT_SELF_DIR/../bin/_common.sh"

rt_detect() {
  command -v codex >/dev/null 2>&1 || { echo "codex CLI not on PATH"; return 1; }
  if [ ! -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
    echo "codex CLI present but not authenticated (run: codex login)"
    return 1
  fi
  return 0
}

rt_map_tier() {
  # Codex resolves its own defaults from ~/.codex/config.toml; empty means "use default".
  case "$1" in
    smol)    printf 'gpt-5.1-codex-mini' ;;
    regular) printf '' ;;
    smart)   printf '' ;;
    ultra)   printf '' ;;
    *)       printf '' ;;
  esac
}

# rt_launch <role> <prompt_file> <task> <log> <project> <layout> [tmux_target] [sandbox] [model_tier]
rt_launch() {
  local role="$1" prompt_file="$2" task="$3" log="$4" project="$5" layout="$6"
  local tmux_target="${7:-}" sandbox="${8:-workspace-write}" tier="${9:-regular}"
  local model; model="$(rt_map_tier "$tier")"

  # No --system-prompt exists: fold the role into the prompt itself.
  local full_prompt
  full_prompt="$(cat "$prompt_file" 2>/dev/null)
---
TASK: $task"

  local model_args=""
  [ -n "$model" ] && model_args="-m $model"

  if [ "$layout" = "tmux" ]; then
    local sess="${tmux_target%%:*}" win="${tmux_target#*:}"
    local pf="$project/.agent-teams/prompts/.codex-$role.txt"
    printf '%s\n' "$full_prompt" >"$pf"
    # No `tee`: piping would drop the TTY and turn this into a one-shot run.
    # shellcheck disable=SC2086
    tmux new-window -d -t "$sess" -n "$win" -c "$project" \
      "codex --sandbox '$sandbox' $model_args \"\$(cat '$pf')\"" \
      || return 1
    tmux set-option -w -t "$tmux_target" remain-on-exit on 2>/dev/null || true
    tmux pipe-pane -o -t "$tmux_target" "cat >> '$log'" 2>/dev/null || true
    printf '%s' "$tmux_target"
    return 0
  fi

  # Headless. stdin MUST be /dev/null or codex waits on stdin (verified).
  # shellcheck disable=SC2086
  ( cd "$project" && codex exec --json \
      --sandbox "$sandbox" \
      -C "$project" \
      --skip-git-repo-check \
      $model_args \
      -o "$project/.agent-teams/logs/$role.last.txt" \
      "$full_prompt" >>"$log" 2>&1 </dev/null ) &
  local pid=$!
  printf 'pid:%s' "$pid"
}

# rt_status <project> -> role<TAB>state<TAB>session_id
# Codex has no session-list command, so we read its rollout files.
rt_status() {
  local project="$1"
  python3 - "$project" <<'PY'
import glob, json, os, sys, time
project = sys.argv[1]
home = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
cutoff = time.time() - 7 * 86400
for path in glob.glob(os.path.join(home, "sessions", "*", "*", "*", "rollout-*.jsonl")):
    try:
        if os.path.getmtime(path) < cutoff:
            continue
        with open(path, "r", errors="replace") as fh:
            first = fh.readline()
            meta = json.loads(first)
            if (meta.get("payload") or {}).get("cwd") != project:
                continue
            sid = (meta.get("payload") or {}).get("session_id") or ""
            state = "idle"
            for line in fh:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                t = rec.get("type")
                if t in ("error", "turn.failed"):
                    state = "errored"
                elif t == "turn.started" and state != "errored":
                    state = "working"
                elif t == "turn.completed" and state == "working":
                    state = "idle"
            print("\t".join(["", state, sid]))
    except Exception:
        continue
PY
}

rt_stop() {
  local sid="$1" kill_flag="${2:-}"
  # sid may be "pid:NNNN" for headless launches.
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
  *) echo "usage: codex.sh {detect|map_tier|launch|status|stop}" >&2; exit 2 ;;
esac
