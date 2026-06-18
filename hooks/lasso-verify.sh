#!/usr/bin/env bash
# lasso-verify: deterministic trust-but-verify for lasso-mode.
#
# One lever, three modes:
#   (stdin JSON, no args)  Stop-hook mode. Claude Code invokes this when the
#                          agent finishes a turn. Verifies the diff and blocks
#                          the stop if a check is red.
#   install [DIR]          Arm a project: merge the Stop hook into its
#                          .claude/settings.json, write a starter config, and
#                          gitignore the state dir. Idempotent.
#   check [DIR]            Run the same checks once and print the result. The
#                          rerunnable artifact a reviewer trusts instead of you.
set -uo pipefail

MAX_ROUNDS_DEFAULT=3
CHECK_TIMEOUT_DEFAULT=300

# ---- JSON helpers. Prefer jq, then python3. Block via exit 2 if neither. ----
have() { command -v "$1" >/dev/null 2>&1; }

emit_block() { # $1 reason, $2 short system message
  local reason="$1" sm="$2"
  if have jq; then
    jq -n --arg r "$reason" --arg s "$sm" \
      '{decision:"block", reason:$r, systemMessage:$s}'
    exit 0
  elif have python3; then
    REASON="$reason" SM="$sm" python3 - <<'PY'
import json, os
print(json.dumps({"decision":"block","reason":os.environ["REASON"],
                  "systemMessage":os.environ["SM"]}))
PY
    exit 0
  else
    printf '%s\n' "$reason" >&2
    exit 2
  fi
}

emit_note() { # $1 short system message, non-blocking
  local sm="$1"
  if have jq; then
    jq -n --arg s "$sm" '{systemMessage:$s, suppressOutput:true}'
  elif have python3; then
    SM="$sm" python3 - <<'PY'
import json, os
print(json.dumps({"systemMessage":os.environ["SM"],"suppressOutput":True}))
PY
  fi
  exit 0
}

# Read .scripts from a package.json. Args: file, key. Echoes "true" if present.
pkg_has_script() {
  local file="$1" key="$2"
  if have python3; then
    FILE="$file" KEY="$key" python3 - <<'PY' 2>/dev/null
import json, os
try:
    d = json.load(open(os.environ["FILE"]))
    print("true" if os.environ["KEY"] in (d.get("scripts") or {}) else "")
except Exception:
    print("")
PY
  elif have jq; then
    jq -er --arg k "$key" '.scripts[$k] // empty | "true"' "$file" 2>/dev/null
  fi
}

# ---- Detection. Echoes "name<TAB>command" lines, cheap checks first. --------
detect_checks() {
  local dir="$1" conf="$1/.claude/lasso-verify.conf"

  # An explicit config is authoritative. Lines: name=command. Blank command skips.
  if [ -f "$conf" ]; then
    while IFS= read -r line; do
      line="${line%%#*}"
      [ -z "${line// }" ] && continue
      local name="${line%%=*}" cmd="${line#*=}"
      name="$(printf '%s' "$name" | tr -d '[:space:]')"
      cmd="${cmd# }"
      [ -z "$name" ] && continue
      [ -z "${cmd// }" ] && continue
      printf '%s\t%s\n' "$name" "$cmd"
    done <"$conf"
    return
  fi

  # Node / TypeScript.
  if [ -f "$dir/package.json" ]; then
    local pm="npm run"
    [ -f "$dir/pnpm-lock.yaml" ] && pm="pnpm run"
    [ -f "$dir/yarn.lock" ] && pm="yarn"
    [ -f "$dir/bun.lockb" ] && pm="bun run"
    local s
    for s in typecheck type-check tsc lint build; do
      if [ -n "$(pkg_has_script "$dir/package.json" "$s")" ]; then
        printf '%s\t%s %s\n' "$s" "$pm" "$s"
      fi
    done
    if [ -n "$(pkg_has_script "$dir/package.json" test)" ]; then
      # npm needs "test" without "run"; others take it either way.
      [ "$pm" = "npm run" ] && printf 'test\tnpm test\n' || printf 'test\t%s test\n' "$pm"
    fi
  fi

  # Python.
  if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.cfg" ] || [ -f "$dir/setup.py" ]; then
    have ruff && printf 'ruff\truff check .\n'
    have mypy && printf 'mypy\tmypy .\n'
    have pytest && printf 'pytest\tpytest -q\n'
  fi

  # Rust.
  if [ -f "$dir/Cargo.toml" ] && have cargo; then
    printf 'cargo-check\tcargo check\n'
    printf 'cargo-test\tcargo test\n'
  fi

  # Go.
  if [ -f "$dir/go.mod" ] && have go; then
    printf 'go-vet\tgo vet ./...\n'
    printf 'go-test\tgo test ./...\n'
  fi
}

