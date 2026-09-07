---
name: setup-lasso
description: Pick which model each lasso role uses, asked in terms of the work (frontend, backend, docs, review, deep reasoning) rather than internal role names, and gate the skills that fan out to a panel. Writes the model into the lasso agent files, and the reasoning effort and permission gates into settings. Use for /setup-lasso, "configure lasso models", or changing lasso's model choices.
disable-model-invocation: true
---

# Setup lasso

Ask the user which model to use for each kind of work, then write the answers where the harness reads them.

Three outputs, because each setting lives somewhere different:

- **Model** goes in each agent file's `model:` frontmatter, under `~/.claude/agents/` (or wherever `CLAUDE_HOME` points). Claude Code and Cursor both read that directory and both honor the field, so one write configures both.
- **Effort** goes in `settings.json` under `modelSettings.<model>.effortLevel`. Agent frontmatter does not carry it.
- **The cost gate** goes in `settings.json` under `permissions.ask`, so the harness prompts before a fan-out skill runs.

## Steps

### 1. Detect the host and build the model menu

Check for `~/.cursor/`. If it exists, the user may be running lasso in Cursor too, so ask which host they are configuring and offer that host's models.

**Claude Code.** Three options. Haiku is deliberately absent: it does not support `xhigh` effort, so it cannot do the work lasso reserves reasoning for.

| Option | Price per MTok in / out |
|---|---|
| `opus` (Claude Opus 5) | $5 / $25 |
| `sonnet` (Claude Sonnet 5) | $2 / $10 |
| `fable` (Claude Fable 5.1) | $10 / $50 |

The aliases already resolve to the newest model in each family. Never write a dated ID.

**Cursor.** Do not guess a roster. Ask the user which models their plan includes, or read what the picker offers, and use those IDs verbatim (`composer-2`, `gpt-5.6-sol`, `claude-opus-5`). Cursor also accepts inline parameters, so `claude-opus-5[effort=xhigh]` sets effort in the same field.

Show the price column next to every option. The point of the ask is that the user can see what each choice costs.

### 2. Ask in terms of the work

Five questions via `AskUserQuestion`, one round. Do not walk the internal role list; nobody thinks in "how-explainer".

| Question | Writes |
|---|---|
| "Which model for frontend work?" | `lasso-agent-frontend.md` |
| "For backend work?" | `lasso-agent-backend.md` |
| "For docs, prose, and skill authoring?" | `lasso-agent-docs.md`, `lasso-agent.md` |
| "For code review and second opinions?" | `lasso-reviewer-a.md`, `-b.md`, `-c.md` |
| "For deep reasoning and synthesis?" | `lasso-judge.md`, `lasso-explorer.md` |

On the review question, offer a spread rather than one model. The panel earns its cost by disagreeing, and three copies of one model agree with themselves. Default spread is the strongest model twice plus a cheaper third. If the user picks a single model for all three, take it, and tell them once what they gave up.

If the user declines to answer, keep the current value. Never silently substitute a default for a question they skipped.

### 3. Write the agent files

Edit only the `model:` line in each file's frontmatter. Leave the body alone; it holds the role's instructions and the depth cap. Re-running this skill overwrites the same line, so it stays idempotent.

If an agent file is missing, the install is incomplete. Say so and point at `./install.sh` rather than creating a partial one.

### 4. Write the effort setting

Effort is `low`, `medium`, `high`, `xhigh`, or `max`. Default is `high`.

Set `xhigh` for the judgment models, the reviewers and `lasso-judge`, where deeper reasoning is the whole point. Leave mechanical delegates at `high`. Reserve `max` for a specific hard problem the user names; Claude Code's own guidance is that it may burn tokens without improving the answer.

`xhigh` runs on Fable 5, Opus 4.7 and later, and Sonnet 5. If a chosen model does not support it, the setting is ignored and effort falls back to `high`. Say so rather than writing a line that does nothing.

Merge into `settings.json`, preserving every key already there:

```json
{
  "modelSettings": {
    "claude-opus-5": { "effortLevel": "xhigh" }
  }
}
```

User settings (`~/.claude/settings.json`) unless the user asks for this project only.

### 5. Gate the expensive skills

Six skills fan out to a panel: `architect`, `arena`, `interrogate`, `reflect`, `figure-it-out`, `recall`. They are model-invocable so the router can reach them, and gated so the model cannot spend three opus agents without asking.

The gate is a permission rule, not a line of prose the model can talk itself past. `ask` is a first-class permission behavior and `Skill(<name>)` is a valid specifier, so the harness stops and prompts before the skill runs.

Merge into the same `settings.json`, preserving existing rules:

```json
{
  "permissions": {
    "ask": [
      "Skill(architect)",
      "Skill(arena)",
      "Skill(interrogate)",
      "Skill(reflect)",
      "Skill(figure-it-out)",
      "Skill(recall)"
    ]
  }
}
```

Ask the user whether they want the gate before writing it. Someone running unattended (`/loop`, an autonomous run) may want these to proceed without a prompt, since nobody is at the keyboard to answer. Offer three options: gate all six (the default), gate none, or pick which.

The cheap skills stay ungated. The 20 principles, `tdd`, `show-me-your-work`, and `blast-radius` spawn nothing, and a prompt for a 350-token read costs more attention than it saves.

### 6. Confirm

Report which files changed, the model now on each role, the effort, and which skills are gated. Tell the user to run `/reload-plugins` or restart so the agent files reload. On Cursor, the picker still applies to the main thread; these settings govern the subagents.
