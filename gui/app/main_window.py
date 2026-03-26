from __future__ import annotations

import re
from pathlib import Path

from PySide6.QtCore import QSignalBlocker, Qt
from PySide6.QtWidgets import (
    QFileDialog,
    QFormLayout,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QApplication,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QSplitter,
    QStatusBar,
    QToolBar,
    QVBoxLayout,
    QWidget,
)

from gui.app.theme import build_stylesheet
from gui.core.models import GuiSettings, NoteRecord
from gui.core.repository import NoteRepository, RepositoryError
from gui.core.search import collect_tag_counts, filter_notes
from gui.core.services import ImportService, IntegrationError, launch_external_editor
from gui.core.settings import SettingsStore, get_runtime_details, resolve_notes_dir


class SettingsDialog(QDialog):
    def __init__(self, settings: GuiSettings, parent: QWidget | None = None):
        super().__init__(parent)
        self.setWindowTitle("notes-gui settings")

        self.notes_dir_edit = QLineEdit(settings.notes_dir_override or "")
        self.sort_order_combo = QComboBox()
        self.sort_order_combo.addItem("Last modified", "modified")
        self.sort_order_combo.addItem("Title", "title")
        self.sort_order_combo.setCurrentIndex(0 if settings.sort_order == "modified" else 1)
        self.theme_combo = QComboBox()
        self.theme_combo.addItem("Dark", "dark")
        self.theme_combo.addItem("Light", "light")
        self.theme_combo.setCurrentIndex(0 if settings.theme == "dark" else 1)

        runtime_details = get_runtime_details()
        self.editor_label = QLabel(runtime_details["editor"])
        self.pager_label = QLabel(runtime_details["pager"])

        browse_button = QPushButton("Browse…")
        browse_button.clicked.connect(self._choose_notes_dir)

        notes_dir_row = QHBoxLayout()
        notes_dir_row.addWidget(self.notes_dir_edit)
        notes_dir_row.addWidget(browse_button)

        form = QFormLayout()
        form.addRow("Notes directory", self._wrap_layout(notes_dir_row))
        form.addRow("Default sort", self.sort_order_combo)
        form.addRow("Theme", self.theme_combo)
        form.addRow("Detected editor", self.editor_label)
        form.addRow("Detected pager", self.pager_label)

        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)

        layout = QVBoxLayout()
        layout.addLayout(form)
        layout.addWidget(buttons)
        self.setLayout(layout)

    def _wrap_layout(self, layout: QHBoxLayout) -> QWidget:
        wrapper = QWidget()
        wrapper.setLayout(layout)
        return wrapper

    def _choose_notes_dir(self) -> None:
        selected = QFileDialog.getExistingDirectory(self, "Choose notes directory", self.notes_dir_edit.text())
        if selected:
            self.notes_dir_edit.setText(selected)

    def to_settings(self) -> GuiSettings:
        notes_dir_override = self.notes_dir_edit.text().strip() or None
        return GuiSettings(
            notes_dir_override=notes_dir_override,
            sort_order=self.sort_order_combo.currentData(),
            theme=self.theme_combo.currentData(),
        )


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("notes-gui")

        self.settings_store = SettingsStore()
        self.settings = self.settings_store.load()
        self.repository = NoteRepository(resolve_notes_dir(self.settings))
        self.import_service = ImportService()

        self.all_notes: list[NoteRecord] = []
        self.current_note_path: Path | None = None
        self.saved_note_path: Path | None = None
        self.loading_note = False
        self.is_dirty = False

        self._build_ui()
        self.apply_theme()
        self.refresh_notes()

    def _build_ui(self) -> None:
        toolbar = QToolBar("Main")
        toolbar.setMovable(False)
        self.addToolBar(toolbar)

        new_action = toolbar.addAction("New")
        new_action.triggered.connect(self.create_note)
        save_action = toolbar.addAction("Save")
        save_action.triggered.connect(self.save_current_note)
        delete_action = toolbar.addAction("Delete")
        delete_action.triggered.connect(self.delete_current_note)
        refresh_action = toolbar.addAction("Refresh")
        refresh_action.triggered.connect(self.refresh_notes)
        import_action = toolbar.addAction("Import")
        import_action.triggered.connect(self.import_notes)
        edit_action = toolbar.addAction("Open external editor")
        edit_action.triggered.connect(self.open_external_editor)
        settings_action = toolbar.addAction("Settings")
        settings_action.triggered.connect(self.show_settings_dialog)

        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("Search notes")
        self.search_box.textChanged.connect(self.apply_filters)

        self.tag_list = QListWidget()
        self.tag_list.currentItemChanged.connect(lambda *_: self.apply_filters())

        self.note_list = QListWidget()
        self.note_list.currentItemChanged.connect(self.on_note_selected)

        left_layout = QVBoxLayout()
        left_layout.setContentsMargins(16, 16, 12, 16)
        left_layout.setSpacing(10)
        left_layout.addWidget(QLabel("Search"))
        left_layout.addWidget(self.search_box)
        left_layout.addWidget(QLabel("Tags"))
        left_layout.addWidget(self.tag_list, 1)
        left_layout.addWidget(QLabel("Notes"))
        left_layout.addWidget(self.note_list, 3)
        left_panel = QWidget()
        left_panel.setLayout(left_layout)

        self.title_edit = QLineEdit()
        self.title_edit.textChanged.connect(self.mark_dirty)

        self.tags_edit = QLineEdit()
        self.tags_edit.setPlaceholderText("Tags, separated by commas or spaces")
        self.tags_edit.textChanged.connect(self.mark_dirty)

        self.body_edit = QPlainTextEdit()
        self.body_edit.textChanged.connect(self.mark_dirty)

        self.path_label = QLabel("No note selected")
        self.path_label.setTextInteractionFlags(Qt.TextSelectableByMouse)

        right_layout = QVBoxLayout()
        right_layout.setContentsMargins(12, 16, 16, 16)
        right_layout.setSpacing(10)
        right_layout.addWidget(QLabel("Title"))
        right_layout.addWidget(self.title_edit)
        right_layout.addWidget(QLabel("Tags"))
        right_layout.addWidget(self.tags_edit)
        right_layout.addWidget(QLabel("Body"))
        right_layout.addWidget(self.body_edit, 1)
        right_layout.addWidget(self.path_label)
        right_panel = QWidget()
        right_panel.setLayout(right_layout)

        splitter = QSplitter()
        splitter.addWidget(left_panel)
        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        self.setCentralWidget(splitter)

        status_bar = QStatusBar()
        self.setStatusBar(status_bar)
        self.update_status()

    def apply_theme(self) -> None:
        app = QApplication.instance()
        if app is not None:
            app.setStyleSheet(build_stylesheet(self.settings.theme))

    def mark_dirty(self) -> None:
        if self.loading_note:
            return
        self.is_dirty = True
        self.update_status()

    def update_status(self) -> None:
        notes_dir = str(self.repository.notes_dir)
        current_path = str(self.current_note_path) if self.current_note_path else "(no note selected)"
        dirty_marker = " *unsaved changes*" if self.is_dirty else ""
        self.statusBar().showMessage(f"Notes dir: {notes_dir} | Current: {current_path}{dirty_marker}")

    def parse_tag_input(self) -> list[str]:
        raw_value = self.tags_edit.text().strip()
        if not raw_value:
            return []
        return [segment for segment in re.split(r"[,\s]+", raw_value) if segment]

    def current_form_note(self) -> NoteRecord:
        title = self.title_edit.text().strip() or "Untitled Note"
        path = self.current_note_path or self.repository.create_draft(title).path
        return NoteRecord(
            path=path,
            slug=path.stem,
            title=title,
            tags=self.parse_tag_input(),
            body=self.body_edit.toPlainText(),
        )

    def maybe_continue_with_unsaved_changes(self) -> bool:
        if not self.is_dirty:
            return True

        answer = QMessageBox.question(
            self,
            "Unsaved changes",
            "Save your changes before continuing?",
            QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel,
            QMessageBox.Save,
        )
        if answer == QMessageBox.Cancel:
            return False
        if answer == QMessageBox.Discard:
            return True
        return self.save_current_note()

    def load_note_into_editor(self, note: NoteRecord, saved: bool) -> None:
        self.loading_note = True
        self.title_edit.setText(note.title)
        self.tags_edit.setText(", ".join(note.tags))
        self.body_edit.setPlainText(note.body)
        self.current_note_path = note.path
        self.saved_note_path = note.path if saved else None
        self.path_label.setText(str(note.path))
        self.loading_note = False
        self.is_dirty = not saved
        self.update_status()

    def clear_editor(self) -> None:
        self.loading_note = True
        self.title_edit.clear()
        self.tags_edit.clear()
        self.body_edit.clear()
        self.path_label.setText("No note selected")
        self.loading_note = False
        self.current_note_path = None
        self.saved_note_path = None
        self.is_dirty = False
        self.update_status()

    def refresh_notes(self, select_path: Path | None = None) -> None:
        self.repository = NoteRepository(resolve_notes_dir(self.settings))
        self.all_notes = self.repository.list_notes()
        self.populate_tags()
        self.apply_filters(select_path)

    def populate_tags(self) -> None:
        with QSignalBlocker(self.tag_list):
            current_tag = self.selected_tag()
            self.tag_list.clear()

            all_item = QListWidgetItem("All notes")
            all_item.setData(Qt.UserRole, None)
            self.tag_list.addItem(all_item)

            for tag, count in collect_tag_counts(self.all_notes):
                item = QListWidgetItem(f"{tag} ({count})")
                item.setData(Qt.UserRole, tag)
                self.tag_list.addItem(item)

            self.select_tag(current_tag)

    def selected_tag(self) -> str | None:
        current_item = self.tag_list.currentItem()
        if current_item is None:
            return None
        return current_item.data(Qt.UserRole)

    def select_tag(self, tag: str | None) -> None:
        with QSignalBlocker(self.tag_list):
            for index in range(self.tag_list.count()):
                item = self.tag_list.item(index)
                if item.data(Qt.UserRole) == tag:
                    self.tag_list.setCurrentItem(item)
                    return
            if self.tag_list.count() > 0:
                self.tag_list.setCurrentRow(0)

    def apply_filters(self, select_path: Path | None = None) -> None:
        current_selection = select_path or self.current_note_path
        filtered = filter_notes(
            self.all_notes,
            search_text=self.search_box.text(),
            selected_tag=self.selected_tag(),
            sort_order=self.settings.sort_order,
        )

        selected_path_to_load: Path | None = None
        with QSignalBlocker(self.note_list):
            self.note_list.clear()
            for note in filtered:
                tags = ", ".join(note.tags)
                modified = Path(note.path).stat().st_mtime if note.path.exists() else note.modified_at
                subtitle = f" [{tags}]" if tags else ""
                item = QListWidgetItem(f"{note.title}{subtitle}")
                item.setToolTip(f"{note.path}\nLast modified: {modified:.0f}")
                item.setData(Qt.UserRole, str(note.path))
                self.note_list.addItem(item)

            if current_selection is not None:
                for index in range(self.note_list.count()):
                    item = self.note_list.item(index)
                    if item.data(Qt.UserRole) == str(current_selection):
                        self.note_list.setCurrentItem(item)
                        selected_path_to_load = Path(item.data(Qt.UserRole))
                        break
            elif self.note_list.count() > 0:
                self.note_list.setCurrentRow(0)
                current_item = self.note_list.currentItem()
                if current_item is not None:
                    selected_path_to_load = Path(current_item.data(Qt.UserRole))

        if selected_path_to_load is not None:
            note = self.repository.load_note(selected_path_to_load)
            self.load_note_into_editor(note, saved=True)

    def select_note_item(self, note_path: Path | None) -> None:
        if note_path is None:
            return
        for index in range(self.note_list.count()):
            item = self.note_list.item(index)
            if item.data(Qt.UserRole) == str(note_path):
                self.note_list.setCurrentItem(item)
                return

    def on_note_selected(self, current: QListWidgetItem | None, _: QListWidgetItem | None) -> None:
        if current is None:
            return

        if not self.maybe_continue_with_unsaved_changes():
            self.select_note_item(self.saved_note_path or self.current_note_path)
            return

        selected_path = Path(current.data(Qt.UserRole))
        note = self.repository.load_note(selected_path)
        self.load_note_into_editor(note, saved=True)

    def create_note(self) -> None:
        if not self.maybe_continue_with_unsaved_changes():
            return

        title, accepted = QInputDialog.getText(self, "Create note", "Title")
        if not accepted:
            return

        draft = self.repository.create_draft(title or "Untitled Note")
        self.load_note_into_editor(draft, saved=False)

    def save_current_note(self) -> bool:
        if not self.current_note_path and not self.title_edit.text().strip() and not self.body_edit.toPlainText().strip():
            return True

        note = self.current_form_note()
        try:
            saved = self.repository.save_note(note, previous_path=self.saved_note_path)
        except RepositoryError as exc:
            QMessageBox.critical(self, "Save failed", str(exc))
            return False

        self.load_note_into_editor(saved, saved=True)
        self.refresh_notes(select_path=saved.path)
        return True

    def delete_current_note(self) -> None:
        if self.current_note_path is None:
            QMessageBox.information(self, "Delete note", "No note is selected.")
            return

        if self.saved_note_path is None:
            answer = QMessageBox.question(
                self,
                "Discard draft",
                "Discard the current unsaved note?",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No,
            )
            if answer == QMessageBox.Yes:
                self.clear_editor()
            return

        answer = QMessageBox.question(
            self,
            "Delete note",
            f"Delete note '{self.title_edit.text().strip() or self.saved_note_path.name}'?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )
        if answer != QMessageBox.Yes:
            return

        try:
            self.repository.delete_note(self.saved_note_path)
        except RepositoryError as exc:
            QMessageBox.critical(self, "Delete failed", str(exc))
            return

        self.clear_editor()
        self.refresh_notes()

    def import_notes(self) -> None:
        backup_dir = QFileDialog.getExistingDirectory(self, "Select Standard Notes backup directory", str(Path.home()))
        if not backup_dir:
            return

        try:
            result = self.import_service.run_import(Path(backup_dir))
        except IntegrationError as exc:
            QMessageBox.critical(self, "Import failed", str(exc))
            return

        message = QMessageBox(self)
        message.setWindowTitle("Import results")
        if result.succeeded:
            message.setIcon(QMessageBox.Information)
            message.setText("Import completed.")
            self.refresh_notes()
        else:
            message.setIcon(QMessageBox.Critical)
            message.setText("Import failed.")
        message.setDetailedText((result.stdout + "\n" + result.stderr).strip())
        message.exec()

    def open_external_editor(self) -> None:
        if self.current_note_path is None:
            QMessageBox.information(self, "Open external editor", "No note is selected.")
            return

        if self.is_dirty and not self.save_current_note():
            return

        try:
            launch_external_editor(self.saved_note_path or self.current_note_path)
        except IntegrationError as exc:
            QMessageBox.critical(self, "External editor failed", str(exc))

    def show_settings_dialog(self) -> None:
        if not self.maybe_continue_with_unsaved_changes():
            return

        dialog = SettingsDialog(self.settings, self)
        if dialog.exec() != QDialog.Accepted:
            return

        self.settings = dialog.to_settings()
        self.settings_store.save(self.settings)
        self.apply_theme()
        self.clear_editor()
        self.refresh_notes()
