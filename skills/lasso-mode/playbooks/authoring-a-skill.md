### Authoring or modifying a skill

**You own the skill's voice.** Agent-facing prose has a higher bar than human prose; unhelpful sentences become instructions.

1. Author the `SKILL.md` directly. A skill is a directory under `.claude/skills/<name>/` (project) or `~/.claude/skills/<name>/` (personal) holding `SKILL.md`, optionally with `references/` and `scripts/` subdirectories for progressive disclosure. The frontmatter is YAML with `name` (kebab-case, matches the directory) and `description` (one scalar; this is the only thing the model sees when deciding to invoke, so make it trigger on the real cues). Add `disable-model-invocation: true` for heavy, opinionated, or explicit-only skills so they fire only when the user invokes them. Keep the body lean; push long reference material into `references/` files the skill points at, since those load only when read. Apply the **unslop** skill to every line.
2. Validate the skill: frontmatter has `name` and `description`, referenced files exist, cross-skill links resolve. Run `claude plugin validate` if the skill ships in a plugin.
3. Test cases if structural; skip if subjective.
4. Run **Opening a PR**.

When in doubt, delete; prose earns its keep by changing a decision. Match tone to scope. Point at structural sources (types, READMEs, config); hardcoded details go stale (the **encode-lessons-in-structure** principle skill). Delegate to other skills by path; don't restate. A workflow you keep hitting but isn't captured → propose a new skill.

**Reply:** summary of the skill, key design decisions, validation notes.
