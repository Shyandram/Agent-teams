# Unified orchestration model

This project combines two layers:

1. **Workflow semantics**, inspired by CrewAI: flows, crews, agents, tasks, state,
   approval gates, and guardrails.
2. **Runtime operations**, provided by agent-teams: Claude Code, Codex, and pi
   sessions; tmux/background execution; durable notes; logs; status; and recovery.

The layers are deliberately separate. A workflow should not need to know whether its
general runs in Claude Code or Codex, and a runtime session should not need a Python
framework installed just to launch.

## Concept mapping

| Unified concept | Meaning here |
|---|---|
| Flow | The lifecycle of a main research or application objective |
| Crew | One approved main-task general and its child roles |
| General | The crew owner and session coordinator |
| Agent | A role or subagent with a focused responsibility |
| Task | A bounded assignment with an owner, inputs, output, and acceptance check |
| Event | A proposal, approval, handoff, result, block, or review message |
| Flow state | Durable state in `AIM.md`, `team.yaml`, coordination notes, and session records |
| Guardrail | Approval gates, evidence requirements, permissions, and launch checks |

## Research lifecycle

```text
main general session
        |
        v
propose idea-generals
        |
        v
review + approve/reject
        |
        +--> rejected/proposed: remains a task in the main crew
        |
        +--> approved: starts one idea-general session
                              |
                              v
                    idea roles and tasks as subagents
                              |
                              v
                    evidence review -> closeout
```

An idea-general is represented in `team.yaml` as:

```yaml
- name: idea1-general
  parent: research-general
  session: true
  approval: proposed
```

The main general changes only the approval field after discussion and evidence review:

```yaml
  approval: approved
```

The next launch then creates a session for `idea1-general`. Three approved ideas plus
the main general create four top-level sessions. Their ordinary research, analysis, and
verification roles remain subagents inside those sessions.

## Task contract

Every task should be small enough to verify independently and carry:

```text
id          stable task identifier
owner       role or general responsible for the result
inputs      files, sources, or prior task outputs
output      artifact or finding expected
acceptance  observable test, evidence requirement, or decision rule
status      proposed | ready | running | blocked | done | rejected
```

Coordination notes are the current durable task transport. A future task adapter may
materialize these records into CrewAI `Task` objects, but the repository contract and
approval rules remain authoritative.

## Optional CrewAI integration

CrewAI may be used inside an approved idea-general session when a project wants Python
`Crew`/`Flow` execution, structured outputs, or CrewAI-specific tools. The integration
must obey these rules:

- CrewAI is optional; the base launcher remains dependency-free.
- A CrewAI Flow is a child execution engine, not a replacement for the main general.
- CrewAI agents do not bypass `approval: proposed` or repository permissions.
- CrewAI task results must be written to the same coordination and evidence channels.
- The agent-teams monitor tracks the owning runtime session; CrewAI-specific tracing is
  supplemental, not the source of truth for session liveness.

This makes the combination useful in both directions: use agent-teams to operate a
distributed multi-runtime team, and use CrewAI inside a session when an application needs
structured in-process orchestration.
