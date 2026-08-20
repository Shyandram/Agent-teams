# Modes: in-session team vs detached fleet

There are two ways to run a team, and the split is forced by a hard constraint rather
than taste:

> **Native Claude Code teammates cannot be spawned headlessly.** A `-p`/`--print` session
> never spawns them; native teams require an interactive TTY.

So a team that must survive SSH disconnect, run in the background, or span runtimes cannot
use the native mechanism at all — hence Mode B.

| | **Mode A — in-session** | **Mode B — detached fleet** |
|---|---|---|
| Use when | You are at an interactive session now | Background, over SSH, or cross-runtime |
| Runtimes | Claude Code only | Claude Code + Codex + pi |
| Spawning | Claude calls the Agent tool with a name | One OS process per session owner; child roles are delegated subagents |
| Comms | `SendMessage` mailbox + shared task list | Coordination notes on disk |
| Survives disconnect | Only with `--teammate-mode tmux` | Yes |
| Monitoring | Native agent panel, plus this dashboard | This dashboard |

Both share the same role library, the same `AGENTS.md`, and the same coordination
protocol. They are the interactive and detached forms of one team.

## Mode A

```bash
agent-teams launch --mode native
```

This spawns nothing. It verifies the setup and prints the exact recipe to paste into an
interactive session, because only Claude-inside-a-session can create teammates:

```bash
cd <project>
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --teammate-mode tmux
```

Expected observable once teammates spawn: `~/.claude/teams/session-XXXXXXXX/` appears.

Caveats worth knowing: the feature is experimental and gated; team config under
`~/.claude/teams/` is runtime state that must never be pre-authored; and `skills:` /
`mcpServers:` frontmatter in a subagent definition is **ignored** for teammates.

## Mode B — the default

```bash
agent-teams launch --layout bg      # headless + logs
agent-teams launch --layout tmux    # interactive, takeover-able
```

`--layout bg` uses `claude --bg` and `codex exec --json`. Nothing to attach to; observe
through the dashboard and logs.

`--layout tmux` runs one interactive session per session owner in its own window of a detached
tmux session. This is the only configuration that lets you **take a role over mid-flight**:

```bash
agent-teams attach lead
```

Coordination notes are the durable channel in both layouts — deliberately, because the
shared task tools are unavailable by default on current models, and because notes survive
session death, runtime differences, and context loss.

## Choosing

- Sitting at a terminal, one machine, Claude only → **Mode A**
- Anything on a server you SSH into → **Mode B, `--layout tmux`**
- Fully unattended or scripted → **Mode B, `--layout bg`**
- Mixed runtimes → **Mode B** (Mode A is Claude-only)
