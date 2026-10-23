#!/usr/bin/env python3
"""Check that lasso is installed and configured the way /setup-lasso leaves it.

Run before /setup-lasso to see what is missing, and after to confirm it landed.
Checks the live installed state, not the repo, because that is what the harness
actually loads. Exits non-zero if any check fails.
"""
import json, os, pathlib, re, sys

REPO = pathlib.Path(__file__).resolve().parent.parent
HOME = pathlib.Path(os.environ.get("CLAUDE_HOME", pathlib.Path.home() / ".claude"))
GATED = ["architect", "arena", "interrogate", "reflect", "figure-it-out", "recall"]
TYPED = {"lasso-mode", "setup-lasso", "setup-lasso-verify", "automate-me"}
JUDGMENT = ["lasso-judge", "lasso-reviewer-a", "lasso-reviewer-b", "lasso-reviewer-c"]
EFFORTS = {"low", "medium", "high", "xhigh"}
VALID = {"opus", "sonnet", "haiku", "fable", "inherit"}

results = []
warnings = []
def warn(name, detail=""):
    """Something worth knowing that is not a failure. Arming a hook is
    per-project and deliberate, so an unarmed project is a note, not a break."""
    warnings.append((name, detail))

def check(name, ok, detail=""):
    # A detail line explains a failure. Printing it on a pass reads as a
    # contradiction ("PASS ... has not run").
    results.append((ok, name, "" if ok else detail))

# 1. Installed skills point at this checkout, not a stale one.
sk = HOME / "skills" / "lasso-mode"
if not sk.exists():
    check("skills installed", False, f"{sk} missing — run ./install.sh")
else:
    target = sk.resolve()
    ok = REPO in target.parents
    check("skills point at this repo", ok,
          "" if ok else f"resolves to {target}, not {REPO} — run ./install.sh")

# 2. Every agent file installed, each pinning a model.
missing, unpinned = [], []
for f in sorted((REPO / "agents").glob("*.md")):
    inst = HOME / "agents" / f.name
    if not inst.exists():
        missing.append(f.name); continue
    m = re.search(r"^model:\s*(.+)$", inst.read_text(), re.M)
    if not m:
        unpinned.append(f.name)
    elif m.group(1).strip() not in VALID and not m.group(1).strip().startswith("claude-"):
        unpinned.append(f"{f.name} (model={m.group(1).strip()!r}, not a Claude Code tier)")
check("agent files installed", not missing, f"missing: {', '.join(missing)}")
check("every agent pins a model", not unpinned, f"unpinned: {', '.join(unpinned)}")

# Agents are copies, so personal config stays out of the repo and survives a
# git checkout. A symlink here means an old install.
linked = [f.name for f in sorted((HOME / "agents").glob("lasso-*.md")) if f.is_symlink()]
check("agents are copies, not symlinks", not linked,
      f"symlinked: {', '.join(linked)} — re-run ./install.sh")

# Effort is per-role in the agent file. modelSettings would force one value on
# every role sharing a model.
no_effort, weak = [], []
for f in sorted((HOME / "agents").glob("lasso-*.md")):
    m = re.search(r"^effort:\s*(\S+)", f.read_text(), re.M)
    if not m or m.group(1) not in EFFORTS:
        no_effort.append(f.stem)
    elif f.stem in JUDGMENT and m.group(1) != "xhigh":
        weak.append(f"{f.stem}={m.group(1)}")
check("every agent sets an effort", not no_effort, f"missing effort: {', '.join(no_effort)}")
check("judgment roles run at xhigh", not weak, f"below xhigh: {', '.join(weak)}")

# 2b. The hooks. lasso-guard blocks destructive commands before they run;
# lasso-verify re-runs the project's checks when a turn ends. Installed means
# the file is reachable; armed means a settings.json actually registers it.
for hook, kind, where in (("lasso-guard", "PreToolUse", "blocks destructive commands"),
                          ("lasso-verify", "Stop", "re-runs the project's checks")):
    script = HOME / "hooks" / f"{hook}.sh"
    check(f"{hook} installed", script.exists(),
          f"{script} missing — run ./install.sh")
    armed = False
    for s in (pathlib.Path(".claude/settings.json"), HOME / "settings.json"):
        if not s.exists():
            continue
        try:
            blob = json.dumps(json.loads(s.read_text()).get("hooks", {}).get(kind, []))
        except json.JSONDecodeError:
            continue
        if hook in blob:
            armed = True; break
    # Arming is per-project and deliberate, so a missing one is a warning, not
    # a failure: plenty of projects legitimately run without it.
    if not armed:
        warn(f"{hook} not armed here",
             f"no {kind} hook registered — run {script} install")

# 3. Skill flags: only the four typed ones stay blocked.
flagged = sorted(p.parent.name for p in (REPO / "skills").glob("*/SKILL.md")
                 if "disable-model-invocation" in p.read_text())
check("only the config skills are model-blocked", set(flagged) == TYPED,
      f"flagged: {flagged}")

# 4. settings.json — effort and the permission gate.
settings_path = HOME / "settings.json"
if not settings_path.exists():
    check("settings.json exists", False, f"{settings_path} missing")
else:
    try:
        s = json.loads(settings_path.read_text())
    except json.JSONDecodeError as e:
        s = None; check("settings.json parses", False, str(e))
    if s is not None:
        check("settings.json parses", True)
        ask = s.get("permissions", {}).get("ask", [])
        want = {f"Skill({g})" for g in GATED}
        have = want & set(ask)
        check("fan-out skills are gated", have == want,
              f"missing: {sorted(want - have)}" if have != want else "")

width = max(len(n) for _, n, _ in results)
for ok, name, detail in results:
    print(f"  {'PASS' if ok else 'FAIL'}  {name:<{width}}  {detail}")
for name, detail in warnings:
    print(f"  warn  {name:<{width}}  {detail}")
failed = sum(1 for ok, _, _ in results if not ok)
print(f"\n{len(results)} checks, {failed} failed, {len(warnings)} warnings")
if failed:
    print("Fix: ./install.sh from this repo, reload, then /setup-lasso")
sys.exit(1 if failed else 0)
