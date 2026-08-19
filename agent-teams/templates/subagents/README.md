# Subagents

Helpers that belong to **one role only**. Another role cannot see or call them, and two
roles may carry different definitions under the same name without colliding.

They are passed to the runtime per session (`claude --agents`), which is what makes them
private — a file in `.claude/agents/` would be visible to every session in the project.

    .agent-teams/subagents/<role>/<name>.md

`init` gives every role its own copy of `explorer`, `critic`, and `verifier`. They are
copies, so you can specialise one role's critic without touching anyone else's.

    agent-teams subagent list
    agent-teams subagent list engineering
    agent-teams subagent new engineering migration-checker

## Format

```markdown
---
name: explorer
description: when the owning role should call this
tools: Read, Grep, Glob
model_tier: smol
---
The subagent's system prompt.
```

`description` is what the owning role reads when deciding whether to delegate, so write
it as a trigger condition, not a title.

`model_tier` maps the same way as roles (`smol`/`regular`/`smart`/`ultra`). Helpers are
usually cheaper than their owner — that is much of the point.

## When they earn their keep

Delegate work that is separable and context-hungry: a wide search, an adversarial review,
a long verification run. Doing it in a subagent keeps that noise out of the role's own
window.

Do not delegate work that needs context the role already holds, or that is small enough
that explaining it costs more than doing it. A subagent starts with no history and
returns only its final message.
