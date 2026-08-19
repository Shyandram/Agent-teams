# Library aim — {{PROJECT_NAME}}

> For a reusable component: something other code depends on. The distinguishing
> constraint is that **the interface is the product** — callers you cannot see will
> depend on every decision recorded here.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## What it does

> One sentence a prospective user would recognise as their problem.

TODO

## Who calls it, and from where

| Caller | Use case | Constraint they impose |
|---|---|---|
| TODO | TODO | TODO |

## Public surface

> Everything here is a promise. Keep it as small as it can be — an interface is far
> easier to widen later than to narrow.

| Symbol | Signature | Stability |
|---|---|---|
| TODO | TODO | stable / experimental |

**Explicitly not public:** TODO

## Compatibility

- **Versioning:** TODO — semver, and what counts as breaking here
- **Supported versions of {{PRIMARY_LANGUAGE}}:** TODO
- **Deprecation policy:** TODO — how long a deprecated symbol survives
- **Breaking changes require:** a migration note, a deprecation period, and a major bump

## Non-goals

> What this library deliberately does not do, so callers do not ask. The most useful
> section for keeping a library small.

- TODO

## Error behaviour

> How failures reach the caller: exceptions, results, error values. Consistency matters
> more than the choice.

TODO

## Performance envelope

> The complexity or throughput callers may rely on. Anything stated here is a promise.

TODO

## Verification

- Build: `{{BUILD_CMD}}` · Test: `{{TEST_CMD}}` · Lint: `{{LINT_CMD}}`
- Public surface covered by tests: TODO
- Examples in the docs are executed as tests: TODO

---

## For the team

- **The interface is the product.** A change that is easy internally but visible to
  callers is expensive; say so before making it.
- **Never break a documented promise silently.** Deprecate, document, then remove.
- **Every public symbol has a test and an example**, or it is not public yet.
