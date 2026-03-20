#!/usr/bin/env pwsh
<#
.SYNOPSIS
    A CLI tool for managing markdown notes.
.DESCRIPTION
    Create, list, show, edit, remove, and search markdown notes stored in $env:NOTES_DIR (default: ~/notes).
.EXAMPLE
    .\notes.ps1 add "My First Note"
    .\notes.ps1 list
    .\notes.ps1 show "My First Note"
    .\notes.ps1 search "keyword"
#>

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# --- Configuration ---

function Get-NotesDir {
    if ($env:NOTES_DIR) { return $env:NOTES_DIR }
    return Join-Path $HOME "notes"
}

function Ensure-NotesDir {
    $dir = Get-NotesDir
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-Editor {
    if ($env:EDITOR) { return $env:EDITOR }
    if ($env:VISUAL) { return $env:VISUAL }
    return "notepad"
}

# --- Slug Helpers ---

function ConvertTo-Slug {
    param([string]$Title)
    $slug = $Title.ToLower().Trim()
    $slug = $slug -replace '\s+', '-'
    $slug = $slug -replace '[^a-z0-9\-]', ''
    $slug = $slug -replace '-+', '-'
    $slug = $slug.Trim('-')
    return $slug
}

function Get-NoteFilename {
    param([string]$Title)
    return "$(ConvertTo-Slug $Title).md"
}

function Get-NotePath {
    param([string]$Title)
    $dir = Ensure-NotesDir
    return Join-Path $dir (Get-NoteFilename $Title)
}

# --- Commands ---

function Invoke-AddNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Error "Usage: notes add <title>"
        return
    }

    $path = Get-NotePath $Title
    if (Test-Path $path) {
        Write-Error "Note '$Title' already exists."
        return
    }

    # Create the file with a heading so the editor opens a non-empty file
    $heading = "# $Title"
    Set-Content -Path $path -Value $heading -Encoding utf8

    $editor = Get-Editor
    Start-Process -FilePath $editor -ArgumentList "`"$path`"" -NoNewWindow -Wait
    Write-Host "Note '$Title' created."
}

function Invoke-ListNotes {
    $dir = Ensure-NotesDir
    $notes = Get-ChildItem -Path $dir -Filter "*.md" -File -ErrorAction SilentlyContinue

    if (-not $notes) {
        Write-Host "No notes found."
        return
    }

    foreach ($note in $notes | Sort-Object Name) {
        Write-Output ($note.BaseName)
    }
}

function Invoke-ShowNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Error "Usage: notes show <title>"
        return
    }

    $path = Get-NotePath $Title
    if (-not (Test-Path $path)) {
        Write-Error "Note '$Title' not found."
        return
    }

    Get-Content -Path $path -Raw
}

function Invoke-EditNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Error "Usage: notes edit <title>"
        return
    }

    $path = Get-NotePath $Title
    if (-not (Test-Path $path)) {
        Write-Error "Note '$Title' not found."
        return
    }

    $editor = Get-Editor
    Start-Process -FilePath $editor -ArgumentList "`"$path`"" -NoNewWindow -Wait
}

function Invoke-RemoveNote {
    param(
        [string]$Title,
        [switch]$Force
    )

    if (-not $Title) {
        Write-Error "Usage: notes remove <title> [-Force]"
        return
    }

    $path = Get-NotePath $Title
    if (-not (Test-Path $path)) {
        Write-Error "Note '$Title' not found."
        return
    }

    if (-not $Force) {
        $confirm = Read-Host "Delete note '$Title'? (y/N)"
        if ($confirm -notin @('y', 'yes')) {
            Write-Host "Cancelled."
            return
        }
    }

    Remove-Item -Path $path -Force
    Write-Host "Note '$Title' removed."
}

function Invoke-SearchNotes {
    param([string]$SearchText)

    if (-not $SearchText) {
        Write-Error "Usage: notes search <text>"
        return
    }

    $dir = Ensure-NotesDir
    $notes = Get-ChildItem -Path $dir -Filter "*.md" -File -ErrorAction SilentlyContinue

    if (-not $notes) {
        Write-Host "No notes found."
        return
    }

    $found = $false
    $escapedText = [regex]::Escape($SearchText)

    foreach ($note in $notes | Sort-Object Name) {
        $lines = Get-Content -Path $note.FullName
        $hitLines = [System.Collections.ArrayList]::new()
        $lineNum = 0

        foreach ($line in $lines) {
            $lineNum++
            if ($line -imatch $escapedText) {
                [void]$hitLines.Add([PSCustomObject]@{ LineNumber = $lineNum; Text = $line })
            }
        }

        if ($hitLines.Count -gt 0) {
            $found = $true
            Write-Host ""
            Write-Host "=== $($note.BaseName) ===" -ForegroundColor Cyan
            foreach ($hit in $hitLines) {
                Write-Host "  $($hit.LineNumber): $($hit.Text)"
            }
        }
    }

    if (-not $found) {
        Write-Host "No matches found for '$SearchText'."
    }
}

function Show-Help {
    Write-Host @"
notes.ps1 - Markdown note manager

Usage:
  .\notes.ps1 <command> [arguments]

Commands:
  add <title>       Create a new note and open it in the editor
  list              List all note titles
  show <title>      Display a note's content
  edit <title>      Open an existing note in the editor
  remove <title>    Delete a note (use -Force to skip confirmation)
  search <text>     Search all notes for text (case-insensitive)
  help              Show this help message

Environment:
  NOTES_DIR         Directory for notes (default: ~/notes)
  EDITOR / VISUAL   Preferred text editor (default: notepad)
"@
}

# --- Main Dispatch ---

# Check for -Force anywhere in the remaining arguments
$forceFlag = $false
if ($Arguments -and ($Arguments -contains '-Force')) {
    $forceFlag = $true
    $Arguments = @($Arguments | Where-Object { $_ -ne '-Force' })
}

$arg = if ($Arguments.Count -gt 0) { $Arguments[0] } else { $null }

switch (($Command ?? '').ToLower()) {
    'add'    { Invoke-AddNote -Title $arg }
    'list'   { Invoke-ListNotes }
    'show'   { Invoke-ShowNote -Title $arg }
    'edit'   { Invoke-EditNote -Title $arg }
    'remove' { Invoke-RemoveNote -Title $arg -Force:$forceFlag }
    'search' {
        # Rejoin all remaining args as the search text
        $searchText = if ($Arguments) { $Arguments -join ' ' } else { $null }
        Invoke-SearchNotes -SearchText $searchText
    }
    'help'   { Show-Help }
    default  { Show-Help }
}
