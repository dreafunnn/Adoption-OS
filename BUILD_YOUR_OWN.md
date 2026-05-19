# Build Your Own Claude Code Plugin

A guide to build plugins.

---

## Start with the problem, not the code

Before writing code, pick one painful, repeatable workflow and define the user. 

Before you open the spec, answer these three questions in writing:

1. **Who is this for, specifically?** Not "engineers" — which engineer, in which role, at which moment in their day?
2. **What decision or task does it enable that they can't do cleanly today?**
3. **What would they see or get if it worked perfectly?**

A strong plugin starts with a sentence like:

“This plugin helps a [specific persona] do [specific job] faster, more consistently, or with better evidence.”

**Once you have this statement, you have your prompt to put into Claude Code. **

---

## Add a skill that teaches the agent how to behave

4. Add a skill that teaches the agent how to behave
A skill gives the agent repeatable judgment. It is where you encode the team’s standards, rules, and preferred way of working.
The skill might define:
How to classify severity
How to write a good incident summary
How to evaluate whether a Terraform module is compliant
How to identify an adoption blocker
How to format a leadership-ready recommendation
Example:
The “CVE Triage Skill” teaches the agent how to evaluate vulnerability severity using exploitability, affected service criticality, exposure, package usage, and available remediation paths.
The skill is what turns the plugin from a generic AI helper into something that reflects how your organization works.





---

## Read the spec yourself before writing a prompt

The official spec lives at `https://code.claude.com/docs/en/plugins`. Read it before you ask Claude to build anything. Specifically, understand:

- What goes in `.claude-plugin/plugin.json` and which fields are required vs. optional
- The difference between `agents` (takes a file path, not a directory) and `skills` (takes a directory)
- How `disallowedTools` must be written — a YAML inline array `[Write, Edit]`, not a comma-separated string
- What `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are and when each one applies
- What the hook payload actually looks like on stdin — you can't write a hook script without knowing the shape of the input

If you skip this and let Claude interpret the spec for you, you'll approve fixes you don't understand and end up owning something you can't maintain.

---

## Build in this order

**Structure first, content second, wiring last.**

1. Create the directory layout and a minimal `plugin.json`
2. Add stub files for your agent and skill (frontmatter only, no body)
3. Run `claude plugin validate .` — fix everything before moving on
4. Write your hook script and test it by piping mock JSON directly to it — don't wait for a live session
5. Write agent and skill content only after the structure is clean
6. Run `claude --plugin-dir ./` and test each component independently before chaining them

Don't skip step 4. The hook is the easiest thing to get wrong and the hardest to debug once it's buried in a live session.

---

## Three things to be hyper aware of

**1. Hook scripts must be executable.** `chmod +x hooks/your-script.sh` on every fresh clone. Put this in your install steps or it will silently not fire.

**2. Your hook will receive malformed or null payloads.** Validate JSON before extracting fields, use `// {}` fallbacks in jq, and always `exit 0` on bad input — a failed hook must never crash an engineer's session.

**3. `${CLAUDE_PLUGIN_DATA}` is a runtime variable.** It's set by Claude Code, not your shell. Don't write to `./` and don't tell users to `echo $CLAUDE_PLUGIN_DATA` in their terminal — it will be empty. Use the runtime variable in scripts and document the default path (`~/.claude/plugins/data/<plugin-name>/`) for humans.

---

## How to know it actually works

Test each component in isolation before running the pipeline end-to-end:

```bash
# Hook — pipe a mock payload directly, don't rely on a live session.
# The runtime sends tool_name (not tool), and Bash failures use isError not error.
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_response":{"content":"ok"}}' \
  | bash hooks/your-script.sh
# Bash failure shape — isError:true, not error:"..."
echo '{"tool_name":"Bash","tool_input":{"command":"git rebase origin/main"},"tool_response":{"isError":true,"stdout":"","stderr":"CONFLICT"}}' \
  | bash hooks/your-script.sh

# Agent — run against a small, controlled directory you created
claude --plugin-dir ./ -p "Run the <agent-name> agent on ./tests/mock-data"

# Skill — invoke with known input and check the output structure
claude --plugin-dir ./ -p "/<plugin-name>:<skill-name> <paste your sample input>"
```

If any component fails in isolation, fix it before chaining. An end-to-end run that fails tells you something broke — isolated tests tell you what.

---

## One last thing

When you review your own files before shipping, read them as if you didn't write them. The thing that trips most people isn't missing a feature — it's a mismatch between what a file says and what the runtime expects. Read every file, run every command, check every output. If you're tempted to skip the final review because "it validated," don't.

The spec validates structure. Only you can validate intent.
