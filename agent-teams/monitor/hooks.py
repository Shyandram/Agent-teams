#!/usr/bin/env python3
"""Fire a hook when a role enters a state that needs attention.

A dashboard that shows a wedged agent and does nothing still requires a human to be
watching it. Hooks close that loop: they turn an observed state into an action.

Hooks are plain executables in the project:

    .agent-teams/hooks/on_blocked      a role is waiting on a permission prompt
    .agent-teams/hooks/on_errored      the runtime failed (quota, auth, crash)
    .agent-teams/hooks/on_stalled      alive but nothing new for N seconds
    .agent-teams/hooks/on_idle         finished a turn and went quiet
    .agent-teams/hooks/on_done         a role reported status: done

Each is invoked with the role name as argv[1] and this environment:

    AT_ROLE AT_STATE AT_RUNTIME AT_PROJECT AT_SESSION_ID
    AT_IDLE_SECONDS AT_TOKENS AT_LAST_TEXT AT_RESULT

Design rules, learned the hard way:
  * Edge-triggered. A hook fires when a role ENTERS a state, not every poll -- a
    2s poll would otherwise fire hundreds of times for one stuck agent.
  * Never blocks the dashboard. Hooks run detached with a hard timeout; a hook that
    hangs or fails is reported as a warning and never stalls collection.
  * Off unless the file exists. No config to enable, nothing to forget.
  * Non-zero exit is surfaced, not swallowed -- a silently failing hook is worse
    than no hook.
"""

import os
import subprocess
import time

HOOK_STATES = ("blocked", "errored", "stalled", "idle", "done")

# A hook gets this long before it is killed. Long enough to curl a webhook,
# short enough that a hung hook cannot pile up across polls.
HOOK_TIMEOUT_SECONDS = 20

# How long without transcript movement counts as stalled.
DEFAULT_STALL_SECONDS = 600

_last_state = {}      # role -> state we last fired for
_running = []         # (Popen, role, hook_name, deadline)


def hooks_dir(project):
    return os.path.join(project, ".agent-teams", "hooks")


def _hook_path(project, state):
    p = os.path.join(hooks_dir(project), "on_%s" % state)
    return p if os.path.isfile(p) and os.access(p, os.X_OK) else None


def _effective_state(row, stall_seconds):
    """Map a role row to the state hooks care about, or None."""
    state = row.get("state")
    if state in ("blocked", "errored"):
        return state
    result = row.get("result_block") or ""
    if "status: done" in result.replace("  ", " "):
        return "done"
    idle = row.get("idle_seconds")
    if state in ("working", "idle") and isinstance(idle, (int, float)):
        if idle >= stall_seconds:
            return "stalled"
    if state == "idle":
        return "idle"
    return None


def reap(warnings=None):
    """Collect finished hooks. Called every poll; never blocks."""
    still = []
    now = time.time()
    for proc, role, name, deadline in _running:
        rc = proc.poll()
        if rc is None:
            if now > deadline:
                try:
                    proc.kill()
                except Exception:
                    pass
                if warnings is not None:
                    warnings.append("hook %s for %s timed out after %ds"
                                    % (name, role, HOOK_TIMEOUT_SECONDS))
            else:
                still.append((proc, role, name, deadline))
            continue
        if rc != 0 and warnings is not None:
            warnings.append("hook %s for %s exited %d" % (name, role, rc))
    _running[:] = still


def fire(project, rows, warnings=None, stall_seconds=None):
    """Fire hooks for roles that have just entered an actionable state."""
    if stall_seconds is None:
        try:
            stall_seconds = int(os.environ.get("AGENT_TEAMS_STALL_SECONDS")
                                or DEFAULT_STALL_SECONDS)
        except ValueError:
            stall_seconds = DEFAULT_STALL_SECONDS

    reap(warnings)
    if not os.path.isdir(hooks_dir(project)):
        return

    for row in rows or []:
        role = row.get("role")
        if not role:
            continue
        state = _effective_state(row, stall_seconds)
        previous = _last_state.get(role)

        # Edge-triggered: only on entering a new state.
        if state == previous:
            continue
        _last_state[role] = state
        if not state:
            continue

        path = _hook_path(project, state)
        if not path:
            continue

        env = dict(os.environ)
        env.update({
            "AT_ROLE": str(role),
            "AT_STATE": str(state),
            "AT_RUNTIME": str(row.get("runtime") or ""),
            "AT_PROJECT": str(project),
            "AT_SESSION_ID": str(row.get("session_id") or ""),
            "AT_IDLE_SECONDS": str(int(row.get("idle_seconds") or 0)),
            "AT_TOKENS": str(row.get("tokens_total") or 0),
            "AT_LAST_TEXT": (row.get("last_text") or "")[:2000],
            "AT_RESULT": (row.get("result_block") or "")[:2000],
        })
        try:
            proc = subprocess.Popen(
                [path, str(role)],
                cwd=project, env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            _running.append((proc, role, os.path.basename(path),
                             time.time() + HOOK_TIMEOUT_SECONDS))
        except Exception as exc:
            if warnings is not None:
                warnings.append("could not run hook %s for %s: %s"
                                % (os.path.basename(path), role, exc))


def reset():
    """Forget remembered states (for tests)."""
    _last_state.clear()
