# agent-teams

**Run a team of agents. See which one is stuck.**

Role-based agent teams across **Claude Code**, **Codex**, and **pi** — one shared
contract, one dashboard, and no infrastructure to stand up.

Built for the case where you SSH from a laptop into a Linux box and want several agents
working in parallel without losing track of them.

📄 **[Documentation site](https://shyandram.github.io/Agent-teams/)** ·
📦 [Skill source](agent-teams/) ·
🔬 [Verified runtime behaviour](agent-teams/docs/SPIKE-FINDINGS.md)

---

```
  shop  (~/projects/shop)

    ROLE             RUNTIME      STATE       IDLE    TOKENS  LAST
  ──────────────────────────────────────────────────────────────────────
  ! engineering      claude-code  blocked      4m    52,110  git add … && git commit
  x research-lit     codex        errored     11m    18,402  usage limit reached
  > research-data    codex        working      3s    31,887  validating licences
  - qa               claude-code  idle        45s    12,004  42 passed
  . ux               claude-code  stopped       –     8,251  status: done
  ? devops           claude-code  unknown       –         –  not started

  ! 1 role BLOCKED on a permission prompt — it will not progress
      until a human acts:  engineering
```

## Why

Run five agents in parallel and the hard part stops being the work — it becomes knowing
which of them quietly stopped. An agent waiting on a permission prompt nobody can answer
produces exactly the same silence as one that is thinking.

Every state that needs a human is rendered loudly and separately:

| | State | Meaning |
|---|---|---|
| `!` | **blocked** | Waiting on a permission prompt. Never resolves on its own. |
| `x` | **errored** | Quota exhausted, auth expired, crashed. |
| `>` | working | Actively producing. |
| `-` | idle | Alive, nothing in flight. |
| `.` | stopped | Session ended; result and spend still readable. |
| `?` | unknown | Declared but never started. |

## Install

```bash
git clone https://github.com/Shyandram/Agent-teams.git ~/skills/agent-teams
bash ~/skills/agent-teams/agent-teams/install.sh
```

Installs into every agent CLI it finds. Claude Code and Codex read the same `SKILL.md`
format, so one directory serves both. Symlinks by default, so edits apply everywhere.

**Requires** bash 3.2+, Python 3.8+ (stdlib only — no pip), and one of `claude` /
`codex` / `pi`. tmux optional. Windows: SSH to the Linux host, or use WSL.

## Use

```bash
agent-teams init --kind app-dev     # AGENTS.md, AIM.md, roles, permission allowlist
agent-teams doctor                  # runtimes, auth, tmux, workspace trust
agent-teams launch --layout tmux    # start one session per main-task general
agent-teams monitor                 # dashboard on 127.0.0.1:8787
```

Reach the dashboard from a laptop through a tunnel — it binds loopback and has no
authentication:

```bash
ssh -L 8787:localhost:8787 user@your-linux-box
```

## Composition

Parallelism only pays when instances own **different** work, so a catalogue of 66
assignments across 11 roles attaches by suffix:

```bash
# three researchers and two analysts, each on a different slice
agent-teams init --kind research \
  --roles "lead,research:survey,research:data,analysis:primary,analysis:ablation,qa"

# or two squads, each owning one direction end to end
agent-teams init --roles "lead,qa" \
  --squad "attn:research,analysis,engineering" \
  --squad "conv:research,analysis,engineering"
```

Squads decide internally without the lead, and are told *not* to converge on each other —
if every squad lands on the same approach, the parallelism bought nothing.

Presets describe the roles available to a main-task general. The general owns the runtime
session; research, engineering, QA, and other child roles are delegated inside it. This
means adding a role does not automatically create another top-level session. Use separate
session owners only for genuinely independent main tasks.

The generated manifest makes the relationship explicit:

```yaml
- name: lead
  general: true
  session: true
- name: research
  parent: lead
  session: false
```

Only `lead` creates a runtime session. `research` keeps its own role prompt and can open
further subagents when the general delegates work to it.

## Four ways a fleet dies quietly

All found by running real fleets, not by reading documentation. Each looks like an agent
that is still working.

| What happens | What the tool does |
|---|---|
| **Untrusted directory** — a background session blocks on its first write, even with `acceptEdits` | `launch` refuses to start rather than spawning agents that wedge. It never sets the trust flag for you; that is a security control. |
| **Chained commands** — permission matching applies to the whole command, so `git add X && git commit` matches neither entry | The contract tells roles to run one command per call. Allowlisting every compound form is unwinnable. |
| **Quota exhaustion** — a rate-limited role stops producing, indistinguishable from finishing | Rendered as `errored`, never as idle. A hook can fire on it. |
| **Work on a side branch** — an agent may relocate into a git worktree and commit there | `close` refuses to disband while commits sit in a worktree, and says which. |

## Commands

| | |
|---|---|
| `init` | Scaffold `AIM.md`, `AGENTS.md`, roles, permission allowlist |
| `doctor` | Runtimes, auth, tmux, workspace trust, native-teams availability |
| `launch` | Start the team (`--mode`, `--layout`, `--only`, `--include-general`) |
| `monitor` · `status` | Dashboard, or a one-shot snapshot (`--json`) |
| `team` · `role` · `focus` | Structure, custom roles and sub-roles, assignment catalogue |
| `send` · `broadcast` · `steer` · `inbox` | Messaging between roles |
| `model` | Which model each role runs on, and why |
| `attach` · `stop` · `close` | Take over, stop, or disband with a closeout report |

## Status

| Runtime | | |
|---|---|---|
| `claude-code` | **verified** | Launch, status, tmux takeover, stop, monitor exercised against live sessions |
| `codex` | **verified** | Launch, file writes, role binding, monitor and close exercised against live sessions |
| `pi` | **untested** | Not installed during development — the adapter has never been run |

## Documentation

| | |
|---|---|
| [Site](https://shyandram.github.io/Agent-teams/) | Overview |
| **[Command reference](agent-teams/docs/commands.md)** | **Every command and flag, with examples — start here to use it** |
| [Skill README](agent-teams/README.md) | Overview and rationale |
| [SPIKE-FINDINGS](agent-teams/docs/SPIKE-FINDINGS.md) | Verified runtime behaviour — trust this over vendor docs where they disagree |
| [Modes](agent-teams/docs/modes.md) · [Monitor](agent-teams/docs/monitor.md) · [Runtimes](agent-teams/docs/runtimes.md) | Design and mechanics |
| [SSH workflow](agent-teams/docs/ssh-workflow.md) · [Troubleshooting](agent-teams/docs/troubleshooting.md) | Operating it |
| [Installation](agent-teams/docs/installation.md) | The skill, and the runtimes themselves |

## Licence

MIT
