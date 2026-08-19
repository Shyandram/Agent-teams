# AGENTS.md — {{PROJECT_NAME}}

Shared operating agreement for every agent and human working in this repository.

**Scope.** This file applies to the whole repository, from the directory it sits in
downward. It is read natively by Codex, referenced by Claude Code sessions, and is the
contract each teammate is expected to have read *before* touching anything. A
subdirectory may add its own `AGENTS.md`; the nearest one wins for conflicts, but it may
only narrow this agreement, never loosen it.

**Project kind:** {{PROJECT_KIND}} · **Primary language:** {{PRIMARY_LANGUAGE}} ·
**Session timestamps:** {{TIMEZONE}}

**Read order for a new session:** this file → `docs/coordination/README.md` → every
coordination note in `docs/coordination/` with status `active`, `blocked`, or `handoff` →
`git status --short` and `git log --oneline -15`. Only then start work.

---

## Project map

> **Fill this in.** Keep it to one line per entry. It is the map every new session uses to
> orient itself; a stale map costs more than no map.

| Path | What lives there | Who usually touches it |
|---|---|---|
| `` | | |
| `` | | |
| `` | | |

**Key commands**

| Purpose | Command |
|---|---|
| Build | `{{BUILD_CMD}}` |
| Test | `{{TEST_CMD}}` |
| Lint / typecheck | `{{LINT_CMD}}` |

**Things that are not obvious from the file tree** (generated artifacts, external data
sources, environments, anything with a surprising owner):

-
-

---

## Start with repository state and evidence

- **Read before writing.** Establish the current state of the repository before proposing
  or making any change. Assumptions about what the code does are not evidence; the code,
  the tests, and the git history are.
- **Run `git status --short` before your first edit and before every commit.** Know what
  is already modified, staged, or untracked before you add to it.
- **Treat every pre-existing change as another session's work in progress.** Uncommitted
  edits, stray branches, and half-finished files belong to somebody. Do not revert,
  reformat, "clean up", stash, or commit them. If they block you, say so in your
  coordination note and pick different work.
- **Search before inventing.** Before adding a helper, type, constant, config key, or
  document, grep for an existing one. Duplicate implementations that drift apart are a
  larger cost than the time saved by not looking.
- When the repository contradicts a document (including this one), the repository is the
  fact and the document is the claim. Fix the document, and note the discrepancy.

---

## Keep changes scoped and traceable

- **Make the smallest coherent change that accomplishes the task.** Coherent means it
  stands on its own and can be reviewed, explained, and reverted as a unit.
- **Separate behaviour changes from cleanup.** Renames, reformatting, and refactors go in
  their own commits, never mixed with a change that alters what the software does — a
  diff where both are tangled cannot be reviewed.
- **New directories are allowed** when a piece of work genuinely needs its own space, as
  long as the boundary is clear: state its purpose in the project map above and in your
  coordination note.
- **Never create a nested `.git` directory or a second checkout inside this repository.**
  One repository, one working tree. Use branches or a proper `git worktree` outside the
  repository root if you need isolation.
- **Do not add dependencies, change lockfiles, alter CI configuration, or deploy anything
  without an explicit request.** If a task appears to require a new dependency, stop and
  ask; propose the smallest alternative you found alongside it.
- Anything you generate for your own convenience — scratch scripts, dumps, exports,
  screenshots, logs — is transient. It does not belong in the repository.

---

## Git controls all durable project work

Git is the record of what happened. Treat it as the deliverable, not as bookkeeping.

- **Use the native `git` CLI for all repository operations**: status, diff, log, add,
  commit, branch, checkout, merge, rebase, push, fetch, tag, stash, worktree.
- **`gh` is only for GitHub-specific API surfaces** that git cannot reach: pull requests,
  issues, reviews, releases, Actions metadata. **`gh` is never a substitute for `git`.**
  Do not use it to read files, browse history, or move commits.
- **Never `git add .` or `git add -A`.** Stage explicit paths you have inspected in the
  diff. Blanket staging is how another session's work and stray artifacts get committed.
- **Commit messages state what changed and why**, in the imperative. Reference the driving
  issue or task where one exists. A message that only restates the filenames is noise.
- **Never rewrite published history and never force-push** — no `rebase`, `commit
  --amend`, `reset --hard`, `push --force`, or branch deletion on anything already pushed
  or shared — without (a) explicit authorization from the user for that specific action
  and (b) a stated recovery plan (the reflog entry or backup ref that gets you back).
  `--force-with-lease` is still a force-push.
