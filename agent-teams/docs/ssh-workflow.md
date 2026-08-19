# Working from a laptop against a Linux server

The intended shape: the team lives on the server, you drive it from a Mac or Windows
laptop, and disconnecting never kills anything.

```
  Mac / Windows                        Linux server
  ─────────────                        ────────────
  terminal  ──── ssh ──────────────▶   tmux session at_<project>
                                         ├── window: engineering  (claude)
                                         ├── window: qa           (codex)
                                         └── window: devops       (codex)
  browser   ──── ssh -L 8787 ──────▶   agent-teams monitor
```

## One-time setup on the server

```bash
git clone <repo> ~/skills/agent-teams
cd /path/to/your/project
bash ~/skills/agent-teams/bin/agent-teams init --kind app-dev
bash ~/skills/agent-teams/bin/agent-teams doctor      # fix anything red
```

`doctor` will tell you if the project is untrusted. Fix that once, interactively, before
launching anything — background agents in an untrusted directory block forever:

```bash
cd /path/to/your/project && claude    # accept, then exit
```

## Daily loop

```bash
ssh -L 8787:localhost:8787 user@server
cd ~/project

agent-teams launch --layout tmux
agent-teams monitor &
```

Open <http://localhost:8787> on the laptop. The tunnel makes the server's loopback port
reachable locally; the dashboard is never exposed to the network.

**Close the laptop whenever you like.** The tmux session and any `--bg` agents keep
running on the server. Reconnecting is just the same `ssh -L` line again.

## Taking a role over

The dashboard tells you *that* something needs you; tmux is where you act.

```bash
agent-teams attach engineering     # lands in that role's window
```

You are now typing at that agent. Detach with `Ctrl-b d` and it keeps working.

Under `--layout bg` there is no interactive pane, so `attach` tails the log instead.
`claude attach <id>` can pull a background Claude session into your terminal.

## Why the dashboard and tmux both exist

They answer different questions and neither replaces the other:

| | Dashboard | tmux |
|---|---|---|
| Question | What is every role doing? | Let me deal with *this* role |
| Reach | One screen, all runtimes | One session at a time |
| Interaction | Read-only by design | Full keyboard |

Watch in the browser, intervene in tmux.

## Windows

Use SSH from Windows Terminal, PowerShell, or WSL — the `-L` flag works the same. Native
Windows is not a supported host for the team itself; run it on the Linux box and treat
Windows as the terminal.

## If port 8787 is taken

```bash
agent-teams monitor --port 9100
ssh -L 9100:localhost:9100 user@server
```

Both numbers must match. Do not use `--bind 0.0.0.0` to avoid the tunnel — the dashboard
has no authentication.

## Several projects at once

Each project gets its own tmux session (`at_<project>`) and its own monitor port:

```bash
agent-teams monitor -C ~/proj-a --port 8787
agent-teams monitor -C ~/proj-b --port 8788
ssh -L 8787:localhost:8787 -L 8788:localhost:8788 user@server
```