# ---- Diff fingerprint. Empty output means nothing to verify. ----------------
diff_fingerprint() {
  local dir="$1"
  git -C "$dir" diff HEAD 2>/dev/null
  local f
  while IFS= read -r f; do
    [ -f "$dir/$f" ] && { printf '>>%s\n' "$f"; cat "$dir/$f" 2>/dev/null; }
  done < <(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null)
}

hash_of() { if have sha1sum; then sha1sum | cut -d' ' -f1; else shasum | cut -d' ' -f1; fi; }

run_checks() { # $1 dir. Sets RESULTS (failing report) and FAILED count.
  local dir="$1" name cmd out rc to="${LASSO_CHECK_TIMEOUT:-$CHECK_TIMEOUT_DEFAULT}"
  RESULTS=""
  PASSED=""
  FAILED=0
  while IFS=$'\t' read -r name cmd; do
    [ -z "$name" ] && continue
    if have timeout; then
      out="$(cd "$dir" && timeout "$to" bash -lc "$cmd" 2>&1)"; rc=$?
    else
      out="$(cd "$dir" && bash -lc "$cmd" 2>&1)"; rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
      PASSED="$PASSED $name"
    else
      FAILED=$((FAILED+1))
      local tail; tail="$(printf '%s\n' "$out" | tail -n 40)"
      RESULTS="$RESULTS
--- $name FAILED (exit $rc): $cmd ---
$tail
"
    fi
  done < <(detect_checks "$dir")
}

