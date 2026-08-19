# The monitor

```bash
agent-teams monitor -C <project> [--port 8787] [--bind 127.0.0.1] [--refresh 2]
```

Python 3 stdlib only — no pip, no Node, nothing to install. Binds loopback and is
**read-only by construction**: the server defines no `do_POST`/`do_PUT`/`do_DELETE`, so
write methods return 501 rather than being rejected by a check that could be forgotten.

Reach it from a laptop through a tunnel:

```bash
ssh -L 8787:localhost:8787 user@server
```

Do not use `--bind 0.0.0.0` to skip the tunnel; there is no authentication.

## States

Precedence, loudest first. The ordering is the whole point: the dashboard exists to make
the states that need a human impossible to miss.

| State | Meaning | Who must act |
|---|---|---|
| `blocked` | Waiting on a permission prompt. **Never self-resolves.** | You |
| `errored` | Runtime failure — quota, auth, crash | You |
| `stopped` | Session ended | — |
| `working` | Actively producing | — |
| `idle` | Alive, nothing in flight | — |
| `unknown` | Declared in `team.yaml`, no live session | Maybe |

An unrecognised runtime state degrades to `unknown` **and** emits a warning naming the
value, so the dashboard never invents a state it does not understand.

## Where the data comes from

Three collectors, merged per role:

1. **`claude agents --json --all --cwd <project>`** — pid, status, state, session id. No
   TTY required.
2. **Session transcripts** — `~/.claude/projects/<slug>/<sessionId>.jsonl`, where `slug`
   is the absolute cwd with `/` and `.` replaced by `-`. Only the last 256 KB is read;
   these files reach tens of MB. A background agent may relocate into a git worktree, in
   which case its transcript lives under the *worktree's* slug — the collector falls back
   to a worktree glob, because checking only the project slug loses that content silently.
3. **Codex rollouts** — `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, matched on
   `session_meta.payload.cwd`, scanned for `type:"error"` / `turn.failed`.

Plus `docs/coordination/*.md` frontmatter for each role's declared `status`.

**`claude logs` is deliberately not used.** It replays the raw ANSI TUI stream — cursor
moves, synchronised-update markers, spinner frames, interleaved partial words — and does
not survive stripping, because the TUI redraws in place rather than appending lines.

## Design rules it follows

- **Never lie about state.** When the API is unreachable the page keeps the last known
  data behind a staleness banner rather than blanking; an empty table would read as
  "nothing running".
- **Show unmanaged sessions.** Live sessions in the project that no `team.yaml` role
  claims appear marked unmanaged. Hiding a blocked stray agent would be a lie by omission.
- **No layout thrash.** Rows are persistent elements updated via `textContent`, never
  rebuilt from `innerHTML` — so transcript text cannot inject markup, and the table does
  not flicker on each poll.
- **Read-only.** v1 observes; it does not send input. Intervene through tmux.

## Scripting

`agent-teams status --json` emits the same payload as `GET /api/state`:

```bash
agent-teams status --json | jq '.roles[] | select(.state=="blocked") | .role'
```
