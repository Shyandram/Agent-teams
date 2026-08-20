# Library aim — {{PROJECT_NAME}}

> For a reusable component: something other code depends on. The distinguishing
> constraint is that **the interface is the product** — callers you cannot see will
> depend on every decision recorded here.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## What it does     <!-- aim:objective -->

> One sentence a prospective user would recognise as their problem.

TODO

## Who calls it, and from where     <!-- aim:audience -->

| Caller | Use case | Constraint they impose |
|---|---|---|
| TODO | TODO | TODO |

## Public surface     <!-- aim:method -->

> Everything here is a promise. Keep it as small as it can be — an interface is far
> easier to widen later than to narrow.

| Symbol | Signature | Stability |
|---|---|---|
| TODO | TODO | stable / experimental |

**Explicitly not public:** TODO

## Compatibility     <!-- aim:constraints -->

- **Versioning:** TODO — semver, and what counts as breaking here
- **Supported versions of {{PRIMARY_LANGUAGE}}:** TODO
- **Deprecation policy:** TODO — how long a deprecated symbol survives
- **Breaking changes require:** a migration note, a deprecation period, and a major bump

## Non-goals     <!-- aim:boundary -->

> What this library deliberately does not do, so callers do not ask. The most useful
> section for keeping a library small.

- TODO

## Error behaviour     <!-- aim:risks -->

> How failures reach the caller: exceptions, results, error values. Consistency matters
> more than the choice.

TODO

## Performance envelope     <!-- aim:success -->

> The complexity or throughput callers may rely on. Anything stated here is a promise.

TODO

## Verification     <!-- aim:verification -->

- Build: `{{BUILD_CMD}}` · Test: `{{TEST_CMD}}` · Lint: `{{LINT_CMD}}`
- Public surface covered by tests: TODO
- Examples in the docs are executed as tests: TODO

## Current state     <!-- aim:current -->

> What is true right now. The lead updates this; everyone else reads it first. A role
> joining mid-flight should be able to start from here without reading every note.

- **Shipped:** TODO
- **In flight:** TODO — who owns it
- **Blocked:** TODO — on what
- **Decided since last update:** TODO

## Definition of done for the whole project     <!-- aim:done -->

> Not per-task — for this library. What must be true before callers should depend on it.

- [ ] Every symbol in the public surface has a test and a runnable example
- [ ] Every documented promise about compatibility and errors is enforced by a test
- [ ] TODO

---

## For the team     <!-- aim:team -->

- **The interface is the product.** A change that is easy internally but visible to
  callers is expensive; say so before making it.
- **Never break a documented promise silently.** Deprecate, document, then remove.
- **Every public symbol has a test and an example**, or it is not public yet.
- **Claims get audited.** Where the team has a `verification` role, a `status: done` is a
  hypothesis until it returns *confirmed*. *Unverifiable* — nothing recorded to re-run —
  is a finding, not a pass. Record the command or seed that would let someone else check
  you, at the time you make the claim, not afterwards.
