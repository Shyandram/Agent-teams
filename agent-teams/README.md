# agent-teams

Role-based multi-agent teams for research and application-development projects —
across **Claude Code**, **Codex**, and **pi**, with one shared contract and one
dashboard that shows every session at once.

Built for the case where you SSH from a Mac or Windows laptop into a Linux box and
want several agents working in parallel without losing track of them.

> **Looking for how to use a specific command?**
> [**`docs/commands.md`**](docs/commands.md) is the canonical reference — every command,
> every flag, with examples. This file explains *why*; that one explains *how*.

---

## Install

```bash
bash /path/to/agent-teams/install.sh
```

Installs into every agent CLI it finds — Claude Code (`~/.claude/skills/`), Codex
(`~/.codex/skills/`), and pi. Symlinks by default, so edits here apply everywhere.
`--dry-run`, `--copy`, `--uninstall`, or `--claude`/`--codex`/`--pi` to narrow it.

Claude Code and Codex share the same `SKILL.md` format, so one directory serves both.
The CLI also works standalone by absolute path if you would rather skip the skill layer.

Need the runtimes themselves? See [`docs/installation.md`](docs/installation.md).

## Quickstart

```bash
SKILL=/path/to/agent-teams

# 1. Scaffold the contract, roles, and manifest
bash $SKILL/bin/agent-teams init --kind app-dev --name my-project \
     --build-cmd "npm run build" --test-cmd "npm test"

# 2. Check the machine is ready (do not skip this)
bash $SKILL/bin/agent-teams doctor

# 3. Start the workers
bash $SKILL/bin/agent-teams launch --layout tmux

# 4. Watch them
bash $SKILL/bin/agent-teams monitor
```

Then open <http://localhost:8787>.

---

## Mixed-runtime teams

Runtimes are assigned to session owners, so one team can span CLIs. The **general** owns
the session for a main task; child roles are delegated subagents associated with that
session rather than additional top-level workers.

```bash
agent-teams init --kind app-dev --general lead \
    --runtime claude-code \
    --runtime-for qa=codex \
    --runtime-for devops=codex
```

That gives a `lead` session owner in Claude Code with `engineering` and `ux` as child
roles. Use separate session owners when the main tasks themselves must run independently.

Change your mind later by editing `.agent-teams/team.yaml` — no re-init needed.

---

## The two modes

Native Claude Code teammates **cannot be spawned headlessly** — a `-p`/`--print`
session never spawns them. That constraint, not a preference, is why there are two
modes.

### Mode A — in-session team (interactive, Claude Code only)

```bash
agent-teams launch --mode native
```

Prints the exact recipe to run in an interactive session. Teammates get the native
`SendMessage` mailbox and shared task list.

### Mode B — detached fleet (headless, all runtimes) — the default

```bash
agent-teams launch --layout bg      # background sessions + logs
agent-teams launch --layout tmux    # interactive sessions you can take over
```

`--layout tmux` is the one worth knowing: each session owner runs an interactive session
in its own tmux window, so the fleet **survives SSH disconnect** and you can drop into a
main task and type at it:

```bash
agent-teams attach lead
```

---

## Two ways a fleet dies silently

Both were observed during development (`docs/SPIKE-FINDINGS.md`), and both look like
"still working" from the outside.

**1. Untrusted directory.** A background Claude session in a directory that has never
been trusted blocks forever on its first write — even with `--permission-mode
acceptEdits`. `launch` refuses to start rather than let this happen. Fix it once:

```bash
cd <project> && claude    # accept the trust prompt, then exit
```

`doctor` reports trust status. The skill will never set that flag for you; it is a
security control.

**2. Quota exhaustion.** A rate-limited Codex role stops and looks idle. The dashboard
shows it as `errored`, not `idle`.

---

## Watching from a laptop

The dashboard binds `127.0.0.1` and has no authentication, so reach it through SSH:

```bash
ssh -L 8787:localhost:8787 user@your-linux-box
```

Then open <http://localhost:8787> locally. Do not use `--bind 0.0.0.0` on a networked
machine.

State precedence, loudest first:

