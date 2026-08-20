# Spike findings — verified runtime behaviour

Empirically established on 2026-08-20 against `claude` v2.1.236, `codex` v0.147.0,
`tmux` 3.7c, macOS (darwin 25.5.0). **Every claim below was observed, not inferred
from documentation.** Implementation must follow these, not the docs, where they differ.

## Claude Code — Mode B (background fleet)

### Works

| Behaviour | Evidence |
|---|---|
| `claude --bg "<prompt>"` returns immediately, prints short session id | `backgrounded · fe98f3d0` |
| `--append-system-prompt-file <f>` injects the role | Transcript contained `[ENGINEERING] Simple file creation…`, the exact prefix the role file demanded |
| `claude agents --json --all --cwd <P>` needs no TTY | Returned `{"id","name","status","state","kind","pid","sessionId","cwd","startedAt"}` |
| `claude stop <short-id>` stops cleanly | `stopped fe98f3d0`, then `state:"stopped"` |
| Undocumented subcommands exist | `claude attach <id>`, `claude logs <id>`, `claude stop <id>` — printed by `--bg`, absent from `claude --help` Commands |

Observed `status` values: `busy`, `idle`, `waiting`, `null`.
Observed `state` values: `working`, `blocked`, `stopped`.

**`state:"blocked"` + `status:"waiting"` means the agent is sitting on a permission
prompt and will never progress on its own.** This is the single most important signal
the monitor renders.

### Does NOT work — workspace trust is a hard prerequisite

A `--bg` session in an **untrusted directory blocks on its first write**, and it does so
*even with* `--permission-mode acceptEdits --allowedTools Write Edit`. It stalls on:

```
Do you want to create spike_proof.txt?
  1. Yes   2. Yes, and allow Claude to edit its own settings   3. No
```

Root cause confirmed from `~/.claude.json`:

```
/Users/.../tmp/spike-claude          hasTrustDialogAccepted: false   ← blocked
/Users/.../files/Projects/Skills     hasTrustDialogAccepted: true    ← fine
```

**Implications, all mandatory:**

1. `doctor` MUST read `~/.claude.json → .projects["<abs path>"].hasTrustDialogAccepted`
   and report it.
2. `launch --mode bg` MUST refuse to start with a clear message when the project is
   untrusted, rather than spawning agents that silently wedge.
3. The skill MUST NOT flip that flag itself. It is a security control; the user trusts a
   directory by opening `claude` in it once, interactively. Auto-setting it would defeat
   the control and is out of scope.

### `claude logs` is NOT a usable content feed

`claude logs <id>` replays the **raw ANSI TUI stream** — cursor moves, `[?2026h`
synchronised-update markers, spinner frames, and interleaved partial words
(`erusng…`, `✢g(1s · ↓6 tokens)`). Stripping ANSI yields unreadable soup because the
TUI redraws in place rather than appending lines.

**Use the session transcript instead** (verified clean):

```
~/.claude/projects/<slug>/<sessionId>.jsonl
slug = absolute cwd with every '/' and '.' replaced by '-'
  ~/.claude/jobs/<job>/tmp/spike-claude
  → -Users-wengshyangen--claude-jobs-1c096578-tmp-spike-claude
```

Typed JSONL records observed: `assistant`, `user`, `attachment`, `mode`,
`permission-mode`, `agent-name`, `ai-title`, `last-prompt`, `file-history-snapshot`,
`atis-latch`.

Clean assistant text extraction:

```bash
jq -r 'select(.type=="assistant") | .message.content[]?
       | select(.type=="text") | .text' "$F" | tail -1
```

This path works identically for interactive, background, and native-teammate sessions,
so one collector serves all three.

## Codex — Mode B

### Verified

- Flags parse and are honoured: `--json`, `-C/--cd`, `-s/--sandbox`, `-o/--output-last-message`, `--skip-git-repo-check`
- Emits well-formed JSONL to stdout with a top-level `type`:
  `thread.started`, `turn.started`, `turn.failed`, `error`
- **Must redirect stdin**: without `< /dev/null` it prints
  `Reading additional input from stdin...` and waits. Every spawn needs `< /dev/null`.

### Verified end to end (2026-08-20, after the quota reset)

`codex exec --json -s workspace-write --skip-git-repo-check -C <dir> -o <file>` wrote the
requested file and exited 0. Event stream:

```
thread.started · turn.started · item.started · item.completed x3 · turn.completed
```

Note `item.started` / `item.completed` — absent from the first round, which only saw the
failure path. Any state mapping must tolerate unrecognised event types rather than
assuming the set is closed.

Then through the skill: a `codex` role launched with `agent-teams launch`, produced a
correct coordination note with valid frontmatter (`status: complete`), emitted a
`<result>` block, and was bound to its role by the monitor. `close` reported it in the
closeout table. Two bugs were found doing this and are fixed — see below.

**The earlier quota failure remains a finding in its own right:** exhaustion is a silent
fleet-failure mode, and the monitor must surface `type:"error"` / `turn.failed` as a
distinct `errored` state or a quota-dead role reads as merely idle.

## Findings from end-to-end testing (second round)

Everything below was discovered by running real fleets, not by reading docs. Each one
was a live bug in this skill before it was fixed.

### Workspace trust INHERITS to subdirectories

