from __future__ import annotations


def build_stylesheet(theme: str) -> str:
    if theme == "light":
        return _build_light_stylesheet()
    return _build_dark_stylesheet()


def _build_dark_stylesheet() -> str:
    return """
QMainWindow, QDialog {
    background-color: #0B1020;
    color: #F3F4F6;
}
QWidget {
    color: #F3F4F6;
    font-family: "Segoe UI Variable Text", "Inter", "Segoe UI", sans-serif;
    font-size: 13px;
    font-weight: 500;
}
QToolBar {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #111827, stop:0.45 #172554, stop:1 #3B0764);
    border: none;
    spacing: 10px;
    padding: 12px 16px;
}
QToolButton {
    background: rgba(15, 23, 42, 0.72);
    color: #F8FAFC;
    border: 1px solid rgba(96, 165, 250, 0.35);
    border-radius: 12px;
    padding: 9px 14px;
    margin-right: 6px;
    font-weight: 700;
}
QToolButton:hover {
    background: #2563EB;
    border-color: #93C5FD;
}
QToolButton:pressed {
    background: #7C3AED;
    border-color: #C4B5FD;
}
QLineEdit, QPlainTextEdit, QListWidget, QComboBox {
    background-color: #111827;
    color: #F8FAFC;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 9px 12px;
    selection-background-color: #7C3AED;
    selection-color: #F8FAFC;
}
QLineEdit:focus, QPlainTextEdit:focus, QListWidget:focus, QComboBox:focus {
    border: 1px solid #22D3EE;
    background-color: #0F172A;
}
QLineEdit {
    background-color: #131C31;
    font-weight: 600;
}
QLineEdit::placeholder {
    color: #7DD3FC;
}
QPlainTextEdit {
    background-color: #0F172A;
    border: 1px solid #1D4ED8;
    padding: 16px;
    font-family: "Cascadia Code", "JetBrains Mono", Consolas, monospace;
    font-size: 15px;
    font-weight: 600;
    line-height: 1.45;
}
QListWidget {
    outline: none;
    background-color: #101A30;
    padding: 8px;
}
QListWidget::item {
    padding: 10px;
    border-radius: 10px;
    margin: 3px 0;
}
QListWidget::item:selected {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #2563EB, stop:1 #7C3AED);
    color: #FFFFFF;
    border: 1px solid rgba(255, 255, 255, 0.14);
}
QListWidget::item:hover {
    background: #172554;
}
QLabel {
    color: #BFDBFE;
    font-weight: 700;
}
QLabel[hint="true"] {
    color: #93C5FD;
    font-weight: 500;
}
QPushButton, QDialogButtonBox QPushButton {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #2563EB, stop:1 #7C3AED);
    color: white;
    border: none;
    border-radius: 12px;
    padding: 10px 15px;
    min-width: 88px;
    font-weight: 700;
}
QPushButton:hover, QDialogButtonBox QPushButton:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #38BDF8, stop:1 #8B5CF6);
}
QPushButton:pressed, QDialogButtonBox QPushButton:pressed {
    background: #6D28D9;
}
QStatusBar {
    background: #0F172A;
    color: #C4B5FD;
    border-top: 1px solid #312E81;
    font-weight: 600;
}
QSplitter::handle {
    background: #312E81;
    width: 3px;
}
QMessageBox {
    background-color: #0B1020;
}
QComboBox {
    background-color: #131C31;
    padding-right: 28px;
    font-weight: 600;
}
QComboBox::drop-down {
    border: none;
    width: 26px;
}
QComboBox QAbstractItemView {
    background: #111827;
    border: 1px solid #334155;
    selection-background-color: #7C3AED;
    selection-color: white;
}
"""


def _build_light_stylesheet() -> str:
    return """
QMainWindow, QDialog {
    background-color: #EEF2FF;
    color: #0F172A;
}
QWidget {
    color: #0F172A;
    font-family: "Segoe UI Variable Text", "Inter", "Segoe UI", sans-serif;
    font-size: 13px;
    font-weight: 500;
}
QToolBar {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #FFFFFF, stop:0.55 #DBEAFE, stop:1 #EDE9FE);
    border: none;
    spacing: 10px;
    padding: 12px 16px;
}
QToolButton {
    background: rgba(255, 255, 255, 0.9);
    color: #0F172A;
    border: 1px solid #BFDBFE;
    border-radius: 12px;
    padding: 9px 14px;
    margin-right: 6px;
    font-weight: 700;
}
QToolButton:hover {
    background: #DBEAFE;
    border-color: #38BDF8;
}
QToolButton:pressed {
    background: #DDD6FE;
    border-color: #8B5CF6;
}
QLineEdit, QPlainTextEdit, QListWidget, QComboBox {
    background-color: #FFFFFF;
    color: #0F172A;
    border: 1px solid #CBD5E1;
    border-radius: 12px;
    padding: 9px 12px;
    selection-background-color: #8B5CF6;
    selection-color: #FFFFFF;
}
QLineEdit:focus, QPlainTextEdit:focus, QListWidget:focus, QComboBox:focus {
    border: 1px solid #06B6D4;
}
QLineEdit {
    background-color: #FFFFFF;
    font-weight: 600;
}
QLineEdit::placeholder {
    color: #6366F1;
}
QPlainTextEdit {
    background-color: #FFFFFF;
    border: 1px solid #93C5FD;
    padding: 16px;
    font-family: "Cascadia Code", "JetBrains Mono", Consolas, monospace;
    font-size: 15px;
    font-weight: 600;
    line-height: 1.45;
}
QListWidget {
    outline: none;
    background-color: #F8FAFC;
    padding: 8px;
}
QListWidget::item {
    padding: 10px;
    border-radius: 10px;
    margin: 3px 0;
}
QListWidget::item:selected {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #2563EB, stop:1 #8B5CF6);
    color: white;
}
QListWidget::item:hover {
    background: #E0E7FF;
}
QLabel {
    color: #4338CA;
    font-weight: 700;
}
QLabel[hint="true"] {
    color: #6366F1;
    font-weight: 500;
}
QPushButton, QDialogButtonBox QPushButton {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #2563EB, stop:1 #8B5CF6);
    color: white;
    border: none;
    border-radius: 12px;
    padding: 10px 15px;
    min-width: 88px;
    font-weight: 700;
}
QPushButton:hover, QDialogButtonBox QPushButton:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #38BDF8, stop:1 #A78BFA);
}
QPushButton:pressed, QDialogButtonBox QPushButton:pressed {
    background: #7C3AED;
}
QStatusBar {
    background: #FFFFFF;
    color: #6D28D9;
    border-top: 1px solid #C7D2FE;
    font-weight: 600;
}
QSplitter::handle {
    background: #C7D2FE;
    width: 3px;
}
QComboBox {
    font-weight: 600;
    padding-right: 28px;
}
QComboBox::drop-down {
    border: none;
    width: 26px;
}
QComboBox QAbstractItemView {
    background: #FFFFFF;
    border: 1px solid #CBD5E1;
    selection-background-color: #8B5CF6;
    selection-color: white;
}
"""
