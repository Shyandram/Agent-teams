# Hooks

Scripts here run when a role enters a state that needs attention. Without them the
dashboard shows a wedged agent and nothing happens until you notice.

Enable one by copying off the `.sample` suffix and making it executable:

    cp on_blocked.sample on_blocked && chmod +x on_blocked

| Hook | Fires when |
|---|---|
| `on_blocked` | waiting on a permission prompt — never self-resolves |
| `on_errored` | runtime failure: quota, auth, crash |
| `on_stalled` | alive but nothing new for `AGENT_TEAMS_STALL_SECONDS` (default 600) |
| `on_idle` | finished a turn and went quiet |
| `on_done` | reported `status: done` in its result block |

Each is run with the role name as `$1` and this environment:

    AT_ROLE  AT_STATE  AT_RUNTIME  AT_PROJECT  AT_SESSION_ID
    AT_IDLE_SECONDS  AT_TOKENS  AT_LAST_TEXT  AT_RESULT

Behaviour worth knowing:

- **Edge-triggered.** A hook fires when a role *enters* a state, not on every poll —
  otherwise a 2s poll would fire hundreds of times for one stuck agent.
- **Never blocks the dashboard.** Hooks run detached with a 20s timeout; a hook that
  hangs is killed and reported as a warning.
- **Failures are surfaced, not swallowed.** A non-zero exit shows up in the dashboard's
  warnings, because a silently broken hook is worse than no hook.
- Hooks run with the project as their working directory.

Keep them fast and side-effect-light. A hook that takes an expensive or irreversible
action on its own is how an unattended fleet does something you did not intend — the
samples deliberately leave those lines commented out.
