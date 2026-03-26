from __future__ import annotations

import os
import re
import shlex
import shutil
import sys
from pathlib import Path


def get_default_notes_dir() -> Path:
    configured = os.environ.get("NOTES_DIR")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / "notes"


def get_default_editor_command() -> str:
    return os.environ.get("EDITOR") or os.environ.get("VISUAL") or ("notepad" if os.name == "nt" else "vi")


def get_default_gui_editor_command(configured: str | None = None) -> str:
    if configured:
        return configured.strip()

    configured = os.environ.get("NOTES_GUI_EDITOR")
    if configured:
        return configured.strip()

    if os.name == "nt":
        return "notepad"

    if sys.platform == "darwin":
        return "open"

    return "xdg-open"


def get_default_pager_command() -> str:
    return os.environ.get("PAGER") or ("more.com" if os.name == "nt" else "less")


def slugify(title: str) -> str:
    slug = title.lower().strip()
    slug = re.sub(r"\s+", "-", slug)
    slug = re.sub(r"[^a-z0-9-]", "", slug)
    slug = re.sub(r"-+", "-", slug)
    return slug.strip("-")


def display_title_from_path(path: Path) -> str:
    display = path.stem.replace("-", " ").strip()
    return display.title() if display else path.stem


def get_settings_path() -> Path:
    if os.name == "nt":
        base = Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming"))
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "notes-gui" / "settings.json"


def quote_shell_arg(value: str) -> str:
    if os.name == "nt":
        return '"' + value.replace('"', '""') + '"'
    return shlex.quote(value)


def find_pwsh() -> str:
    for candidate in ("pwsh", "pwsh.exe"):
        if shutil.which(candidate):
            return candidate
    raise RuntimeError("PowerShell 7 (pwsh) is required to run notes import.")


def resolve_repo_root() -> Path | None:
    for parent in Path(__file__).resolve().parents:
        if (parent / "notes.ps1").exists():
            return parent
    return None


def resolve_notes_command() -> list[str]:
    repo_root = resolve_repo_root()
    if repo_root is not None:
        return [find_pwsh(), "-NoProfile", "-File", str(repo_root / "notes.ps1")]

    installed = shutil.which("notes")
    if installed:
        return [installed]

    raise RuntimeError("Could not find the notes CLI. Install it or run notes-gui from the repository.")
