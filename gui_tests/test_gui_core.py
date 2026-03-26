from __future__ import annotations

import os
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from gui.core.compat import get_default_gui_editor_command, slugify
from gui.core.models import GuiSettings, NoteRecord
from gui.core.repository import NoteRepository, extract_tags_from_first_line, parse_note_file
from gui.core.search import collect_tag_counts, filter_notes
from gui.core.services import ImportService, IntegrationError
from gui.core.settings import SettingsStore


class NotesGuiCoreTests(unittest.TestCase):
    def test_slugify_matches_cli_behavior(self) -> None:
        self.assertEqual(slugify("Café & Résumé!"), "caf-rsum")

    def test_parse_note_with_inline_tags_on_heading_line(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            note_path = Path(temp_dir) / "cooking.md"
            note_path.write_text("# Cooking Notes #Recipes #Dinner\n\nChicken and rice\n", encoding="utf-8")

            note = parse_note_file(note_path)

            self.assertEqual(note.title, "Cooking Notes")
            self.assertEqual(note.tags, ["recipes", "dinner"])
            self.assertEqual(note.body, "Chicken and rice")

    def test_parse_note_with_tag_line_before_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            note_path = Path(temp_dir) / "travel.md"
            note_path.write_text("#Travel #Ideas\n# Summer Trip\n\nSpain\n", encoding="utf-8")

            note = parse_note_file(note_path)

            self.assertEqual(note.title, "Summer Trip")
            self.assertEqual(note.tags, ["travel", "ideas"])
            self.assertEqual(note.body, "Spain")

    def test_repository_save_can_rename_note_when_title_changes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = NoteRepository(Path(temp_dir))
            draft = repository.create_draft("Initial Title")
            saved = repository.save_note(draft)

            renamed = NoteRecord(
                path=saved.path,
                slug=saved.slug,
                title="Renamed Title",
                tags=["Work"],
                body="Updated body",
            )
            renamed_saved = repository.save_note(renamed, previous_path=saved.path)

            self.assertFalse(saved.path.exists())
            self.assertTrue(renamed_saved.path.exists())
            self.assertEqual(renamed_saved.path.name, "renamed-title.md")
            self.assertEqual(renamed_saved.tags, ["work"])

    def test_filter_notes_supports_search_and_tags(self) -> None:
        notes = [
            NoteRecord(Path("alpha.md"), "alpha", "Alpha", ["Work"], "Budget review", 20),
            NoteRecord(Path("beta.md"), "beta", "Beta", ["Home"], "Groceries and chores", 10),
        ]

        filtered = filter_notes(notes, search_text="budget", selected_tag="Work")
        self.assertEqual([note.title for note in filtered], ["Alpha"])

    def test_collect_tag_counts_summarizes_sidebar_tags(self) -> None:
        notes = [
            NoteRecord(Path("a.md"), "a", "A", ["Work", "ideas"], "", 1),
            NoteRecord(Path("b.md"), "b", "B", ["work"], "", 1),
        ]

        self.assertEqual(collect_tag_counts(notes), [("ideas", 1), ("work", 2)])

    def test_settings_store_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            settings_path = Path(temp_dir) / "settings.json"
            store = SettingsStore(settings_path)
            store.save(GuiSettings(notes_dir_override=str(Path(temp_dir) / "notes"), sort_order="title", theme="light"))
            loaded = store.load()

            self.assertEqual(loaded.sort_order, "title")
            self.assertEqual(loaded.theme, "light")
            self.assertIn("notes", loaded.notes_dir_override or "")

    def test_import_service_uses_command_override(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "fake_import.py"
            backup_dir = Path(temp_dir) / "backup"
            backup_dir.mkdir()

            script_path.write_text(
                textwrap.dedent(
                    """
                    import sys
                    if len(sys.argv) >= 3 and sys.argv[1] == "import":
                        print(f"imported:{sys.argv[2]}")
                        raise SystemExit(0)
                    raise SystemExit(2)
                    """
                ),
                encoding="utf-8",
            )

            service = ImportService([sys.executable, str(script_path)])
            result = service.run_import(backup_dir)

            self.assertTrue(result.succeeded)
            self.assertIn("imported:", result.stdout)

    def test_gui_entry_module_imports(self) -> None:
        import gui.main  # noqa: F401

    def test_gui_smoke_mode_exits_without_starting_event_loop(self) -> None:
        import gui.main

        with mock.patch.object(sys, "argv", ["notes-gui", "--smoke-test"]):
            self.assertEqual(gui.main.main(), 0)

    def test_extract_tags_uses_first_line_rules(self) -> None:
        self.assertEqual(extract_tags_from_first_line("# Heading #Work #Ideas"), ["work", "ideas"])

    def test_normalize_tags_is_case_insensitive(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = NoteRepository(Path(temp_dir))
            saved = repository.save_note(
                NoteRecord(
                    path=Path(temp_dir) / "mixed.md",
                    slug="mixed",
                    title="Mixed Tags",
                    tags=["Work", "work", "WORK", "Ideas"],
                    body="Body",
                )
            )

            self.assertEqual(saved.tags, ["work", "ideas"])

    def test_import_service_wraps_missing_command_errors(self) -> None:
        service = ImportService(["command-that-does-not-exist-for-notes-tests"])

        with self.assertRaises(IntegrationError):
            service.run_import(Path.cwd())

    def test_gui_editor_default_is_graphical_on_windows(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch("gui.core.compat.os.name", "nt"):
                with mock.patch("gui.core.compat.sys.platform", "win32"):
                    self.assertEqual(get_default_gui_editor_command(), "notepad")

    def test_gui_editor_default_is_graphical_on_linux(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch("gui.core.compat.os.name", "posix"):
                with mock.patch("gui.core.compat.sys.platform", "linux"):
                    self.assertEqual(get_default_gui_editor_command(), "xdg-open")


if __name__ == "__main__":
    unittest.main(verbosity=2)
