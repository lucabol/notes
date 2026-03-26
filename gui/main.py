from __future__ import annotations

import sys

from PySide6.QtWidgets import QApplication

from gui.app.main_window import MainWindow


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("notes-gui")
    window = MainWindow()
    if "--smoke-test" in sys.argv:
        window.close()
        window.deleteLater()
        app.processEvents()
        app.quit()
        return 0

    window.resize(1200, 800)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
