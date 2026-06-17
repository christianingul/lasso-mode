---
name: python
description: "INVOKE when writing or reviewing Python: package layout, typing, async, dependency management, and testing. Covers our conventions, then escalates to live docs."
---

# Python

Our conventions for Python work, then the escalation ladder for anything this skill doesn't settle.

## Conventions

- **Type everything at the boundaries.** Public functions, dataclasses/Pydantic models, and module APIs carry full type hints. Parse and validate external data into typed models at the edge; trust the types inside.
- **`uv` for environments and dependencies** unless the repo already standardizes on Poetry or pip-tools. Match the repo; don't introduce a second tool.
- **Prefer the standard library and a small dependency set.** Every dependency is a maintenance and supply-chain cost. Justify additions.
- **Async is a posture, not a sprinkle.** If a code path is async, keep it async end to end; don't block the event loop with sync I/O. Don't make code async that has no concurrency to exploit.
- **Tests with `pytest`.** Small, fast, deterministic. A failing test first when fixing a bug (the **tdd** skill).
- **`ruff` for lint and format**, `mypy` or `pyright` for type checking, run before declaring done.

## Escalation ladder

Follow this in order. Stop at the first rung that answers the question.

1. **This skill** for our conventions. For LangChain/LangGraph/Deep Agents Python, the dedicated `langchain-*`, `langgraph-*`, and `deep-agents-*` skills are authoritative; read those instead.
2. **Context7 MCP** for current, version-specific library detail (a third-party package's API, a stdlib change across versions). Call `resolve-library-id` with the package name, then `get-library-docs` with the resolved ID. Prefer live docs over memory whenever the exact signature, argument, or version behavior matters.
3. **Your own knowledge** only when the source skill and the MCP both come up short. Say so when you do.
</content>
