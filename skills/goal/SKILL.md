---
name: goal
description: "Write the contract for a `/goal` run, the persistent loop that plans, acts, tests, and iterates until a stop condition is met instead of waiting for your next message. Use for '/goal', 'goal loop', 'write me a goal', or kicking off a long autonomous run with a verifiable finish."
---

# Goal

`/goal` turns a prompt into a persistent agent. When a turn ends and the goal is not met, it continues instead of waiting for you. That single change is what makes it different from a normal prompt, and it is why the contract you hand it matters more than the wording.

Distinct from `/loop`, which re-invokes the agent on a schedule and is what the **autonomous-run** playbook drives. `/loop` wakes you up; `/goal` never went to sleep. Use `/goal` when there is a check that says done, `/loop` when you are watching something that changes on its own.

Not a budget cap, not a safety boundary, not "run forever". A contract with a verification loop attached.

## When it earns its cost

All three, or use a normal prompt:

1. More than about thirty minutes of mechanical work.
2. A stop condition a command can check. Tests pass, coverage hits a number, the build goes green, the eval clears a threshold.
3. A repo that is ready for it. Working build, tests worth trusting, `CLAUDE.md` or `AGENTS.md` present.

Fits migrations, coverage lifts, refactors behind contract tests, repro-then-fix, eval hillclimbing.

Does not fit exploratory work, "improve this", anything where done is a judgment call, or destructive operations on shared infrastructure. A short vague goal burns tokens and returns what a normal prompt would have.

## The contract

Six lines. Write them as lines, not as a paragraph.

```
**Objective:** <one sentence, one outcome>
**Read first:** <the files, the plan, the issue>
**Constraints:** <what must not change: public API, deps, conventions>
**Validate:** `<the exact command>` after each change
**Checkpoints:** work in checkpoints, log progress briefly
**Stop when:** <the checkable condition>, OR when further work needs a human decision
```

Do not prefix the output with `/goal`. The user types that themselves.

**Forbid reward-hacking explicitly.** Add: *"Do not delete, skip, weaken, or narrow tests to make the goal pass."* A loop optimizing against a stop condition will find the cheapest route to it, and deleting the failing test is cheaper than fixing the bug. This line is not optional, and it is the one thing the **prove-it-works** principle skill cannot enforce from outside the run.

**Forbid scope creep explicitly.** Add: *"Do not refactor unrelated code. Do not add dependencies."*

**One objective and one stop condition.** A backlog in a goal produces a run that finishes none of it.

Keep the objective short. If it needs more than a few hundred words, put the detail in `PLAN.md` and point the goal at the file. Use literal paths, literal commands, literal issue numbers.

## Write it with a second pass

A hand-written goal under-specifies, because you know the constraints you did not write down and the loop does not. Before committing to a long run, have an agent inspect the repo, surface the hidden constraints and edge cases, and emit the contract. Then read what it produced and cut what is wrong.

The **architect** skill is the heavier version of this when the goal covers a design, not a sweep.

## Running one

Goals are scoped to the working directory, so `cd` there first. Type `/goal <contract>`, then leave.

Bare `/goal` reports status. `/goal pause` freezes, `/goal resume` unfreezes, `/goal clear` kills it, `/goal <new>` replaces the contract. Typing anything pauses it, so your input always wins.

## When it drifts

- Small drift: type the correction. It folds in and resumes.
- Loose objective: pause, read the status, replace the contract with a tighter one. Do not stack instructions onto a vague goal.
- Real mess: clear it, look at `git status`, rewrite the contract, start again.

Do not let a drifting goal keep running to see where it lands. The diff compounds faster than the insight.

## Before you merge what it produced

Read the diff. A long autonomous run means more code to check, not less, and the loop had every incentive to satisfy the stop condition rather than the intent. Run the **blast-radius** skill over anything that touched a boundary, and treat a suspiciously clean result as a reason to look at the tests it was validating against.

For a run you want an auditable trail from, pair it with the **show-me-your-work** skill.

**Reply:** the contract, as the six lines above, ready to paste.
