---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-agent review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\". A panel of reviewers challenges changes from independent angles."
---

# Interrogate

Spawn a panel of reviewers to adversarially review code changes. The diversity comes from two deliberate levers: a different model per reviewer and a divergent review lens. Both live in the `lasso-reviewer-*` agent files, so the spread survives on any host that reads agent frontmatter. Each reviewer also applies the shared code-quality lens. Agreement across independent lenses is high-confidence signal; a lone-lens finding is worth reading but lower confidence.

The deliverable is a synthesized verdict. Do NOT auto-apply changes.

## Step 1, Determine Scope

Identify what to review from context:

- If the user points at specific files or a diff, use that
- If on a feature branch, run `git diff main...HEAD` (or the appropriate base branch) for the full changeset
- If the user's message references recent work, gather the relevant files

Package the diff (or file contents) plus any surrounding context files the reviewers need to understand the code.

## Step 2, State the Intent

Before spawning reviewers, state the intent explicitly. What is this code trying to accomplish? Derive this from:

- The user's message
- Commit messages
- PR description if one exists
- The code itself

Write one clear paragraph. Reviewers challenge whether the work achieves the intent well, not whether the intent itself is correct. If you're unsure about the intent, ask the user before proceeding.

## Step 3, Spawn Reviewers

Launch the panel in a single message. Three reviewers, one per lens:

| `subagent_type` | Lens |
|---|---|
| `lasso-reviewer-a` | correctness and edge cases |
| `lasso-reviewer-b` | architecture and maintainability |
| `lasso-reviewer-c` | security and failure modes |

Each agent file pins its own model and read-only flag. Do not pass a `model`; configure it with `/setup-lasso`. Three is the panel size and the maximum, per the **lasso-mode** skill's fan-out budget. If a reviewer must consult an MCP source, use `general-purpose` for that one and say why.

Read [`references/reviewer-prompt.md`](./references/reviewer-prompt.md) and fill in the template for each reviewer with:
1. The stated intent
2. The diff or file contents
3. That reviewer's assigned lens (above)
4. The review rubric from [`references/rubric.md`](./references/rubric.md)
5. The shared code-quality lens from [`references/code-quality-review.md`](./references/code-quality-review.md)

The rubric and code-quality lens go to every reviewer; only the assigned lens differs. The divergence between lenses is what makes the panel adversarial. Scale the panel up (more lenses, e.g. perf or API ergonomics) for a large or contested diff.

Each reviewer produces structured findings as described in the prompt template.

## Step 4, Synthesize

As results come back, build a unified picture:

1. **Parse all findings** from the reviewers
2. **Identify consensus**. Findings raised by 2+ reviewers independently are highest signal.
3. **Identify lone-lens findings**. Still worth reading, but weight accordingly.
4. **Deduplicate**. Different lenses may describe the same issue differently. Merge these and note which reviewers raised it.
5. **Note disagreements**. If one reviewer flags something and another explicitly says the opposite, that's useful context for the verdict.

## Step 5, Lead Judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator.

Read [`references/lead-judgment.md`](./references/lead-judgment.md) and apply it. It owns the four buckets and the filtering principles. Reviewers only see a slice of the codebase. You have the full context (the goal, the constraints, the timeline, which tradeoffs were already considered). Use that context aggressively.

## Output Format

Present the verdict in this structure:

### Intent
> [The stated intent paragraph from Step 2]

### Reviewers
List each reviewer on its own line like `- <lens> (<model>): [N findings]`

### Act On
[Findings that should be addressed. For each: description, which reviewers raised it, why it matters.]

### Consider
[Findings worth thinking about. For each: description, which reviewers raised it, tradeoff involved.]

### Noted
[Valid but low-priority. Brief list.]

### Dismissed
[Rejected findings with brief rationale. This shows the user what was filtered out and why, so they can override your judgment if they disagree.]

### Agreement Map
[Where did the lenses agree, where did they diverge, and what does the pattern of agreement/disagreement tell us?]
