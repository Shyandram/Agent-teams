# Design: role priority and multiple hosts

Status: **future update — planned, not built, not scheduled.**

Nothing in this document exists in the skill today. It is filed so the reasoning survives
until there is a reason to build it. The transport question in section 3 is deliberately
**left open**: it should be decided against a real second machine, not in the abstract.

Revisit this when there is an actual multi-server project to run, or when a pooled role
dies from quota often enough that manual failover becomes annoying.

## What was asked for

> Support the priority of the same roles if exist, which possibly useful for multiple
> servers for a project.

Two things are tangled here, and separating them is most of the design work.

---

## 1. The distinction that has to come first

Today, several instances of one role mean **partitioned** work: `research-lit` and
`research-data` are both `research`, but they are *not interchangeable* — each owns a
different slice, and both run. Priority would be meaningless between them: you cannot
"fail over" from the literature review to the dataset work.

Priority only means something between instances that are **interchangeable** — same role,
same slice, differing only in where they run or what they cost. That is a genuinely
different concept, and conflating it with `focus` would produce a confusing tool.

So the proposal introduces one new idea, not two:

| Concept | Field | Instances are | Priority applies |
|---|---|---|---|
| Partition (exists today) | `focus:` | different slices, all active | no |
| **Pool (new)** | `pool:` | interchangeable, ordered | **yes** |

```yaml
# partitioned — both run, no ordering
- name: research-lit
  role: research
  focus: prior work 2020-2026
- name: research-data
  role: research
  focus: datasets and provenance

# pooled — interchangeable, priority orders them
- name: train-a
  role: engineering
  pool: trainers
  priority: 1
  host: gpu-01
- name: train-b
  role: engineering
  pool: trainers
  priority: 2
  host: gpu-02
```

## 2. What priority actually decides

Four separate questions, which should not be collapsed into one number without saying so:

| Question | Rule |
|---|---|
| **Who gets the next task?** | lowest `priority` number in the pool that is `idle` |
| **Who takes over on failure?** | next priority up, when the current holder is `errored`/`stopped` |
| **Whose answer wins on conflict?** | lowest priority number is authoritative; the other must escalate rather than overwrite |
| **What runs when capacity is short?** | launch in priority order; `--only-priority <=2` to run a subset |

Failover is the one worth building first: a quota-exhausted role currently just sits there
as `errored`, and the monitor already detects exactly that state. Promotion is a small
step from a detection that already works.

**A rule that has to be explicit:** priority is *preference*, not authority over correctness.
A priority-2 instance that finds a real defect is not overruled by priority-1. The
tie-break applies to allocation and to merge conflicts, never to evidence.

## 3. Multiple hosts

### What is host-local, and therefore the actual constraint

| State | Scope | Consequence |
|---|---|---|
| `~/.claude.json` trust flags | per host | **every host must be trusted separately**, interactively, once |
| `~/.claude/projects/*.jsonl` transcripts | per host | monitor content cannot be read from another host |
| `~/.codex/sessions/rollout-*.jsonl` | per host | same |
| `claude agents --json` | per host | live state must be queried on each host |
| `.agent-teams/` | per project | **the only thing that is naturally shareable** |

This is the crux: team state is shareable, but *observation* is not. Any multi-host
design is mostly a question of how observation gets aggregated.

### Transport options

**A — Shared filesystem (NFS/SSHFS).** Zero new code; mount the project on each host.
Rejected as the default: POSIX locking over NFS is unreliable, and the mailbox and
session files are exactly the concurrent writes that would corrupt. Fine for a
single-writer setup; not something to recommend blindly.

**B — Git as the transport.** Coordination notes and `team.yaml` are already tracked, and
`AGENTS.md` already mandates git discipline. Each host commits and pulls; git is the
serialization point, which solves the claim race for free. Costs: latency equals the pull
interval, and inbox JSON would merge-conflict constantly. Good for *durable* state
(notes, results), bad for *chatty* state (mailbox).

