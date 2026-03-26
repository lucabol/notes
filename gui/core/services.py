from __future__ import annotations

import subprocess
from pathlib import Path

from gui.core.compat import get_default_editor_command, quote_shell_arg, resolve_notes_command
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


def launch_external_editor(note_path: Path) -> None:
    editor = get_default_editor_command()
    command = f"{editor} {quote_shell_arg(str(note_path))}"
    try:
        subprocess.Popen(command, shell=True)
    except OSError as exc:
        raise IntegrationError(f"Failed to start editor '{editor}': {exc}") from exc
