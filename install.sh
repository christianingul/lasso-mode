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

echo "Linking agents into $AGENTS_DEST"
for agent in "$REPO"/agents/*.md; do
  [ -e "$agent" ] || continue
  ln -sfn "$agent" "$AGENTS_DEST/$(basename "$agent")"
  echo "  $(basename "${agent%.md}")"
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
