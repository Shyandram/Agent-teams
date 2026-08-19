# Installation

Two separate things: **installing this skill** into your agent CLIs, and **installing the
runtimes** themselves. Do the runtimes first if you have none.

---

# Part 1 — install this skill

```bash
bash /path/to/agent-teams/install.sh
```

With no arguments it installs into every runtime it finds on `PATH`. It **symlinks** by
default, so editing the skill directory updates every runtime at once.

```bash
bash install.sh --claude      # only Claude Code
bash install.sh --codex       # only Codex
bash install.sh --pi          # only pi (untested)
bash install.sh --copy        # snapshot instead of symlink
bash install.sh --dry-run     # show what would happen
bash install.sh --uninstall   # remove what it installed
```

It refuses to overwrite a real directory it did not create, so an existing skill of the
same name is never clobbered.

### Where it lands

| Runtime | Path | Status |
|---|---|---|
| Claude Code | `~/.claude/skills/agent-teams/` | Verified |
| Codex | `~/.codex/skills/agent-teams/` | Verified |
| pi | `~/.pi/agent/packages/agent-teams/` + `pi install <path>` | Untested |

Claude Code and Codex read the **same `SKILL.md` format** — same `name` / `description`
frontmatter — so one directory serves both. (Codex keeps its own bundled skills under
`~/.codex/skills/.system/`; user skills sit at the top level.)

`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, and `PI_HOME` are honoured if set.

For pi the script stages a package directory with a `skills/` convention folder and then
prints the command to register it:

```bash
pi install ~/.pi/agent/packages/agent-teams
```

### After installing

Start a **new** session so the runtime picks the skill up, then ask it to "set up an agent
team for this project". Or skip the skill layer and call the CLI directly — it works
standalone by absolute path:

```bash
bash /path/to/agent-teams/bin/agent-teams doctor
```

### Project-local instead of global

To scope the skill to one repository, put it in that repo's `.claude/skills/` rather than
`~/.claude/skills/`, or pass `claude --plugin-dir /path/to/agent-teams`.

---

# Part 2 — install the runtimes

You need **at least one**. A team can mix them, so a common setup is Claude Code
plus Codex.

Run `agent-teams doctor` at any point — it reports what is installed, what is
authenticated, and prints the install command for whatever is missing.

Commands below are quoted from official sources (Claude Code docs, the `openai/codex`
README, pi's quickstart). Where something could not be verified on the build machine it
says so.

---

## Claude Code

**Verified working** (v2.1.236 on macOS during development).

### Install

**macOS, Linux, WSL** — native installer, recommended, auto-updates:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://claude.ai/install.ps1 | iex
```

**Homebrew** (does *not* auto-update):

```bash
brew install --cask claude-code
```

**Debian / Ubuntu** — signed apt repository, good for servers:

```bash
sudo apt install curl gnupg
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
  -o /etc/apt/keyrings/claude-code.asc
echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-code.list
sudo apt update
sudo apt install claude-code
```

Verify the key fingerprint before trusting it:

```bash
gpg --show-keys /etc/apt/keyrings/claude-code.asc
# expect 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
```

**Fedora / RHEL:**

```bash
sudo tee /etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
sudo dnf install claude-code
```

**npm** (requires Node.js 22+; never use `sudo npm install -g`):

```bash
npm install -g @anthropic-ai/claude-code
```

### Authenticate

```bash
claude          # opens a browser; follow the prompts
```

Requires a Pro, Max, Team, Enterprise, or Console account — the free plan does not
include Claude Code.

### Verify

```bash
claude --version     # e.g. 2.1.236 (Claude Code)
claude doctor        # installation and settings diagnostics
```

### Requirements

macOS 13+, Windows 10 1809+, Ubuntu 20.04+, Debian 10+, or Alpine 3.19+ · 4 GB+ RAM ·
x64 or ARM64. On Alpine also `apk add bash curl libgcc libstdc++ ripgrep` and set
`USE_BUILTIN_RIPGREP=0`.

---

## Codex

**Integration verified**; a full end-to-end write test was blocked by a usage limit
during development.

### Install

**macOS / Linux:**

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

**Windows PowerShell:**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

**npm:**

```bash
npm install -g @openai/codex
```

**Homebrew:**

```bash
brew install --cask codex
```

### Authenticate

```bash
codex login                  # ChatGPT OAuth in a browser
codex login --device-auth    # headless server: device-code flow
codex login status
```

On a server with no browser, `--device-auth` is the one you want. API-key alternative:

```bash
printenv OPENAI_API_KEY | codex login --with-api-key
```

### Verify

```bash
codex --version
codex doctor
```

Credentials land in `~/.codex/auth.json`; config in `~/.codex/config.toml`.

### Note for teams

Codex reads `AGENTS.md` natively, walking from the project root down to the working
directory, capped at 32 KiB. That is why the contract `init` writes doubles as Codex's
instruction channel and is kept under that limit.

---

## pi

**Untested.** pi was not installed on the machine where this skill was built, so its
adapter is written from documentation and source reading and has never been run. Verify a
single pi role by hand before trusting a fleet to it.

### Install

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

`--ignore-scripts` is part of the documented command, not an optional hardening flag.
Standalone binaries can also be built from source via `./scripts/build-binaries.sh` in
the `earendil-works/pi` repository.

### Authenticate

There is **no `pi login` subcommand.** Start the CLI and use the in-session slash command:

```bash
pi
# then, inside the session:
/login
```

Built-in subscription logins cover Claude Pro/Max, ChatGPT Plus/Pro (Codex), and GitHub
Copilot. Credentials land in `~/.pi/agent/auth.json`. To check state without a session:

```bash
pi auth check
```

### One thing worth knowing

pi does **not** wrap the `codex` CLI. It reimplements Codex's OAuth flow with the
byte-identical client id `app_EMoamEEZ73f0CkXaXp7hrann` and calls the Responses API
directly — which is why its models appear as `openai-codex/<model>`, and why an
`auth.openai.com/oauth/authorize?...&originator=pi` URL is simply a pi login artifact.
Installing pi does not give you `codex`, and vice versa.

---

## tmux (optional)

Only needed for `--layout tmux`. Everything works without it.

```bash
sudo apt install tmux      # Debian / Ubuntu
sudo dnf install tmux      # Fedora / RHEL
brew install tmux          # macOS
```

Version 3.5+ is preferable so `extended-keys` works (Shift+Enter inside panes). Verified
here on 3.7c.

---

## Python (for the monitor)

The dashboard is Python 3.8+ **standard library only** — no pip installs, no Node. Nearly
every Linux server already has it:

```bash
python3 --version
```

If missing: `sudo apt install python3` / `sudo dnf install python3`.

---

## Putting it together on a fresh Linux server

```bash
# runtimes
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh

# authenticate (codex uses the device flow when there is no browser)
claude
codex login --device-auth

# optional
sudo apt install tmux

# the skill itself
git clone <repo> ~/skills/agent-teams
bash ~/skills/agent-teams/bin/agent-teams doctor
```

`doctor` tells you what is still missing. Then, once per project, trust the directory —
background agents in an untrusted directory block forever:

```bash
cd /path/to/project && claude    # accept the trust prompt, then exit
```
