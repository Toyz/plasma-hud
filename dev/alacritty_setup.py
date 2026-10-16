#!/usr/bin/env python3
"""Point an Alacritty config at the Helba World theme (idempotent).

    python3 dev/alacritty_setup.py ~/.config/alacritty/alacritty.toml

Removes inline [colors.*] tables (the theme file provides them; [colors] itself and
its other keys stay) and makes sure [general] import lists
~/.config/alacritty/helba-world.toml. Everything else is kept as written.
"""
import re
import sys
import tomllib

path = sys.argv[1]
THEME = "~/.config/alacritty/helba-world.toml"
text = open(path).read() if __import__("os").path.exists(path) else ""

# Drop [colors.<anything>] tables (header up to the next table header).
lines, out, skip = text.splitlines(keepends=True), [], False
for ln in lines:
    header = re.match(r"^\s*\[\[?([^\]]+)\]\]?\s*$", ln)
    if header:
        skip = header.group(1).strip().startswith("colors.")
    if not skip:
        out.append(ln)
text = "".join(out)

data = tomllib.loads(text) if text.strip() else {}
imports = data.get("general", {}).get("import", [])
if THEME not in imports:
    if "general" in data and "import" in data["general"]:
        # Append to the existing import list.
        text = re.sub(r"(\bimport\s*=\s*\[)", lambda m: m.group(1) + f'"{THEME}", ', text, count=1)
    elif re.search(r"^\s*\[general\]\s*$", text, re.M):
        text = re.sub(r"^(\s*\[general\]\s*\n)", lambda m: m.group(1) + f'import = ["{THEME}"]\n', text, count=1, flags=re.M)
    else:
        text = f'[general]\nimport = ["{THEME}"]\n\n' + text
tomllib.loads(text)   # still valid
open(path, "w").write(re.sub(r"\n{3,}", "\n\n", text))
print("alacritty: importing", THEME)
