from __future__ import annotations

import re
from pathlib import Path

from gui.core.compat import display_title_from_path, slugify
from gui.core.models import NoteRecord


TAG_PATTERN = re.compile(r"(?:^|\s)#([A-Za-z0-9_-]+)(?=\s|$)")


class RepositoryError(RuntimeError):
    """Raised when repository operations fail."""


def normalize_tags(tags: list[str]) -> list[str]:
    normalized: list[str] = []
    seen: set[str] = set()
    for tag in tags:
        clean = re.sub(r"[^A-Za-z0-9_-]", "", tag.strip().lstrip("#"))
        if not clean:
            continue
        key = clean.lower()
        if key in seen:
            continue
        seen.add(key)
        normalized.append(clean)
    return normalized


def extract_tags_from_first_line(line: str) -> list[str]:
    return normalize_tags(TAG_PATTERN.findall(line or ""))


def extract_title_from_heading_line(line: str) -> str | None:
    stripped = line.strip()
    if not stripped.startswith("# "):
        return None

    remainder = stripped[2:].strip()
    if not remainder:
        return ""

    title_parts: list[str] = []
    for token in remainder.split():
        if token.startswith("#") and len(token) > 1:
            break
        title_parts.append(token)

    title = " ".join(title_parts).strip()
    return title or remainder


def compose_note_text(title: str, tags: list[str], body: str) -> str:
    clean_title = title.strip() or "Untitled Note"
    clean_tags = normalize_tags(tags)
    heading = f"# {clean_title}"
    if clean_tags:
        heading = f"{heading} " + " ".join(f"#{tag}" for tag in clean_tags)

    normalized_body = body.replace("\r\n", "\n").rstrip("\n")
    if not normalized_body:
        return f"{heading}\n"
    return f"{heading}\n\n{normalized_body}\n"


def parse_note_file(path: Path) -> NoteRecord:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    first_line = lines[0] if lines else ""
    tags = extract_tags_from_first_line(first_line)

    title = display_title_from_path(path)
    body = text

    if lines and first_line.startswith("# "):
        title = extract_title_from_heading_line(first_line) or title
        body_start = 1
        if body_start < len(lines) and lines[body_start].strip() == "":
            body_start += 1
        body = "\n".join(lines[body_start:])
    elif tags and len(lines) > 1 and lines[1].startswith("# "):
        title = extract_title_from_heading_line(lines[1]) or title
        body_start = 2
        if body_start < len(lines) and lines[body_start].strip() == "":
            body_start += 1
        body = "\n".join(lines[body_start:])

    return NoteRecord(
        path=path,
        slug=path.stem,
        title=title,
        tags=tags,
        body=body,
        modified_at=path.stat().st_mtime,
    )


class NoteRepository:
    def __init__(self, notes_dir: Path):
        self.notes_dir = Path(notes_dir).expanduser()

    def ensure_notes_dir(self) -> Path:
        self.notes_dir.mkdir(parents=True, exist_ok=True)
        return self.notes_dir

    def list_notes(self) -> list[NoteRecord]:
        self.ensure_notes_dir()
        return [parse_note_file(path) for path in self.notes_dir.glob("*.md")]

    def load_note(self, path: Path) -> NoteRecord:
        return parse_note_file(path)

    def _build_unique_path(self, title: str, existing_path: Path | None = None) -> Path:
        base_slug = slugify(title) or "untitled-note"
        candidate = self.notes_dir / f"{base_slug}.md"
        suffix = 2

        while candidate.exists():
            if existing_path is not None and candidate.resolve() == existing_path.resolve():
                return candidate
            candidate = self.notes_dir / f"{base_slug}-{suffix}.md"
            suffix += 1

        return candidate

    def create_draft(self, title: str) -> NoteRecord:
        self.ensure_notes_dir()
        clean_title = title.strip() or "Untitled Note"
        path = self._build_unique_path(clean_title)
        return NoteRecord(path=path, slug=path.stem, title=clean_title, tags=[], body="")

    def save_note(self, note: NoteRecord, previous_path: Path | None = None) -> NoteRecord:
        self.ensure_notes_dir()
        clean_title = note.title.strip() or "Untitled Note"
        current_path = previous_path if previous_path and previous_path.exists() else None
        target_path = self._build_unique_path(clean_title, current_path)
        target_path.write_text(compose_note_text(clean_title, note.tags, note.body), encoding="utf-8")

        if current_path is not None and current_path.resolve() != target_path.resolve() and current_path.exists():
            current_path.unlink()

        return parse_note_file(target_path)

    def delete_note(self, path: Path) -> None:
        if not path.exists():
            raise RepositoryError(f"Note '{path.name}' does not exist.")
        path.unlink()
