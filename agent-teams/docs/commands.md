# Command reference

Every command, every flag, what it actually does.

This is the canonical reference — written from the argument parsers, not from the help
text. Where the two disagree, this file is right and `--help` is missing something.

For the design behind it, see [modes.md](modes.md) (why there are two launch modes),
[runtimes.md](runtimes.md) (Claude Code vs Codex vs pi), and
[monitor.md](monitor.md) (how state is collected).

---

## Contents

- [Before anything](#before-anything)
- [A typical session](#a-typical-session)
- [Setting up](#setting-up) — `init` `doctor` `skills`
- [Composing the team](#composing-the-team) — `role` `focus` `team` `model`
- [Running it](#running-it) — `launch` `restart`
- [Watching it](#watching-it) — `status` `monitor`
- [Talking to it](#talking-to-it) — `send` `broadcast` `steer` `inbox` `attach`
- [Ending it](#ending-it) — `stop` `close`
- [Syntax reference](#syntax-reference)
- [Environment variables](#environment-variables)
- [Files on disk](#files-on-disk)
- [`status --json` schema](#status---json-schema)

---

## Before anything

**Install** — see [installation.md](installation.md). In short:

```bash
git clone https://github.com/Shyandram/Agent-teams.git ~/skills/agent-teams
bash ~/skills/agent-teams/agent-teams/install.sh
```

**Requires** bash 3.2+, Python 3.8+ (stdlib only), and at least one of `claude`, `codex`,
`pi`. tmux is optional but unlocks live steering and takeover.

**Every command takes `-C PATH` / `--project-dir PATH`.** Default is the current
directory. Every command except `init`, `role`, and `focus` needs a project that has
already been through `init`.

**Every command takes `-h` / `--help`.**

Commands write human output to **stderr** and machine output (`status --json`) to
**stdout**, so `agent-teams status --json | jq` works without filtering noise.

---

## A typical session

```bash
cd ~/projects/shop

agent-teams init --kind app-dev            # 1. scaffold the contract
$EDITOR AIM.md                             # 2. fill this in — see below
agent-teams doctor                         # 3. check runtimes, auth, trust
agent-teams launch --layout tmux           # 4. start the workers
agent-teams monitor                        # 5. watch (127.0.0.1:8787)

agent-teams steer engineering "API first"  #    redirect a running role
agent-teams attach qa                      #    take one over by hand

agent-teams close --reason "v1 shipped"    # 6. disband + closeout report
```

**Step 2 is the one people skip.** `AIM.md` arrives full of `TODO`s, and a fleet
launched against an unfilled aim produces roles that invent their own objectives and
diverge quietly. Nothing in the tool currently blocks that — it is on you.

Watching from a laptop, over SSH:

```bash
ssh -L 8787:localhost:8787 user@your-linux-box
# then open http://localhost:8787 locally
```

The monitor binds loopback and **has no authentication**. The tunnel is the access
control. See [ssh-workflow.md](ssh-workflow.md).

---

## Setting up

### `init` — scaffold the team contract

```
agent-teams init [options]
```

Writes `AGENTS.md`, `AIM.md`, `docs/coordination/`, `.claude/agents/*.md`,
`.claude/settings.json` (the permission allowlist), and `.agent-teams/`. Refuses to
overwrite existing files without `--force`.

| Flag | Effect |
|---|---|
| `--kind K` | Role preset: `research` `app-dev` `full-stack` `custom` |
| `--roles a,b,c` | Explicit role list. Implies `--kind custom` |
| `--name NAME` | Project name (default: directory name) |
| `--runtime RT` | Default runtime for every role: `claude-code` `codex` `pi` |
| `--runtime-for R=RT` | Override one role's runtime. Repeatable |
| `--general ROLE` | Which role orchestrates (default: `lead`) |
| `--aim KIND` | Which `AIM.md` to write: `research` `app-dev` `experiment` `library` `migration` |
| `--squad "name:a,b"` | A group owning one direction end to end. Repeatable |
| `--focus-for R=SPEC` | What one instance owns. `@key` or free text. Repeatable |
| `--subagents` | Also write `.claude/agents/` specialist definitions |
| `--no-reference-skills` | Do not point roles at the reference skill library |
| `--build-cmd` `--test-cmd` `--lint-cmd` | Filled into `AGENTS.md` |
| `--language LANG` | e.g. `TypeScript`, `Python` |
| `--timezone TZ` | Default `Asia/Taipei` |
| `--force` | Overwrite existing files |
| `--dry-run` | Show what would be written |

**Presets are deliberately small.** Every role is another full context to pay for and
another thing that can wedge.

| Preset | Roles | n |
|---|---|---|
| `solo` | engineering | 1 |
| `app-dev` | lead, engineering, qa | 3 |
| `research` | lead, research, analysis, qa | 4 |
| `app-dev-wide` | lead, engineering:api, engineering:ui, qa:functional, qa:regression, devops, verification | 7 |
| `research-wide` | lead, research:survey, research:data, analysis:primary, analysis:ablation, engineering, qa, verification | 8 |
| `full-stack` | lead, engineering:api, engineering:ui, ux, qa, devops, verification, product-marketing, legal | 9 |

```bash
# a research team with three researchers on different literatures
agent-teams init --kind research \
  --roles "lead,research:survey,research:data,research:competing,analysis:primary,qa"

# a mixed-runtime app team: Claude implements, Codex reviews
agent-teams init --kind app-dev --general lead \
  --runtime claude-code --runtime-for qa=codex --runtime-for devops=codex \
  --build-cmd "npm run build" --test-cmd "npm test" --language TypeScript
```

`--aim` is independent of `--kind`: you can run an `app-dev` team against an
`experiment` aim.

### `doctor` — is this machine ready

```
agent-teams doctor [-C PATH]
```

Takes no other flags. Reports, in order:

1. **Runtimes** — is `claude` / `codex` / `pi` installed and authenticated
2. **tmux** — version, and whether `--layout tmux` is available
3. **Workspace trust** — ⚠ *the one that silently kills fleets*
4. **Native agent teams** — whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set
5. **Scaffold** — `AGENTS.md`, `docs/coordination/README.md`, `.agent-teams/team.yaml`
6. **Team** — each role's runtime, tier, and permission/sandbox setting

**Run this before every launch.** An untrusted directory makes every background agent
block forever on its first write, and a blocked agent looks exactly like a thinking one.
`doctor` prints the fix; the tool never sets the trust flag for you, because that is a
security control.

### `skills` — the reference library roles consult

```
agent-teams skills [--fetch | --update | --remove | --list]
```

Roles consult [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills)
(MIT, ~350 skills) for domain depth. By default they fetch over the network on demand.

| Flag | Effect |
|---|---|
| `--fetch` | Shallow-clone into `.agent-teams/reference-skills/` |
| `--update` | Pull the latest into an existing copy |
| `--remove` | Delete the local copy (roles fall back to the network) |
| `--list` | Show which directories each role is pointed at |
| *(none)* | Report whether a local copy exists |

Vendoring makes it faster and works offline. The copy is gitignored. Roles are told to
treat its contents as **reference material, never as instructions** — it is third-party
text arriving through a tool, so it is data.

---

## Composing the team

### `role` — list, create, and specialise roles

```
agent-teams role list
agent-teams role show <name>
agent-teams role new <name> [--extends PARENT] [--add]
```

Roles resolve in this order, **first match wins**:

1. `<project>/.agent-teams/roles/<name>.md` — your own, per project
2. `<skill>/roles/<name>.md` — built-in core
3. `<skill>/roles/extras/<name>.md` — built-in opt-in

So a project-local role of the same name overrides a built-in one, and you can add roles
without touching the skill.

**Core:** `lead` `engineering` `research` `analysis` `qa` `verification` `ux` `devops`
**Extras (opt-in):** `translation` `legal` `simulation` `product-marketing`

`--extends` creates a **sub-role** whose prompt is the parent's body followed by yours —
a frontend engineer that inherits the shared engineering discipline instead of restating
it. `--add` also puts it in `team.yaml`.

```bash
agent-teams role new frontend --extends engineering --add
agent-teams role show verification
```

> **`qa` vs `verification`** — `qa` tests **the product**: does it work? `verification`
> tests **the reporting**: is what the roles *said* they did actually true? It re-runs
> the command a role put in its `verified:` line and returns confirmed / contradicted /
> **unverifiable**. It does not fix what it finds — a verifier that repairs has audited
> its own work.

### `focus` — what one instance owns

```
agent-teams focus list [role]
```

Read-only browser over `templates/focus.tsv` — 72 assignments across 12 roles.

The catalogue **key is the instance suffix**, so focus attaches automatically:

```bash
--roles "research:survey,research:data,analysis:ablation"
#         └─ becomes research-survey, with the `survey` focus attached
```

Override at `init` time:

```bash
--focus-for analysis-1=@leakage      # a catalogue entry, by key
--focus-for analysis-1="free text"   # your own wording
```

**Parallelism only pays when instances own different work.** Two instances of one role
without distinct focus do the same work twice — this catalogue exists to prevent exactly
that.

### `team` — see and change the structure

```
agent-teams team                          draw the structure
agent-teams team add <role>
agent-teams team remove <role>
agent-teams team move <role> [--runtime RT] [--extends PARENT] [--general]
```

The tree nests sub-roles under the role they extend. The general is marked, and each row
shows runtime, model, and live state.

| `move` flag | Effect |
|---|---|
| `--runtime RT` | Move that role to another runtime |
| `--extends P` | Re-parent a sub-role (`""` to detach) |
| `--general` | Make it the general |

**Changes take effect at the next launch.** Adding a role also needs its prompt file:
re-run `init --force`, or write `.agent-teams/prompts/<role>.txt` by hand.

### `model` — which model each role runs on

```
agent-teams model                       show every role's resolved model, and why
agent-teams model set <role> <tier>     smol | regular | smart | ultra
agent-teams model set <role> <name>     pin a concrete model, e.g. opus
agent-teams model reset <role>          drop the pin; fall back to the tier
```

Roles declare **intent** (`model_tier`), not vendor model names, so one team can span
runtimes:

| Tier | claude-code | codex | Use for |
|---|---|---|---|
| `ultra` | opus | provider default | a decision expensive to get wrong: architecture, a security call, an ambiguous spec, a bug that survived two attempts |
| `smart` | opus | provider default | non-trivial implementation; review that must catch subtle defects |
| `regular` | sonnet | provider default | well-specified work with a clear acceptance test |
| `smol` | haiku | gpt-5.1-codex-mini | mechanical passes: renames, formatting, lint, bulk edits |

**Precedence, highest first:**

1. `--model-for <role>=<model>` — one launch, operator override
2. `--tier-for <role>=<tier>` — one launch, by intent
3. `model:` in `team.yaml` — the lead's persisted judgement (this is what `model set` writes)
4. `AGENT_TEAMS_MODEL` — the owner's global default
5. `model_tier:` in `team.yaml` — the role's declared intent

`AGENT_TEAMS_MODEL` is a **default, not a ceiling**: a deliberate per-role decision
outranks it. For a hard cap the lead cannot escape, set `AGENT_TEAMS_MODEL_LOCK=1`.

Escalate a role that is looping or producing plausible-but-wrong work; drop one that is
grinding through volume. Record the change and the reason in your coordination note, so
the next session knows why the team is configured this way.

---

## Running it

### `launch` — start the team

```
agent-teams launch [options]
```

| Flag | Effect |
|---|---|
| `--mode bg` | Detached fleet, one worker per role **(default)** |
| `--mode native` | Print the spawn recipe for an interactive Claude session |
| `--layout bg` | Headless sessions + log files **(default)** |
| `--layout tmux` | One interactive session per role, in its own tmux window |
| `--only a,b` | Launch a subset |
| `--task "..."` | Shared opening task for every role |
| `--include-general` | Also launch the general as a worker |
| `--model-for R=M` | Override one role's model, this launch only |
| `--tier-for R=T` | Override one role's tier, this launch only |
| `--dry-run` | Show what would start |

**`--mode native` does not fork anything.** Native Claude teammates *cannot* be spawned
headlessly — verified, see [SPIKE-FINDINGS.md](SPIKE-FINDINGS.md). This mode prepares the
environment and prints the prompt for you to paste into an interactive session.

**The general is skipped by default** because the general is the session *you* are
sitting in. It delegates to the others rather than being one of them.

**`--layout bg` vs `--layout tmux`** — the choice that matters most:

| | `bg` | `tmux` |
|---|---|---|
| Survives SSH disconnect | ✓ | ✓ |
| Live `steer` into the session | ✗ (queued) | **✓ (immediate)** |
| `attach` gives real takeover | Claude roles only | **✓ all roles** |
| Needs tmux installed | ✗ | ✓ |

If tmux is available, prefer it. It is the only channel that reaches a running agent
*right now*.

```bash
agent-teams launch --layout tmux --task "read AIM.md, then start on your focus"
agent-teams launch --only research-survey,research-data
agent-teams launch --dry-run                  # always safe
```

### `restart` — stop and start again

```
agent-teams restart [--only a,b] [--task "..."] [--kill]
```

Reuses the layout each role was launched with. Use it after changing a role's model or
focus — or to clear a role that is wedged.

**A blocked agent will not recover on its own.** Restarting is usually faster than
answering its prompt. `restart` implies `--orphans`, so it also clears sessions whose
session file was lost.

---

## Watching it

### `status` — one-shot snapshot

```
agent-teams status [-C PATH] [--json]
```

Human table on stderr; `--json` writes the full state document to stdout. Schema is
[below](#status---json-schema).

```bash
agent-teams status
agent-teams status --json | jq '.roles[] | select(.state=="blocked") | .role'
```

### `monitor` — the web dashboard

```
agent-teams monitor [--port N] [--bind ADDR] [--refresh N]
```

| Flag | Default | |
|---|---|---|
| `--port N` | `8787` | |
| `--bind ADDR` | `127.0.0.1` | loopback only — **no authentication exists** |
| `--refresh N` | `2` | poll seconds |

One row per role: role · runtime · state · idle · tokens · last activity. Click to
expand a live tail.

**The six states, and which need you:**

| | State | Meaning |
|---|---|---|
| `!` | **blocked** | Waiting on a permission prompt. **Never resolves on its own.** |
| `x` | **errored** | Quota exhausted, auth expired, crashed |
| `>` | working | Actively producing |
| `-` | idle | Alive, nothing in flight |
| `.` | stopped | Session ended; result and spend still readable |
| `?` | unknown | Declared but never started |

The first two are rendered loudly and separately, because an agent waiting on a prompt
nobody can answer produces exactly the same silence as one that is thinking.

Do not `--bind 0.0.0.0`. Use an SSH tunnel. See [monitor.md](monitor.md) for the
collectors and [hooks](../templates/hooks/README.md) for firing on a state change.

---

## Talking to it

Four channels. Which one you want depends on the layout.

### `send` / `broadcast` — queued message

```
agent-teams send <role> "<message>" [--from ROLE] [--urgent]
agent-teams broadcast "<message>"   [--from ROLE] [--urgent]
```

Writes JSON to `.agent-teams/inbox/<role>.json`. **Delivery is at the recipient's next
poll** — a background agent cannot be interrupted mid-turn. Roles are told to check their
inbox at natural breakpoints and after each unit of work.

`--urgent` makes it render loudly in the monitor. `--from` defaults to
`$AGENT_TEAMS_ROLE`, else `human` — which is how roles message each other, with an audit
trail in `.agent-teams/outbox/`.

`broadcast` is `send --all`; it skips the sender.

### `steer` — redirect a role that is already running

```
agent-teams steer <role> "<message>" [--queue] [--from ROLE]
```

Under `--layout tmux` the message is **typed straight into the role's pane**, so it lands
immediately. Otherwise it falls back to the inbox. Either way it is recorded, so a live
steer still leaves an audit trail. `--queue` forces the slow path.

```bash
agent-teams steer research-data "stop at 3 datasets, we don't need more"
```

### `inbox` — what is waiting

```
agent-teams inbox [<role>] [--all] [--json] [--mark-read]
```

With no role, shows the unread count for every role. `--all` includes read messages;
`--mark-read` marks everything read after showing (roles do this themselves).

Useful for the failure mode where you sent something important and the role never
reached a breakpoint to read it.

### `attach` — take over the seat

```
agent-teams attach <role> [-C PATH]
```

- **tmux layout** → drops you into that role's window. Type at the agent directly.
  Detach and it keeps going.
- **bg layout** → tails the log read-only, and prints `claude attach <session-id>` if it
  is a Claude role. Codex background roles are tail-only.

---

## Ending it

### `stop` — stop roles, keep everything else

```
agent-teams stop [--only a,b] [--kill] [--orphans]
```

| Flag | Effect |
|---|---|
| `--only a,b` | Just these roles |
| `--kill` | Also remove the agent's retained git worktree — **inspect first**, commits may live there |
| `--orphans` | Also stop this project's agent sessions that no session file tracks any more |

Logs and coordination notes are always kept.

Only sessions this tool named (`at:<role>`) are touched, so **an interactive session you
are sitting in inside the same directory is never killed.** Without `--orphans`, `stop`
reaches only roles listed in `.agent-teams/sessions/`; a role whose session file was lost
stays visible in the monitor but is otherwise unreachable — that is what `--orphans` is
for.

### `close` — disband and write a closeout report

```
agent-teams close [--dry-run] [--force] [--keep-worktrees] [--reason "..."]
```

**Reviews before tearing anything down**, and refuses if work would be lost:

- a role still working → refuses unless `--force`
- a coordination note not finished → lists it (active / blocked / handoff)
- commits sitting in a worktree → lists it; **they are not on your branch**
- unread messages → lists them

Then stops every role, removes the tmux session, and writes
`docs/coordination/_closeout-<timestamp>.md` with what each role did, its final state,
its token spend, and anything left unresolved.

Logs, coordination notes, and worktrees are **always preserved**. Worktree removal is
never automatic, because commits live there.

```bash
agent-teams close --dry-run                    # review only, change nothing
agent-teams close --reason "v1 shipped"
```

---

## Syntax reference

### Role instances

Several instances of one role can run at once — the point of the whole design for
research.

| Syntax | Produces |
|---|---|
| `research` | `research` |
| `research:survey` | `research-survey`, with the `survey` focus attached |
| `analysis*3` | `analysis-1`, `analysis-2`, `analysis-3` |

### Squads

```bash
--squad "attn:research,analysis,engineering"
--squad "conv:research,analysis,engineering"
```

A squad is a small group owning **one direction end to end** — thinking and
implementation together. Squads decide internally without the lead, and are told *not* to
converge on each other: if every squad lands on the same approach, the parallelism bought
nothing.

### Focus assignment

```bash
--focus-for analysis-1=@leakage       # catalogue entry, by key
--focus-for analysis-1="free text"    # your own wording
```

An unknown `@key` is an error naming the role, not a silent fallback.

### Runtime and model assignment

```bash
--runtime-for qa=codex                # at init, persisted
--model-for qa=sonnet                 # at launch, one run only
--tier-for  qa=smart                  # at launch, one run only
```

---

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `AGENT_TEAMS_MODEL` | — | Global default model for **Claude** roles. Precedence level 4 — a per-role decision still outranks it |
| `AGENT_TEAMS_MODEL_CODEX` | — | Same, for Codex roles. **Separate on purpose**: Codex rejects Claude model names with a 400 |
| `AGENT_TEAMS_MODEL_PI` | — | Same, for pi roles |
| `AGENT_TEAMS_MODEL_LOCK` | unset | `1` makes `AGENT_TEAMS_MODEL` a **hard ceiling** the lead cannot override |
| `AGENT_TEAMS_ROLE` | — | Set automatically inside a launched role. Makes `send`/`steer` default `--from` to that role |
| `AGENT_TEAMS_STALL_SECONDS` | `600` | How long a role must be silent before hooks treat it as stalled |
| `AGENT_TEAMS_YES` | unset | `1` answers every confirmation prompt with yes. **For scripts and CI only** |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | unset | `1` enables native Claude teams (Mode A). Interactive sessions only |

---

## Files on disk

Written by `init`, in the project root:

| Path | What it is |
|---|---|
| `AGENTS.md` | **The shared contract.** Read natively by Codex; injected for Claude. Kept under 32 KB because Codex truncates past 32 KiB |
| `AIM.md` | What the project is trying to achieve. **Fill this in before launching** |
| `docs/coordination/` | Per-session notes — the durable cross-role channel |
| `docs/coordination/_closeout-*.md` | Written by `close` |
| `.claude/agents/*.md` | Role definitions for native (Mode A) teammates |
| `.claude/settings.json` | Permission allowlist. `acceptEdits` does **not** cover Bash, which is why this exists |

Under `.agent-teams/`:

| Path | What it is |
|---|---|
| `team.yaml` | Per-role runtime, model tier, permission mode, sandbox, focus, squad |
| `prompts/<role>.txt` | The emitted role prompt |
| `roles/<name>.md` | Your project-local roles — these override built-ins |
| `sessions/<role>.json` | Live session handle: pid, session id, tmux target, layout |
| `logs/<role>.log` | Per-role output. Gitignored |
| `inbox/<role>.json` · `outbox/<role>.json` | Messaging, capped at 200 messages |
| `hooks/` | Executables fired on a state change — see [hooks/README.md](../templates/hooks/README.md) |
| `reference-skills/` | Vendored copy from `skills --fetch`. Gitignored |

**Roles may commit and push, but only to their own branch — `agent/<role>`**, one branch
per role instance (so `research-survey` owns `agent/research-survey`). The allowlist
denies force-push and pushes to `main`.

---

## `status --json` schema

```json
{
  "project": "/abs/path",
  "project_name": "shop",
  "generated_at": "2026-08-20T09:14:02Z",
  "roles": [ ... ],
  "warnings": [ "..." ]
}
```

Each row in `roles`:

| Key | |
|---|---|
| `role` | Instance name, e.g. `research-survey` |
| `runtime` | `claude-code` · `codex` · `pi` |
| `layout` | `bg` · `tmux` |
| `state` | `blocked` `errored` `stopped` `working` `idle` `unknown` |
| `status` | Raw runtime status, before normalisation |
| `pid` · `session_id` | Process handle; `session_id` is `pid:N` for non-Claude roles |
| `idle_seconds` · `last_activity` | Silence, and the epoch of the last observed output |
| `last_text` | Clipped tail of what it last produced |
| `note_status` | From the coordination note: `active` `blocked` `handoff` `complete` |
| `tokens_total` · `tokens_cache_read` | Spend |
| `managed` | `false` = live in this project but not declared in `team.yaml` |
| `error` | Why this row could not be read, if it could not |
| `name` · `cwd` · `started_at` | Session metadata |

`collect_state` **never raises** — anything it could not read becomes an entry in
`warnings`, so a broken collector degrades one row instead of blanking the dashboard.

---

## When something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| Every role blocks immediately | Directory not trusted | `cd <project> && claude`, accept the prompt, exit |
| A role blocks on a `git` command | Compound command (`git add X && git commit`) — permission matching applies to the whole string, so it matches no allowlist entry | The contract tells roles one command per call; restart the role |
| A role goes silent and never returns | Quota exhausted | Shows as `errored`, not idle. Switch that role's runtime or wait |
| Work is "done" but not on your branch | The agent relocated into a git worktree and committed there | `close` refuses to disband and names it |
| `steer` does not land | Role is on `--layout bg` | It was queued; it arrives at the next inbox check |

Full list: [troubleshooting.md](troubleshooting.md).
