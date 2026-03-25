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

By default the installer writes launchers to `$HOME\bin` on Windows and `$HOME/.local/bin` elsewhere. It creates `notes.ps1` plus a shell-specific launcher (`notes.cmd` on Windows, `notes` elsewhere). Make sure that directory is on your `PATH`.

## Quick start

```powershell
# Create a note (opens in $EDITOR)
.\notes.ps1 add "My First Note"

# List all notes
.\notes.ps1 list

# Show a note
.\notes.ps1 show "My First Note"

# Edit a note
.\notes.ps1 edit "My First Note"

# Delete a note
.\notes.ps1 remove "My First Note"

# Search across all notes
.\notes.ps1 search "keyword"
```

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
.\notes.ps1 list +Recipes          # recommended — works unquoted in all shells
.\notes.ps1 list tag:Recipes       # also works unquoted everywhere
.\notes.ps1 list '#Recipes'        # needs quotes (# is a comment character)

.\notes.ps1 search "chicken" +Recipes   # search within a single tag
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
.\notes.ps1 import "C:\path\to\standard-notes-backup"
```

Each note is converted from the Standard Notes Lexical format and saved as a `.md` file.

## Running tests

The project uses [Pester](https://pester.dev/) for tests and [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) for linting. The CI script installs both automatically:

```powershell
.\ci.ps1
```

## License

MIT
