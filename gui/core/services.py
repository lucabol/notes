from __future__ import annotations

import os
import shlex
import subprocess
from pathlib import Path

from gui.core.compat import get_default_gui_editor_command, resolve_notes_command
from gui.core.models import ImportResult


class IntegrationError(RuntimeError):
    """Raised when an external integration fails."""


class ImportService:
    def __init__(self, command: list[str] | None = None):
        self.command = command

    def run_import(self, backup_dir: Path) -> ImportResult:
        command = list(self.command or resolve_notes_command())
        try:
            completed = subprocess.run(
                [*command, "import", str(backup_dir)],
                capture_output=True,
                text=True,
            )
        except (OSError, RuntimeError) as exc:
            raise IntegrationError(f"Failed to run notes import: {exc}") from exc
        return ImportResult(
            command=command,
            return_code=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
        )


def _build_editor_command(note_path: Path, editor_command: str | None = None) -> list[str]:
    editor = get_default_gui_editor_command(editor_command).strip()
    if not editor:
        raise IntegrationError("No editor command is configured.")

    try:
        parts = shlex.split(editor, posix=os.name != "nt")
    except ValueError as exc:
        raise IntegrationError(f"Failed to parse editor '{editor}': {exc}") from exc

    if os.name == "nt":
        parts = [
            part[1:-1] if len(part) >= 2 and part.startswith('"') and part.endswith('"') else part
            for part in parts
        ]

    if not parts:
        raise IntegrationError("No editor command is configured.")

    return [*parts, str(note_path)]


def launch_external_editor(note_path: Path, editor_command: str | None = None) -> None:
    try:
        subprocess.Popen(_build_editor_command(note_path, editor_command))
    except OSError as exc:
        editor = get_default_gui_editor_command(editor_command)
        raise IntegrationError(f"Failed to start editor '{editor}': {exc}") from exc
