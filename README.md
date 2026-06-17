# lasso-mode

Tame and squeeze the most out of Claude Code. lasso-mode is an engineering-rigor workflow system plus a stack-aware documentation layer, packaged as standalone Claude Code skills.

It does two things:

1. **Rigor.** A router skill (`/lasso-mode`) matches a task to one of 16 playbooks, grounded in 20 one-principle-each skills, and routes to focused workflow skills (`how`, `why`, `architect`, `interrogate`, `tdd`, `reflect`, `unslop`, and more). The goal is less code, higher quality, verified work. This half is a Claude Code port of [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan (poteto).

2. **Stack awareness.** A `skills.md` index (owned by the router) tells the agent where to go for our stack: LangChain, LangGraph, Deep Agents, Langfuse, React, Next.js, Python. For any of these it follows a fixed **escalation ladder** so it stops coding fast-moving libraries from stale memory.

## The escalation ladder

For any stack technology, climb in order and stop at the first rung that answers the question:

1. **Source skill.** Read the vendored, authored skill (e.g. `langgraph-fundamentals`, `vercel-react-best-practices`). Conventions plus distilled guidance.
2. **MCP docs tool.** If the skill is insufficient, query the technology's MCP server for live, version-specific docs.
3. **Pre-trained weights.** Only if neither satisfies the request, fall back to your own knowledge, and say so.

The full map lives in `skills/lasso-mode/references/skills.md`.

## Install

```bash
./install.sh
```

This symlinks every skill into `~/.claude/skills/` and the agent into `~/.claude/agents/` (override the target with `CLAUDE_HOME`). Edits in this repo take effect live. In Claude Code, run `/reload-plugins` (or restart), then check `/help` and `/agents`.

Then start a task with `/lasso-mode <your request>`.

## MCP servers

The stack docs layer uses three MCP servers, configured in `.mcp.json` (project-scoped; copy into `~/.claude/` for global). Claude Code expands `${VAR}` from your environment.

| Server | Covers | Setup |
|---|---|---|
| `mcpdoc` | LangGraph, LangChain, Deep Agents (`llms.txt`) | Needs [`uv`](https://docs.astral.sh/uv/) on PATH (`uvx`). Keyless. |
| `context7` | React, Next.js, Python, thousands of libraries | Runs via `npx`. Keyless; add `CONTEXT7_API_KEY` for higher limits. |
| `langfuse` | Your Langfuse prompts and observability | Set `LANGFUSE_HOST` and `LANGFUSE_AUTH_B64`. |

`LANGFUSE_AUTH_B64` is the base64 of `public_key:secret_key`:

```bash
export LANGFUSE_HOST="https://cloud.langfuse.com"
export LANGFUSE_AUTH_B64="$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64)"
```

Run `/mcp` in Claude Code to confirm the servers connect. A server that isn't connected is treated as a gap; the agent falls through to the next rung instead of blocking.

## Configuring models

Every agent here is a Claude model. Panels (`interrogate`, `arena`, `how` critics) get their diversity from divergent lenses and model tiers (`opus`/`sonnet`/`haiku`), not from different vendors. Run `/setup-lasso` to override the per-role tier defaults; skills fall back to sensible defaults without it.

## What's inside

- `skills/lasso-mode/` — the router: principles index, 16 playbooks, the `references/skills.md` stack index.
- `skills/principle-*/` — 20 one-principle-each skills.
- `skills/{how,why,architect,arena,interrogate,tdd,reflect,unslop,recall,blast-radius,figure-it-out,show-me-your-work,automate-me,typescript-best-practices,setup-lasso}/` — workflow skills.
- `skills/stack/` — vendored author skills (LangChain, LangGraph, Deep Agents, Vercel React) plus thin `nextjs`, `python`, `langfuse` skills that escalate to MCP.
- `agents/lasso-agent.md` — the subagent that runs the full lasso style.

## Credits

lasso-mode stands on three MIT-licensed projects. See [`NOTICE`](./NOTICE) for details and commit pins.

- [pstack](https://github.com/cursor/plugins/tree/main/pstack) — the workflow engine, by Lauren Tan (poteto).
- [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) — the LangChain/LangGraph/Deep Agents skills.
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — the React/Next.js performance skill.
</content>