# ============================ install mode ==================================
do_install() {
  local dir="${1:-$PWD}"
  dir="$(cd "$dir" && pwd)"
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  # Detect before touching any file. Opening the conf for write would make
  # detect_checks read it back empty and treat that as authoritative.
  local detected; detected="$(detect_checks "$dir")"
  mkdir -p "$dir/.claude"
  local settings="$dir/.claude/settings.json"

  if ! have jq; then
    echo "jq is required to merge settings.json safely. Install jq and re-run." >&2
    exit 1
  fi
  [ -f "$settings" ] || echo '{}' >"$settings"

  local block
  block="$(jq -n --arg cmd "$self" '{matcher:"*",hooks:[{type:"command",command:$cmd,timeout:600}]}')"

  # Replace any prior lasso-verify Stop entry, keep everything else intact.
  local tmp; tmp="$(mktemp)"
  jq --argjson b "$block" --arg cmd "$self" '
    .hooks = (.hooks // {})
    | .hooks.Stop = ((.hooks.Stop // [])
        | map(select((.hooks // []) | all(.command != $cmd)))
        + [$b])
  ' "$settings" >"$tmp" && mv "$tmp" "$settings"

  # Starter config from current detection, commented so the user can tune it.
  local conf="$dir/.claude/lasso-verify.conf"
  if [ ! -f "$conf" ]; then
    {
      echo "# lasso-verify checks. One per line: name=command. Blank command skips."
      echo "# Delete this file to fall back to auto-detection. Edit freely."
      printf '%s\n' "$detected" | while IFS=$'\t' read -r n c; do
        [ -n "$n" ] && echo "$n=$c"
      done
    } >"$conf"
  fi

  # Keep loop state out of git.
  local gi="$dir/.gitignore"
  if ! { [ -f "$gi" ] && grep -qF ".claude/.lasso-verify/" "$gi"; }; then
    printf '.claude/.lasso-verify/\n' >>"$gi"
  fi

  echo "Armed lasso-verify on $dir"
  echo "  hook:   $settings (Stop)"
  echo "  config: $conf"
  echo "  checks: $(printf '%s\n' "$detected" | cut -f1 | paste -sd' ' -)"
  echo "Reload the session (/reload-plugins or restart) so the hook loads."
}

# ============================ check mode ====================================
do_check() {
  local dir="${1:-$PWD}"
  dir="$(cd "$dir" && pwd)"
  run_checks "$dir"
  if [ "$FAILED" -eq 0 ]; then
    echo "lasso-verify: green ($(echo "${PASSED:-none}" | xargs))"
    exit 0
  fi
  echo "lasso-verify: $FAILED check(s) failed"
  printf '%s\n' "$RESULTS"
  exit 1
}

# ============================ hook mode =====================================
do_hook() {
  local stdin; stdin="$(cat)"
  # Defensive loop guard if the harness ever sends stop_hook_active.
  if have jq && [ "$(printf '%s' "$stdin" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
    exit 0
  fi

  local dir="${CLAUDE_PROJECT_DIR:-}"
  if [ -z "$dir" ] && have jq; then dir="$(printf '%s' "$stdin" | jq -r '.cwd // empty')"; fi
  [ -z "$dir" ] && dir="$PWD"

  # No git, no scoping. Don't verify what we can't bound.
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0

  local fp; fp="$(diff_fingerprint "$dir")"
  local statedir="$dir/.claude/.lasso-verify" statefile
  statefile="$dir/.claude/.lasso-verify/state"

  # Nothing changed this turn. Nothing to prove. Clear any stale state.
  if [ -z "${fp// }" ]; then rm -f "$statefile" 2>/dev/null; exit 0; fi

  local cur; cur="$(printf '%s' "$fp" | hash_of)"

  run_checks "$dir"
  if [ "$FAILED" -eq 0 ]; then
    rm -f "$statefile" 2>/dev/null
    emit_note "lasso-verify ✓ green:$(echo "${PASSED:- (no checks detected)}")"
  fi

  local prev_hash="" prev_count=0 max="${LASSO_MAX_ROUNDS:-$MAX_ROUNDS_DEFAULT}"
  if [ -f "$statefile" ]; then read -r prev_hash prev_count <"$statefile" 2>/dev/null; fi
  [ -z "$prev_count" ] && prev_count=0

  # Agent returned without touching the diff, or we have looped enough. Let it stop.
  if [ "$prev_hash" = "$cur" ] || [ "$((prev_count+1))" -gt "$max" ]; then
    rm -f "$statefile" 2>/dev/null
    emit_note "lasso-verify: $FAILED check(s) still failing after $prev_count round(s). Stopping; verify manually."
  fi

  mkdir -p "$statedir"
  printf '%s %s\n' "$cur" "$((prev_count+1))" >"$statefile"

  emit_block \
"lasso-verify blocked the stop. ${FAILED} check(s) are red on your diff. Fix the root cause, not the symptom (principle-fix-root-causes), then finish.
${RESULTS}
Re-run any one with: lasso-verify check" \
"lasso-verify: ${FAILED} red, blocking stop"
}

# Skip dispatch when sourced (lets tests call the functions directly).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    install) shift; do_install "${1:-$PWD}" ;;
    check)   shift; do_check "${1:-$PWD}" ;;
    *)       do_hook ;;
  esac
fi
