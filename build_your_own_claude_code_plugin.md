# Build Your Own Claude Code Plugin

**Reference build:** [`adoption-os`](https://github.com/dreafunnn/Adoption-OS/tree/main)

You’ve seen `adoption-os` turn Claude Code usage into new workflows, playbooks, and an exec readout. This guide shows you how to build the same kind of operating loop for your own workflow: observe the right signal, choose the right component, produce a useful artifact, and verify it works from a fresh clone.

---

## Reviewing the Adoption OS Pattern

`adoption-os` works because it follows a simple architecture:

```text
Hook observes → Agent analyzes → Skill produces artifact → README/demo proves it works
```

For another workflow, keep the same pattern and swap the domain.

| Layer | Question | `adoption-os` example | Your version |
|---|---|---|---|
| Signal | What raw evidence should the plugin observe or ingest? | Claude Code usage logs | Logs, PRs, alerts, incidents, CI failures, tickets |
| Judgment | What should the agent analyze or decide? | Which workflows are worth standardizing | Priority, root cause, risk, owner, next action |
| Artifact | What should the plugin produce? | Internal playbook or exec readout | Runbook, remediation plan, migration plan, PR summary |
| Operating loop | How does the output get reused? | Shared with teams and leadership | Sent to owners, pasted into Jira, added to docs |

Do not start with files. Start with the loop.

---

## 1. Define the Problem

Build a plugin when a workflow is **repeated**, has a **right way to do it**, and is a persistent problem or manual effort.

To start, define the role of the user and the issue they have. Here is a template you can use:

```text
Every time someone [does X], they should [do Y],
but today they don't, consistently.
```

A strong example:

```text
Every time a data engineer debugs a flaky dbt run, they should know what broke,
which models are affected, who owns the fix, and what to try next — but today
they piece it together from raw logs, CI output, and tribal knowledge.
```

Good fits:
- Scaffolding a microservice
- Debugging flaky dbt runs
- Enforcing a Terraform standard
- Triage for dependency CVEs
- Turning incident notes into a follow-up plan
- Creating a monthly platform adoption readout

Poor fits:
- One-off questions
- Work needing context Claude cannot see
- Workflows that change every week
- Vague goals like “make engineers more productive”

---

## 2. Choose the Right Component

Match the component to the shape of the workflow. Do not add surface area just to check boxes.

| If the workflow needs... | Build... | Example |
|---|---|---|
| A repeatable artifact from clear inputs | **Skill** | Draft a runbook, service template, migration plan, or team update |
| Judgment across messy evidence | **Agent** | Diagnose flaky dbt failures, rank CVEs, find adoption patterns |
| Automatic capture or guardrails | **Hook** | Log tool usage after edits, block unsafe commands, remind users of standards |
| External data from another system | **MCP** | Pull Jira, GitHub, Datadog, Slack, or internal catalog context |
| Repeatable local execution | **Script** | Normalize logs, generate a file tree, run a validation command |

Most first plugins should be one skill. Add an agent only when the workflow requires judgment. Add a hook only when something should happen automatically. Add MCP only when the plugin needs data from an external system.

---

## 3. Start With the Minimum Viable Plugin

Begin small. You can add more components later.

```text
my-plugin/
  .claude-plugin/
    plugin.json
  skills/
    my-skill/
      SKILL.md
  README.md
```

Add `agents/` only if judgment is needed.

```text
my-plugin/
  agents/
    my-agent.md
```

Add `hooks/` only if something should happen automatically.

```text
my-plugin/
  hooks/
    hooks.json
    my-hook.sh
```

Add MCP only if the workflow genuinely needs an external system.

---

## 4. Build It in This Order

### Step 1: Stub and validate

Create the manifest and empty files first. Validate the structure before you write logic.

```bash
claude plugin validate .
```

Fix structure before behavior. Broken packaging makes good prompts irrelevant.

### Step 2: Write the skill or agent prompt

This is most of the work. Be specific. Give examples. Define the output.

A useful `SKILL.md` should include:

```markdown
---
description: Scaffold a microservice to company standards.
---

Given a service name, create the standard files:

1. `ci.yml`
2. `Dockerfile`
3. `health.ts`
4. `README.md`
5. `CODEOWNERS`

Follow every company convention.
If the service name is missing, ask before generating.
End with a short summary of what was created.
```

A useful agent spec should define:

```text
Agent name:
Persona it serves:
Inputs it reads:
Analysis it performs:
Output format:
What it must never do:
```

Example:

```text
Agent name: cve-triage-agent
Persona: Security engineer
Inputs: dependency alerts, package names, service criticality, ownership data
Analysis: ranks vulnerabilities by operational risk
Output: prioritized list with severity, affected service, owner, and recommended action
Must never: invent exploitability, modify files, or create tickets without approval
```

### Step 3: Test on real runtime

Reading correctly is not the same as working correctly.

Test locally with:

```bash
claude --plugin-dir ./ -p "/my-plugin:my-skill [paste sample input]"
```

If you have an agent:

```bash
claude --plugin-dir ./ -p "Run the my-agent agent on ./tests/mock-data"
```

If you have a hook:

```bash
chmod +x hooks/my-hook.sh

echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_response":{"content":"ok"}}' \
  | bash hooks/my-hook.sh
```

### Step 4: Write the README last

A teammate should be able to install from a fresh clone using only the README.

Include:

```text
What this plugin does
Who it is for
What problem it solves
Install instructions
How to validate it
How to run the demo
How each component works
Security notes
Troubleshooting
```

---

## 5. Verify and Ship

You are done when all four are true:

- `claude plugin validate .` passes cleanly
- The plugin does the job when run via `--plugin-dir` against real or realistic input
- A teammate can install it from a fresh clone using only your README
- Output ends clean: no stray questions, no half-finished state, no invented facts

Create mock data before testing live customer data.

```text
tests/mock-data/
  good-case.jsonl
  messy-case.jsonl
  edge-case-empty-input.txt
  expected-output.md
```

Mock data should prove the plugin works on both clean and messy inputs.

---

## Worked Example: Idea to Plugin

### The pain

New microservices are scaffolded by hand. Half of them miss the standard CI config or health-check route, and code review catches the issue late.

### 1. Define it

```text
Every time someone starts a service, they should generate the five standard files;
today they copy an old repo and miss one.
```

### 2. Choose the component

This workflow has a clear input and a structured output.

- Input: service name
- Output: five standard files
- Component: **Skill**

It does not need an agent because there is not much judgment. It does not need a hook because nothing has to happen automatically.

### 3. Build it

Write a `SKILL.md` that tells Claude exactly what to generate, what conventions to follow, what to ask if input is missing, and how to summarize the result.

### 4. Verify and ship

A teammate should be able to run one command, scaffold a service, review the files, and ship the commit.

### The lesson

The workflow picks the component, and the component tells you what to write. You are translating a repeated operating pattern, not architecting from scratch.

---

## Watch Out for These

- **Building a hook?** It should fail safely. Unless the hook is explicitly a guardrail, it should not block normal work.
- **Writing hook data?** Write to plugin data storage, not the project repo. Avoid creating files that accidentally get committed.
- **Building an agent?** Bound it tightly. Define inputs, output format, and disallowed tools.
- **Letting the agent invent signal?** Do not. Require it to cite files, rows, logs, or events when making claims.
- **Skipping the fresh-clone test?** Do not. If a teammate cannot run it from your README, the plugin is not self-serve.
- **Adding MCP too early?** Start with mock data. Add external systems only after the core loop works.

---

## What Excellent Looks Like

Excellent plugins are:

- **Specific:** one persona, one workflow, one artifact
- **Grounded:** they use real evidence, not vague prompting
- **Bounded:** agents know what they can and cannot do
- **Runnable:** validate, test, and demo from a fresh clone
- **Reusable:** another team can swap the workflow and keep the pattern
- **Operational:** the output fits into how the team already works

The best test is simple: can another engineer clone the repo, validate it, run it, understand the pattern, and adapt it to their own workflow without asking you for help?

---

## Final Checklist

Before sharing, make sure:

```text
[ ] The plugin solves one specific workflow
[ ] The persona is named clearly
[ ] The input signal is explicit
[ ] The output artifact is useful immediately
[ ] The component choice is justified
[ ] Any hook or MCP exists for a real reason
[ ] Mock data is included
[ ] The demo runs from a fresh clone
[ ] The README explains how to adapt the pattern
[ ] Security assumptions are explicit
```
