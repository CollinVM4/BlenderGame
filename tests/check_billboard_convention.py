"""Reject direct BillboardGui.Size writes outside the shared style implementation.

Conservative source lint: tracks constructor names, typed parameters and cast
aliases within each file. Forbidding every direct write also catches pixel sizes
hidden behind constants/conditional expressions. Child GuiObject offsets are OK.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
IMPLEMENTATION = Path("src/shared/WorldBillboardStyle.luau")


def violations(source: str) -> list[int]:
    # Ignore comments so examples cannot mask or create a violation.
    source = re.sub(r"--\[\[.*?\]\]", "", source, flags=re.S)
    source = re.sub(r"--[^\n]*", "", source)
    names = set(re.findall(r'\b(\w+)\s*=\s*Instance\.new\(["\']BillboardGui["\']\)', source))
    names.update(re.findall(r"\b(\w+)\s*:\s*BillboardGui\b", source))
    # Include aliases, including `local billboard = gui :: BillboardGui`.
    while True:
        previous = names.copy()
        for alias, target in re.findall(r"\blocal\s+(\w+)\s*=\s*(\w+)\b(?=[ \t]*(?:::|$))", source, re.M):
            if target in names:
                names.add(alias)
        if previous == names:
            break
    found = set()
    for name in names:
        assignment = rf"\b{re.escape(name)}\.Size\s*(?:,\s*[\w.,\s]+)?[+*/-]?=(?!=)"
        for match in re.finditer(assignment, source):
            found.add(source.count("\n", 0, match.start()) + 1)
    return sorted(found)


def check(root: Path = ROOT) -> list[str]:
    errors = []
    for path in (root / "src").rglob("*.luau"):
        relative = path.relative_to(root)
        if relative == IMPLEMENTATION:
            continue
        for line in violations(path.read_text(encoding="utf-8")):
            errors.append(f"{relative}:{line}: use WorldBillboardStyle.ApplyBillboard; no direct BillboardGui.Size writes")
    return errors


if __name__ == "__main__":
    errors = check()
    print("\n".join(errors) if errors else "PASS: all world billboard sizes use the shared convention")
    raise SystemExit(bool(errors))
