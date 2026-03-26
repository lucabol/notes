from __future__ import annotations

import json
from pathlib import Path

from gui.core.compat import (
    get_default_gui_editor_command,
    get_default_notes_dir,
    get_default_pager_command,
    get_settings_path,
)
from gui.core.models import GuiSettings


class SettingsStore:
    def __init__(self, path: Path | None = None):
        self.path = path or get_settings_path()

    def load(self) -> GuiSettings:
        if not self.path.exists():
            return GuiSettings()

        data = json.loads(self.path.read_text(encoding="utf-8"))
        return GuiSettings(
            notes_dir_override=data.get("notes_dir_override"),
            sort_order=data.get("sort_order", "modified"),
        )

    def save(self, settings: GuiSettings) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "notes_dir_override": settings.notes_dir_override,
            "sort_order": settings.sort_order,
        }
        self.path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def resolve_notes_dir(settings: GuiSettings) -> Path:
    if settings.notes_dir_override:
        return Path(settings.notes_dir_override).expanduser()
    return get_default_notes_dir()


def get_runtime_details() -> dict[str, str]:
    return {
        "editor": get_default_gui_editor_command(),
        "pager": get_default_pager_command(),
    }
