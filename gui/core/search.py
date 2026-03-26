from __future__ import annotations

from gui.core.models import NoteRecord


def filter_notes(
    notes: list[NoteRecord],
    search_text: str = "",
    selected_tag: str | None = None,
    sort_order: str = "modified",
) -> list[NoteRecord]:
    normalized_text = search_text.strip().lower()
    normalized_tag = selected_tag.strip().lower() if selected_tag else None

    filtered: list[NoteRecord] = []
    for note in notes:
        if normalized_tag and normalized_tag not in {tag.lower() for tag in note.tags}:
            continue

        if normalized_text:
            haystack = f"{note.title}\n{note.body}".lower()
            if normalized_text not in haystack:
                continue

        filtered.append(note)

    if sort_order == "title":
        return sorted(filtered, key=lambda note: (note.title.lower(), -note.modified_at))

    return sorted(filtered, key=lambda note: (-note.modified_at, note.title.lower()))


def collect_tag_counts(notes: list[NoteRecord]) -> list[tuple[str, int]]:
    counts: dict[str, int] = {}
    for note in notes:
        for tag in note.tags:
            counts[tag] = counts.get(tag, 0) + 1
    return sorted(counts.items(), key=lambda item: item[0].lower())