| State | Meaning |
|---|---|
| `blocked` | Waiting on a permission prompt. **A human must act or it never finishes.** |
| `errored` | Runtime error — quota, auth, crash |
| `stopped` | Session ended |
| `working` | Actively producing |
| `idle` | Alive, nothing in flight |
| `unknown` | In `team.yaml`, no live session |

---

## Commands

| Command | Purpose |
|---|---|
| `init` | Scaffold `AGENTS.md`, coordination protocol, `.claude/agents/`, `team.yaml` |
| `doctor` | Runtimes, auth, tmux, workspace trust, native-teams availability |
| `launch` | Start the team (`--mode`, `--layout`, `--only`, `--include-general`) |
| `status` | One-shot snapshot (`--json` for scripts) |
| `monitor` | Web dashboard |
| `attach ROLE` | Enter a role's session |
| `stop` | End sessions; logs and notes are kept |
| `skills` | Manage the reference skill library (below) |
| `team` | Draw the structure; add / remove / move roles |
| `role` | List roles, or create your own (sub-roles via `--extends`) |
| `send` `broadcast` `acks` `steer` `inbox` | Talk between roles |
| `close` | Disband the team with a review + closeout report |
| `model` | Show or change which model each role runs on |

---

## Model allocation

Which model a role runs on is a judgement call — the lead makes it, you can override it.

```bash
agent-teams model                          # every role's model, and why
agent-teams model set engineering ultra    # by intent: smol|regular|smart|ultra
agent-teams model set ux haiku             # or pin a concrete model
agent-teams model reset ux                 # drop the pin
```

```
ROLE             RUNTIME       TIER      MODEL      DECIDED BY
lead             claude-code   smart     opus       model_tier
engineering      claude-code   ultra     opus       model_tier
ux               claude-code   regular   haiku      team.yaml model: (lead)
devops           claude-code   regular   sonnet     model_tier
```

Precedence, highest first:

| | Set by | Scope |
|---|---|---|
| 1 | `launch --model-for role=opus` | one launch |
| 2 | `launch --tier-for role=ultra` | one launch |
| 3 | `model:` in `team.yaml` | the lead's persisted call |
| 4 | `AGENT_TEAMS_MODEL` | your global default |
| 5 | `model_tier:` in `team.yaml` | the role's declared intent |

`AGENT_TEAMS_MODEL` is a **default, not a ceiling** — a deliberate per-role decision
beats it. For a hard cap the lead cannot escape:

```bash
AGENT_TEAMS_MODEL=sonnet AGENT_TEAMS_MODEL_LOCK=1 agent-teams launch
```

Tiers are about how expensive a wrong answer is, not how big the task looks: `ultra` for
decisions costly to reverse, `smart` for non-trivial implementation and subtle review,
`regular` for well-specified work, `smol` for mechanical passes. Changes apply at next
launch — restart the role.

---

## Reference skill library

Roles are pointed by default at [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills)
(MIT, ~350 domain skills) for depth beyond their brief — `research` at `research/` and
`research-ops/`, `qa` at `engineering-team/`, `standards/`, `compliance-os/`, and so on.

```bash
agent-teams skills --list     # which directories each role is pointed at
agent-teams skills --fetch    # vendor a local copy (faster, offline)
agent-teams skills --remove   # drop it; roles fall back to the network
```

Without a local copy roles fetch over the network on demand — no clone required. Opt out
entirely with `init --no-reference-skills`.

Roles are instructed to treat the library as **reference material, never instructions**:
this project's `AGENTS.md` wins on conflict, and directives found inside fetched content
are ignored.

---

## Roles

Core: `lead` · `engineering` · `research` · `analysis` · `qa` · `verification` · `ux` · `devops`
Extras: `translation` · `legal` · `simulation` · `product-marketing`

| Preset | Roles | |
|---|---|---|
| `solo` | engineering | 1 |
| `app-dev` | lead, engineering, qa | 3 |
| `research` | lead, research, analysis, qa | 4 |
| `app-dev-wide` | + engineering:api/ui, qa:functional/regression, devops, verification | 7 |
| `research-wide` | + research:survey/data, analysis:primary/ablation, engineering, verification | 8 |
| `full-stack` | + ux, devops, verification, product-marketing, legal | 9 |