**C — One coordinator, workers over SSH.** ← recommended. One host owns `.agent-teams/`.
Others run agents and are reached with `ssh`. The adapters already shell out, so launching
becomes a prefix; the monitor SSHes to each host for `claude agents --json` and tails
transcripts remotely. No daemon, no database, consistent with the skill's zero-infra
principle. Costs: the coordinator is a single point of failure, and every command pays SSH
latency.

**D — A service (agent-swarm's model).** SQLite plus an API server, agents claim from a
queue. Genuinely better at scale and at scheduling. Rejected for now: it replaces a tool
with one install step and no runtime dependencies with one needing a service, a database,
and an operational story. Worth revisiting only if the fleet outgrows C.

### Sketch under C

```yaml
hosts:
  local:   {}
  gpu-01:  {ssh: me@gpu-01,  project: /srv/proj, max_roles: 4}
  gpu-02:  {ssh: me@gpu-02,  project: /srv/proj, max_roles: 4}

roles:
  - name: train-a
    role: engineering
    pool: trainers
    priority: 1
    host: gpu-01
```

- `doctor --all-hosts` — reachability, runtime versions, auth, **and trust** per host
- `launch` — dispatches each role to its host; refuses a host that is unreachable or
  untrusted, exactly as it refuses an untrusted local directory today
- `status` / `monitor` — fan out per host, merge, and show a `HOST` column
- `send` / `steer` — mailbox lives on the coordinator; workers poll it over the shared
  path or via a small `inbox --pull` that SSHes home

## 4. What will actually be hard

Listing these because the honest version of this plan is not the happy path.

- **Trust does not travel.** Every host needs its own interactive `claude` visit. This is
  the same wedge already documented for local runs, multiplied by host count, and it
  cannot be automated away without defeating a security control.
- **Two instances claiming one task.** With no global lock, a naive queue double-assigns.
  Options: atomic `O_EXCL` create on a shared FS, or git commit as the serialization
  point. Either way the claim protocol must be designed, not assumed.
- **Split brain.** If the coordinator is unreachable, workers keep running and their work
  is invisible. The monitor must show *host unreachable* distinctly from *role idle* —
  the same principle as `errored` versus `idle` today.
- **Path skew.** The project path differs per host; nothing may assume a shared absolute
  path.
- **Clock skew** breaks idle/stall detection across hosts; timestamps should come from the
  coordinator or be explicitly tolerant.
- **Secrets must not travel.** Each host authenticates itself; the skill never ships
  credentials over SSH.
- **Worktrees are per host.** A role's commits may sit on a side branch on a machine
  nobody is looking at. `close` already warns about this locally and would need to check
  every host.

## 5. Suggested order, if this is ever picked up

Each step is useful on its own, which is the point — none of it requires the next.

1. **`pool:` + `priority:`, single host.** Ordered launch, `--only-priority`. Small, and
   makes the concept concrete before any distribution exists.
2. **Failover on `errored`.** Promote the next priority when a pooled instance dies or
   exhausts quota. Builds on hook detection that already works, and is the highest value
   per line of code in this document.
3. **`hosts:` + SSH dispatch.** `doctor --all-hosts` first, since the trust problem should
   surface before anything is launched remotely.
4. **Multi-host monitor.** Fan-out collection, `HOST` column, unreachable-host state.
5. **Claim protocol**, only if a real queue is wanted. Do not build this speculatively.

Stopping after 2 is a coherent product. Stopping after 4 is also coherent. 5 is where the
complexity lives and should wait for evidence that it is needed.

## 6. What this should not become

A distributed scheduler. If the requirement grows into cross-host queueing, budgets, and
autoscaling, agent-swarm already exists and does it properly with containers and a
database. The value of this skill is that it is a few files with no runtime dependencies;
a half-built scheduler would forfeit that without matching what already exists.