- **Keep transient output out of version control.** Logs, caches, build artifacts,
  coverage reports, `.env` files, credentials, large binaries, and per-session runtime
  state are ignored, not committed. If something must be ignored, add it to `.gitignore`
  in its own commit.
- **Never commit secrets.** If a credential reaches a commit, stop, tell the user
  immediately, and treat the credential as compromised — removing it from history is not
  sufficient.
- Work on a branch unless the user asked for a commit on the default branch. Push only
  when asked.

---

## Preserve integrity

The most dangerous output is one that looks right.

- **A plausible-looking result is not evidence of correctness.** Output that renders,
  compiles, or reads well tells you nothing about whether it is true. Confirm the claim
  independently — a test, a second derivation, a source, a spot-check against known
  values — before reporting it.
- **Check the boring things**: units and their conversions; what the denominator actually
  counts; time zones and date boundaries; off-by-one and inclusive/exclusive ranges; empty
  inputs, single-element inputs, and duplicates; sorting stability; null versus zero
  versus missing; overflow and precision; invariants that must hold before and after
  (totals conserved, identifiers unique, references resolvable).
- **Never fabricate.** No invented data, sources, citations, quotations, benchmark
  numbers, metrics, test results, or command output. Never report a number you did not
  compute or a result you did not observe. If you estimated, say "estimated" and show how.
- **Missing values stay missing.** Do not fill gaps with zeros, averages, interpolations,
  or plausible guesses to make a pipeline, chart, or table look complete. Absence is
  information; propagate it and surface it to the user.
- **Externally-sourced facts carry provenance**: the source (title and stable
  URL/identifier), the date the source itself gives, and the date you retrieved it. Record
  it next to the fact — in a comment, a data dictionary, or your coordination note. A fact
  without provenance may not be presented as established.
- **Distinguish measured, derived, and assumed.** Label assumptions as assumptions,
  including in code comments and in summaries to the user.
- **Report negative results.** A failed approach, a disproven hypothesis, or a check that
  did not pass is a finding. Suppressing it wastes the next session's time.
- Uncertainty is stated, not smoothed over. "I could not verify X" is an acceptable and
  often correct answer.

---

## Code conventions

- **Follow the patterns already in the codebase** — naming, file layout, error handling,
  logging, test structure. Consistency beats personal preference. If an existing pattern
  is genuinely wrong, raise it rather than silently forking a second style.
- **Type strictly where the language supports it.** No suppressions, escape hatches, or
  dynamic-any types to make an error disappear; fix the underlying shape. If a suppression
  is unavoidable, it needs a comment explaining why and what would remove it.
- **Prefer pure functions** where practical: inputs in, value out, no hidden state or
  ambient I/O. Push side effects to the edges so the core stays testable.
- **Guard edge cases explicitly** at the boundary rather than deep inside the logic: empty
  and missing inputs, out-of-range values, failed lookups, partial responses, timeouts.
  Fail loudly and early rather than producing a quietly wrong value.
- **Errors carry context.** Say what operation failed, on what input, and what the caller
  should do. Never swallow an exception to keep a flow green.
- **User-facing text belongs in the project's localization layer** if one exists — never
  hardcoded in components or handlers. Add new keys to every locale the project ships;
  keep key shapes and interpolation placeholders identical across locales.
- **Comments explain why, not what.** Delete dead code instead of commenting it out; git
  remembers it.
- Write the test alongside the change when the project has tests. A bug fix gets a test
  that fails before it and passes after.

---

## Verification is part of completion

Work is not done when the code is written. It is done when it has been checked.

1. **Run the narrowest relevant check first** — the single test, the one file's
   typecheck — so failures are fast and attributable.
2. **Then run the repository gates** that your change could affect: `{{TEST_CMD}}`,
   `{{LINT_CMD}}`, and `{{BUILD_CMD}}` where relevant.
3. **Record the actual commands and their actual results** in your coordination note.

**Never claim a check passed unless you ran it in this workspace, in this session, and
read its output.** Not "should pass", not "passed last time", not inferred from a clean
diff. This is the single most damaging failure mode on an agent team, because the next
session builds on your claim.

**State explicitly when a check was skipped, blocked, or failed** — and why:

- *skipped* — say which check and why it was not relevant.
- *blocked* — say what stopped it (missing credentials, no network, absent tooling).
- *failed for a pre-existing reason* — show that it fails on a clean checkout too, and say
  so; do not silently absorb someone else's broken gate, and do not "fix" it as a
  side-quest without asking.

Report verification as evidence: the command, and the part of the output that shows the
result. Summaries without commands are not verification.

---

## Documentation consistency

