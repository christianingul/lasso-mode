---
name: git-worktree
description: "Give each parallel agent its own checkout so two of them cannot overwrite each other. Covers creating a worktree, bootstrapping the gitignored files a fresh one is missing, merging back, and cleanup. Use when fanning work out across branches, running an arena, or when agents keep clobbering the same files."
---

# Git worktrees

One repo, several folders. `git worktree add` makes another checkout of the same repository in its own directory on its own branch. They share one `.git`, so history is common, but the files are separate and two agents physically cannot overwrite each other.

This is the concrete form of the **separate-before-serializing-shared-state** principle skill. That principle says eliminate the sharing before you reach for a lock; a worktree per agent is how you eliminate it for a repo. The **arena** skill and the Phase B fan-out in **architect** both assume this.

## First, know where you are

```bash
[ "$(git rev-parse --path-format=absolute --git-dir)" = "$(git rev-parse --path-format=absolute --git-common-dir)" ] \
  && echo "primary checkout" || echo "worktree"
```

In the primary checkout, do not start editing. Create a worktree for the task, bootstrap it, `cd` in, and work there. Already in a worktree, carry on.

## The model

- One task, one worktree, one agent. Never two agents in one directory.
- The primary checkout is the integration point. It stays on the main branch and is for reviewing and merging, not a scratchpad.
- Nothing auto-merges. A human reads the diff, merges or discards, then the worktree goes.
- Worktree branches are local and short-lived. Do not push one unless asked.
- Merge one at a time, and rebase onto main first if main moved.

```bash
git worktree add ../myrepo-task-x          # new worktree and branch
git worktree add ../fix-y -b fix-y main    # explicit branch off main
git worktree list
git worktree remove ../myrepo-task-x
git worktree prune                         # clear stale registrations
```

A branch can only be checked out in one worktree at a time, main included.

## Bootstrap it, or the agent fails confusingly

A fresh worktree holds tracked files only. Everything gitignored is absent, and an agent dropped into a bare one hits errors that look like code problems. This is the failure to plan for.

1. **Env files.** Copy `.env`, `.env.local` and friends from the primary checkout. Copy, never symlink: an agent editing a symlinked env file corrupts the original.
2. **Dependencies.** Run the real install (`npm ci`, `pnpm install`, `uv sync`, `bundle install`). Do not symlink `node_modules` to save disk. Bundlers resolve it to a path outside the worktree and refuse to build; Turbopack dies with `FATAL: Symlink [project]/node_modules is invalid, it points out of the filesystem root`. Remove the symlink with `rm -f node_modules` and install properly.
3. **Local databases and services.** One shared server needs a pinned identity so worktrees do not each spawn a container fighting for the same port. In Docker Compose set a top-level `name:`, or the project name comes from the folder and every worktree starts its own. Per-worktree state like a SQLite file gets copied or re-seeded.
4. **Ports.** Dev servers, test runners and debuggers bind fixed ports. Run one at a time, or make the port configurable per worktree.
5. **Generated files.** Build output and codegen are gitignored, so rebuild in the worktree.
6. **Git hooks.** `core.hooksPath` and `.git/config` are shared automatically, but check the hook scripts do not assume the primary checkout's path.

Codify this rather than repeating it, per the **build-the-lever** principle skill. One setup script committed to the repo, run as the first command in every new worktree, is the whole fix. Inside a worktree the primary checkout is:

```bash
dirname "$(git rev-parse --path-format=absolute --git-common-dir)"
```

## Merging back

```bash
# from the primary checkout, after reading the diff
git merge --no-ff task-branch
git worktree remove ../myrepo-task-x
git branch -d task-branch
```

## Gotchas

- Missing gitignored files is the failure you will actually hit. Bootstrap before the agent starts, not after it complains.
- Each worktree duplicates the working files and its own `node_modules`. Delete merged ones.
- A worktree that stalls for days rots. Rebase onto main or restart it.
- Uncommitted work in a removed worktree is gone. Commit early; commits live in the shared repo even after the folder does not.
- Worktrees isolate files, not git state. One stash list, one config, one refs namespace across all of them.
