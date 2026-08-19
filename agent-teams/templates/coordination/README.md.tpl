# Coordination notes — {{PROJECT_NAME}}

This directory is how concurrent sessions — human and agent, on any runtime — stay out of
each other's way. It is the **only** reliable channel between sessions: teammate agents
cannot message one another directly, so anything another session needs to know must be
written down here and committed.

The full protocol is normative in the repository's `AGENTS.md`. This file is the working
reference.

---

## What lives here

```
docs/coordination/
├── README.md              # this file
├── _template.md           # copy this to start a note
└── <session-id>.md        # one note per session
```

`_template.md` is a template, never an active note. Do not edit it to record work.

---

## Session identity

Every session adopts an identity at start:

```
YYYYMMDD-HHMM-<role>-<short-task>
```

| Part | Meaning |
|---|---|
| `YYYYMMDD-HHMM` | Session start time, in the project timezone ({{TIMEZONE}}) |
| `<role>` | Role name, matching the entry in `.agent-teams/team.yaml` |
| `<short-task>` | Two to four lowercase hyphenated words describing the task |

Example: `20260820-0930-engineering-fix-auth-refresh`

The same string is the note filename (`docs/coordination/20260820-0930-engineering-fix-auth-refresh.md`),
the `session_id` in its frontmatter, and how you refer to yourself to other sessions.

Two sessions of the same role starting in the same minute must differ in `<short-task>`.
If they would not, add a distinguishing word — the identity has to be unique.

---

## Starting a note

1. `cp docs/coordination/_template.md docs/coordination/<session-id>.md`
2. Fill in the frontmatter and the Objective.
3. **Do this before your first edit**, not after you finish.
4. Commit it early; update and commit it as facts change.

Before you start, read every note here whose `status` is `active`, `blocked`, or
`handoff`. Those are the sessions whose work can collide with yours.

---

## Note lifecycle

`status` moves through these states. It is a single value in the frontmatter.

```
        ┌──────────────────────────────► complete
        │                                   ▲
     active ◄──────────► blocked ───────────┘
        │                   │
        └───► handoff ◄─────┘
                │
                └──► (another session opens its own note and continues)
```

| Status | Meaning | The note must contain |
|---|---|---|
| `active` | Work in flight | Objective, intended files, what you have done so far |
| `blocked` | Cannot proceed, will not self-resolve | Exactly what is needed, and from whom |
| `handoff` | Resumable, offered to another session | The full handoff checklist below |
| `complete` | Finished and verified | Files changed, commands run with their real results |

Rules:

- **Update `updated` on every change** to the note.
- **Never leave a note `active` when your session ends.** Move it to `complete`,
  `handoff`, or `blocked` — whichever is honest.
- **`complete` means verified**, not "code written". The commands you ran and what they
  actually printed belong in the note. Never record a check you did not run.
- **Never mark another session's note `complete`.** Only the owning session may close its
  own note. The one permitted edit to someone else's note is appending a clearly
  attributed line under its Open questions section.

---

## Notes are soft claims, not locks

Listing a file under **Intended files** signals *"I am working here"*. It does not reserve
the file and it does not confer ownership.

- Prefer picking work that does not overlap an active claim.
- If you must touch a claimed file, make the smallest possible change, leave the other
  session's work intact, and record exactly what you changed and why in your own note.
- A stale claim does not block the repository. If a note has not been updated in a long
  time and its work is plainly not in flight, you may proceed — but write down that you
  did, and what state you found things in.
- **Git is the authority on what exists.** A note that disagrees with the working tree is
  out of date, not a fact. Check `git status --short` and `git log` before trusting a note.

An apparently idle session is not necessarily a finished one: a runtime that has hit a
usage limit stops producing output and looks identical to one that is done. Before
treating work as abandoned, look for evidence it finished — a terminal-state note,
commits, changed files — and check the role's log for an error or quota message.

---

## Handing off

Before setting `status: handoff`, the note must contain all of:

- **What is done** — concretely, not "made progress".
- **What is deliberately not done** — and why, so the next session does not redo it.
- **The exact next action** — one specific action, precise enough to execute without
  reconstructing your reasoning.
- **Branch and commit** — the branch name and the HEAD commit your work sits on.
- **Working-tree state** — clean, or exactly what is uncommitted and why.
- **Commands to reproduce your last result** — with the output you actually saw.

---

## Taking over a `handoff`

1. Read the source note in full, then verify its claims against the repository: `git
   status --short`, `git log --oneline -15`, and re-run its key commands. Do not build on
   an unverified claim.
2. **Open your own note** with your own session id. Reference the source session id in
   the Dependencies section (`took over from <session-id>`).
3. State in your note what you inherited and what you verified — including anything in the
   source note that turned out to be stale.
4. **Leave the original note as `handoff`.** Do not edit it and do not mark it
   `complete`; it is the other session's record and stays intact.
5. If you decide *not* to continue the work after all, say so in your note so the next
   reader knows the handoff was seen and declined.

---

## Conflict priority

When instructions or evidence disagree, highest wins:

1. Explicit user direction in the current session
2. Repository evidence — code, tests, observed behaviour
3. Documented project constraints — `AGENTS.md`, `docs/`, coordination notes
4. Role recommendation

A lower item never overrides a higher one. When user direction conflicts with repository
evidence, do not silently pick a side: state the conflict with the evidence, and ask.

---

## Housekeeping

- Notes are committed to the repository — they are the durable record, not scratch files.
- Do not delete other sessions' notes. Completed notes are project history; archive them
  in bulk only when the user asks.
- Keep notes factual and short. A note is read by someone with none of your context, often
  under time pressure.
