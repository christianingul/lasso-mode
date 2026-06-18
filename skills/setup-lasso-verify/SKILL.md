---
name: setup-lasso-verify
description: Arm a project with lasso's trust-but-verify Stop hook. Detects the project's checks (typecheck, lint, build, test), registers a deterministic hook that re-runs them when an agent finishes and blocks the stop while anything is red. Use for /setup-lasso-verify, "arm verification", "set up the verify hook", or "trust but verify".
disable-model-invocation: true
---

# Setup lasso-verify

Arm the current project with a `Stop` hook that re-runs its checks every time an agent finishes a turn, and blocks the stop while a check is red. This is the structural enforcement of **principle-prove-it-works**. The agent no longer self-reports "done" unverified. A deterministic script re-runs the real checks and refuses the stop until they pass.

The lever is `hooks/lasso-verify.sh`, symlinked to `~/.claude/hooks/lasso-verify.sh` by `install.sh`. It is the hook, the installer, and a rerunnable manual check in one file.

## Steps

### 1. Confirm the target project

Default to the current working directory. It must be a git repo. The hook scopes verification to the diff, so a non-git directory is a no-op and arming it is pointless. If the user names a different project, use that path.

### 2. Arm it

Run the installer. It is idempotent.

```bash
~/.claude/hooks/lasso-verify.sh install
```

This does three things. It merges a `Stop` hook into the project's `.claude/settings.json`, replacing any prior lasso-verify entry and leaving every other hook intact. It writes a starter `.claude/lasso-verify.conf` listing the checks it auto-detected. It adds `.claude/.lasso-verify/` (the loop-guard state) to `.gitignore`.

Auto-detection covers Node (`package.json` scripts: typecheck, lint, build, test, with the right package manager), Python (ruff, mypy, pytest), Rust (`cargo check`, `cargo test`), and Go (`go vet`, `go test`).

### 3. Show the detected checks and let the user tune them

Read back `.claude/lasso-verify.conf` and show it. Each line is `name=command`. An empty command skips that check. Delete the file to fall back to auto-detection on every run.

If detection missed a check or picked the wrong command, edit the conf. This is the place to drop a slow end-to-end suite that should not gate every turn, or to add a project-specific command. Keep the checks cheap and read-only. The hook runs them on every finished turn that has a diff, so a multi-minute suite makes the agent painful to work with. Never put a deploy, a push, or anything with side effects in here.

### 4. Confirm the manual check works

Prove the lever before trusting it. Run it once by hand.

```bash
~/.claude/hooks/lasso-verify.sh check
```

Exit 0 with a green line means the checks pass on the current tree. Exit 1 prints which check failed and the tail of its output. This is the same logic the hook runs, so a reviewer reruns this instead of trusting a summary.

### 5. Tell the user how it behaves and to reload

The hook loads on the next session, so tell the user to run `/reload-plugins` or restart.

Explain the runtime behavior in one short pass. When an agent finishes a turn that changed the diff, the hook re-runs the checks. All green, the turn ends with a one-line `lasso-verify ✓ green` note. Anything red, the stop is blocked and the failing output is fed back so the agent fixes the root cause before finishing. The loop is bounded. If the agent returns without changing the diff, or after a few rounds (default 3, set `LASSO_MAX_ROUNDS`), the hook stops blocking and lets the turn end with a note that verification is still red. A clean tree with no diff is a silent no-op.

## Tuning knobs

- `.claude/lasso-verify.conf`. Which checks run and their commands. Authoritative when present.
- `LASSO_MAX_ROUNDS` (default 3). How many corrective rounds before the hook gives up and lets the agent stop.
- `LASSO_CHECK_TIMEOUT` (default 300s). Per-check timeout, when `timeout` is on PATH.

## Disarming

Remove the `Stop` block from `.claude/settings.json` (or delete the lasso-verify entry from its `Stop` array) and reload. The conf and state dir are inert without the hook registration.
