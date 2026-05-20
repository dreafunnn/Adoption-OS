# adoption-os

A Claude Code plugin for platform engineering leads running a company-wide Claude Code rollout.

Mandate: roll out Claude Code to hundreds of engineers, standardize what works, and prove ROI to leadership. Most engineers are doing things that work and things that don't, and that knowledge stays local. adoption-os gives you a way to collect it, find the patterns, turn the best ones into internal playbooks that your team will actually use, and report upward without spending a day collecting notes and writing a slide deck.

Four pieces:

1. A background hook that logs every `Edit`, `Write`, and `Bash` call to a CSV
2. An analysis agent (`pattern-harvester`) that reads session logs and surfaces what's worth standardizing
3. A skill (`draft-playbook`) that turns a workflow candidate into a full internal guide, written in your team's voice
4. A skill (`write-exec-readout`) that formats findings into a structured update for your VP or CIO

```
hook captures tool usage
        ↓
pattern-harvester agent finds what to standardize (and where teams are stuck)
        ↓
draft-playbook skill turns top candidates into publishable internal guides
        ↓
write-exec-readout skill drafts your monthly CIO update — with real numbers
```

---

## Install

Requires [Claude Code](https://claude.ai/code) and `jq` (`brew install jq` on Mac, `apt install jq` on Linux).

```bash
git clone https://github.com/dreafunnn/Adoption-OS
cd Adoption-OS
chmod +x hooks/logger.sh   # required on every fresh clone
```

Validate the structure before loading:

```bash
claude plugin validate .
# ✔ Validation passed
```

---

## Try it in 5 minutes

The repo ships with sample session logs in `tests/beefco-sessions/` — five engineers at a fictional Fortune 500 ("Beef Co") across two weeks, with realistic `.jsonl` session transcripts and a usage CSV. Run the harvester against them:

```bash
claude --plugin-dir ./ -p "Run the pattern-harvester agent on ./tests/beefco-sessions"
```

You get three things back: a ranked list of workflows worth standardizing, intervention signals for where engineers are stuck and why, and a short list of anti-patterns to address.

Take the top candidate from those findings and turn it into an internal playbook:

```bash
claude --plugin-dir ./ -p "/adoption-os:draft-playbook [paste candidate here]. Voice: terse and opinionated, Stripe-style docs."
```

Output is a complete markdown guide — problem statement, when to use it, step-by-step instructions, a runnable example, and failure modes — ready to paste into Confluence or a docs repo. The voice note is optional; leave it out and the skill writes in plain technical prose.

Then draft the exec readout:

```bash
claude --plugin-dir ./ -p "/adoption-os:write-exec-readout [paste findings here]"
```

Output is a five-section exec update — TL;DR, what changed, what's working, what's blocked, and what you need from leadership.

For a full end-to-end demo with pre-seeded session data across 5 Beef Co engineers and 5 teams:

```bash
bash demo/demo.sh
```

---

## Components

**Hook — `hooks/logger.sh`**

Fires on every `Edit`, `Write`, or `Bash` call via a `PostToolUse` hook. Appends a timestamped row to `~/.claude/plugins/data/adoption-os/adoption-os.csv` with columns: `timestamp`, `user`, `tool`, `target`, `success`. The `user` field is pulled from `$USER` automatically — no configuration needed. The CSV is the raw evidence layer; the longer it runs, the more useful the readout becomes.

> `CLAUDE_PLUGIN_DATA` is a runtime variable set by Claude Code, not your shell. The path above is the default location.

To watch it fire in real time, open a second terminal while working in Claude Code:

```bash
watch -n1 "tail -5 ~/.claude/plugins/data/adoption-os/adoption-os.csv"
```

**Agent — `pattern-harvester`**

Takes a directory path as its argument. Reads session logs and usage CSVs, finds recurring patterns across engineers, and returns ranked workflow candidates with estimated time-savings, a set of intervention signals showing where teams are struggling, and a list of anti-patterns. It has no write access (`disallowedTools: [Write, Edit]`) and will cite the specific file or row behind every finding.

Point it at a designated log export directory — not a live project directory. It reads everything it finds.

To run it against your team's real Claude Code sessions, point it at `~/.claude/projects/`. Each subdirectory is a URL-encoded working directory; each `.jsonl` file inside is a session transcript — one JSON event per line (`tool_use`, `tool_result`, `user`, `assistant`). The agent reads all three formats: `.jsonl`, `.md`/`.txt`, and `.csv`.

**Skill — `draft-playbook`**

Takes a workflow candidate from `pattern-harvester` and writes a complete internal engineering guide: problem statement, triggering conditions, step-by-step instructions, a runnable example, common failure modes, and an owner field. Pass voice or tone notes alongside the candidate description to match your team's documentation style — "terse and opinionated", "Stripe-style", "first person plural" all work. If no voice is specified it defaults to clear, direct technical prose. Output is publishable markdown with no placeholders except the owner field.

**Skill — `write-exec-readout`**

Takes findings as `$ARGUMENTS` and formats them into a five-section update. In an interactive session it also reads the CSV directly and pulls live usage numbers into the "What's working" section — so the proof point gets stronger over time without extra work. This requires an interactive Claude Code session; it won't work with `claude -p` since the CSV path falls outside the sandboxed working directory.

If you pass stale or estimated numbers, the skill will flag the discrepancy and derive corrected figures from the raw CSV — it reads the source data directly rather than trusting injected summaries.

---

## Security

Session data is written to `~/.claude/plugins/data/adoption-os/` — not your project directory. It will never appear in `git status` or get committed accidentally.

The hook validates the JSON payload before processing and sanitizes extracted values against both shell injection and CSV formula injection. `pattern-harvester` cannot write or edit files. The skill treats CSV values as data only and will not interpret cell contents as instructions.

---

## What's in the box

```
adoption-os/
├── .claude-plugin/plugin.json       # manifest
├── agents/pattern-harvester.md      # analysis agent
├── skills/draft-playbook/           # internal playbook drafting skill
├── skills/write-exec-readout/       # exec readout skill
├── hooks/hooks.json                 # PostToolUse hook config
├── hooks/logger.sh                  # session logger
├── demo/demo.sh                     # end-to-end demo with pre-seeded data
├── demo/pitch.html                  # 5-minute demo pitch page
├── tests/beefco-sessions/           # Beef Co Fortune 500 mock data (.jsonl + CSV)
├── tests/mock-sessions/             # simpler generic mock data (.md + CSV)
├── BUILD_YOUR_OWN.md                # long-form guide for building your own plugin
└── BUILD_YOUR_OWN_PLUGIN.html       # one-page field guide (open in browser, or
                                     #   convert to Word with `textutil -convert docx`)
```