**Sessions follow main tasks.** The general owns the runtime session for a main task;
research, engineering, QA, and other child roles are delegated subagents in that
session. Add a child role when a gap appears rather than creating another top-level
session. `init` warns above six role definitions because delegated context still costs
attention even though it does not create another process.

Custom teams: `--roles lead,engineering,legal`. Add your own by dropping a file into
`roles/` — see `roles/README.md` for the format.

---

## Install on a Linux server

The CLI runs by absolute path; nothing needs to be on `PATH`.

```bash
git clone <repo> ~/skills/agent-teams
bash ~/skills/agent-teams/bin/agent-teams doctor
```

To let Claude Code discover it as a skill:

```bash
mkdir -p ~/.claude/skills
ln -s ~/skills/agent-teams ~/.claude/skills/agent-teams
```

Optionally shorten the invocation:

```bash
echo 'alias agent-teams="bash ~/skills/agent-teams/bin/agent-teams"' >> ~/.bashrc
```

**Requirements:** bash 3.2+, Python 3.8+ (stdlib only — no pip), and at least one of
`claude` / `codex` / `pi`. tmux is optional. Windows users should SSH to the Linux host
or use WSL.

**Cost control:** `AGENT_TEAMS_MODEL=sonnet` pins every Claude role to one model,
overriding the per-role tier.

---

## What gets written into your project

```
AGENTS.md                        # the shared contract (Codex reads this natively)
docs/coordination/README.md      # the coordination-note protocol
docs/coordination/_template.md   # per-session note template
.claude/agents/<role>.md         # Claude subagent definitions
.claude/settings.json            # permission allowlist — REVIEW THIS
.agent-teams/team.yaml           # team manifest — edit this
.agent-teams/prompts/<role>.txt  # role prompts for non-Claude runtimes
.agent-teams/logs/               # gitignored
.agent-teams/sessions/           # gitignored
```

`init` refuses to overwrite without `--force`.

---

## Runtime status

| Runtime | Status |
|---|---|
| `claude-code` | Verified end to end |
| `codex` | Verified end to end — launch, writes, role binding, monitor, close |
| `pi` | **Untested** — pi was not installed during development |

---

## Docs

- `docs/SPIKE-FINDINGS.md` — verified runtime behaviour. Trust it over vendor docs where they disagree.
- `docs/INTERFACES.md` — frozen internal contracts.
- `roles/README.md` — role format and how to add one.

---

## Team structure

```bash
agent-teams team
```

```
  shop
   ROLE                        RUNTIME      MODEL
  ------------------------------------------------------
  ? lead              general  claude-code  opus
  ? engineering                claude-code  opus
  ? `- checkout       sub      claude-code  opus
  ? qa                         codex        default
  ? ux                         claude-code  sonnet

  ! blocked   x errored   > working   - idle   . stopped   ? not started
