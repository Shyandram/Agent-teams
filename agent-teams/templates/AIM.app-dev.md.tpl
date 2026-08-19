# Product aim — {{PROJECT_NAME}}

> The single source of truth for what this project is building and when it is done.
> Every role reads this before its own brief. If work does not serve something written
> here, it is out of scope — say so rather than doing it.
>
> Fill this in **before** launching the team. An unfilled aim produces roles that invent
> their own requirements and quietly build different products.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## Problem

> Whose problem, and what it costs them today. Not the feature — the problem the feature
> is for. If you cannot name who is hurting, you are not ready to build.

TODO

## Users

| Who | What they are trying to do | How they do it today |
|---|---|---|
| TODO | TODO | TODO |

## Outcome

> What is true when this works, from the user's side. Observable, not internal:
> "a user can recover a deleted draft without contacting support", not "add undo stack".

TODO

## Acceptance criteria

> Decided **now**, not after the build. These are what QA verifies against and what
> "done" means. Each must be checkable by someone who did not write the code.

- [ ] TODO
- [ ] TODO

## Non-goals

> What this deliberately does not do, and why. The most useful section here: it is what
> stops a parallel team from expanding scope indefinitely.

- TODO — deferred because TODO
- TODO — not doing, because TODO

## Constraints

| Kind | Constraint |
|---|---|
| Technical | TODO |
| Compatibility | TODO — existing data, APIs, stored state |
| Performance | TODO — with a number, or say "not a constraint" |
| Security / privacy | TODO |
| Deadline | TODO |

## Architecture decisions

> Decisions already made that roles must not silently relitigate. Record the reason —
> a decision without one gets reversed by the next session that finds it inconvenient.

| Decision | Reason | Decided |
|---|---|---|
| TODO | TODO | TODO |

## Verification

- Build: `{{BUILD_CMD}}`
- Test: `{{TEST_CMD}}`
- Lint: `{{LINT_CMD}}`
- Language: {{PRIMARY_LANGUAGE}}

Manual checks that automation does not cover: TODO

## Rollout

> How this reaches users, and how it gets undone if it is wrong. A change with no way
> back is a decision, not a deployment.

TODO

## Open questions

- TODO

---

## For the team

Several instances of one role may work different slices at once — two engineers on two
services, several QA instances on different surfaces. Each one's `focus` in
`.agent-teams/team.yaml` says which slice is theirs.

Rules that override role instinct:

- **Acceptance criteria are fixed before the work.** Changing them after seeing the
  implementation is a scope change and must be raised, not absorbed.
- **A non-goal is a decision, not a suggestion.** If you believe one is wrong, say so;
  do not quietly build it.
- **Verified means run.** Never report a check as passing unless you ran it in this
  workspace and saw it pass.
- **Compatibility is not optional.** Stored data, public shapes, and existing callers
  keep working unless a migration is part of the task.
