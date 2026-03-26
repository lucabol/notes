# notes

A lightweight CLI tool for managing plain-text markdown notes, written in PowerShell. Notes are stored as `.md` files in a local folder, making them easy to sync, back up, or use with any text editor.

## Features

- **CRUD operations** – create, list, show, edit, and remove notes
- **Full-text search** – find notes by content (case-insensitive)
- **Tag support** – tag notes by putting a `#tag` on the first line and filter by tag across all commands
- **Standard Notes import** – migrate from a Standard Notes backup in one command
- **Pager support** – long output is automatically piped through your preferred pager
- **Flexible tool commands** – `EDITOR`, `VISUAL`, and `PAGER` can include arguments such as `code --wait`
- **Automation-friendly** – user-visible failures return non-zero exit codes for scripts and CI
- **Simple install flow** – `install.ps1` creates launchers in your user bin directory
- **Desktop GUI** – optional `notes-gui` app for browsing, editing, searching, tagging, and importing notes
- **Cross-platform** – runs on Windows, macOS, and Linux via PowerShell 7+

## Requirements

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)

## Installation

Clone the repository and run the installer to create a lightweight launcher in your user bin directory.

```powershell
git clone https://github.com/lucabol/notes.git
cd notes
pwsh -NoProfile -File .\install.ps1
```

By default the installer writes launchers to `$HOME\bin` on Windows and `$HOME/.local/bin` elsewhere. It creates `notes.ps1` plus a shell-specific launcher (`notes.cmd` on Windows, `notes` elsewhere).

If the GUI sources are present and Python 3 is available, the installer also creates a local `.venv-gui`, installs the GUI dependencies into it, and creates `notes-gui.ps1` plus a shell-specific GUI launcher (`notes-gui.cmd` on Windows, `notes-gui` elsewhere).

Make sure that directory is on your `PATH`.

## Optional GUI requirements

The desktop GUI is implemented in Python with PySide6. The simplest path is to let `install.ps1` bootstrap `.venv-gui` for you.

If you want to install the GUI dependencies manually instead, create a virtual environment and install `requirements-gui.txt` into it:

```powershell
python -m venv .venv-gui
```

Then use the Python executable inside that virtual environment to install the requirements:

- Windows PowerShell: `.\.venv-gui\Scripts\python -m pip install -r .\requirements-gui.txt`
- Linux/macOS: `./.venv-gui/bin/python -m pip install -r ./requirements-gui.txt`

Then launch it with:

```powershell
notes-gui
```

## Quick start

The examples below assume you ran `install.ps1` and added the install directory to your `PATH`. If you want to run directly from the repository instead, replace `notes` with `.\notes.ps1`.

```powershell
# Create a note (opens in $EDITOR)
notes add "My First Note"

# List all notes
notes list

# Show a note
notes show "My First Note"

# Edit a note
notes edit "My First Note"

# Delete a note
notes remove "My First Note"

# Search across all notes
notes search "keyword"
```

## GUI quick start

The GUI works against the same `NOTES_DIR` as the CLI.

- browse and search notes
- filter by tag
- edit title, tags, and body
- save, delete, and create notes
- import a Standard Notes backup
- open the current note in your configured external editor

## Commands

| Command | Description |
|---|---|
| `add <title>` | Create a new note and open it in the editor |
| `list [pattern]` | List all notes, optionally filtered by name or tag |
| `show <title>` | Print a note's content to the terminal |
| `edit <title>` | Open a note in the editor |
| `remove <title> [-Force]` | Delete a note (prompts for confirmation unless `-Force`) |
| `search <text> [tag]` | Search note contents for text, optionally scoped to a tag |
| `check` | Show the notes directory path and verify it is accessible |
| `import <path>` | Import notes from a Standard Notes backup directory |
| `help` | Show the built-in help message |

## Tags

Tag a note by placing a `#tag` token on the **first line**:

```markdown
# My Cooking Notes #Recipes

...
```

Then filter any command by tag using one of three equivalent prefixes:

```powershell
notes list +Recipes          # recommended — works unquoted in all shells
notes list tag:Recipes       # also works unquoted everywhere
notes list '#Recipes'        # needs quotes (# is a comment character)

notes search "chicken" +Recipes   # search within a single tag
```

## Configuration

| Environment variable | Default | Description |
|---|---|---|
| `NOTES_DIR` | `~/notes` | Directory where notes are stored |
| `EDITOR` / `VISUAL` | `notepad` on Windows, `vi` elsewhere | Editor used for `add` and `edit` |
| `PAGER` | `more.com` on Windows, `less` elsewhere | Pager used for long output |

```powershell
# Example: use VS Code and store notes on a synced drive
$env:EDITOR   = "code --wait"
$env:NOTES_DIR = "$HOME/Dropbox/notes"
```

Command strings with arguments are supported, so values like `code --wait` and `less -FRX` work as expected.

## Automation and scripting

Commands that fail for user-visible reasons, such as missing notes, duplicate adds, invalid import paths, or editor launch failures, return a non-zero exit code. This makes `notes.ps1` safer to use from scripts, wrappers, and CI jobs.

## Importing from Standard Notes

Export your Standard Notes data as a `.zip` backup, unzip it, then run:

```powershell
notes import "C:\path\to\standard-notes-backup"
```

Each note is converted from the Standard Notes Lexical format and saved as a `.md` file.

## Running tests

The project uses [Pester](https://pester.dev/) for tests and [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) for linting. The CI script installs both automatically:

```powershell
.\ci.ps1
```

The CI script now also creates a local `.venv-gui-ci`, installs the GUI Python dependency there when needed, and runs the Python unit tests under `gui_tests\`.

## License

MIT