```

Restructure without hand-editing `team.yaml`:

```bash
agent-teams team add legal
agent-teams team remove ux
agent-teams team move qa --runtime claude-code
agent-teams team move checkout --extends engineering
agent-teams team move engineering --general
```

## Your own roles, and sub-roles

Project roles live in `.agent-teams/roles/` and override built-ins of the same name, so
you can add or specialise roles without touching the skill.

```bash
agent-teams role list
agent-teams role new frontend --extends engineering --add
agent-teams role show frontend
```

`--extends` makes a **sub-role**: its prompt is the parent's body followed by its own, so
a specialisation inherits the shared discipline instead of restating it.

## Talking between roles

```bash
agent-teams send qa "auth landed at src/auth.ts:88 — re-run the suite"
agent-teams broadcast "freezing main in 10 minutes"   # everyone reads this FIRST
agent-teams acks                   # who has read it, who has not
agent-teams steer engineering "stop, the spec changed"
agent-teams inbox                  # unread counts for every role
```

A **broadcast** is one shared record, not a copy per inbox, and every role drains it
*before* its own messages — it is what changes the plan for everyone, so reading it
second means acting on instructions it already superseded. Because there is one record,
`acks` can answer who has actually read it, and the sender gets a receipt once the last
role has.

Messages are JSON files, so Codex and pi roles participate exactly like Claude ones and
nothing is lost when a session dies. Delivery is at the recipient's next inbox check —
every role prompt tells it to check after each unit of work. `steer` on a `--layout tmux`
role types straight into the pane and lands immediately.

## Results

Roles end a unit of work with a block the dashboard shows instead of a transcript tail:

```
<result>
status: done
summary: Token refresh now rotates hourly.
changed: src/auth.ts:88
verified: npm test -> 42 passed
next: none
</result>
```

`status: done` means finished **and** checked. A failed or skipped check means `partial`
or `blocked` — never `done`.

## Hooks

`.agent-teams/hooks/` turns a state into an action, so you do not have to be watching:

| Hook | Fires when |
|---|---|
| `on_blocked` | waiting on a permission prompt — never self-resolves |
| `on_errored` | quota, auth, or crash |
| `on_stalled` | quiet for `AGENT_TEAMS_STALL_SECONDS` (default 600) |
| `on_idle` / `on_done` | finished a turn / reported `status: done` |

Samples ship disabled — enable one by dropping the `.sample` suffix and `chmod +x`. They
are edge-triggered (once per state change, not per poll), time-limited to 20s, and never
block the dashboard.

## Closing the team

```bash
agent-teams close                  # reviews, then refuses if work would be lost
agent-teams close --dry-run        # review only
agent-teams close --force
```

It refuses while a role is still running, a coordination note is unfinished, or commits
are sitting in an agent worktree — those are **not on your branch**. Then it stops
everything, removes the tmux session, and writes `docs/coordination/_closeout-*.md` with
each role's final state, token spend, and what was left unresolved. Logs, notes, and
worktrees are always kept.

---

## Aim: what the whole project is for

`init` writes an **`AIM.md`** at the repo root, chosen by `--kind`:

- **research** — question, hypotheses *with their falsifiers*, success criteria fixed in
  advance, method, data provenance, validity threats, reproducibility
- **app-dev** — problem, users, outcome, acceptance criteria, **non-goals**, constraints,
  architecture decisions with reasons, rollout and rollback

`AGENTS.md` says *how* to work; `AIM.md` says *what for*, and every role reads it first.
Fill it in **before** launching: a team working from an unfilled aim invents its own
objectives and diverges quietly.

## Several instances of one role

Parallelism pays when instances of the same role work *different slices*:

```bash
agent-teams init --kind research \
  --roles "lead,research:lit,research:data,analysis*2,qa" \
  --focus-for "research-lit=systematic review, 2020-2026" \
  --focus-for "analysis-1=primary hypothesis" \
  --focus-for "analysis-2=ablations and negative controls"
```

- `research:lit` → instance `research-lit`, built from the `research` role
- `analysis*2` → `analysis-1`, `analysis-2`
- `--focus-for` gives each its own slice; the `research`/`app-dev` presets ship sensible
  defaults so two instances never start with identical briefs

Each instance remains a first-class role prompt and coordination identity, but only a
session owner has its own runtime session and session log. Child roles are associated with
their owner; their prompts say which slice is theirs and tell them to message others
rather than duplicate work.

### Proposal and approval gate

An idea-general can be proposed without starting a session:

```yaml
- name: idea1-general
  parent: lead
  session: true
  approval: proposed
```

The main general reviews the idea and changes `approval` to `approved`. The next launch
then starts that idea-general as a separate session. This lets one main general turn
three approved ideas into three child-general sessions—four sessions total including the
main general—while keeping unapproved ideas inside the main session.

## Unified workflow vocabulary

The design also borrows CrewAI’s useful workflow vocabulary without requiring CrewAI as a
dependency: the overall objective is a **Flow**, each approved idea-general is a **Crew**,
each role is an **Agent**, and each coordination assignment is a verifiable **Task**.
CrewAI can optionally run inside an approved session for structured Python workflows;
agent-teams remains responsible for cross-runtime sessions, approval, permissions,
monitoring, logs, and recovery. See [unified orchestration](docs/design/unified-orchestration.md).

## Squads: small groups owning one direction

When several directions should be explored at once, give each its own group with thinking
*and* implementation inside it:

```bash
agent-teams init --kind research --roles "lead,qa" \
  --squad "attn:research,analysis,engineering" \
  --squad "conv:research,analysis,engineering"
