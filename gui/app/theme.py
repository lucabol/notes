from __future__ import annotations


def build_stylesheet(theme: str) -> str:
    if theme == "light":
        return _build_light_stylesheet()
    return _build_dark_stylesheet()


def _build_dark_stylesheet() -> str:
    return """
QMainWindow, QDialog {
    background-color: #111827;
    color: #E5E7EB;
}
QWidget {
    color: #E5E7EB;
    font-size: 13px;
}
QToolBar {
    background: #0F172A;
    border: none;
    spacing: 8px;
    padding: 10px 14px;
}
QToolButton {
    background: #1F2937;
    color: #E5E7EB;
    border: 1px solid #334155;
    border-radius: 10px;
    padding: 8px 12px;
    margin-right: 6px;
}
QToolButton:hover {
    background: #2563EB;
    border-color: #3B82F6;
}
QToolButton:pressed {
    background: #1D4ED8;
}
QLineEdit, QPlainTextEdit, QListWidget, QComboBox {
    background-color: #0F172A;
    color: #E5E7EB;
    border: 1px solid #334155;
    border-radius: 10px;
    padding: 8px 10px;
    selection-background-color: #2563EB;
    selection-color: #F8FAFC;
}
QLineEdit:focus, QPlainTextEdit:focus, QListWidget:focus, QComboBox:focus {
    border: 1px solid #60A5FA;
}
QPlainTextEdit {
    padding: 14px;
    font-family: Consolas, "Cascadia Code", "Fira Code", monospace;
    font-size: 14px;
    line-height: 1.35;
}
QListWidget {
    outline: none;
    padding: 6px;
}
QListWidget::item {
    padding: 8px;
    border-radius: 8px;
    margin: 2px 0;
}
QListWidget::item:selected {
    background: #1D4ED8;
    color: #EFF6FF;
}
QListWidget::item:hover {
    background: #1E293B;
}
QLabel {
    color: #CBD5E1;
}
QPushButton, QDialogButtonBox QPushButton {
    background: #2563EB;
    color: white;
    border: none;
    border-radius: 10px;
    padding: 9px 14px;
    min-width: 88px;
}
QPushButton:hover, QDialogButtonBox QPushButton:hover {
    background: #3B82F6;
}
QPushButton:pressed, QDialogButtonBox QPushButton:pressed {
    background: #1D4ED8;
}
QStatusBar {
    background: #0F172A;
    color: #94A3B8;
    border-top: 1px solid #1E293B;
}
QSplitter::handle {
    background: #1E293B;
    width: 2px;
}
QMessageBox {
    background-color: #111827;
}
"""


def _build_light_stylesheet() -> str:
    return """
QMainWindow, QDialog {
    background-color: #F3F4F6;
    color: #111827;
}
QWidget {
    color: #111827;
    font-size: 13px;
}
QToolBar {
    background: #FFFFFF;
    border: none;
    spacing: 8px;
    padding: 10px 14px;
}
QToolButton {
    background: #FFFFFF;
    color: #111827;
    border: 1px solid #D1D5DB;
    border-radius: 10px;
    padding: 8px 12px;
    margin-right: 6px;
}
QToolButton:hover {
    background: #DBEAFE;
    border-color: #60A5FA;
}
QToolButton:pressed {
    background: #BFDBFE;
}
QLineEdit, QPlainTextEdit, QListWidget, QComboBox {
    background-color: #FFFFFF;
    color: #111827;
    border: 1px solid #D1D5DB;
    border-radius: 10px;
    padding: 8px 10px;
    selection-background-color: #3B82F6;
    selection-color: #FFFFFF;
}
QLineEdit:focus, QPlainTextEdit:focus, QListWidget:focus, QComboBox:focus {
    border: 1px solid #3B82F6;
}
QPlainTextEdit {
    padding: 14px;
    font-family: Consolas, "Cascadia Code", "Fira Code", monospace;
    font-size: 14px;
    line-height: 1.35;
}
QListWidget {
    outline: none;
    padding: 6px;
}
QListWidget::item {
    padding: 8px;
    border-radius: 8px;
    margin: 2px 0;
}
QListWidget::item:selected {
    background: #2563EB;
    color: white;
}
QListWidget::item:hover {
    background: #E5E7EB;
}
QLabel {
    color: #4B5563;
}
QPushButton, QDialogButtonBox QPushButton {
    background: #2563EB;
    color: white;
    border: none;
    border-radius: 10px;
    padding: 9px 14px;
    min-width: 88px;
}
QPushButton:hover, QDialogButtonBox QPushButton:hover {
    background: #3B82F6;
}
QPushButton:pressed, QDialogButtonBox QPushButton:pressed {
    background: #1D4ED8;
}
QStatusBar {
    background: #FFFFFF;
    color: #6B7280;
    border-top: 1px solid #E5E7EB;
}
QSplitter::handle {
    background: #E5E7EB;
    width: 2px;
}
"""
