# lasso-mode

**Tame Claude Code. Make it work like a disciplined senior engineer on your exact stack.**

lasso-mode is a collection of standalone agent skills that does two things at once: it enforces rigorous engineering workflow, and it routes the agent to current, authoritative documentation for your stack instead of letting it guess from stale memory. It is the "lasso" you throw over an otherwise fast-but-undisciplined agent. Built for Claude Code; the skills are plain `SKILL.md`, so Cursor, GitHub Copilot and Codex read them too.

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

### 4. Diversity comes from divergent lenses first, models second

pstack's review panels (`interrogate`, `arena`, `how` critics) run several frontier models from different vendors to get adversarial diversity. Claude Code is single-provider, so lasso-mode leans on the lens: each reviewer gets a deliberately divergent angle (correctness, architecture, security) plus its own model. The signal comes from the conflict between lenses, and agreement across them is high-confidence.

The model half lives in the `agents/` files rather than inside the skills, so it works on any host that reads agent frontmatter. On Cursor that means a panel can genuinely span vendors: point `lasso-reviewer-a` at Claude, `-b` at GPT, `-c` at Composer. On Claude Code it is the Anthropic tiers. Either way, `/setup-lasso` is where you choose.

---

## Architecture

```
/lasso-mode  (router, the front door)
├─ Principles index ............ 20 principle-* skills, read at task start
├─ Playbooks ................... 16 step-by-step procedures, one per task type
│   investigation · bug-fix · perf · hillclimb · feature · refactoring
│   prototype · visual-parity · forensics · eval · autonomous-run
│   session-pickup · pause-safely · authoring-a-skill · opening-a-pr
├─ Workflow skills ............. how · why · architect · arena · interrogate
│   tdd · reflect · unslop · recall · blast-radius · figure-it-out
│   show-me-your-work · automate-me · typescript-best-practices
│   setup-lasso · setup-lasso-verify
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

### Claude Code

```bash
./install.sh
```

This symlinks every skill into `~/.claude/skills/`, the agent into `~/.claude/agents/`, and the hooks into `~/.claude/hooks/` (override the target with `CLAUDE_HOME`). Symlinks mean edits in this repo take effect live. In Claude Code, run `/reload-plugins` or restart, then check `/help` and `/agents`.

> Because install uses symlinks into your global `~/.claude/`, switching this repo to a different branch changes your active skills. That is convenient for iteration, worth knowing for surprises.

### Cursor, Copilot, Codex, and everything else

Every skill here is a plain `SKILL.md` folder, the format Cursor, GitHub Copilot, Codex, Gemini CLI and dozens of other agents already read. Nothing needs converting. Install with the [`skills` CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add christianingul/lasso-mode --all              # every skill, every detected agent
npx skills add christianingul/lasso-mode -g -a cursor -a github-copilot
npx skills add . --list                                     # from a clone, without installing
```

It walks the repo for `SKILL.md` and finds all 55, including the nested ones under `skills/stack/`. Use `--copy` if your setup does not follow symlinks; `npx skills remove` undoes it.

Where each agent looks:

| Agent | `--agent` | Global path |
|---|---|---|
| Claude Code | `claude-code` | `~/.claude/skills/` |
| Cursor | `cursor` | `~/.cursor/skills/` |
| GitHub Copilot | `github-copilot` | `~/.copilot/skills/` |
| Codex | `codex` | `~/.codex/skills/` |

Cursor and VS Code Copilot also scan `~/.claude/skills/`, so `./install.sh` can cover all three on its own.

## Portability

The skills load anywhere. Four things do not carry, and each one fails quietly:

- **Parallel fan-out.** `arena`, `interrogate`, `why`, `how`, `reflect` and `swarm` are built on spawning several subagents at once. A host that cannot spawn subagents collapses them to a single pass, which still produces a confident writeup. `arena` in particular exists so different models disagree; one model asked three times agrees with itself.
- **The `lasso-agent` subagent and `.mcp.json`.** The `skills` CLI installs skills only. Subagent definitions and MCP servers need their host's own configuration.
- **Claude Code built-ins.** Skills reference `/loop`, `code-review`, `security-review`, `verify`, `AskUserQuestion` and `~/.claude/projects/` memory paths. Elsewhere an agent will improvise a substitute instead of stopping.
- **The verify hooks.** `hooks/lasso-verify.sh` is a Claude Code Stop hook. Other agents have their own hook systems, or none.

