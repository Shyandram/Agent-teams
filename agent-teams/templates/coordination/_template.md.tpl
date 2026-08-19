---
session_id: <YYYYMMDD-HHMM-role-short-task>
role: <role name, matching .agent-teams/team.yaml>
status: active
started: <YYYY-MM-DD HH:MM {{TIMEZONE}}>
updated: <YYYY-MM-DD HH:MM {{TIMEZONE}}>
branch: <git branch this session works on>
---

# <session-id>

> Copy this file to `docs/coordination/<session-id>.md` before your first edit.
> Update it whenever the facts change — not only at the end. Delete these quoted
> instruction lines once you have filled the section in.
>
> **`status` must be exactly one of `active`, `blocked`, `handoff`, `complete`** — the
> monitor reads that field literally, so no trailing comments or extra words. Bump
> `updated` every time you change anything here. Never leave a note `active` when your
> session ends.
>
> **Be brief.** This note is read by other sessions whose context is the scarcest thing
> on the team. Target ~10 lines of actual content across all sections; a section with
> nothing to say gets one line or `none`. Lead with the decision, reference files as
> `path:line` and commits as SHAs instead of pasting them, and cut every sentence that
> narrates process rather than changing what the reader does. Cut words, never
> substance — a failed check or a shaky assumption always stays.

## Objective

> What this session is trying to accomplish, in one or two sentences, and the acceptance
> criteria you will judge yourself against. Specific enough that another session can tell
> whether it was met.

## Intended files

> Paths you expect to touch. This is a **soft claim** — a courtesy signal, not a lock and
> not ownership. Add paths as the work grows; note any you claimed but did not touch.

- `path/to/file`

## Dependencies

> What this session depends on, and what depends on it.
> - Other sessions: `<session-id>` — blocking / blocked by / took over from
> - Work that must land first, external services, credentials, data, approvals
> - Nothing? Write "none".

## Decisions & reasons

> Choices another session would otherwise have to re-derive or might accidentally undo.
> Record the alternative you rejected and why. Label assumptions as assumptions.

| Decision | Reason | Alternative rejected |
|---|---|---|
| | | |

## Files changed

> What you actually changed, once changed. Keep it current — this is what a reviewer and
> the next session read first.

| Path | Change | Committed as |
|---|---|---|
| | | `<short sha>` or `uncommitted` |

## Commands run and their ACTUAL results

> Only commands you really ran in this workspace, in this session, with the output you
> really saw. Never record a check you did not run or a result you expect.
> Mark anything skipped, blocked, or failing for a pre-existing reason, and say why.

| Command | Result | Notes |
|---|---|---|
| `` | pass / fail / blocked / skipped | |

## Open questions / risks

> What you are unsure about, what could break, what you could not verify, and what you
> would check next. Negative results and disproven approaches belong here — they save the
> next session the same dead end.
> Another session may append a clearly attributed line under this heading; nowhere else.

-

## Exact next action for another session

> One specific, executable action — not a summary of remaining work. Precise enough that
> a session with none of your context can start immediately.
> Required before setting `status: handoff`, together with: what is done, what is
> deliberately not done, branch and HEAD commit, working-tree state (clean, or exactly
> what is uncommitted and why), and the commands to reproduce your last result.

- **Next action:**
- **Branch / HEAD:**
- **Working tree:** clean | uncommitted: <what and why>
- **Deliberately not done:**
