# Stack index

The map from a technology to where its knowledge lives. When a task touches our stack, come here first, then follow the escalation ladder. Do not code a fast-moving library from memory before checking the ladder.

## The escalation ladder

For any stack technology, climb these rungs in order and stop at the first one that fully answers the question:

1. **Source skill.** Read the vendored, authored skill for that technology (the rows below). These hold our conventions plus distilled, opinionated guidance. They load only when read, so reading one is cheap.
2. **MCP docs tool.** If the source skill doesn't cover the exact API, signature, version behavior, or current best practice, query the technology's MCP server for live, version-specific docs. The servers are wired in the repo's `.mcp.json`.
3. **Pre-trained weights.** Only if the source skill and the MCP both come up short, fall back to your own knowledge. When you do, say so in your reply so the gap can be closed later (a missing skill section, a new llms.txt source, a Context7 lookup that should have worked).

The ladder is one-directional. Skipping rung 1 to guess from weights is the failure mode this whole system exists to prevent.

## The map

| Technology | Source skill(s) (rung 1) | MCP tool (rung 2) | Then |
|---|---|---|---|
| LangGraph | `langgraph-fundamentals`, `langgraph-persistence`, `langgraph-human-in-the-loop`, `langgraph-cli` | `mcpdoc` → `fetch_docs` (LangGraph `llms.txt`) | weights |
| LangChain | `langchain-fundamentals`, `langchain-middleware`, `langchain-rag`, `langchain-dependencies`, `ecosystem-primer` | `mcpdoc` → `fetch_docs` (LangChain `llms.txt`) | weights |
| Deep Agents | `deep-agents-core`, `deep-agents-memory`, `deep-agents-orchestration`, `managed-deep-agents`, `swarm` | `mcpdoc` → `fetch_docs` (LangChain `llms.txt`) | weights |
| Langfuse | `langfuse` | Langfuse MCP (`<host>/api/public/mcp`); `context7` for SDK detail | weights |
| React | `vercel-react-best-practices` | `context7` → `resolve-library-id` + `get-library-docs` (`/facebook/react`) | weights |
| Next.js | `nextjs`, `vercel-react-best-practices` (performance) | `context7` → `get-library-docs` (`/vercel/next.js`) | weights |
| Python | `python` | `context7` → `resolve-library-id` + `get-library-docs` (per package) | weights |
| Any other library | — (no source skill yet) | `context7` → `resolve-library-id` + `get-library-docs` | weights |

## MCP servers, in one line each

- **mcpdoc** (`langchain-ai/mcpdoc`, keyless). Serves the LangGraph and LangChain `llms.txt`. One tool: `fetch_docs`. Use for anything in the LangChain ecosystem.
- **context7** (`@upstash/context7-mcp`). Version-specific docs for thousands of libraries, including React, Next.js, and most Python and JS packages. Tools: `resolve-library-id`, `get-library-docs`.
- **langfuse** (native, `<LANGFUSE_HOST>/api/public/mcp`). Prompt management and observability against your own Langfuse project. Needs `LANGFUSE_*` env keys.

If an MCP server isn't connected (check `/mcp`), note it as a gap and fall through to weights rather than blocking.
</content>
