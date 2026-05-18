# Build Your Own Claude Code Plugin

A guide for engineers who want to build a plugin for their org — not a tutorial, not a spec dump. This is what you actually need to know before you start.

---

## Start with the problem, not the code

Before you open the spec, answer these three questions in writing:

1. **Who is this for, specifically?** Not "engineers" — which engineer, in which role, at which moment in their day?
2. **What decision or task does it enable that they can't do cleanly today?**
3. **What would they see or get if it worked perfectly?**

If you can't answer all three in two sentences each, you're not ready to build. The most common failure mode is building something technically correct that nobody uses because the use case was fuzzy from the start.

---

## Read the spec yourself before writing a prompt

The official spec lives at `https://code.claude.com/docs/en/plugins`. Read it before you ask Claude to build anything. Specifically, understand:

- What goes in `.claude-plugin/plugin.json` and which fields are required vs. optional
- The difference between `agents` (takes a file path, not a directory) and `skills` (takes a directory)
- How `disallowedTools` must be written — a YAML inline array `[Write, Edit]`, not a comma-separated string
- What `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are and when each one applies
- What the hook payload actually looks like on stdin — you can't write a hook script without knowing the shape of the input

Thirty minutes here saves hours of debugging later. If you skip this and let Claude interpret the spec for you, you'll approve fixes you don't understand and end up owning something you can't maintain.

---

## Build in this order

**Structure first, content second, wiring last.**

1. Create the directory layout and a minimal `plugin.json`
2. Add stub files for your agent and skill (frontmatter only, no body)
3. Run `claude plugin validate .` — fix everything before moving on
4. Write your hook script and test it by piping mock JSON directly to it — don't wait for a live session
5. Write agent and skill content only after the structure is clean
6. Run `claude --plugin-dir ./` and test each component independently before chaining them

Don't skip step 4. The hook is the easiest thing to get subtly wrong and the hardest to debug once it's buried in a live session.

---

## Three things that will bite you

**1. Hook scripts must be executable.** `chmod +x hooks/your-script.sh` on every fresh clone. Put this in your install steps or it will silently not fire.

**2. Your hook will receive malformed or null payloads.** Validate JSON before extracting fields, use `// {}` fallbacks in jq, and always `exit 0` on bad input — a failed hook must never crash an engineer's session.

**3. `${CLAUDE_PLUGIN_DATA}` is a runtime variable.** It's set by Claude Code, not your shell. Don't write to `./` and don't tell users to `echo $CLAUDE_PLUGIN_DATA` in their terminal — it will be empty. Use the runtime variable in scripts and document the default path (`~/.claude/plugins/data/<plugin-name>/`) for humans.

---

## How to know it actually works

Test each component in isolation before running the pipeline end-to-end:

```bash
# Hook — pipe a mock payload directly, don't rely on a live session
echo '{"tool":"Edit","tool_input":{"file_path":"src/app.ts"},"tool_response":{"content":"ok"}}' \
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