An exact-path check against `~/.claude.json` produces false refusals. A subdirectory of a
trusted project runs unblocked (verified: a fresh subdir of a trusted repo completed a
write with no prompt). `at_project_is_trusted` walks up ancestors.

### `acceptEdits` does not cover Bash

`--permission-mode acceptEdits` auto-accepts *edits* but still prompts on `Bash`. Since
most roles carry `Bash`, a background fleet wedges immediately. The fix is an explicit
`.claude/settings.json` `permissions.allow` list written by `init` — least-privilege and
auditable, unlike a blanket bypass.

### Permission matching is per whole command, so command chains defeat the allowlist

`git add X && git commit -m "$(cat <<'EOF' ...)"` does **not** match entries allowing
`git add` and `git commit` individually — it is one unapproved command, and the session
stops forever. Allowlisting every compound form is unwinnable, so the contract instructs
roles to issue **one command per call**, avoiding `&&`, `||`, and `$(...)`.

### Writing `.claude/settings.json` adds a one-time settings-trust prompt

The first *interactive* session after `init` shows "This folder pre-approves N tool
permissions … Only proceed if you trust this configuration." A human answers it once. It
is a consequence of shipping the allowlist and is worth the trade, but it means the first
`--layout tmux` launch needs one keystroke.

### Background agents relocate into a git worktree

A backgrounded agent may call `EnterWorktree` itself and then work and commit inside
`.claude/worktrees/<name>/`. Two consequences:

1. **Its transcript moves.** It lands under the *worktree's* slug directory
   (`-Users-me-proj--claude-worktrees-<name>`), not the project's. Resolving only the
   project slug silently loses the content of every worktree-based agent, so
   `transcript_path()` falls back to a worktree glob.
2. **Its work is on a side branch**, not in the main working tree. Do not report a role's
   output as landed without checking where it committed.

### `--session-id` is ignored for `--bg`

The backgrounded session gets a fresh id regardless. The id must be read back — from the
`backgrounded · <id> · <name>` line (field 3, *not* `$NF`, since `-n` appends the name)
and then resolved to a full UUID via `claude agents --json`.

### More undocumented subcommands

`claude rm <id>` removes a stopped session's retained worktree and job state. `claude
stop` deliberately retains the worktree so unmerged work is not lost. State takes a few
seconds to settle after `stop`, so do not re-read status immediately.

### `claude agents` emits `state: "done"`

Absent from the first round of findings. Unmapped values must degrade to `unknown` *and*
emit a warning naming the value, so the dashboard never silently invents a state.
`startedAt` is epoch **milliseconds**.

### Piping a tmux window through `tee` destroys the interactive session

`tmux new-window "claude ... | tee -a log"` makes stdout a pipe rather than a TTY, so the
CLI runs non-interactively, completes, exits, and tmux tears the window down — the exact
opposite of what the tmux layout is for. Log with `tmux pipe-pane -o` instead, which
copies output without touching the TTY, and set `remain-on-exit on` so a failed window
stays readable.

### bash 3.2 mis-parses a heredoc inside `$( )`

Stock macOS ships bash 3.2, and

    x="$(python3 - "$f" <<'PY'
    ...
    PY
    )"

fails to parse there, with the error reported far downstream in an unrelated function —
which makes it genuinely hard to locate. Run the heredoc on its own, redirect to a file,
and read the file back. This is a real constraint of the stated bash-3.2 portability
contract, not a style preference.

### `basename | tr -c` mangles the trailing newline

`tr -c 'A-Za-z0-9_-' '_'` rewrites the trailing newline into `_`, producing session names
like `at__proj_`. Strip the newline with `printf '%s'` before translating.

## Environment

- `timeout(1)` is absent on macOS. Do not use it in the CLI; use backgrounding + polling.
- `tmux` 3.7c present (≥3.5, so `extended-keys` is available).
- `pi` NOT installed — its adapter ships untested and must say so.
- `jq` present, but the CLI must not require it; the monitor uses Python stdlib.

## Net effect on the design

| Plan assumption | Reality | Action |
|---|---|---|
| `claude logs` feeds the monitor | ANSI soup | Read session transcript JSONL |
| Per-role permission config suffices | Trust gates it first | Add trust precheck to `doctor` + `launch` |
| Codex verifiable now | Quota-limited | Defer step 3; add "errored" state |
| `timeout` available | macOS lacks it | Poll instead |

## Findings from the Codex verification round

### A `pid:` placeholder is truthy, and that made Codex roles unbindable

The launcher records `session_id: "pid:<n>"` for a headless Codex role, because Codex has
no session id until its first rollout file lands. The monitor's claim path was guarded by
`if rollout is None and not (short_id or full_id)` — and the placeholder is truthy, so the
guard never opened. Every Codex role stayed `unknown` while its own rollout appeared
beside it as an unmanaged orphan. Fixed with an explicit `_is_codex_session_id()` that
treats a `pid:` value as absent.

### "Started after the role did" is too brittle to match a rollout

The fallback also skipped any rollout whose start was more than 60s before the role's
recorded `started_at`. Observed in practice: the rollout began **67 seconds before** the
session file's timestamp — the two come from different clocks and different moments. The
hard cutoff left the role permanently unbound. Replaced with nearest-match: claim the
unclaimed rollout for this project whose start is closest to the role's.

Both bugs share a shape worth remembering: a placeholder that is truthy, and a threshold
that assumed two clocks agree.
