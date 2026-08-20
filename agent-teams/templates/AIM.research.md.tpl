# Research aim — {{PROJECT_NAME}}

> The single source of truth for what this research is trying to establish. Every role
> reads this before its own brief. If work does not serve something written here, it is
> out of scope — say so rather than doing it.
>
> Fill this in **before** launching the team. An unfilled aim produces roles that invent
> their own objectives and quietly diverge.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## Question     <!-- aim:objective -->

> The one question this research answers, stated so that a wrong answer is possible.
> "Does X improve Y under Z?" — not "explore X".

TODO

## Why it matters     <!-- aim:rationale -->

> What becomes possible, or what decision gets made, once this is answered. If nothing
> changes either way, reconsider the question.

TODO

## Hypotheses     <!-- aim:hypotheses -->

| # | Hypothesis | What would falsify it |
|---|---|---|
| H1 | TODO | TODO |
| H2 | TODO | TODO |

> Every hypothesis needs a falsifier. One with no way to be wrong is not a hypothesis,
> and no amount of analysis will make it one.

## Success criteria     <!-- aim:success -->

> What must be true for this to be finished. Numeric where possible, and decided **now**
> rather than after seeing results — a threshold chosen afterwards is not a threshold.

- TODO
- TODO

## Scope     <!-- aim:boundary -->

**In scope:** TODO

**Explicitly out of scope:** TODO

> The second list matters more than the first. It is what stops a parallel team from
> expanding indefinitely.

## Prior art     <!-- aim:prior-art -->

> What already exists that partly answers this, and why it is not enough.
>
> **Fill this in before designing the method.** It is often what reveals the question has
> already been answered — which is a result, cheaply obtained, and worth more than a
> method designed in ignorance of it.

| Work | What it established | Why it does not settle this |
|---|---|---|
| TODO | TODO | TODO |

## Method     <!-- aim:method -->

> How the question gets answered: design, comparisons, baselines, controls.
> Name the baseline you are beating and why it is the fair one.

TODO

## Data     <!-- aim:inputs -->

| Source | Access | Licence / terms | Retrieved | Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

> Provenance is recorded when data arrives, not reconstructed later. A dataset whose
> licence nobody checked is a finding you cannot publish.

## Validity threats     <!-- aim:risks -->

> How this could produce a confident wrong answer. Be specific; "bias" is not a threat,
> "the control group was drawn from a different period" is.

| Threat | Why it could bite | Mitigation |
|---|---|---|
| TODO | TODO | TODO |

Standing threats to check against regardless: leakage between train and evaluation
splits, a metric that rewards the wrong behaviour, results that only hold on the subset
that was examined, and a comparison whose baseline was tuned less carefully than the
method.

## Deliverables     <!-- aim:outputs -->

- TODO — e.g. a reproducible result with seed and command
- TODO — e.g. a written finding with evidence and stated limits

## Reproducibility     <!-- aim:verification -->

- Commands: `{{BUILD_CMD}}` · `{{TEST_CMD}}`
- Seeds: TODO
- Environment: {{PRIMARY_LANGUAGE}}, TODO
- Every reported number must be reproducible from a recorded command and seed. A number
  no one can regenerate is not a result.

## Open questions     <!-- aim:open -->

> Things not yet decided. Better recorded here than silently resolved by whoever hits
> them first.

- TODO

## Current state     <!-- aim:current -->

> The running answer. Not what we plan to do — what we currently believe, and how
> strongly. The lead updates this at every checkpoint; everyone else reads it first.
>
> With several researchers and analysts working different slices at once, this is the
> only place the whole picture exists. Without it, a new instance reconstructs it from
> scattered coordination notes and often re-runs work that is already done.

| Hypothesis | Where it stands | Evidence | Confidence |
|---|---|---|---|
| H1 | untested / supported / contradicted | TODO — run, seed, or source | low / medium / high |

- **Ruled out so far:** TODO — and by what
- **Changed since the last update:** TODO
- **Blocked:** TODO — on what, and who is waiting

## Checkpoints     <!-- aim:checkpoints -->

> Points at which the direction is re-examined against evidence, not just continued.
> Without these a research team optimises for looking busy.

| When | What must be true by then | If it is not |
|---|---|---|
| TODO | TODO | TODO — abandon, narrow, or change approach |

## Ethics and compliance     <!-- aim:compliance -->

> Delete this section if there is genuinely no human data, no personal data, and no
> licensing constraint. Otherwise it is not optional.

- Human subjects / personal data involved: TODO
- Licences on data or models that restrict use or publication: TODO
- Approval required before publishing: TODO

## Definition of done for the whole project     <!-- aim:done -->

> Not per-task — for this research. What has to exist for the question to count as
> answered, including the case where the answer is "no".

- [ ] TODO
- [ ] The result is reproducible from a recorded command and seed
- [ ] The strongest objection to the result is written down and addressed

---

## For the team     <!-- aim:team -->

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
- **Claims get audited.** Where the team has a `verification` role, a `status: done` is a
  hypothesis until it returns *confirmed*. *Unverifiable* — nothing recorded to re-run —
  is a finding, not a pass. Record the command or seed that would let someone else check
  you, at the time you make the claim, not afterwards.
