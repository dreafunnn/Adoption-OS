# adoption-os

> A Claude Code plugin for the Head of Platform Engineering running a company-wide AI rollout.

Mandate: roll out Claude Code to hundreds of engineers, prove ROI to leadership, and standardize what works and what doesn't.

**adoption-os turns your rollout into a learning machine.** It captures what engineers are actually doing, synthesizes patterns across teams, and formats the findings into an exec-ready update your VP or CIO can act on — in 90 seconds.

The agent captures patterns from the eng team's Claude Code sessions (what's working, what's not), identifies the highest-leverage workflows to standardize, and drafts internal playbooks in the company's voice. Skill writes exec readouts for the VP of Eng on rollout progress. Hook logs adoption signals (skill usage, hook fires) to a CSV the engineer can show leadership.

---

## The loop

```
hook captures tool usage
        ↓
pattern-harvester agent finds what to standardize (and where teams are stuck)
        ↓
write-exec-readout skill drafts your monthly CIO update — with real numbers
```

---

## Try it in 5 minutes

**Prerequisites:** Claude Code and `jq` installed (`brew install jq` on Mac).

```bash
# 1. Clone and enter the plugin
git clone https://github.com/YOUR_USERNAME/adoption-os
cd adoption-os

# 2. Make the hook executable (required on every fresh clone)
chmod +x hooks/logger.sh

# 3. Validate the plugin structure
claude plugin validate .
# Expected: ✔ Validation passed

# 4. Load the plugin and run the pattern harvester against sample data
claude --plugin-dir ./ -p "Run the pattern-harvester agent on ./tests/mock-sessions"
```

You'll see a ranked list of workflow candidates, a set of intervention signals showing where engineers are struggling, and a list of anti-patterns — all sourced to specific files.

```bash
# 5. Draft an exec readout from the findings
claude --plugin-dir ./ -p "/adoption-os:write-exec-readout 3 teams onboarded this month, git rebase workflows flagged as top intervention signal, no shared skills deployed yet"
```

You'll get a five-section readout — TL;DR, what changed, what's working, what's blocked, and the ask — written for a leader who has 90 seconds.

---

## Components

### Hook — session logger
Fires automatically after every `Edit`, `Write`, or `Bash` call. Appends a row to a persistent CSV at `~/.claude/plugins/data/adoption-os/adoption-os.csv`. The longer it runs, the richer the proof points in your monthly readout.

### Agent — `pattern-harvester`
Point it at a directory of session logs or usage CSVs. It returns:
- **Workflow candidates** — ranked by impact, with suggested format (skill, agent, or command) and estimated time-savings
- **Intervention signals** — where teams are struggling and what would fix it
- **Anti-patterns** — misuse worth addressing before it becomes habit

> Only point this agent at designated log export directories. It reads everything it finds.

### Skill — `write-exec-readout`
Takes raw findings and formats them into a five-section exec readout. In an interactive session, it automatically pulls live stats from the session log CSV — so the proof point in "What's working" gets stronger every month without any extra work.

> Live CSV integration requires an interactive Claude Code session. It will not work with `claude -p` (non-interactive mode).

---

## Security

- Session data is written to `~/.claude/plugins/data/adoption-os/`, not your project directory — it will never show up in `git status`.
- `pattern-harvester` cannot write or edit files (`disallowedTools: [Write, Edit]`). It reads and reports only.
- CSV values are treated as data only. The skill will not interpret cell contents as instructions.
- The hook sanitizes all logged values against shell injection and CSV formula injection before writing.

---

## What's in the box

```
adoption-os/
├── .claude-plugin/plugin.json       # plugin manifest
├── agents/pattern-harvester.md      # workflow analysis agent
├── skills/write-exec-readout/       # exec readout skill
├── hooks/hooks.json                 # PostToolUse hook config
├── hooks/logger.sh                  # session logger script
└── tests/mock-sessions/             # sample data to try it immediately
```
