# Experiment aim — {{PROJECT_NAME}}

> One focused experiment, not a research programme. Narrower than `AIM.research.md`:
> a single question, a single design, a decision at the end.
>
> Fill this in **before** launching. Fixing the design after seeing results is how an
> experiment becomes a story.
>
> Last updated: <YYYY-MM-DD> by <role/person>

## The question     <!-- aim:objective -->

> One sentence. A wrong answer must be possible.

TODO

## The decision this informs     <!-- aim:rationale -->

> What you will do differently depending on the outcome. If the answer changes nothing,
> do not run the experiment.

- If it holds: TODO
- If it does not: TODO

## Design     <!-- aim:method -->

| | |
|---|---|
| Independent variable | TODO — the one thing that changes |
| Held constant | TODO — everything that must not |
| Measured | TODO — the outcome, and how it is computed |
| Baseline | TODO — what this is compared against |
| Sample / runs | TODO — how many, and why that many |
| Seeds | TODO |

**Pre-registered threshold:** TODO
> The number that counts as success, written down before any result is seen. A threshold
> chosen afterwards is not a threshold.

## Confounds     <!-- aim:risks -->

| Confound | Why it could explain the result instead | Control |
|---|---|---|
| TODO | TODO | TODO |

## What would falsify the expected result     <!-- aim:hypotheses -->

TODO
> If you cannot answer this, the experiment is not yet designed.

## Stopping rule     <!-- aim:verification -->

> When to stop, decided in advance — including when to stop early because it is clearly
> not working. Without one, an experiment runs until someone gets a result they like.

TODO

## Outputs     <!-- aim:outputs -->

- [ ] The number, with its seed and command
- [ ] The raw output, kept
- [ ] A one-paragraph finding, including the case against it

## Current state     <!-- aim:current -->

> Where the run has got to. Update it as the experiment proceeds; a reader should not
> have to reconstruct progress from logs.

- **Runs completed:** TODO
- **Result so far:** TODO — and whether it has moved since the last update
- **Blocked:** TODO

## Definition of done     <!-- aim:done -->

> An experiment is done when the stopping rule fires, not when someone is satisfied.

- [ ] The stopping rule fired, and which branch of it
- [ ] The number is reproducible from the recorded command and seed
- [ ] The finding states the case against itself
- [ ] TODO

---

## For the team     <!-- aim:team -->

- **Run first, interpret second.** Do not adjust the design mid-run to rescue a result.
- **A null result is the answer**, not a failure. Report it with the same care.
- **Every number carries its command and seed.** A figure nobody can regenerate is not
  evidence.
- **Claims get audited.** Where the team has a `verification` role, a `status: done` is a
  hypothesis until it returns *confirmed*. *Unverifiable* — nothing recorded to re-run —
  is a finding, not a pass. Record the command or seed that would let someone else check
  you, at the time you make the claim, not afterwards.
