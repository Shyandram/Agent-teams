# REFERENCE ONLY -- this file is documentation, not an input.
#
# `agent-teams init` GENERATES .agent-teams/team.yaml directly (it needs one entry per
# selected role, with per-role runtime overrides) and never renders this template. It is
# kept as the human-readable description of the format; edit the generated file, not this.
# If you change the schema here, change bin/agent-teams and docs/INTERFACES.md section 2.
#
# .agent-teams/team.yaml — team manifest for {{PROJECT_NAME}}
#
# Read by a deliberately naive parser (no yq dependency):
#   - one key per line
#   - list items are two-space indented and start with "- name:"
# Conventions that keep the file safe to parse: keep comments on their own
# lines rather than trailing a value, and indent any comment that sits inside
# the "roles:" block. Keep the file in exactly this shape.
#
# ---------------------------------------------------------------------------
# runtime — which CLI hosts the role. One team may mix runtimes freely.
#   claude-code  Claude Code. Best default. Backgroundable, resumable sessions;
#                reads .claude/agents/<role>.md and AGENTS.md.
#   codex        OpenAI Codex CLI. Reads AGENTS.md natively. Useful for a second
#                opinion or to spread load across providers/quotas.
#   pi           pi CLI. Ships untested — verify before relying on it.
# A role with no "runtime:" falls back to default_runtime below.
#
# model_tier — portable statement of how much capability the role needs. Each
# runtime adapter maps it to a concrete model, so the manifest stays valid when
# model names change.
#   smol     trivial, high-volume, mechanical work
#   regular  ordinary implementation and research
#   smart    architecture, correctness-critical work, lead/integrator roles
#   ultra    hardest reasoning only; slowest and most expensive
#
# permission_mode — Claude Code roles only. How the session handles writes.
#   plan        read-only; produces a plan, changes nothing
#   manual      asks before every action
#   acceptEdits edits files without asking, still asks for riskier actions
#   auto        broadly autonomous
#   dontAsk     suppresses prompts; use only in a sandbox you can throw away
# NOTE: none of these help in an UNTRUSTED directory. A background session in a
# directory whose trust prompt was never accepted blocks forever on its first
# write, even with acceptEdits. A human must open the runtime interactively in
# this directory once and accept the trust prompt. Agents must not set that flag.
#
# sandbox — Codex roles only. Filesystem/network reach of the session.
#   read-only           can read, cannot write; pairs well with research roles
#   workspace-write     can write inside the project; the normal choice
#   danger-full-access  unrestricted; only with an explicit user decision
#
# Give a Claude role permission_mode, give a Codex role sandbox. Extra keys are
# ignored, but keeping them straight keeps the manifest readable.
# ---------------------------------------------------------------------------

version: 1
project_name: {{PROJECT_NAME}}
default_runtime: claude-code
general: lead
roles:
  - name: lead
    runtime: claude-code
    model_tier: smart
    permission_mode: acceptEdits
    general: true
    session: true
    approval: approved
  - name: research
    runtime: codex
    model_tier: regular
    sandbox: workspace-write
    parent: lead
    session: false
    approval: approved
  # Add roles below, two-space indented, one "- name:" per role.
  # Each name must have a matching definition in .claude/agents/<name>.md.
  #
  #  - name: engineering
  #    runtime: claude-code
  #    model_tier: smart
  #    permission_mode: acceptEdits
  #  - name: qa
  #    runtime: claude-code
  #    model_tier: regular
  #    permission_mode: plan
