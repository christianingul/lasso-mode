---
name: langfuse
description: "INVOKE when working with Langfuse: prompt management, tracing, observability, evals, or scores for LLM apps. Covers our conventions, then escalates to the Langfuse MCP and live docs."
---

# Langfuse

Langfuse is our LLM observability and prompt-management layer. Our conventions, then the escalation ladder.

## Conventions

- **Prompts live in Langfuse, not in code.** Fetch by name with a label (`production`, `latest`, or a pinned version) at runtime. Cache the fetched prompt and fall back to a checked-in default if Langfuse is unreachable, so a fetch failure degrades instead of breaking.
- **Trace every LLM call.** Wrap chains/agents so each generation, retrieval, and tool call is a span under one trace. For LangChain/LangGraph, use the Langfuse callback handler rather than hand-rolling spans.
- **Score what you care about.** Attach evals/scores (quality, latency, cost, user feedback) to traces so regressions are visible. Name scores consistently across releases.
- **Never log secrets or raw PII into trace inputs/outputs.** Redact at the boundary.
- **Keys via env**, never committed: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST`.

## Escalation ladder

Follow this in order. Stop at the first rung that answers the question.

1. **This skill** for our conventions.
2. **Langfuse MCP** for prompt management and live project data. The native server is exposed at `<LANGFUSE_HOST>/api/public/mcp` (streamable HTTP) and is wired in this repo's `.mcp.json`. Use it to fetch, list, and update prompts and to inspect observations and metrics directly rather than guessing at prompt contents or schema. For API/SDK detail not covered by the MCP, query **Context7** for `langfuse`.
3. **Your own knowledge** only when the source skill and the MCP both come up short. Say so when you do.
</content>
