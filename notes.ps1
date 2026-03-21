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

function Get-Pager {
    if ($env:PAGER) { return $env:PAGER }
    return "more.com"
}

function Send-ToPager {
    param([string[]]$Lines)
    if ([Console]::IsOutputRedirected) {
        $Lines | ForEach-Object { Write-Output $_ }
        return
    }
    # Only invoke the pager when content exceeds screen height
    try {
        $pageSize = [Console]::WindowHeight - 2
        if ($Lines.Count -gt $pageSize) {
            $Lines | & (Get-Pager)
            return
        }
    } catch { }
    $Lines | ForEach-Object { Write-Output $_ }
}

# --- Tag Argument Helpers ---

function Get-TagFromArg {
    param([string]$Arg)
    if ($Arg.StartsWith('#')) { return $Arg.Substring(1) }
    if ($Arg.StartsWith('+')) { return $Arg.Substring(1) }
    if ($Arg.StartsWith('tag:')) { return $Arg.Substring(4) }
    return $null
}

function Test-IsTagArg {
    param([string]$Arg)
    return ($Arg.StartsWith('#') -or $Arg.StartsWith('+') -or $Arg.StartsWith('tag:'))
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

function Find-NotePath {
    param([string]$Title)
    $dir = Ensure-NotesDir
    $slug = ConvertTo-Slug $Title
    $files = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
    if (-not $files) { return @() }

    # 1. Exact filename match (case-insensitive)
    $exact = @($files | Where-Object { $_.Name -ieq $Title })
    if ($exact.Count -gt 0) { return $exact }

    # 2. Slug basename match (case-insensitive)
    $slugMatch = @($files | Where-Object { $_.BaseName -ieq $slug })
    if ($slugMatch.Count -gt 0) { return $slugMatch }

    # 3. Partial substring match on filename (case-insensitive)
    $partial = @($files | Where-Object { $_.Name -imatch [regex]::Escape($Title) })
    if ($partial.Count -gt 0) { return $partial }

    # 4. Partial substring match on slug against basename
    $partialSlug = @($files | Where-Object { $_.BaseName -imatch [regex]::Escape($slug) })
    if ($partialSlug.Count -gt 0) { return $partialSlug }

    return @()
}

function Resolve-NotePath {
    param([string]$Title)

    $tagName = Get-TagFromArg $Title
    if ($tagName) {
        $found = @(Find-NotesByTag $tagName)
        if ($found.Count -eq 0) {
            Write-Host "Error: No notes tagged '$Title'." -ForegroundColor Red
            return $null
        }
    } else {
        $found = @(Find-NotePath $Title)
        if ($found.Count -eq 0) {
            Write-Host "Error: Note '$Title' not found." -ForegroundColor Red
            return $null
        }
    }

    if ($found.Count -eq 1) {
        return $found[0].FullName
    }

    # Multiple matches — let the user pick
    $label = if (Test-IsTagArg $Title) { "tagged '$Title'" } else { "match '$Title'" }
    Write-Host "Multiple notes ${label}:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host "  [$($i + 1)] $($found[$i].Name)"
    }
    $choice = Read-Host "Pick a number (1-$($found.Count)), or 0 to cancel"
    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $found.Count) {
        Write-Host "Cancelled."
        return $null
    }
    return $found[$idx - 1].FullName
}

# --- Tag Helpers ---

function Find-NotesByTag {
    param([string]$Tag)
    $dir = Ensure-NotesDir
    $files = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
    if (-not $files) { return @() }

    $escapedTag = [regex]::Escape($Tag)
    $tagPattern = "(?:^|\s)#${escapedTag}(?:\s|$)"

    $matched = @($files | Where-Object {
        $firstLine = (Get-Content $_.FullName -TotalCount 1)
        $firstLine -and ($firstLine -imatch $tagPattern)
    })
    return $matched
}

# --- Commands ---

function Invoke-AddNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Host "Usage: notes add <title>" -ForegroundColor Red
        return
    }

    $path = Get-NotePath $Title
    if (@(Find-NotePath $Title).Count -gt 0) {
        Write-Host "Error: Note '$Title' already exists." -ForegroundColor Red
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
    param([string]$Pattern)

    $dir = Ensure-NotesDir
    $notes = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue

    if (-not $notes) {
        Write-Host "No notes found."
        return
    }

    if ($Pattern) {
        $tagName = Get-TagFromArg $Pattern
        if ($tagName) {
            $notes = @(Find-NotesByTag $tagName)
            if (-not $notes) {
                Write-Host "No notes tagged '$Pattern'."
                return
            }
        } else {
            $escaped = [regex]::Escape($Pattern)
            $notes = @($notes | Where-Object { $_.Name -imatch $escaped })
            if (-not $notes) {
                Write-Host "No notes matching '$Pattern'."
                return
            }
        }
    }

    $lines = @($notes | Sort-Object Name | ForEach-Object { $_.Name })
    Send-ToPager -Lines $lines
}

