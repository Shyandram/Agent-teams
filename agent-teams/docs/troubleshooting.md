# Troubleshooting

Symptoms first. Every entry here is a failure that actually happened during development,
not a hypothetical.

---

## A role never produces anything

Check `agent-teams status` first. The state tells you which of these it is.

### `blocked` — waiting on a permission prompt

This is the most common failure and it **never resolves on its own**: a background
session is asking a question no one can see.

Causes, in the order to check them:

1. **The command was not in the allowlist.** Look at what it tried:

   ```bash
   agent-teams status -C <project>          # the LAST column shows recent output
   ```

   Then add the command to `permissions.allow` in `<project>/.claude/settings.json`.

2. **The command was a chain.** `git add X && git commit -m "..."` does not match
   allowlist entries for `git add` or `git commit` — permission matching applies to the
   whole command. The contract tells roles to run one command per call; if a role keeps
   chaining, restate that rule in its task.

3. **The directory is not trusted.** `agent-teams doctor` reports this. Fix once:

   ```bash
   cd <project> && claude     # accept the prompt, then exit
   ```

   Trust inherits to subdirectories, so trusting a repo root covers everything under it.

4. **The settings-trust prompt is pending.** After `init` writes
   `.claude/settings.json`, the first *interactive* session asks you to confirm the
   pre-approved permissions. Answer it once in the tmux window.

### `errored` — the runtime failed

Usually quota. Codex reports:

```json
{"type":"error","message":"You've hit your usage limit. … try again at 11:39 AM."}
```

A quota-dead role looks idle from the outside; that is why the dashboard has a separate
`errored` state. Wait for the reset or switch the role's runtime in `team.yaml`.

### `unknown` — declared but never started

The role is in `team.yaml` with no live session. Either it was never launched, or its
launch failed — check `.agent-teams/logs/<role>.log`.

---

## The role committed, but I don't see the changes

A background agent may have moved itself into a git worktree and committed **there**:

```bash
git worktree list
ls <project>/.claude/worktrees/
```

Its work is on a side branch. Merging it is your decision — the skill will not merge for
you. `agent-teams stop --kill` removes the worktree, so inspect before using `--kill`.

---

## `--layout tmux` fails or the window disappears

- **"requires tmux, which is not installed"** — install it (`apt install tmux` /
  `brew install tmux`), or use `--layout bg`, which needs nothing.
- **The window vanishes immediately** — a window closes when its command exits. The
  adapters set `remain-on-exit on` so failures stay readable:

  ```bash
  tmux capture-pane -p -t at_<project>:<role> | tail -20
  ```

- **Do not add `| tee` to the launch command.** Piping removes the TTY, which makes the
  CLI run non-interactively and exit. Logging goes through `tmux pipe-pane`.

---

## The dashboard shows nothing / stale data

- Confirm the API directly:

  ```bash
  curl -s localhost:8787/api/state | head -40
  ```

- **A banner saying data is stale is deliberate.** When the API is unreachable the page
  keeps showing the last known state rather than blanking — an empty table would imply
  "nothing running", which would be a lie.
- Reaching it from a laptop needs the tunnel; the server binds loopback on purpose:

  ```bash
  ssh -L 8787:localhost:8787 user@server
  ```

- If a role's `LAST` column is empty but the role is alive, its transcript may sit under a
  worktree slug. That is handled, but a brand-new session has no assistant text yet.

---

## A role appears twice in the dashboard

Rows marked unmanaged (`managed: false`) are live sessions in the project that no
`team.yaml` role claims — usually leftovers from an earlier run. Clear them:

```bash
claude agents --json --all --cwd <project>
claude stop <id> && claude rm <id>
```

They are shown rather than hidden deliberately: silently dropping a blocked agent would
make the dashboard misleading.

---

## `init` refuses to run

```
error these already exist: AGENTS.md .agent-teams/team.yaml
```

By design — it will not overwrite work. Use `--force`, or init into a different
directory. Nothing is written when it refuses.

---

## Everything is slow / too expensive

Pin every Claude role to one model:

```bash
AGENT_TEAMS_MODEL=sonnet agent-teams launch
```

Or set `model_tier: regular` (or `smol`) per role in `team.yaml`.

---

## `pi` roles do not work

Expected. The pi adapter is **untested** — pi was not installed during development.
`doctor` says so. Verify a single pi role by hand before trusting a fleet to it.