- When behaviour changes, update the documentation that describes it **in the same
  change**: README, this file, the project map, API docs, data dictionaries, and any
  runbook or example that would now be wrong.
- Documentation states what is true now. Do not describe planned or aspirational
  behaviour in the present tense; mark it as planned or leave it out.
- Fix documentation you discover is wrong while working nearby, in a separate commit, and
  mention it in your note.
- Examples and code snippets in documentation must be ones you actually ran.
- Do not create new documentation files unless asked or genuinely required. Extending an
  existing document is almost always better than adding another one.

---

## Cross-session coordination protocol

Several sessions — human and agent, possibly on different runtimes — work in this
repository at the same time. Coordination notes are how they stay out of each other's way.
This protocol is mandatory.

### Session identity

At the start of a session, adopt an identity of the form:

```
YYYYMMDD-HHMM-<role>-<short-task>
```

- `YYYYMMDD-HHMM` — session start time in {{TIMEZONE}}.
- `<role>` — your role name, matching `.agent-teams/team.yaml`.
- `<short-task>` — two to four lowercase hyphenated words, e.g. `fix-auth-refresh`.

Example: `20260820-0930-engineering-fix-auth-refresh`. Use this identity in your note
filename, in your commit messages where the project's convention allows it, and whenever
you refer to yourself to another session.

### One note per session

Each session keeps exactly one note at:

```
docs/coordination/<session-id>.md
```

Copy `docs/coordination/_template.md` to start it. Rules:

- **Create it before your first edit**, not after you finish.
- **Update it when the facts change** — when you claim a new file, make a decision that
  affects others, hit a blocker, or finish. A note written only at the end is useless to
  anyone who needed it mid-flight.
- **Record actual commands and their actual results**, not intentions.
- **Never edit another session's note**, except to append a clearly attributed line under
  its "Open questions" section. In particular, **never mark another session's note
  `complete`** — only the session that owns a note may close it. If a note looks abandoned,
  say so in *your* note and, if you take the work over, follow the handoff rules below.
- Notes are part of the repository. Commit them.

### Notes are soft claims, not locks

Listing a file under "Intended files" is a **courtesy signal that you are working there.**
It is not ownership, and it does not reserve the file.

- Before editing a file another active note claims, check for a conflict; prefer different
  work, or coordinate by writing your intent in your own note first.
- If you must edit a claimed file, make the smallest possible change, say exactly what you
  changed and why in your note, and leave the other session's work intact.
- A stale claim does not block the repository. If a note has not been updated in a long
  while and its work is clearly not in flight, you may proceed — but record that you did
  and what state you found.
- The authority on what exists is git, never a note. A note that disagrees with the
  working tree is out of date.

### Status lifecycle and handoff

A note's `status` is one of `active`, `blocked`, `handoff`, `complete`.

- `active` — work in flight.
- `blocked` — cannot proceed; the note must name exactly what is needed and from whom.
- `handoff` — work is in a defined, resumable state and is offered to another session.
- `complete` — finished and verified; the note records what was done and what was checked.

**When you hand off**, before setting `handoff`, the note must contain: what is done, what
is deliberately not done, the exact next action, the current branch and commit, the state
of the working tree (clean, or exactly what is uncommitted and why), and every command
needed to reproduce your last result.

**When you take over a `handoff`**, open your own note referencing the source session id,
state in it what you inherited, and leave the original note as `handoff` — the original
session's record stays intact.

**When you end a session** for any reason, leave your note in an honest terminal state:
`complete` if verified done, `handoff` if resumable, `blocked` if it is not. Never leave
it `active`.

### Conflict priority

When instructions or evidence disagree, resolve in this order (highest first):

1. **Explicit user direction** in the current session.
2. **Repository evidence** — the code, its tests, and observed behaviour.
3. **Documented project constraints** — this file, `docs/`, ADRs, coordination notes.
4. **Role recommendation** — what your role would normally advise.

A lower item never overrides a higher one. When items 1 and 2 conflict — the user asks for
something the repository shows to be wrong — do not silently pick a side: state the
conflict with the evidence, and ask.

---

## Agent-team operating notes

Operational facts about running several agent sessions at once. These are observed
behaviours, not guesses; ignoring them wastes hours.

- **Background agents block forever on permission prompts in untrusted directories.** A
  backgrounded session started in a workspace that has not been trusted stalls on its
  first write, waiting on an interactive prompt nobody can see — and it does so *even
  with* permissive per-session permission flags. It will never self-resolve. The fix is
  human and one-time: open the runtime interactively in this directory once and accept the
  trust prompt. Agents must not flip that flag themselves; it is a security control. If a
  role has produced nothing since launch, suspect this first.
