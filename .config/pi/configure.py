"""Merge tracked pi preferences without replacing local state or credentials."""
import json
import os
from pathlib import Path
import tempfile
import subprocess

source = Path(__file__).with_name("settings.json")
agent = Path(os.environ.get("PI_CODING_AGENT_DIR", "~/.pi/agent")).expanduser()
agent.mkdir(parents=True, exist_ok=True)
target = agent / "settings.json"
settings = json.loads(target.read_text()) if target.exists() else {}
settings.update(json.loads(source.read_text()))
for package in settings.get("packages", []):
    subprocess.run(["pi", "install", package], check=True)
with tempfile.NamedTemporaryFile(mode="w", dir=agent, delete=False) as file:
    json.dump(settings, file, indent=2)
    file.write("\n")
    temporary = Path(file.name)
temporary.replace(target)
print(f"Configured {target}")
