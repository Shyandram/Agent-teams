# Roles

One file per role. Each file is the **source of truth** for that role: the launcher reads
it, renders the body into `.agent-teams/prompts/<role>.txt`, and appends it to the agent's
existing system prompt. Nothing here replaces the base identity — every body augments it.

- `roles/*.md` — core roles, used by the shipped presets.
- `roles/extras/*.md` — optional roles, added explicitly with `--roles`.

## Format

YAML frontmatter, then a prose body. The frontmatter shape is frozen in
`docs/INTERFACES.md` §1.

```markdown
---
name: engineering
description: Implements features, owns architecture and build health. Use for writing and refactoring application code.
when_to_use: Code needs to be written, changed, reviewed for correctness, or the build is broken.
tools: Read, Write, Edit, Bash, Grep, Glob, TodoWrite
model_tier: smart
permission_mode: acceptEdits
sandbox: workspace-write
---

You are the ENGINEERING role on an agent team.
...prose...
```

| Key | Meaning |
|---|---|
| `name` | Role id. Must match the filename stem. |
| `description` | One line: what the role does. Shown in listings and role pickers. |
| `when_to_use` | The condition that should cause this role to be engaged. |
| `tools` | Comma-separated tool names the role may use. |
| `model_tier` | `smol` \| `regular` \| `smart` \| `ultra` — portable intent; each runtime adapter maps it to a concrete model. |
| `permission_mode` | Claude-side: `acceptEdits` \| `auto` \| `manual` \| `plan` \| `dontAsk`. |
| `sandbox` | Codex-side: `read-only` \| `workspace-write` \| `danger-full-access`. |

Hard rules:

- **No `skills:` or `mcpServers:` frontmatter.** Both are silently ignored for teammates
  (verified). Roles must be self-contained prose.
- **No runtime-specific text in the body.** Never name a CLI, a flag, or a vendor. The
  launcher owns runtime specifics; the body must read identically under any of them.
- **The body is appended, not substituted.** No "You are Claude"-style preamble, no
  attempt to redefine base identity or override safety behaviour.
- **Every body states four things**: what the role owns, an explicit "Do not" list, how it
  coordinates, and its definition of done. Aim for 250–450 words — dense and operational.

## Coordination contract

Every role writes a coordination note at `docs/coordination/<session-id>.md`, using its own
session identifier, from `docs/coordination/_template.md`. Roles read other sessions' notes
before starting, and **hand off** rather than overwriting — no role edits another session's
files or note. Cross-role conflicts go to `lead` for reconciliation.

## Shipped roles

| Role | Tier | Writes? | Owns |
|---|---|---|---|
| `lead` | smart | yes | Acceptance criteria, cross-role reconciliation, integration |
| `engineering` | smart | yes | Implementation, architecture, build health, domain boundaries |
| `research` | regular | note only | Primary sources, provenance discipline, data stewardship |
| `analysis` | smart | note only | Modeling, statistics, evaluation correctness, reproducibility |
| `qa` | regular | note only | Verification, accessibility, release gating |
| `ux` | regular | yes | Information hierarchy, uncertainty/provenance/loading/error states |
| `devops` | regular | yes | Deploy, environments, CI/CD, infra |
| `extras/translation` | regular | yes | Locale parity, key-shape preservation |
| `extras/legal` | smart | note only | Licensing, privacy, trademarks, compliance risk |
| `extras/simulation` | smart | yes | Simulation integrity, provenance classes, seeded reproducibility |
| `extras/product-marketing` | regular | yes | Positioning inside verified capability |

"note only" roles have `Write` in their tool list solely so they can maintain their
coordination note; `permission_mode: manual` + `sandbox: read-only` keep them from silently
changing project files, and their bodies say so explicitly.

## Presets

| Preset | Roles |
|---|---|
| `research` | `lead`, `research`, `analysis`, `engineering`, `qa` |
| `app-dev` | `lead`, `engineering`, `ux`, `qa`, `devops` |
| `full-stack` | `app-dev` + `product-marketing`, `legal` — i.e. `lead`, `engineering`, `ux`, `qa`, `devops`, `product-marketing`, `legal` |

Override any preset with `--roles a,b,c`. Extras are referenced by bare name
(`--roles lead,engineering,simulation`); the loader looks in `roles/` first, then
`roles/extras/`.

## Adding a custom role

1. Create `roles/<name>.md` (or `roles/extras/<name>.md` for optional roles) with `name`
   matching the filename stem.
2. Fill all seven frontmatter keys. Pick `tools` as the minimum the role genuinely needs;
   give `Write`/`Edit` only to roles that produce project files. Pair a writing role with
   `permission_mode: acceptEdits` + `sandbox: workspace-write`, and a reviewing role with
   `permission_mode: manual` (or `plan`) + `sandbox: read-only`.
3. Write a 250–450 word body covering the four required elements, in the same
   second-person, runtime-neutral voice as the shipped roles. Spend most of the words on
   the "Do not" list — that is where role-specific judgement lives.
4. Add the role to `--roles`, or to a preset if it should be part of a default team.

A good role is falsifiable: someone reading the body can tell whether a given piece of
output complies with it. If a rule would not change what an agent does, cut it.
