#!/usr/bin/env python3
"""Check every SKILL.md against the intersection of the Claude Code, Cursor and
VS Code Copilot skill schemas. Exits 1 on any hard failure."""
import re, sys, pathlib

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "skills"

# Fields each host documents. Unknown keys are ignored by all three, but we flag
# them so nobody assumes they do something on a host that never reads them.
CLAUDE = {"name","description","disable-model-invocation","allowed-tools","license","metadata"}
CURSOR = {"name","description","paths","disable-model-invocation","icon","color","metadata"}
COPILOT = {"name","description","argument-hint","user-invocable","disable-model-invocation","context"}

hard, soft = [], []

for skill in sorted(ROOT.rglob("SKILL.md")):
    folder = skill.parent.name
    text = skill.read_text()
    if not text.startswith("---\n"):
        hard.append((folder, "no frontmatter")); continue
    fm = text.split("---\n", 2)[1]
    keys = set(re.findall(r"^([a-zA-Z_-]+):", fm, re.M))
    name = re.search(r"^name:\s*(.+)$", fm, re.M)
    name = name.group(1).strip().strip('"\'') if name else ""
    desc = re.search(r"^description:\s*(.*?)(?=\n[a-zA-Z_-]+:|\Z)", fm, re.S | re.M)
    desc = re.sub(r"\s+", " ", desc.group(1)).strip().strip('">|-') if desc else ""

    if name != folder:            hard.append((folder, f"name '{name}' != folder"))
    if len(name) > 64:            hard.append((folder, f"name {len(name)} chars > Copilot's 64"))
    if not desc:                  hard.append((folder, "empty description"))
    if len(desc) > 1024:          hard.append((folder, f"description {len(desc)} chars > Copilot's 1024"))
    if not re.fullmatch(r"[a-z0-9-]+", name or "x"):
        hard.append((folder, f"name '{name}' not lowercase-hyphen"))

    for k in keys - (CLAUDE | CURSOR | COPILOT):
        soft.append((folder, f"'{k}' read by no host"))
    for host, allowed in (("Cursor", CURSOR), ("Copilot", COPILOT)):
        for k in keys - allowed - {"license","compatibility","metadata","allowed-tools"}:
            soft.append((folder, f"'{k}' ignored by {host}"))

    # Bundled resources: Copilot requires markdown-link syntax with a relative path.
    bare = re.findall(r"`((?:references|playbooks|scripts|assets)/[\w./-]+)`", text)
    linked = set(re.findall(r"\]\(\.?/?((?:references|playbooks|scripts|assets)/[\w./-]+)\)", text))
    for p in sorted(set(bare) - linked):
        target = skill.parent / p
        soft.append((folder, f"{p} referenced as bare path, not [link](./{p})"
                             + ("" if target.exists() else "  MISSING ON DISK")))

for f, m in hard: print(f"FAIL  {f:<40} {m}")
for f, m in soft: print(f"warn  {f:<40} {m}")
print(f"\n{len(list(ROOT.rglob('SKILL.md')))} skills checked: {len(hard)} failures, {len(soft)} warnings")
sys.exit(1 if hard else 0)
