---
name: setup-lasso
description: Configure which Claude model tier lasso uses per role. Writes an override file that the lasso skills read, falling back to their inline defaults. Use for /setup-lasso, "configure lasso models", or changing lasso's model choices.
disable-model-invocation: true
---

# Setup lasso

Write `~/.claude/skills/lasso-mode/references/models.md`, an override file mapping each lasso role to a Claude model tier. The skills read it when present and fall back to their inline defaults when a line is absent, so this is an override layer, not a requirement. Every lasso agent is a Claude model, so the only knob is the tier.

## Steps

### 1. Know the available tiers

Claude Code accepts these `model` values on an `Agent` call: `opus`, `sonnet`, `haiku`, `fable` (plus inherit). That is the whole set. Do not write a value outside it. If a value is ever rejected at spawn time, fall back to `opus` and continue; never block work on the config.

### 2. Load current state

The default role-to-tier mapping is the shape shown in step 4. If `~/.claude/skills/lasso-mode/references/models.md` already exists, read it and treat its values as the current choices. Otherwise start from those defaults.

### 3. Confirm with the user

Show every role with its current tier. Ask whether to accept as-is or change specific roles, offering `opus` / `sonnet` / `haiku` as the options. Prefer `AskUserQuestion` over free text. For panel roles (how critics, arena runners, architect runners, interrogate reviewers) the value is a list, and one agent runs per entry, so the list length sets the panel size. Remember the panels get their diversity from divergent lenses, not different vendors, so it is fine for entries to repeat a tier.

### 4. Write the override file

Overwrite the whole file so re-runs stay idempotent. Shape:

```markdown
# lasso model configuration. One line per role. Delete a line to fall back to the skill default.
# Valid tiers: opus, sonnet, haiku, fable.
feature, refactoring: sonnet
bug-fix: opus
perf-issue: opus
hillclimb: opus
judgment and prose: opus
how explorer: sonnet
how explainer: opus
how critics: opus, opus, sonnet
why investigators: sonnet
why synthesizer: opus
reflect tooling: sonnet
reflect judgment, divergent, synthesizer: opus
arena runners: opus, opus, sonnet
architect runners: opus, opus, sonnet
interrogate reviewers: opus, opus, sonnet
```

### 5. Confirm

Tell the user the file was written and that skills pick it up on their next run. Re-running this skill updates it.