Run `python3 scripts/check-portability.py .` to check every skill against the schema all three hosts share: name, description length, folder match, and bundled resources referenced as relative markdown links. It exits non-zero on a real break, so it works as a pre-commit or CI step.

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

`/lasso-mode` is the front door, but most skills also fire on their own when the situation matches. Three groups:

| Group | Behavior |
|---|---|
| The 20 `principle-*` skills, `tdd`, `show-me-your-work`, `blast-radius`, `how`, `why`, `unslop`, the stack skills | Fire on their own. Cheap, no fan-out. |
| `architect`, `arena`, `interrogate`, `reflect`, `figure-it-out`, `recall` | Fire on their own, but gated. The harness asks before each run. |
| `lasso-mode`, `setup-lasso`, `setup-lasso-verify`, `automate-me` | You type them. Front door and config. |

The gate is a `permissions.ask` rule on `Skill(<name>)` in `settings.json`, written by `/setup-lasso`. It is enforced by the harness, not by a line of prose, so the model cannot talk itself past it. Run `/setup-lasso` with the gate off if you work unattended and nobody is there to answer the prompt.

This split exists because `disable-model-invocation: true` is absolute: a blocked skill cannot be reached by the router at all, and the harness explicitly forbids working around it by reading the file. Anything `/lasso-mode` needs to route to has to be invocable. The gate is how the expensive ones stay under your control without being unreachable.

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

## Models and cost

Run `/setup-lasso`. It asks five questions about the work, not about internal role names, and writes the answers where the harness reads them.

| Question | Agent file |
|---|---|
| Frontend work | `lasso-agent-frontend` |
| Backend work | `lasso-agent-backend` |
| Docs, prose, skill authoring | `lasso-agent-docs`, `lasso-agent` |
| Code review and second opinions | `lasso-reviewer-a`, `-b`, `-c` |
| Deep reasoning and synthesis | `lasso-judge`, `lasso-explorer` |

Model and reasoning level both live in each agent file, as `model:` and `effort:` frontmatter. Claude Code and Cursor both read `~/.claude/agents/` and both honor those fields, so one answer configures both hosts. Keeping them together is what makes them per-role: `sonnet` can run a reviewer at `xhigh` and an explorer at `high` at the same time, which `settings.json` `modelSettings` cannot express because it keys on the model.

Judgment roles (`lasso-judge`, the three reviewers) get `xhigh`. Delegates and `lasso-explorer` stay at `high` — explorers are the most-spawned role, so their effort moves the bill more than any other single setting.

`install.sh` copies the agent files rather than symlinking them, so your choices are yours: a `git checkout` in this repo cannot reset them, and re-running the installer leaves a customized file alone. Skills stay symlinked, so editing the repo still takes effect live.

Haiku is off the Claude Code menu on purpose: it does not support `xhigh`, so it cannot do the work the reviewer and judge roles exist for.

### What a run costs

Subagents are the bulk of it. Every expensive panel is `disable-model-invocation: true`, so it only runs when you type it. Three skills can fire on their own and are the exception worth knowing about: `how` (up to 3 explorers plus a judge), `why` (one investigator per connected MCP category, up to 8), and `swarm` (one agent per row). Each states its agent count before spawning.

The router caps the rest. Panels are three, and three is the maximum. A subagent never spawns its own panel, so depth stops at one. Runners read the principles rather than the whole router, which keeps ~1,600 tokens per agent out of the fan-out.

Prices, per million tokens in / out: Fable 5.1 $10 / $50, Opus 5 $5 / $25, Sonnet 5 $2 / $10. `/setup-lasso` shows these next to each choice.

## License

MIT. See [`LICENSE`](./LICENSE) and [`NOTICE`](./NOTICE).
</content>
