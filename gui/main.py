from __future__ import annotations

import sys


def main() -> int:
    if "--smoke-test" in sys.argv:
        return 0

    from PySide6.QtWidgets import QApplication

    from gui.app.main_window import MainWindow

    app = QApplication(sys.argv)
    app.setApplicationName("notes-gui")
    app.setStyle("Fusion")
    window = MainWindow()
    window.resize(1200, 800)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