```

```
  squad attn
  ?   research-attn      claude-code  sonnet
  ?   analysis-attn      claude-code  opus
  ?   engineering-attn   claude-code  opus

  squad conv
  ?   research-conv      claude-code  sonnet
  ...
  ? lead        general  claude-code  opus
  ? qa                   claude-code  sonnet
```

A squad decides for itself and does not need the lead to change course within its own
direction. Squad members are explicitly told **not** to converge on another squad — if
every squad ends up doing the same thing, the parallelism bought nothing. Notes and
commits are prefixed `<squad>/` so the directions can be compared at the end.

## Subagents

Roles can delegate to a subagent whenever they judge it useful — nothing needs defining
first, and every role carries the `Agent` tool so it can. The prompt tells them *when*
it is worth it (wide search, adversarial self-review, long verification) and when it is
not (small work, or work needing context they already hold).

Optional named specialists, private to one role, are available with `init --subagents`:

    .agent-teams/subagents/<role>/<name>.md

They are passed per session via `claude --agents`, so they are genuinely private — two
roles can carry different definitions under the same name, and nothing lands in the
shared `.claude/agents/` namespace.

---

## Not built yet

Ideas that are designed but deliberately not implemented. They live in `docs/design/`
so the reasoning is available when there is a reason to build them.

| Idea | Why it is not built |
|---|---|
| [Role priority and multiple hosts](docs/design/multi-host-and-priority.md) | Waiting on a real multi-server project. The design separates *pooled* instances (interchangeable, ordered by priority, can fail over) from the *partitioned* instances that exist today (different `focus`, all active, ordering meaningless). Transport is left open on purpose — it should be chosen against an actual second machine. |

The highest-value slice, if it is ever picked up, is automatic failover when a pooled
role exhausts its quota: the monitor already detects that state, so promotion is a short
step from detection that works.

---

## Focus catalogue

A focus says what one instance owns, so its siblings stay out of it. The catalogue
(`templates/focus.tsv`, 66 entries across 11 roles) is keyed by the **instance suffix**,
so it attaches with no extra flag:

```bash
agent-teams focus list            # everything
agent-teams focus list analysis   # one role

--roles "research:survey,research:data,analysis:ablation,qa:edge"
```

`research:survey` becomes `research-survey` and picks up the `survey` assignment
automatically. Override any time:

```bash
--focus-for analysis-1=@leakage        # a catalogue entry, by key
--focus-for analysis-1="free text"     # your own wording
```

A few of the keys: research → `survey data methods competing adjacent sources landscape` ·
analysis → `primary ablation baseline sensitivity error stats leakage scaling` ·
engineering → `api ui data infra perf refactor integration migration` ·
qa → `functional regression edge integration accessibility security repro`.

## Aim templates

`--aim` picks which `AIM.md` gets written, independently of the role preset:

| `--aim` | For |
|---|---|
| `research` | a research programme: question, hypotheses with falsifiers, validity threats, checkpoints, ethics |
| `app-dev` | a product change: problem, acceptance criteria, non-goals, current state, metrics, risks |
| `experiment` | one focused experiment: pre-registered threshold, confounds, stopping rule |
| `library` | a reusable component: public surface, compatibility, deprecation policy |
| `migration` | moving from X to Y: inventory, coexistence, ordering, tested rollback |

Defaults to `research` for research presets, `app-dev` otherwise.

---

## Two kinds of checking

`qa` and `verification` are not the same job, and a team that only has one of them is
missing something.

| | `qa` | `verification` |
|---|---|---|
| Tests | the **product** | the **reporting** |
| Asks | does it work? | is what they said it did true? |
| Evidence | acceptance criteria, regressions, edge cases | reproduced commands, real diffs, actual commits |
| Fixes things | no | **no** — and it must not, or it has audited its own work |

Roles self-report `status: done` and a `verified:` line. Nothing else checks those. On a
team whose work nobody watched happen, a false "done" costs more than a bug — it stops
anyone else from looking.

`verification` re-runs the command a role said it ran, compares, and returns one of three
verdicts: **confirmed**, **contradicted**, or **unverifiable**. That third one matters
most: a claim with no recorded command or seed cannot be checked at all, and that is a
finding, not a pass.

```bash
agent-teams focus list verification
agent-teams team add verification
```

It ships in the `-wide` and `full-stack` presets, and is opt-in for the small ones.
