# Runtimes

One team can span CLIs. Runtime is a per-role setting in `.agent-teams/team.yaml`, so the
general can be Claude Code while workers run on Codex, or the reverse.

| Runtime | Status | Role injection | Session listing |
|---|---|---|---|
| `claude-code` | Verified end to end | `--append-system-prompt-file` | `claude agents --json` |
| `codex` | Integration verified; full write test blocked by a usage limit | Prompt prefix + native `AGENTS.md` | rollout JSONL scan |
| `pi` | **Untested** | Prompt prefix | none |

## Cross-runtime teams

```bash
agent-teams init --kind app-dev --general lead \
    --runtime claude-code \
    --runtime-for qa=codex \
    --runtime-for devops=codex
```

The **general** is the seat you occupy. `launch` skips it by default — you are already
running it — and starts the rest. `--include-general` overrides that.

Change assignments later by editing `team.yaml`; no re-init needed.

### Why mix at all

- **Different strengths per role.** Give implementation to one, review to another.
- **Independent quotas.** When one provider rate-limits, the other roles keep working.
  A quota-dead role shows as `errored`, not `idle`.
- **Whatever you are already sitting in can be the general.** The skill does not care
  which CLI launched it.

## `model_tier` — portable model intent

Roles declare intent, not vendor model names:

| Tier | claude-code | codex |
|---|---|---|
| `smol` | haiku | gpt-5.1-codex-mini |
| `regular` | sonnet | provider default |
| `smart` | opus | provider default |
| `ultra` | opus | provider default |

`AGENT_TEAMS_MODEL=sonnet` overrides every tier for Claude roles — useful for cost
control and for testing a fleet cheaply.

---

## claude-code

Role text goes in via `--append-system-prompt-file`, so it **augments** the base system
prompt rather than replacing it. `init` also writes `.claude/agents/<role>.md`, which is
what native (Mode A) teammates read.

Per-role policy is `permission_mode`. Note that `acceptEdits` does **not** cover `Bash`,
which is why `init` writes a `permissions.allow` list.

Things worth knowing, all verified:

- `--session-id` is ignored for `--bg`; the id must be read back from the output.
- Background agents may relocate into `.claude/worktrees/<name>/` and commit there.
- `claude logs <id>` replays raw ANSI TUI redraws and is not machine-readable. Read the
  session transcript JSONL instead.
- Undocumented but real: `claude attach|logs|stop|rm <id>`.

## codex

Codex has **no `--system-prompt` flag**. Two consequences shape the design:

1. Role text is prepended to the task prompt.
2. Codex reads `AGENTS.md` natively, walking from the project root down to the cwd. The
   shared contract *is* its instruction channel — no glue needed. This is why `init`
   keeps `AGENTS.md` under 32 KB: Codex truncates past 32 KiB.

Per-role policy is `sandbox` (`read-only` / `workspace-write` / `danger-full-access`).
Every role needs `workspace-write` because every role must write a coordination note.

Headless spawns must redirect stdin from `/dev/null`, or `codex exec` waits on stdin.

Codex has no session-list command, so status comes from scanning
`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` and matching `session_meta.payload.cwd`.

## pi

**The adapter is untested.** pi was not installed on the development machine, so every
code path in `runtimes/pi.sh` is written from documentation and source reading, never
observed. `doctor` says so. Verify one role by hand before trusting a fleet to it.

What research established:

- Binary `pi`, from `@earendil-works/pi-coding-agent`; state in `~/.pi/agent/`
- Non-interactive `pi -p/--print`; structured `--mode json`, `--mode rpc`
- There is **no `pi login` subcommand** — login is the in-session `/login` command.
  `pi auth check` reads credential state.
- **pi does not wrap the `codex` CLI.** It reimplements Codex's OAuth flow with the
  byte-identical client id `app_EMoamEEZ73f0CkXaXp7hrann` and calls the Responses API
  directly, which is why its models appear as `openai-codex/<model>`. An
  `auth.openai.com/oauth/authorize?...&originator=pi` URL is a pi login artifact.

Two unrelated third-party team packages exist and neither is required here:
`pi-agents-team` (KristjanPikhof — orchestrator plus ephemeral RPC workers) and
`@tmustier/pi-agent-teams` (tmustier — persistent leader plus named teammates). This
skill drives plain `pi` sessions and keeps its own coordination protocol.

---

## Adding a runtime

Drop `runtimes/<name>.sh` implementing five verbs — `detect`, `map_tier`, `launch`,
`status`, `stop` — per `docs/INTERFACES.md` section 6. Then use
`--runtime-for <role>=<name>`.

Three rules every adapter must honour:

- Redirect stdin from `/dev/null` on headless spawns.
- Never use `timeout(1)` — absent on macOS.
- In tmux windows, never pipe the CLI through `tee`: that removes the TTY and turns an
  interactive session into a one-shot run that exits. Use `tmux pipe-pane -o`.
