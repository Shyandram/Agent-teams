# Internal interfaces — frozen contract

Every component in this skill agrees on the shapes below. Do not change one without
changing its consumers. Paths are relative to the **target project** unless noted.

## 1. `roles/<name>.md` — role source of truth (ships with the skill)

YAML frontmatter, then prose body.

```markdown
---
name: engineering
description: Implements features, owns architecture and build health. Use for writing and refactoring application code.
when_to_use: Code needs to be written, changed, reviewed for correctness, or the build is broken.
tools: Read, Write, Edit, Bash, Grep, Glob, TodoWrite
model_tier: smart          # smol | regular | smart | ultra
permission_mode: acceptEdits   # claude: acceptEdits | auto | manual | plan | dontAsk
sandbox: workspace-write       # codex: read-only | workspace-write | danger-full-access
---

You are the ENGINEERING role on an agent team.
...prose...
```

Rules:
- **No `skills:` or `mcpServers:` frontmatter.** Both are silently ignored for teammates
  (verified). Roles must be self-contained prose.
- Body must make sense when *appended* to an existing system prompt — it augments, it
  does not replace.
- Body must not assume a specific runtime; runtime-specific text is the launcher's job.

## 2. `.agent-teams/team.yaml` — per-project team manifest (written by `init`)

```yaml
version: 1
project_name: acme
default_runtime: claude-code    # claude-code | codex | pi
general: lead                   # the role you occupy; launch skips it by default
roles:
  - name: lead
    runtime: claude-code
    model_tier: smart
    permission_mode: acceptEdits
    sandbox: workspace-write
    general: true               # marks the general; mirrors the top-level key
  - name: research
    runtime: codex
    model_tier: regular
    permission_mode: acceptEdits
    sandbox: workspace-write
```

`init` emits every role with all four policy keys regardless of runtime; the launcher
selects `permission_mode` for `claude-code` and `sandbox` for `codex`/`pi`.

Parsed by a deliberately naive reader (no `yq` dependency): keys one per line, list items
two-space indented starting `- name:`. Keep emitted files in exactly this shape.

`model_tier` is portable intent; each runtime adapter maps it to a concrete model.
An optional `model:` key pins a concrete model for that role and beats the tier — it is
where `agent-teams model set` records the lead's judgement.

`at_team_roles` emits **nine fields separated by US (`\037`), not tab**:
`name`, `runtime`, `model_tier`, `permission_mode`, `sandbox`, `model`, `role` (base),
`focus`, `group`.

Tab would be wrong here: tab is IFS-*whitespace*, so bash `read` collapses runs of tabs
and silently drops empty fields — an empty `model` would shift `role` into its place. US
is not whitespace, so empty fields survive. Every reader must use `IFS=$'\037'`.

`name` is the instance name and is unique; `role` is the definition it is built from.
That is what lets several instances of one role run at once (`research-lit` and
`research-data` are both `research`), each with its own `focus`. `group` names the squad
an instance belongs to.

Model precedence is resolved in exactly one place, `at_resolve_model`, highest first:
`--model-for` > `--tier-for` > `model:` > `AGENT_TEAMS_MODEL` > `model_tier`.
`AGENT_TEAMS_MODEL_LOCK=1` promotes the env var above everything as a hard cap.
Adapters' `map_tier` must stay a pure tier->model mapping and must not consult the
environment, or precedence would be decided in two places.

## 3. `.agent-teams/sessions/<role>.json` — runtime state (written by `launch`)

```json
{
  "role": "engineering",
  "runtime": "claude-code",
  "layout": "bg",
  "session_id": "fe98f3d0",
  "full_session_id": "fe98f3d0-dc57-4d39-bc50-ec0f8d49839d",
  "pid": 81993,
  "tmux_target": null,
  "log": ".agent-teams/logs/engineering.log",
  "cwd": "/abs/path/to/project",
  "started_at": "2026-08-20T06:05:00Z"
}
```

- `layout` is `bg` or `tmux`.
- `tmux_target` is `session:window` when `layout=tmux`, else `null`.
- `full_session_id` may be `null` right after launch; the monitor resolves it from
  `claude agents --json` by matching `id`.
- Codex roles have `session_id: null` until the first rollout file appears.

## 4. Other project paths written by `init`

```
AGENTS.md                        # the contract; Codex reads this natively
docs/coordination/README.md      # protocol
docs/coordination/_template.md   # per-session note template
.claude/agents/<role>.md         # Claude subagent definitions (Mode A + B)
.claude/settings.json            # permissions.allow / .deny for background roles
.agent-teams/prompts/<role>.txt  # --append-system-prompt-file payload (Mode B)
.agent-teams/team.yaml
.agent-teams/logs/<role>.log
.agent-teams/sessions/<role>.json
```

`.claude/settings.json` exists because `--permission-mode acceptEdits` does **not** cover
`Bash`, so a background role would block on its first command. It is written only when
absent (or with `--force`), never silently overwritten, and it is the security-relevant
output of `init` — surface it to the user rather than treating it as boilerplate.
Note that matching applies to whole commands: an entry for `git add` does not permit
`git add X && git commit ...`.

`.gitignore` gains `.agent-teams/logs/` and `.agent-teams/sessions/`.

## 5. Monitor `GET /api/state` response

```json
{
  "project": "/abs/path",
  "project_name": "acme",
  "generated_at": "2026-08-20T06:30:00Z",
  "roles": [
    {
      "role": "engineering",
      "runtime": "claude-code",
      "layout": "bg",
      "state": "working",
      "status": "busy",
      "pid": 81993,
      "session_id": "fe98f3d0",
      "idle_seconds": 3,
      "last_activity": "2026-08-20T06:29:57Z",
      "last_text": "Refactored the auth module and reran the tests.",
      "note_status": "active",
      "error": null
    }
  ],
  "warnings": ["codex quota exhausted for role research"]
}
```

`state` is one of, in descending order of how loudly the UI shows it:

| state | meaning |
|---|---|
| `blocked` | waiting on a permission prompt — will never self-resolve. **Loudest.** |
| `errored` | runtime reported an error (e.g. Codex quota exhausted) |
| `stopped` | session ended |
| `working` | actively producing |
| `idle` | alive, nothing in flight |
| `unknown` | declared in `team.yaml` but no live session found |

## 6. Runtime adapter contract — `runtimes/<name>.sh`

Sourced or executed with a verb as `$1`:

| Verb | Args | Contract |
|---|---|---|
| `detect` | — | exit 0 if installed **and** authenticated; print a one-line reason on failure |
| `launch` | `<role> <prompt_file> <task> <log> <project> <layout> [tmux_target] [policy] [model]` | start the session; print the session id on stdout; exit non-zero on failure. `policy` is `permission_mode` for claude-code and `sandbox` for codex/pi. `model` is already resolved — do not re-map it; empty means "provider default" |
| `status` | `<project>` | print `role<TAB>state<TAB>session_id` lines for its own runtime |
| `stop` | `<session_id> [--kill]` | stop cleanly; exit 0 if already gone |
| `map_tier` | `<model_tier>` | print the concrete model name for this runtime |

Hard-won rules every adapter must honour (see `SPIKE-FINDINGS.md`):
- Always redirect stdin from `/dev/null` — Codex otherwise blocks reading stdin.
- Never use `timeout(1)` — absent on macOS.
- Never parse `claude logs`; read the session transcript JSONL instead.
