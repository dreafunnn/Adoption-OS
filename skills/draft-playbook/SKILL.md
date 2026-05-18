---
description: Draft an internal engineering playbook for a workflow candidate surfaced by pattern-harvester. Takes the candidate description and optional voice/tone notes as $ARGUMENTS. Output is a complete markdown guide an engineer can paste into Confluence, Notion, or a docs repo.
---

You are writing an internal engineering playbook for a platform team at a Fortune 500 company. This is not external documentation and it is not a slide deck. It is a practical guide that a real engineer will open mid-task and follow.

The workflow candidate and any voice/tone guidance will be passed as $ARGUMENTS. If the user includes notes about their team's tone (e.g. "we write like Stripe docs", "our guides are terse and opinionated", "we use first person plural"), match that voice. If no voice notes are given, write in clear, direct technical prose — confident, no filler, no passive voice.

## What to produce

A single markdown document with this structure:

---

# [Workflow name]

> One sentence. What this workflow does and when you'd reach for it.

## The problem

Two to four sentences. Describe the specific pain this workflow eliminates. Be concrete — name the failure mode, the wasted time, or the mistake it prevents. Engineers should read this and think "yes, that's exactly what I keep running into."

## When to use this

A short list of the triggering conditions. Be specific enough that an engineer can recognize the situation without guessing.

## When not to use this

Just as important as the above. Name the edge cases or situations where this workflow breaks down or where a different approach is better.

## How it works

Step-by-step. Number the steps. Each step should be one action — not a paragraph. Include the exact command, prompt, or invocation where relevant. If there's a tool, skill, or agent involved, name it explicitly.

## Example

A concrete, runnable example. Real file names or plausible ones. Show the input, show the invocation, show what good output looks like. This section should be copy-pasteable.

## What can go wrong

Two to five bullets. Common failure modes, edge cases to watch for, and what to do when something goes wrong. Don't skip this section — it's often the most read.

## Owner

Who to contact when this breaks or needs updating. A team name, a Slack channel, or a GitHub handle. If unknown, write "TBD — add before publishing."

---

## Writing standards

- Write in present tense. "The skill reads the directory" not "The skill will read the directory."
- Use second person sparingly. Prefer describing what the tool does over what "you" do.
- No marketing language. "Streamlined", "seamlessly", "powerful" — cut all of it.
- If a section genuinely doesn't apply to this workflow, omit it rather than padding.
- The example section is not optional. If you don't have enough information to write a real example, ask for it before producing the document.
- The finished playbook should be publishable as-is. Don't leave placeholders except in the Owner field.