- **Coordination notes are the durable channel.** Shared task lists and cross-agent
  messaging tools are not reliably available to teammate sessions on current models —
  frontmatter requesting them is silently ignored. Assume no session can message another
  directly. Anything another session must know goes in a coordination note, committed to
  the repository, where it survives session death, runtime differences, and context loss.
  Write for a reader who has none of your context.
- **A role that appears idle may be quota-exhausted, not finished.** When a runtime hits a
  usage limit it stops producing output; from the outside that is indistinguishable from
  having completed the work. Before assuming a role is done, check for evidence it
  actually finished: a terminal-state coordination note, commits, changed files. Absent
  those, check the role's log or session state for an error or quota message and report
  it rather than reassigning the work as complete.
- **Run one shell command per call.** A permission allowlist matches whole commands, so a
  chain like `git add X && git commit -m "$(cat <<'EOF' ... )"` does not match an entry
  permitting `git add` or `git commit` on its own — it is treated as a single unapproved
  command and the session stops on a prompt no one will answer. Issue `git add X`, then
  `git commit -m "short message"` as separate calls. Avoid `&&` and `||` chains, avoid
  `$(...)` substitution, and prefer a plain `-m "message"` over a heredoc. This costs a
  few extra calls and saves a wedged session.
- **Background sessions may relocate into a git worktree.** A backgrounded agent can move
  itself into `.claude/worktrees/<name>/` and commit there, which means its work is on a
  side branch and is *not* in the main working tree. Before reporting a role's work as
  landed, check where it actually committed; merging that branch is a human decision.
- Prefer many small, committed, self-describing steps over one long silent run. A session
  that dies mid-flight should leave behind something the next one can use.

### Keep inter-role communication short

Every word one role writes to another is context another session must pay to read, in a
window that is already the scarcest resource on the team. Verbose handoffs are the main
way multi-agent work degrades: notes grow into transcripts, readers skim, and the one
line that mattered gets missed.

Rules, not suggestions:

- **A coordination note update is at most ~10 lines.** If it will not fit, the work was
  too large a step — split it.
- **Lead with the decision or the ask.** State the conclusion in the first sentence. Put
  reasoning after it, and only the reasoning that changes what the reader does.
- **Link, do not restate.** Reference files by `path:line`, commits by SHA, prior notes
  by session ID. Never paste a diff, a file, a log, or another note's contents into your
  own note.
- **Write only what the reader must act on.** Omit narration of your process, restatements
  of the task, and status that the monitor already shows. "Investigated X, considered Y,
  then Z" is noise; "Z, because Y" is the message.
- **One ask per handoff, with the exact next action.** Not "someone should look at auth" —
  "next: fix the token refresh in `src/auth.ts:88`; test at `tests/auth.spec.ts:40`."
- **No pleasantries, no preamble, no summary of the summary.**

Terseness is not rudeness here, and it never licenses omitting a risk, a caveat, or a
failed check. Cut words, never substance: if a check failed or an assumption is shaky,
that is exactly the sentence to keep.

---

## Definition of done

A task is done only when all six hold:

1. **The requested change is implemented** — the whole request, not a representative part
   — and its scope is no wider than what was asked.
2. **Verification was actually run in this workspace**, and the commands and their real
   results are recorded. Anything skipped, blocked, or failing for a pre-existing reason is
   stated explicitly.
3. **Documentation affected by the change is updated** in the same change, including the
   project map above if the structure moved.
4. **The coordination note is current and in an honest terminal state** (`complete`, or
   `handoff`/`blocked` with the exact next action).
5. **Git is clean and intentional** — explicit staging, a message that says what and why,
   no stray artifacts, no unrelated files, no rewritten shared history.
6. **Residual risk is stated to the user**: what was not covered, what remains uncertain,
   and what you would check next. Silence is a claim of completeness.

If any one of these fails, the task is not done. Say what is missing rather than declaring
success.

---

## Roles

Roles define what each teammate is responsible for and what it should not do. They are not
inlined here — the definitions are the source of truth:

- **`.claude/agents/<role>.md`** — role definitions: purpose, when to use, tools,
  permission posture.
- **`.agent-teams/team.yaml`** — this project's team composition: which roles exist, which
  runtime each runs on, and the model tier and permission or sandbox posture for each.

Read your own role file at the start of a session, and skim the team manifest so you know
who else may be working. If a role's remit is unclear or overlaps another's, resolve it by
the conflict priority above and record the resolution in your coordination note.

Everything in this file applies to every role. A role definition may add obligations; it
may not waive any of the ones above.
