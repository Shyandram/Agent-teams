# Research aim — {{PROJECT_NAME}}

> The single source of truth for what this research is trying to establish. Every role
> reads this before its own brief. If work does not serve something written here, it is
> out of scope — say so rather than doing it.
>
> Fill this in **before** launching the team. An unfilled aim produces roles that invent
> their own objectives and quietly diverge.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## Question

> The one question this research answers, stated so that a wrong answer is possible.
> "Does X improve Y under Z?" — not "explore X".

TODO

## Why it matters

> What becomes possible, or what decision gets made, once this is answered. If nothing
> changes either way, reconsider the question.

TODO

## Hypotheses

| # | Hypothesis | What would falsify it |
|---|---|---|
| H1 | TODO | TODO |
| H2 | TODO | TODO |

> Every hypothesis needs a falsifier. One with no way to be wrong is not a hypothesis,
> and no amount of analysis will make it one.

## Success criteria

> What must be true for this to be finished. Numeric where possible, and decided **now**
> rather than after seeing results — a threshold chosen afterwards is not a threshold.

- TODO
- TODO

## Scope

**In scope:** TODO

**Explicitly out of scope:** TODO

> The second list matters more than the first. It is what stops a parallel team from
> expanding indefinitely.

## Method

> How the question gets answered: design, comparisons, baselines, controls.
> Name the baseline you are beating and why it is the fair one.

TODO

## Data

| Source | Access | Licence / terms | Retrieved | Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

> Provenance is recorded when data arrives, not reconstructed later. A dataset whose
> licence nobody checked is a finding you cannot publish.

## Validity threats

> How this could produce a confident wrong answer. Be specific; "bias" is not a threat,
> "the control group was drawn from a different period" is.

| Threat | Why it could bite | Mitigation |
|---|---|---|
| TODO | TODO | TODO |

Standing threats to check against regardless: leakage between train and evaluation
splits, a metric that rewards the wrong behaviour, results that only hold on the subset
that was examined, and a comparison whose baseline was tuned less carefully than the
method.

## Deliverables

- TODO — e.g. a reproducible result with seed and command
- TODO — e.g. a written finding with evidence and stated limits

## Reproducibility

- Commands: `{{BUILD_CMD}}` · `{{TEST_CMD}}`
- Seeds: TODO
- Environment: {{PRIMARY_LANGUAGE}}, TODO
- Every reported number must be reproducible from a recorded command and seed. A number
  no one can regenerate is not a result.

## Open questions

> Things not yet decided. Better recorded here than silently resolved by whoever hits
> them first.

- TODO

---

## For the team

Multiple instances of one role work different slices of this aim at once — several
researchers on different literatures, several analysts on different hypotheses. Each
one's `focus` in `.agent-teams/team.yaml` says which slice is theirs.

Rules that override role instinct:

- **A negative result is a result.** Report it. Do not go looking for a framing that
  makes it positive.
- **Missing data stays missing.** Do not fill a gap with a plausible value; mark it and
  say what is unknown.
- **The hypothesis is fixed before the analysis.** Changing it after seeing results is a
  new hypothesis and must be labelled as one.
- **Claims carry their evidence.** Every claim in a deliverable names the run, seed, or
  source that supports it.