function Invoke-ShowNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Host "Usage: notes show <title>" -ForegroundColor Red
        return
    }

    $path = Resolve-NotePath $Title
    if (-not $path) { return }

    $lines = @(Get-Content -Path $path)
    Send-ToPager -Lines $lines
}

function Invoke-EditNote {
    param([string]$Title)

    if (-not $Title) {
        Write-Host "Usage: notes edit <title>" -ForegroundColor Red
        return
    }

    $path = Resolve-NotePath $Title
    if (-not $path) { return }

    $editor = Get-Editor
    Start-Process -FilePath $editor -ArgumentList "`"$path`"" -NoNewWindow -Wait
}

function Invoke-RemoveNote {
    param(
        [string]$Title,
        [switch]$Force
    )

    if (-not $Title) {
        Write-Host "Usage: notes remove <title> [-Force]" -ForegroundColor Red
        return
    }

    $path = Resolve-NotePath $Title
    if (-not $path) { return }

    $filename = [System.IO.Path]::GetFileName($path)
    $basename = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $slug = ConvertTo-Slug $Title
    $isPartial = -not (Test-IsTagArg $Title) -and ($filename -ine $Title) -and ($basename -ine $slug)

    if ($isPartial) {
        # Partial match — always confirm, even with -Force
        $confirm = Read-Host "Did you mean '$filename'? (y/N)"
        if ($confirm -notin @('y', 'yes')) {
            Write-Host "Cancelled."
            return
        }
    } elseif (-not $Force) {
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
    param(
        [string]$SearchText,
        [string]$Tag
    )

    if (-not $SearchText) {
        Write-Host "Usage: notes search <text>" -ForegroundColor Red
        return
    }

    $dir = Ensure-NotesDir

    if ($Tag) {
        $notes = @(Find-NotesByTag $Tag)
        if (-not $notes) {
            Write-Host "No notes tagged '#$Tag'."
            return
        }
    } else {
        $notes = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
        if (-not $notes) {
            Write-Host "No notes found."
            return
        }
    }

    $found = $false
    $escapedText = [regex]::Escape($SearchText)
    $outputLines = [System.Collections.ArrayList]::new()

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
            [void]$outputLines.Add("")
            [void]$outputLines.Add("=== $($note.Name) ===")
            foreach ($hit in $hitLines) {
                [void]$outputLines.Add("  $($hit.LineNumber): $($hit.Text)")
            }
        }
    }

    if (-not $found) {
        Write-Host "No matches found for '$SearchText'."
    } else {
        Send-ToPager -Lines $outputLines
    }
}

function Invoke-CheckNotes {
    $dir = Get-NotesDir
    $source = if ($env:NOTES_DIR) { "`$env:NOTES_DIR" } else { "default (~\notes)" }
    Write-Host "Notes directory: $dir (from $source)"

    if (-not (Test-Path $dir)) {
        Write-Host "Status: NOT FOUND (will be created on first use)" -ForegroundColor Yellow
        return
    }

    try {
        $testFile = Join-Path $dir ".notes-access-check"
        Set-Content -Path $testFile -Value "" -ErrorAction Stop
        Remove-Item -Path $testFile -Force
        $count = @(Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue).Count
        Write-Host "Status: OK ($count note(s))" -ForegroundColor Green
    } catch {
        Write-Host "Status: NOT ACCESSIBLE - $_" -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host @"
notes.ps1 - Markdown note manager

Usage:
  .\notes.ps1 <command> [arguments]

Commands:
  add <title>       Create a new note and open it in the editor
  list [pattern]    List all notes (optionally filter by pattern)
  show <title>      Display a note's content
  edit <title>      Open an existing note in the editor
  remove <title>    Delete a note (use -Force to skip confirmation)
  search <text>     Search all notes for text (case-insensitive)
  check             Show notes directory path and check accessibility
  import <path>     Import notes from a Standard Notes backup directory
  help              Show this help message

Tags:
  Filter by tag (first line of note) using any of these prefixes:
    +tag        Recommended — works unquoted in all shells
    tag:tag     Also works unquoted everywhere
    #tag        Needs quotes in PowerShell/bash (# is a comment character)
  Examples:
    list +Chess                 List notes tagged Chess
    show +Recipes               Show a recipe note
    search +Investing dividend  Search within Investing-tagged notes
    list tag:Chess              Same as list +Chess
    list '#Chess'               Same, but requires quotes

Environment:
  NOTES_DIR         Directory for notes (default: ~/notes)
  EDITOR / VISUAL   Preferred text editor (default: notepad)
"@
}

# --- Import from Standard Notes ---

function ConvertFrom-LexicalNode {
    param($Node)

    if (-not $Node) { return "" }

    switch ($Node.type) {
        "root" {
            $parts = @()
            foreach ($child in $Node.children) {
                $parts += ConvertFrom-LexicalNode $child
            }
            return ($parts -join "`n`n")
        }
        "paragraph" {
            $parts = @()
            foreach ($child in $Node.children) {
                $parts += ConvertFrom-LexicalNode $child
            }
            return ($parts -join "")
        }
        "text" {
            $t = $Node.text
            switch ([int]$Node.format) {
                1 { return "**$t**" }    # bold
                2 { return "*$t*" }      # italic
                3 { return "***$t***" }  # bold+italic
                default { return $t }
            }
        }
        "link" {
            $innerParts = @()
            foreach ($child in $Node.children) {
                $innerParts += ConvertFrom-LexicalNode $child
            }
            $linkText = $innerParts -join ""
            return "[$linkText]($($Node.url))"
        }
        "autolink" {
            return $Node.url
        }
        "list" {
            $items = @()
            $counter = if ($Node.PSObject.Properties['start'] -and $Node.start) { [int]$Node.start } else { 1 }
            foreach ($child in $Node.children) {
                $indent = "    " * [int]$child.indent
                $textParts = @()
                $nestedParts = @()
                foreach ($grandchild in $child.children) {
                    if ($grandchild.type -eq "list") {
                        $nestedParts += ConvertFrom-LexicalNode $grandchild
                    } else {
                        $textParts += ConvertFrom-LexicalNode $grandchild
                    }
                }
                if ($textParts.Count -gt 0) {
                    $itemText = $textParts -join ""
                    if ($Node.listType -eq "number") {
                        $items += "${indent}${counter}. $itemText"
                        $counter++
                    } else {
                        $items += "${indent}- $itemText"
                    }
                }
                foreach ($nested in $nestedParts) {
                    $items += $nested
                }
            }
            return ($items -join "`n")
        }
        "listitem" {
            # Handled inline within "list" above
            $parts = @()
            foreach ($child in $Node.children) {
                $parts += ConvertFrom-LexicalNode $child
            }
            return ($parts -join "")
        }
        "table" {
            $rows = @()
            foreach ($row in $Node.children) {
                $cells = @()
                foreach ($cell in $row.children) {
                    $cellParts = @()
                    foreach ($child in $cell.children) {
                        $cellParts += ConvertFrom-LexicalNode $child
                    }
                    $cells += ($cellParts -join " ")
                }
                $rows += "| " + ($cells -join " | ") + " |"
                if ($rows.Count -eq 1) {
                    $rows += "| " + (($cells | ForEach-Object { "---" }) -join " | ") + " |"
                }
            }
            return ($rows -join "`n")
        }
        "tablerow" {
            return ""  # Handled by table
        }
        "tablecell" {
            return ""  # Handled by table
        }
        "linebreak" {
            return "`n"
        }
        "tab" {
            return "`t"
        }
        "snfile" {
            return ""  # Skip embedded file references
        }
        default {
            # Unknown node: try to recurse into children
            if ($Node.children) {
                $parts = @()
                foreach ($child in $Node.children) {
                    $parts += ConvertFrom-LexicalNode $child
                }
                return ($parts -join "")
            }
            return ""
        }
    }
}

function ConvertFrom-LexicalJson {
    param([string]$JsonText)

    $ast = $JsonText | ConvertFrom-Json
    return ConvertFrom-LexicalNode $ast.root
}

function Invoke-ImportNotes {
    param([string]$BackupDir)

    if (-not $BackupDir) {
        Write-Host "Usage: notes import <backup-directory>" -ForegroundColor Red
        return
    }
    if (-not (Test-Path $BackupDir)) {
        Write-Host "Error: Backup directory '$BackupDir' not found." -ForegroundColor Red
        return
    }

    $tagDir  = Join-Path $BackupDir "Items\Tag"
    $noteDir = Join-Path $BackupDir "Items\Note"

    if (-not (Test-Path $noteDir)) {
        Write-Host "Error: No Items\Note directory found in '$BackupDir'." -ForegroundColor Red
        return
    }

    $dir = Ensure-NotesDir

    # --- Build UUID-to-tags mapping from tag files ---
    $uuidTags = @{}
    if (Test-Path $tagDir) {
        foreach ($tagFile in Get-ChildItem -Path $tagDir -Filter "*.txt") {
            $tagJson = Get-Content $tagFile.FullName -Raw | ConvertFrom-Json
            $tagName = $tagJson.title
            foreach ($ref in $tagJson.references) {
                if ($ref.content_type -eq "Note") {
                    $uuid = $ref.uuid
                    if (-not $uuidTags.ContainsKey($uuid)) {
                        $uuidTags[$uuid] = @()
                    }
                    $uuidTags[$uuid] += $tagName
                }
            }
        }
    }

    # --- Process note files ---
    $imported = 0
    $skipped  = 0
    $tagged   = 0
    $usedSlugs = @{}

    # Pre-populate usedSlugs with existing files
    $existingFiles = Get-ChildItem -Path $dir -Filter "*.md" -File -ErrorAction SilentlyContinue
    foreach ($f in $existingFiles) {
        $usedSlugs[$f.BaseName.ToLower()] = $true
    }

    foreach ($noteFile in Get-ChildItem -Path $noteDir -Filter "*.txt" | Sort-Object Name) {
        $content = Get-Content $noteFile.FullName -Raw

        # Skip empty notes
        if (-not $content -or $content.Length -eq 0) {
            $skipped++
            Write-Host "  SKIP (empty): $($noteFile.Name)" -ForegroundColor DarkGray
            continue
        }

        # Extract title: everything before the last -[8hexchars].txt
        $baseName = $noteFile.BaseName
        if ($baseName -match '^(.+)-([0-9a-fA-F]{8})$') {
            $title   = $Matches[1]
            $shortId = $Matches[2]
        } else {
            $title   = $baseName
            $shortId = ""
        }

        # Find tags for this note via the short UUID
        $noteTags = @()
        if ($shortId) {
            foreach ($uuid in $uuidTags.Keys) {
                if ($uuid -like "*$shortId*") {
                    $noteTags += $uuidTags[$uuid]
                }
            }
            $noteTags = @($noteTags | Select-Object -Unique | Sort-Object)
        }

        # Convert content to markdown
        $trimmed = $content.TrimStart()
        if ($trimmed.StartsWith('{"root"')) {
            try {
                $body = ConvertFrom-LexicalJson $content
            } catch {
                $body = $content
            }
        } else {
            $body = $content
        }

        # Build the slug, handling duplicates
        $slug = ConvertTo-Slug $title
        if (-not $slug) {
            $skipped++
            Write-Host "  SKIP (no title): $($noteFile.Name)" -ForegroundColor DarkGray
            continue
        }

        $finalSlug = $slug
        if ($usedSlugs.ContainsKey($finalSlug.ToLower())) {
            $counter = 2
            while ($usedSlugs.ContainsKey("${slug}-${counter}".ToLower())) {
                $counter++
            }
            $finalSlug = "${slug}-${counter}"
            Write-Host "  WARN (duplicate title): '$title' -> ${finalSlug}.md" -ForegroundColor Yellow
        }
        $usedSlugs[$finalSlug.ToLower()] = $true

        # Compose file content
        $lines = @()
        if ($noteTags.Count -gt 0) {
            $lines += ($noteTags | ForEach-Object { "#$_" }) -join " "
            $lines += ""
            $tagged++
        }
        $lines += "# $title"
        $lines += ""
        $lines += $body

        $outPath = Join-Path $dir "$finalSlug.md"
        Set-Content -Path $outPath -Value ($lines -join "`n") -Encoding utf8 -NoNewline

        $imported++
    }

    Write-Host ""
    Write-Host "Import complete: $imported imported, $skipped skipped, $tagged with tags." -ForegroundColor Green
}

# --- Main Dispatch ---

# Normalise $Arguments so .Count always works (even under Set-StrictMode)
if (-not $Arguments) { $Arguments = @() }

# Check for -Force anywhere in the remaining arguments
$forceFlag = $false
if ($Arguments.Count -gt 0 -and ($Arguments -contains '-Force')) {
    $forceFlag = $true
    $Arguments = @($Arguments | Where-Object { $_ -ne '-Force' })
}

$arg = if ($Arguments.Count -gt 0) { $Arguments[0] } else { $null }

switch (($Command ?? '').ToLower()) {
    'add'    { Invoke-AddNote -Title $arg }
    'list'   { Invoke-ListNotes -Pattern $arg }
    'show'   { Invoke-ShowNote -Title $arg }
    'edit'   { Invoke-EditNote -Title $arg }
    'remove' { Invoke-RemoveNote -Title $arg -Force:$forceFlag }
    'search' {
        $searchTag = $null
        $searchArgs = $Arguments
        if ($Arguments -and (Test-IsTagArg $Arguments[0])) {
            $searchTag = Get-TagFromArg $Arguments[0]
            $searchArgs = @($Arguments | Select-Object -Skip 1)
        }
        $searchText = if ($searchArgs) { $searchArgs -join ' ' } else { $null }
        Invoke-SearchNotes -SearchText $searchText -Tag $searchTag
    }
    'check'  { Invoke-CheckNotes }
    'import' { Invoke-ImportNotes -BackupDir $arg }
    'help'   { Show-Help }
    default  { Show-Help }
}
