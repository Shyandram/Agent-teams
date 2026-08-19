# agent-teams

Role-based multi-agent teams for research and application-development projects —
across **Claude Code**, **Codex**, and **pi**, with one shared contract and one
dashboard that shows every session at once.

Built for the case where you SSH from a Mac or Windows laptop into a Linux box and
want several agents working in parallel without losing track of them.

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

Runtimes are assigned **per role**, so one team can span CLIs. Whichever CLI you are
sitting in is the **general** — it delegates, and is not spawned as a worker.

```bash
agent-teams init --kind app-dev --general lead \
    --runtime claude-code \
    --runtime-for qa=codex \
    --runtime-for devops=codex
```

That gives a `lead` general in Claude Code, `engineering` and `ux` in Claude Code, and
`qa` + `devops` in Codex. Flip `--runtime codex` to make Codex the default and Claude
Code the exception.

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

`--layout tmux` is the one worth knowing: each role runs an interactive session in its
own tmux window, so the fleet **survives SSH disconnect** and you can drop into any role
and type at it:

```bash
agent-teams attach engineering
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

Core: `lead` · `engineering` · `research` · `analysis` · `qa` · `ux` · `devops`
Extras: `translation` · `legal` · `simulation` · `product-marketing`

| Preset | Roles |
|---|---|
| `research` | lead, research, analysis, engineering, qa |
| `app-dev` | lead, engineering, ux, qa, devops |
| `full-stack` | app-dev + product-marketing, legal |

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
| `codex` | Integration verified; a full write test was blocked by a usage limit |
| `pi` | **Untested** — pi was not installed during development |

---

## Docs

- `docs/SPIKE-FINDINGS.md` — verified runtime behaviour. Trust it over vendor docs where they disagree.
- `docs/INTERFACES.md` — frozen internal contracts.
- `roles/README.md` — role format and how to add one.
