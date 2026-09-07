#!/usr/bin/env bash
# Install lasso-mode by symlinking its skills and agents into ~/.claude.
# Re-runnable. Edits in this repo take effect live through the symlinks.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SKILLS_DEST="$CLAUDE_HOME/skills"
AGENTS_DEST="$CLAUDE_HOME/agents"

mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"

echo "Linking skills into $SKILLS_DEST"
# Every directory that contains a SKILL.md is one skill. Link it by its basename.
find "$REPO/skills" -name SKILL.md -print0 | while IFS= read -r -d '' skillmd; do
  dir="$(dirname "$skillmd")"
  name="$(basename "$dir")"
  ln -sfn "$dir" "$SKILLS_DEST/$name"
  echo "  /$name"
done

# Agents are COPIED, not symlinked. /setup-lasso writes your model and effort
# choices into these files, and a symlink would put personal config in the repo
# (and let a git checkout silently reset it). Existing files are left alone so
# re-running the installer never clobbers your choices.
echo "Copying agents into $AGENTS_DEST"
for agent in "$REPO"/agents/*.md; do
  [ -e "$agent" ] || continue
  name="$(basename "$agent")"
  dest="$AGENTS_DEST/$name"
  if [ -L "$dest" ]; then
    # Migrating from a previous symlink install.
    rm "$dest"; cp "$agent" "$dest"; echo "  ${name%.md} (was a symlink, now a copy)"
  elif [ ! -e "$dest" ]; then
    cp "$agent" "$dest"; echo "  ${name%.md}"
  elif cmp -s "$agent" "$dest"; then
    echo "  ${name%.md} (unchanged)"
  else
    echo "  ${name%.md} (kept your version; run /setup-lasso to reconfigure)"
  fi
done

HOOKS_DEST="$CLAUDE_HOME/hooks"
mkdir -p "$HOOKS_DEST"
echo "Linking hooks into $HOOKS_DEST"
for hook in "$REPO"/hooks/*.sh; do
  [ -e "$hook" ] || continue
  ln -sfn "$hook" "$HOOKS_DEST/$(basename "$hook")"
  echo "  $(basename "$hook")"
done

echo
echo "Done. In Claude Code: run /reload-plugins (or restart), then /help and /agents to confirm."
echo "MCP servers live in this repo's .mcp.json; set the env vars from the README to enable them."
