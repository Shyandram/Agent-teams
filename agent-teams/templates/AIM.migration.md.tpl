# Migration aim — {{PROJECT_NAME}}

> For moving from one thing to another: a framework, a schema, a service, a dependency.
> The distinguishing constraint is that **both states must work during the move** — a
> migration that requires a flag day usually does not land.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## From → to

| | Current | Target |
|---|---|---|
| What | TODO | TODO |
| Why it is inadequate | TODO | — |
| What the target buys | — | TODO |

## Why now

> Migrations have a real cost and compete with feature work. What makes this the moment?

TODO

## Inventory

> What has to move, counted. A migration plan without a count is a guess.

| Surface | Count | Owner | Difficulty |
|---|---|---|---|
| TODO | TODO | TODO | easy / awkward / unknown |

**Unknowns to resolve before committing:** TODO

## Strategy

- [ ] **Incremental** — old and new coexist; move a slice at a time *(preferred)*
- [ ] **Big bang** — one cutover *(requires justification: why can these not coexist?)*

**Coexistence mechanism:** TODO — adapter, shim, dual-write, feature flag

## Order

> Sequenced, with the reason. Usually: lowest-risk first to prove the path, highest-churn
> last so it does not rot while you work.

1. TODO
2. TODO

## Rollback

> For each stage: how to get back, and whether it has been *tested* rather than assumed.
> A migration stage with no tested rollback is a one-way door.

| Stage | Rollback | Tested? |
|---|---|---|
| TODO | TODO | no |

## Definition of done

- [ ] Every item in the inventory moved, or explicitly recorded as abandoned
- [ ] The old path removed, not merely unused
- [ ] Docs, examples, and CI reference only the new path
- [ ] No compatibility shim left behind without a removal date

## Risks

| Risk | Blast radius | Mitigation |
|---|---|---|
| TODO | TODO | TODO |

---

## For the team

- **Both states work at every commit.** Never leave the repository in a half-migrated
  state that only builds on your machine.
- **Behaviour does not change during a migration.** If you find a bug, record it and fix
  it separately — a migration diff that also changes behaviour cannot be reviewed.
- **Count before you plan.** Report the real inventory even when it is worse than hoped.
- **An untested rollback is not a rollback.**
