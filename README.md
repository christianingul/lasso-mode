# lasso-mode

**Tame Claude Code. Make it work like a disciplined senior engineer on your exact stack.**

lasso-mode is a collection of standalone Claude Code skills that does two things at once: it enforces rigorous engineering workflow, and it routes the agent to current, authoritative documentation for your stack instead of letting it guess from stale memory. It is the "lasso" you throw over an otherwise fast-but-undisciplined agent.

---

## The problem it solves

Claude Code is powerful, and that power cuts both ways. Left unguided, an agent tends to:

- **Write slop.** It over-engineers, adds layers nobody asked for, and optimizes for lines of code instead of a maintainer's sanity.
- **Skip the proof.** "It compiles" stands in for "it works." Bugs get patched at the symptom, not the root.
- **Trust stale memory.** It writes LangGraph, Next.js, or Langfuse code from whatever it absorbed at training time, which is often a version or two behind the API that actually ships today.

The first two are workflow problems. The third is a knowledge problem. lasso-mode attacks both.

---

## Design philosophy

**Go deep first, then go fast.** Throughput without quality is not the goal. The point is to write *less* code of *higher* quality, so that you can then parallelize across many agents with confidence. This half of the philosophy is inherited directly from [pstack](https://github.com/cursor/plugins/tree/main/pstack); lasso-mode is a Claude Code port of its engine.

The philosophy shows up as four concrete commitments:

### 1. Principles ground every decision

Twenty single-idea skills (`principle-laziness-protocol`, `principle-prove-it-works`, `principle-fix-root-causes`, …) encode the non-negotiables. The router reads them at the start of every task, and every decision it makes must trace back to a named principle. A citation with no decision behind it means the rule was skipped. This is what stops "be a good engineer" from being a vibe.

### 2. The work proves itself

Verification is against the real artifact, not a proxy. Bugs are reproduced before they are fixed. Multi-step work is sequenced into units that each end in a check. The deliverable is evidence, not assertion.

### 3. Knowledge has an explicit escalation ladder

This is the part pstack doesn't have, and the reason lasso-mode exists for *your* stack. When a task touches a known technology, the agent does not start from its own weights. It climbs a fixed ladder and stops at the first rung that answers the question:

1. **Source skill.** Read the vendored, authored skill for that technology (e.g. `langgraph-fundamentals`, `vercel-react-best-practices`). Conventions plus distilled, opinionated guidance. Loads only when read, so it is nearly free until needed.
2. **MCP docs tool.** If the skill is insufficient, query the technology's MCP server for live, version-specific documentation.
3. **Pre-trained weights.** Only if neither rung satisfies the request does the agent fall back to its own knowledge, and it says so, so the gap can be closed later.

The ladder is one-directional. Skipping rung 1 to guess from weights is the exact failure mode the whole system exists to prevent. The map of technology to rungs lives in [`skills/lasso-mode/references/skills.md`](./skills/lasso-mode/references/skills.md).

### 4. Diversity comes from divergent lenses, not different vendors

pstack's review panels (`interrogate`, `arena`, `how` critics) run several frontier models from different vendors to get adversarial diversity. Claude Code is single-provider, so lasso-mode reworks those panels: each reviewer is a Claude agent given a deliberately divergent lens (correctness, architecture, security) and a model tier (`opus`, `sonnet`, `haiku`). The signal comes from the conflict between lenses, and agreement across them is high-confidence.

---

## Architecture

```
/lasso-mode  (router, the front door)
├─ Principles index ............ 20 principle-* skills, read at task start
├─ Playbooks ................... 16 step-by-step procedures, one per task type
│   investigation · bug-fix · perf · hillclimb · feature · refactoring
│   prototype · visual-parity · forensics · eval · autonomous-run
│   session-pickup · pause-safely · multi-phase · authoring-a-skill · opening-a-pr
├─ Workflow skills ............. how · why · architect · arena · interrogate
│   tdd · reflect · unslop · recall · blast-radius · figure-it-out
│   show-me-your-work · automate-me · typescript-best-practices · setup-lasso
└─ Stack index (skills.md) ..... the escalation ladder
    ├─ Source skills (skills/stack/) → vendored author skills + thin pointers
    └─ MCP servers (.mcp.json) ... mcpdoc · context7 · langfuse
```

The router matches your request to a playbook, copies its steps in verbatim, and fires the workflow and stack skills as the steps need them. The `lasso-agent` subagent runs the same style end to end for delegated work.

---

## What it builds on

lasso-mode is an aggregate of three MIT-licensed projects. Full attribution and commit pins are in [`NOTICE`](./NOTICE).

| Source | By | What lasso-mode takes |
|---|---|---|
| [pstack](https://github.com/cursor/plugins/tree/main/pstack) | Lauren Tan (poteto) | The entire workflow engine: router, principles, playbooks, workflow skills. Ported from Cursor to Claude Code and rebranded. |
| [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) | LangChain | The official LangChain, LangGraph, and Deep Agents skills, vendored verbatim into `skills/stack/`. |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Vercel | The official `react-best-practices` skill (React + Next.js performance), vendored verbatim. |

The port from Cursor to Claude Code touched only the harness seams: `Task` → `Agent`, read-only fan-out → the `Explore` subagent, model slugs → Claude tiers, Cursor built-ins remapped (`babysit` → `code-review`, `create-skill` → a self-contained authoring playbook, `deslop` → `unslop`), and the multi-vendor panels reworked as above. The principles and most playbooks port verbatim.

---

## Install

```bash
./install.sh
```

This symlinks every skill into `~/.claude/skills/` and the agent into `~/.claude/agents/` (override the target with `CLAUDE_HOME`). Symlinks mean edits in this repo take effect live. In Claude Code, run `/reload-plugins` or restart, then check `/help` and `/agents`.

> Because install uses symlinks into your global `~/.claude/`, switching this repo to a different branch changes your active skills. That is convenient for iteration, worth knowing for surprises.

## Invoke

```bash
/lasso-mode <your request>
```

It is `disable-model-invocation: true`, so it fires only when you call it. Examples:

```
/lasso-mode build a LangGraph node that summarizes a thread, behind a flag, and verify it
/lasso-mode this Next.js page has a data waterfall, trace it and fix
/lasso-mode investigation: how does our checkpointer scope subgraph state?
```

The model-invocable stack skills (`langgraph-fundamentals`, `nextjs`, `unslop`, and friends) and `/how`, `/why` can also be triggered on their own. `/lasso-mode` is the front door that orchestrates them.

## MCP servers

| Server | Covers | Setup |
|---|---|---|
| `mcpdoc` | LangGraph, LangChain, Deep Agents (`llms.txt`) | Needs [`uv`](https://docs.astral.sh/uv/) on PATH (`uvx`). Keyless. |
| `context7` | React, Next.js, Python, thousands of libraries | Runs via `npx`. Keyless; add `CONTEXT7_API_KEY` for higher limits. |
| `langfuse` | Your Langfuse prompts and observability | Set `LANGFUSE_HOST` and `LANGFUSE_AUTH_B64`. |

```bash
export LANGFUSE_HOST="https://cloud.langfuse.com"
export LANGFUSE_AUTH_B64="$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64)"
```

Run `/mcp` to confirm connections. A server that is not connected is treated as a gap; the agent falls through to the next rung instead of blocking.

## Verify hooks (trust but verify)

The router asks the agent to prove its work (`principle-prove-it-works`). A hook enforces it deterministically, without the agent's cooperation. `hooks/lasso-verify.sh` is a `Stop` hook. When an agent finishes a turn that changed the diff, it re-runs the project's checks (typecheck, lint, build, test) and blocks the stop while anything is red, feeding the failing output back so the agent fixes the root cause before finishing.

It is one file in three modes. The hook Claude Code invokes on `Stop`, an idempotent project installer, and a rerunnable manual check a reviewer trusts instead of your word.

Arm a project:

```bash
/setup-lasso-verify
```

That detects the project's checks (Node, Python, Rust, Go), merges a `Stop` hook into its `.claude/settings.json`, writes a tunable `.claude/lasso-verify.conf`, and gitignores the loop-guard state. Run the same check by hand anytime:

```bash
~/.claude/hooks/lasso-verify.sh check
```

Verification is project-scoped and opt-in, so it never fires on unrelated chats. The loop is bounded: the hook stops blocking once the diff stops changing or after `LASSO_MAX_ROUNDS` (default 3). A clean tree is a silent no-op. Edit `.claude/lasso-verify.conf` to add, drop, or retime checks. Keep them cheap and read-only. Never put a deploy or push in there.

## Configure models

Every agent here is Claude. Run `/setup-lasso` to override the per-role tier defaults (`opus` / `sonnet` / `haiku`); skills fall back to sensible defaults without it.

## License

MIT. See [`LICENSE`](./LICENSE) and [`NOTICE`](./NOTICE).
</content>
