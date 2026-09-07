#!/usr/bin/env bash
# lasso-guard: block catastrophic shell commands before an agent runs them.
#
# Adapted from David Ondrej's deny-dangerous.sh (MIT). See NOTICE.
#
# Modes (same file is the hook, the installer, and a manual check):
#   (stdin JSON, no args)   PreToolUse mode for Claude Code and Codex.
#                           Block = exit 2 with a reason on stderr.
#   cursor                  Cursor beforeShellExecution mode.
#                           Block = {"permission":"deny"} on stdout, exit 0.
#   install [DIR]           Merge the PreToolUse hook into DIR/.claude/settings.json
#                           (default: the current directory).
#   check '<command>'       Run one command string through the denylist and say
#                           whether it would be blocked. For a reviewer.
#   test                    Run the bundled test suite.
#
# Fails open. No jq, no patterns file, or an unreadable payload means allow:
# a broken guard must not brick every agent on the machine.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Resolve symlinks. install.sh links this into ~/.claude/hooks, and the denylist
# sits next to the real file in the repo, not next to the link. Reading relative
# to the link means no patterns file, which means the guard fails open and
# silently blocks nothing.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in
    /*) SELF="$link" ;;
    *)  SELF="$(cd "$(dirname "$SELF")" && pwd)/$link" ;;
  esac
done
SELF="$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")"
PATTERNS="${LASSO_GUARD_PATTERNS:-$(dirname "$SELF")/dangerous-patterns.txt}"

# A missing denylist is a broken install, not a reason to run unguarded. Say so
# once on stderr; the hook still allows, because a guard that blocks everything
# when misinstalled is worse than one that blocks nothing.
[ -f "$PATTERNS" ] || echo "lasso-guard: no denylist at $PATTERNS — running unguarded. Re-run ./install.sh" >&2

# --- matching -------------------------------------------------------------

# Echoes the matched pattern and returns 0 when the command is dangerous.
match_pattern() {
  local cmd="$1" pattern
  [ -f "$PATTERNS" ] || return 1
  while IFS= read -r pattern; do
    case "$pattern" in ''|\#*) continue ;; esac
    if printf '%s\n' "$cmd" | grep -qE -- "$pattern" 2>/dev/null; then
      printf '%s' "$pattern"; return 0
    fi
  done < "$PATTERNS"
  return 1
}

REASON_SUFFIX="Do not retry it and do not work around the guard. Explain the block to the user instead. If the command is genuinely safe, the denylist line is wrong: say which line and let the user decide."

# --- hook modes -----------------------------------------------------------

run_hook() {
  local mode="$1" input cmd pattern
  command -v jq >/dev/null 2>&1 || { [ "$mode" = cursor ] && printf '{"permission":"allow"}\n'; exit 0; }
  input="$(cat)"
  # .tool_input = Claude Code and Codex, .toolInput = Grok CLI, .command = Cursor
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // .toolInput.command // .command // empty' 2>/dev/null)"
  if [ -z "$cmd" ] || ! pattern="$(match_pattern "$cmd")"; then
    [ "$mode" = cursor ] && printf '{"permission":"allow"}\n'
    exit 0
  fi
  if [ "$mode" = cursor ]; then
    jq -cn --arg p "$pattern" --arg s "$REASON_SUFFIX" '{
      permission: "deny",
      user_message: "lasso-guard blocked a dangerous command.",
      agent_message: ("Blocked by lasso-guard. Matched denylist pattern: " + $p + ". " + $s)
    }'
    exit 0
  fi
  echo "Blocked by lasso-guard (hooks/dangerous-patterns.txt). Matched pattern: $pattern. $REASON_SUFFIX" >&2
  exit 2
}

# --- install --------------------------------------------------------------

do_install() {
  local dir="${1:-$PWD}" settings="$dir/.claude/settings.json"
  command -v jq >/dev/null 2>&1 || { echo "jq is required to install the hook." >&2; exit 1; }
  mkdir -p "$dir/.claude"
  [ -f "$settings" ] || echo '{}' > "$settings"
  local tmp; tmp="$(mktemp)"
  # Replace any prior lasso-guard entry, keep every other hook intact.
  jq --arg cmd "$SELF" '
    .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(select((.hooks // []) | map(.command // "") | any(test("lasso-guard")) | not))
      + [{matcher: "Bash", hooks: [{type: "command", command: $cmd}]}])
  ' "$settings" > "$tmp" && mv "$tmp" "$settings"
  echo "Armed lasso-guard in $settings (PreToolUse, matcher Bash)."
  echo "Reload with /reload-plugins or restart. Verify with: $SELF test"
}

# --- manual check and tests ----------------------------------------------

do_check() {
  local cmd="${1:-}" pattern
  [ -n "$cmd" ] || { echo "usage: $(basename "$SELF") check '<command>'" >&2; exit 64; }
  if pattern="$(match_pattern "$cmd")"; then
    echo "BLOCKED  $cmd"; echo "         matched: $pattern"; exit 1
  fi
  echo "allowed  $cmd"; exit 0
}

case "${1:-}" in
  install) shift; do_install "${1:-}" ;;
  check)   shift; do_check "${1:-}" ;;
  test)    exec "$(dirname "$SELF")/test-guard.sh" ;;
  cursor)  run_hook cursor ;;
  "")      run_hook exitcode ;;
  *)       echo "unknown mode: $1" >&2; exit 64 ;;
esac
