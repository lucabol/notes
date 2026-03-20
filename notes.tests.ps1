#!/usr/bin/env pwsh
<#
    Pester v5 tests for notes.ps1
    Uses a temp directory for isolation; no editor popups.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'notes.ps1'
    $script:OrigNotesDir = $env:NOTES_DIR
    $script:OrigEditor   = $env:EDITOR

    # Isolated temp dir for every test run
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-tests-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    $env:NOTES_DIR = $script:TempDir

    # No-op editor — a tiny batch file that exits immediately
    $script:NoopEditor = Join-Path $script:TempDir '_noop-editor.cmd'
    Set-Content -Path $script:NoopEditor -Value '@exit /b 0' -Encoding ascii
    $env:EDITOR = $script:NoopEditor

    # ── helpers ──────────────────────────────────────────────────────
    function script:Invoke-Notes {
        param([string[]]$PassArgs)
        & $script:ScriptPath @PassArgs
    }

    function script:New-NoteFile {
        param([string]$Slug, [string]$Content = "# test`nsome body text")
        $path = Join-Path $env:NOTES_DIR "$Slug.md"
        Set-Content -Path $path -Value $Content -Encoding utf8
    }
}

AfterAll {
    # Restore originals
    $env:NOTES_DIR = $script:OrigNotesDir
    $env:EDITOR    = $script:OrigEditor

    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Remove-Item -Recurse -Force $script:TempDir
    }
}

# ── add ──────────────────────────────────────────────────────────────
Describe 'add' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'creates a new note file' {
        Invoke-Notes 'add', 'Hello World'
        Join-Path $env:NOTES_DIR 'hello-world.md' | Should -Exist
    }

    It 'writes a heading into the new note' {
        Invoke-Notes 'add', 'Heading Test'
        $content = Get-Content (Join-Path $env:NOTES_DIR 'heading-test.md') -Raw
        $content | Should -Match '^# Heading Test'
    }

    It 'emits a success message' {
        $out = Invoke-Notes 'add', 'Msg Test' 6>&1
        "$out" | Should -BeLike "*Note 'Msg Test' created*"
    }

    It 'errors when title is missing' {
        $err = Invoke-Notes 'add' 2>&1
        "$err" | Should -BeLike '*Usage*'
    }

    It 'errors on duplicate add' {
        Invoke-Notes 'add', 'Dup'
        $err = Invoke-Notes 'add', 'Dup' 2>&1
        "$err" | Should -BeLike '*already exists*'
    }

    It 'handles special characters in title' {
        Invoke-Notes 'add', 'Café & Résumé!'
        # slug strips non-alphanumeric chars
        Join-Path $env:NOTES_DIR 'caf-rsum.md' | Should -Exist
    }
}

# ── list ─────────────────────────────────────────────────────────────
Describe 'list' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'reports when no notes exist' {
        $out = Invoke-Notes 'list' 6>&1
        "$out" | Should -BeLike '*No notes found*'
    }

    It 'lists note base-names sorted' {
        New-NoteFile 'bravo'
        New-NoteFile 'alpha'
        New-NoteFile 'charlie'
        $out = Invoke-Notes 'list'
        $out | Should -HaveCount 3
        $out[0] | Should -Be 'alpha'
        $out[1] | Should -Be 'bravo'
        $out[2] | Should -Be 'charlie'
    }
}

# ── show ─────────────────────────────────────────────────────────────
Describe 'show' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'displays note content' {
        New-NoteFile 'demo' "# Demo`nLine two"
        $out = Invoke-Notes 'show', 'Demo'
        "$out" | Should -Match 'Demo'
        "$out" | Should -Match 'Line two'
    }

    It 'errors when title is missing' {
        $err = Invoke-Notes 'show' 2>&1
        "$err" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $err = Invoke-Notes 'show', 'Ghost' 2>&1
        "$err" | Should -BeLike '*not found*'
    }
}

# ── edit ─────────────────────────────────────────────────────────────
Describe 'edit' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'opens without error for existing note' {
        New-NoteFile 'edit-me'
        { Invoke-Notes 'edit', 'edit-me' } | Should -Not -Throw
    }

    It 'errors when title is missing' {
        $err = Invoke-Notes 'edit' 2>&1
        "$err" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $err = Invoke-Notes 'edit', 'Nope' 2>&1
        "$err" | Should -BeLike '*not found*'
    }
}

# ── remove ───────────────────────────────────────────────────────────
Describe 'remove' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'removes a note with -Force' {
        New-NoteFile 'bye'
        Invoke-Notes 'remove', 'bye', '-Force'
        Join-Path $env:NOTES_DIR 'bye.md' | Should -Not -Exist
    }

    It 'emits a removed message with -Force' {
        New-NoteFile 'msgdel'
        $out = Invoke-Notes 'remove', 'msgdel', '-Force' 6>&1
        "$out" | Should -BeLike "*removed*"
    }

    It 'errors when title is missing' {
        $err = Invoke-Notes 'remove' 2>&1
        "$err" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $err = Invoke-Notes 'remove', 'Missing', '-Force' 2>&1
        "$err" | Should -BeLike '*not found*'
    }
}

# ── search ───────────────────────────────────────────────────────────
Describe 'search' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -Filter '*.md' | Remove-Item -Force
    }

    It 'finds matching text in notes' {
        New-NoteFile 'alpha' "# Alpha`nThe quick brown fox"
        New-NoteFile 'beta'  "# Beta`nSlow turtle"
        $out = Invoke-Notes 'search', 'quick' 6>&1
        "$out" | Should -Match 'alpha'
    }

    It 'is case-insensitive' {
        New-NoteFile 'case' "# Case`nHeLLo WoRLd"
        $out = Invoke-Notes 'search', 'hello' 6>&1
        "$out" | Should -Match 'case'
    }

    It 'reports no matches when nothing matches' {
        New-NoteFile 'nomatch' "# No match`nnothing here"
        $out = Invoke-Notes 'search', 'zzzzxyz' 6>&1
        "$out" | Should -BeLike '*No matches found*'
    }

    It 'reports no notes when dir is empty' {
        $out = Invoke-Notes 'search', 'anything' 6>&1
        "$out" | Should -BeLike '*No notes found*'
    }

    It 'errors when search text is missing' {
        $err = Invoke-Notes 'search' 2>&1
        "$err" | Should -BeLike '*Usage*'
    }

    It 'searches across multiple words' {
        New-NoteFile 'multi' "# Multi`nfoo bar baz"
        $out = Invoke-Notes 'search', 'foo', 'bar' 6>&1
        "$out" | Should -Match 'multi'
    }
}

# ── help / default ───────────────────────────────────────────────────
Describe 'help and default' {
    It 'shows help with help command' {
        $out = Invoke-Notes 'help' 6>&1
        "$out" | Should -Match 'Usage'
    }

    It 'shows help with no command' {
        $out = Invoke-Notes 6>&1
        "$out" | Should -Match 'Usage'
    }
}
