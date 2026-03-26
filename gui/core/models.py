from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class NoteRecord:
    path: Path
    slug: str
    title: str
    tags: list[str]
    body: str
    modified_at: float = 0.0


@dataclass(slots=True)
class GuiSettings:
    notes_dir_override: str | None = None
    sort_order: str = "modified"


@dataclass(slots=True)
class ImportResult:
    command: list[str]
    return_code: int
    stdout: str
    stderr: str

    @property
    def succeeded(self) -> bool:
        return self.return_code == 0
