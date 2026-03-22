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

    # No-op editor — a tiny batch file that exits immediately (outside notes dir)
    $script:NoopEditor = Join-Path ([System.IO.Path]::GetTempPath()) "notes-noop-editor-$([guid]::NewGuid().ToString('N')).cmd"
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
    if ($script:NoopEditor -and (Test-Path $script:NoopEditor)) {
        Remove-Item -Force $script:NoopEditor
    }
}

# ── add ──────────────────────────────────────────────────────────────
Describe 'add' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
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
        $out = Invoke-Notes 'add' 6>&1
        "$out" | Should -BeLike '*Usage*'
    }

    It 'errors on duplicate add' {
        Invoke-Notes 'add', 'Dup'
        $out = Invoke-Notes 'add', 'Dup' 6>&1
        "$out" | Should -BeLike '*already exists*'
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
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'reports when no notes exist' {
        $out = Invoke-Notes 'list' 6>&1
        "$out" | Should -BeLike '*No notes found*'
    }

    It 'lists note names sorted' {
        New-NoteFile 'bravo'
        New-NoteFile 'alpha'
        New-NoteFile 'charlie'
        $out = Invoke-Notes 'list'
        $out | Should -HaveCount 3
        $out[0] | Should -Be 'alpha.md'
        $out[1] | Should -Be 'bravo.md'
        $out[2] | Should -Be 'charlie.md'
    }
}

# ── show ─────────────────────────────────────────────────────────────
Describe 'show' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'displays note content' {
        New-NoteFile 'demo' "# Demo`nLine two"
        $out = Invoke-Notes 'show', 'Demo'
        "$out" | Should -Match 'Demo'
        "$out" | Should -Match 'Line two'
    }

    It 'errors when title is missing' {
        $out = Invoke-Notes 'show' 6>&1
        "$out" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $out = Invoke-Notes 'show', 'Ghost' 6>&1
        "$out" | Should -BeLike '*not found*'
    }
}

# ── edit ─────────────────────────────────────────────────────────────
Describe 'edit' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'opens without error for existing note' {
        New-NoteFile 'edit-me'
        { Invoke-Notes 'edit', 'edit-me' } | Should -Not -Throw
    }

    It 'errors when title is missing' {
        $out = Invoke-Notes 'edit' 6>&1
        "$out" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $out = Invoke-Notes 'edit', 'Nope' 6>&1
        "$out" | Should -BeLike '*not found*'
    }
}

# ── remove ───────────────────────────────────────────────────────────
Describe 'remove' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
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
        $out = Invoke-Notes 'remove' 6>&1
        "$out" | Should -BeLike '*Usage*'
    }

    It 'errors when note does not exist' {
        $out = Invoke-Notes 'remove', 'Missing', '-Force' 6>&1
        "$out" | Should -BeLike '*not found*'
    }
}

# ── search ───────────────────────────────────────────────────────────
Describe 'search' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
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
        $out = Invoke-Notes 'search' 6>&1
        "$out" | Should -BeLike '*Usage*'
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

# ── check ────────────────────────────────────────────────────────────
Describe 'check' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'reports directory path from NOTES_DIR and OK status with note count' {
        New-NoteFile 'one'
        New-NoteFile 'two'
        $out = Invoke-Notes 'check' 6>&1
        "$out" | Should -Match 'NOTES_DIR'
        "$out" | Should -Match 'OK'
        "$out" | Should -Match '2 note'
    }

    It 'reports OK with 0 notes when directory is empty' {
        $out = Invoke-Notes 'check' 6>&1
        "$out" | Should -Match 'OK'
        "$out" | Should -Match '0 note'
    }

    It 'reports NOT FOUND when directory does not exist' {
        $saved = $env:NOTES_DIR
        $env:NOTES_DIR = Join-Path ([System.IO.Path]::GetTempPath()) "notes-nonexistent-$([guid]::NewGuid().ToString('N'))"
        try {
            $out = Invoke-Notes 'check' 6>&1
            "$out" | Should -Match 'NOT FOUND'
        } finally {
            $env:NOTES_DIR = $saved
        }
    }
}

# ── list with pattern ────────────────────────────────────────────────
Describe 'list with pattern' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'filters notes by filename pattern' {
        New-NoteFile 'alpha-one'
        New-NoteFile 'alpha-two'
        New-NoteFile 'beta-one'
        $out = Invoke-Notes 'list', 'alpha'
        $out | Should -HaveCount 2
        $out[0] | Should -Be 'alpha-one.md'
        $out[1] | Should -Be 'alpha-two.md'
    }

    It 'reports no matches for unmatched pattern' {
        New-NoteFile 'alpha'
        $out = Invoke-Notes 'list', 'zzz' 6>&1
        "$out" | Should -BeLike "*No notes matching*"
    }

    It 'pattern filtering is case-insensitive' {
        New-NoteFile 'alpha-note'
        $out = @(Invoke-Notes 'list', 'ALPHA')
        $out | Should -HaveCount 1
        $out[0] | Should -Be 'alpha-note.md'
    }
}

# ── tag operations ───────────────────────────────────────────────────
Describe 'tag operations' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    Context 'list with tag filter' {
        It 'list +tag returns only tagged notes' {
            New-NoteFile 'chess-opening' "#Chess`n# Chess Opening`nContent"
            New-NoteFile 'recipe' "#Cooking`n# Recipe`nContent"
            New-NoteFile 'plain' "# Plain`nNo tags"
            $out = @(Invoke-Notes 'list', '+Chess')
            $out | Should -HaveCount 1
            $out[0] | Should -Be 'chess-opening.md'
        }

        It 'list tag:tag filters by tag' {
            New-NoteFile 'chess-opening' "#Chess`n# Chess Opening`nContent"
            New-NoteFile 'recipe' "#Cooking`n# Recipe`nContent"
            $out = @(Invoke-Notes 'list', 'tag:Chess')
            $out | Should -HaveCount 1
            $out[0] | Should -Be 'chess-opening.md'
        }

        It 'list #tag filters by tag' {
            New-NoteFile 'chess-opening' "#Chess`n# Chess Opening`nContent"
            $out = Invoke-Notes 'list', '#Chess'
            $out | Should -HaveCount 1
        }

        It 'reports no tagged notes when tag is not found' {
            New-NoteFile 'alpha' "# Alpha`nContent"
            $out = Invoke-Notes 'list', '+NoSuchTag' 6>&1
            "$out" | Should -BeLike "*No notes tagged*"
        }

        It 'finds notes with multiple tags on first line' {
            New-NoteFile 'multi' "#Chess #Opening`n# Multi-tagged`nContent"
            $out1 = Invoke-Notes 'list', '+Chess'
            $out1 | Should -HaveCount 1
            $out2 = Invoke-Notes 'list', '+Opening'
            $out2 | Should -HaveCount 1
        }

        It 'tag matching is case-insensitive' {
            New-NoteFile 'chess' "#Chess`n# Chess`nContent"
            $out = Invoke-Notes 'list', '+chess'
            $out | Should -HaveCount 1
        }

        It 'does not match tag beyond the first line' {
            New-NoteFile 'tricky' "# Title`n#Chess`nContent"
            $out = Invoke-Notes 'list', '+Chess' 6>&1
            "$out" | Should -BeLike "*No notes tagged*"
        }
    }

    Context 'show with tag' {
        It 'show +tag displays the tagged note' {
            New-NoteFile 'chess-opening' "#Chess`n# Chess Opening`nSicilian defense"
            $out = Invoke-Notes 'show', '+Chess'
            "$out" | Should -Match 'Sicilian defense'
        }

        It 'show +tag errors when no notes have that tag' {
            New-NoteFile 'alpha' "# Alpha`nContent"
            $out = Invoke-Notes 'show', '+NoSuchTag' 6>&1
            "$out" | Should -BeLike "*No notes tagged*"
        }
    }

    Context 'search with tag' {
        It 'search +tag text only searches tagged notes' {
            New-NoteFile 'chess' "#Chess`n# Chess`nSicilian defense"
            New-NoteFile 'recipe' "#Cooking`n# Recipe`nChicken curry"
            $out = Invoke-Notes 'search', '+Chess', 'Sicilian' 6>&1
            "$out" | Should -Match 'chess'
            "$out" | Should -Not -Match 'recipe'
        }

        It 'search +tag reports no tagged notes when tag not found' {
            New-NoteFile 'alpha' "# Alpha`nContent"
            $out = Invoke-Notes 'search', '+NoSuchTag', 'anything' 6>&1
            "$out" | Should -BeLike "*No notes tagged*"
        }

        It 'search +tag reports no matches when text not found in tagged notes' {
            New-NoteFile 'chess' "#Chess`n# Chess`nSicilian defense"
            $out = Invoke-Notes 'search', '+Chess', 'zzzzxyz' 6>&1
            "$out" | Should -BeLike '*No matches found*'
        }
    }
}

# ── import ───────────────────────────────────────────────────────────
Describe 'import' {
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'errors when no backup dir is given' {
        $out = Invoke-Notes 'import' 6>&1
        "$out" | Should -BeLike '*Usage*'
    }

    It 'errors when backup dir does not exist' {
        $out = Invoke-Notes 'import', 'C:\nonexistent-path-xyz' 6>&1
        "$out" | Should -BeLike '*not found*'
    }

    It 'errors when Items\Note is missing' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -BeLike '*No Items*Note directory*'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'imports a plain text note' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        Set-Content -Path (Join-Path $noteDir 'My Note-abcd1234.txt') -Value 'Hello world' -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            Join-Path $env:NOTES_DIR 'my-note.md' | Should -Exist
            $content = Get-Content (Join-Path $env:NOTES_DIR 'my-note.md') -Raw
            $content | Should -Match '# My Note'
            $content | Should -Match 'Hello world'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'skips empty note files' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        # Create a truly empty (0-byte) file
        New-Item -ItemType File -Path (Join-Path $noteDir 'Empty-abcd1234.txt') -Force | Out-Null
        Set-Content -Path (Join-Path $noteDir 'Notempty-efgh5678.txt') -Value 'content' -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            "$out" | Should -Match '1 skipped'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'handles duplicate slugs by appending a number' {
        New-NoteFile 'my-note' "# Existing note"
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        Set-Content -Path (Join-Path $noteDir 'My Note-abcd1234.txt') -Value 'New content' -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            Join-Path $env:NOTES_DIR 'my-note-2.md' | Should -Exist
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'applies tags from tag files' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        $tagDir  = Join-Path $backupDir 'Items\Tag'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tagDir  -Force | Out-Null
        Set-Content -Path (Join-Path $noteDir 'My Note-abcd1234.txt') -Value 'Some content' -Encoding utf8
        $tagJson = @{
            title = "Chess"
            references = @(
                @{ content_type = "Note"; uuid = "xxxx-xxxx-abcd1234" }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $tagDir 'Chess-tag12345.txt') -Value $tagJson -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            "$out" | Should -Match '1 with tags'
            $content = Get-Content (Join-Path $env:NOTES_DIR 'my-note.md') -Raw
            $content | Should -Match '#Chess'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'converts Lexical JSON notes to markdown' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        $lexicalJson = @{
            root = @{
                type = "root"
                children = @(
                    @{
                        type = "paragraph"
                        children = @(
                            @{ type = "text"; text = "Hello world"; format = 0 }
                        )
                    }
                )
            }
        } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $noteDir 'Lexical Test-abcd1234.txt') -Value $lexicalJson -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            $content = Get-Content (Join-Path $env:NOTES_DIR 'lexical-test.md') -Raw
            $content | Should -Match 'Hello world'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }

    It 'imports a note without hex suffix in filename' {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "notes-import-test-$([guid]::NewGuid().ToString('N'))"
        $noteDir = Join-Path $backupDir 'Items\Note'
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
        Set-Content -Path (Join-Path $noteDir 'SimpleNote.txt') -Value 'Plain body' -Encoding utf8
        try {
            $out = Invoke-Notes 'import', $backupDir 6>&1
            "$out" | Should -Match '1 imported'
            Join-Path $env:NOTES_DIR 'simplenote.md' | Should -Exist
            $content = Get-Content (Join-Path $env:NOTES_DIR 'simplenote.md') -Raw
            $content | Should -Match '# SimpleNote'
        } finally {
            Remove-Item $backupDir -Recurse -Force
        }
    }
}

# ── ConvertTo-Slug edge cases ────────────────────────────────────────
Describe 'ConvertTo-Slug edge cases' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    It 'collapses multiple spaces into single hyphens' {
        ConvertTo-Slug 'Hello   World' | Should -Be 'hello-world'
    }

    It 'trims leading and trailing whitespace' {
        ConvertTo-Slug '  Hello World  ' | Should -Be 'hello-world'
    }

    It 'returns empty string for all special characters' {
        ConvertTo-Slug '@#$%^&*()' | Should -Be ''
    }

    It 'returns empty string for empty input' {
        ConvertTo-Slug '' | Should -Be ''
    }

    It 'strips non-ASCII unicode characters' {
        ConvertTo-Slug 'Héllo Wörld' | Should -Be 'hllo-wrld'
    }

    It 'handles mixed case with numbers' {
        ConvertTo-Slug 'Note 42 About Stuff' | Should -Be 'note-42-about-stuff'
    }

    It 'collapses multiple hyphens' {
        ConvertTo-Slug 'Hello---World' | Should -Be 'hello-world'
    }

    It 'trims leading and trailing hyphens' {
        ConvertTo-Slug '-hello-' | Should -Be 'hello'
    }
}

# ── ConvertFrom-LexicalNode / ConvertFrom-LexicalJson ────────────────
Describe 'Lexical JSON conversion' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    It 'converts plain text paragraph' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"Hello world","format":0}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be 'Hello world'
    }

    It 'converts bold text (format 1)' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"bold","format":1}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be '**bold**'
    }

    It 'converts italic text (format 2)' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"italic","format":2}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be '*italic*'
    }

    It 'converts bold+italic text (format 3)' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"both","format":3}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be '***both***'
    }

    It 'converts a link node' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"link","url":"https://example.com","children":[{"type":"text","text":"click","format":0}]}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be '[click](https://example.com)'
    }

    It 'converts an autolink node' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"autolink","url":"https://example.com"}]}]}}'
        ConvertFrom-LexicalJson $json | Should -Be 'https://example.com'
    }

    It 'joins multiple paragraphs with double newline' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"Para 1","format":0}]},{"type":"paragraph","children":[{"type":"text","text":"Para 2","format":0}]}]}}'
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Be "Para 1`n`nPara 2"
    }

    It 'converts unordered list' {
        $json = @{
            root = @{
                type = "root"
                children = @(
                    @{
                        type = "list"
                        listType = "bullet"
                        children = @(
                            @{ type = "listitem"; indent = 0; children = @(@{ type = "text"; text = "Item A"; format = 0 }) }
                            @{ type = "listitem"; indent = 0; children = @(@{ type = "text"; text = "Item B"; format = 0 }) }
                        )
                    }
                )
            }
        } | ConvertTo-Json -Depth 10
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Match '- Item A'
        $result | Should -Match '- Item B'
    }

    It 'converts ordered list' {
        $json = @{
            root = @{
                type = "root"
                children = @(
                    @{
                        type = "list"
                        listType = "number"
                        children = @(
                            @{ type = "listitem"; indent = 0; children = @(@{ type = "text"; text = "First"; format = 0 }) }
                            @{ type = "listitem"; indent = 0; children = @(@{ type = "text"; text = "Second"; format = 0 }) }
                        )
                    }
                )
            }
        } | ConvertTo-Json -Depth 10
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Match '1\. First'
        $result | Should -Match '2\. Second'
    }

    It 'converts a table with header separator' {
        $json = @{
            root = @{
                type = "root"
                children = @(
                    @{
                        type = "table"
                        children = @(
                            @{
                                type = "tablerow"
                                children = @(
                                    @{ type = "tablecell"; children = @(@{ type = "paragraph"; children = @(@{ type = "text"; text = "H1"; format = 0 }) }) }
                                    @{ type = "tablecell"; children = @(@{ type = "paragraph"; children = @(@{ type = "text"; text = "H2"; format = 0 }) }) }
                                )
                            }
                            @{
                                type = "tablerow"
                                children = @(
                                    @{ type = "tablecell"; children = @(@{ type = "paragraph"; children = @(@{ type = "text"; text = "C1"; format = 0 }) }) }
                                    @{ type = "tablecell"; children = @(@{ type = "paragraph"; children = @(@{ type = "text"; text = "C2"; format = 0 }) }) }
                                )
                            }
                        )
                    }
                )
            }
        } | ConvertTo-Json -Depth 15
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Match 'H1'
        $result | Should -Match '---'
        $result | Should -Match 'C1'
    }

    It 'returns empty string for null node' {
        ConvertFrom-LexicalNode $null | Should -Be ''
    }

    It 'handles linebreak node' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"before","format":0},{"type":"linebreak"},{"type":"text","text":"after","format":0}]}]}}'
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Match 'before'
        $result | Should -Match 'after'
    }

    It 'skips snfile nodes' {
        $json = '{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"visible","format":0},{"type":"snfile"}]}]}}'
        $result = ConvertFrom-LexicalJson $json
        $result | Should -Be 'visible'
    }
}

# ── Get-TagFromArg / Test-IsTagArg ──────────────────────────────────
Describe 'tag argument helpers' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    Context 'Get-TagFromArg' {
        It 'parses #tag prefix' {
            Get-TagFromArg '#Chess' | Should -Be 'Chess'
        }

        It 'parses +tag prefix' {
            Get-TagFromArg '+Chess' | Should -Be 'Chess'
        }

        It 'parses tag: prefix' {
            Get-TagFromArg 'tag:Chess' | Should -Be 'Chess'
        }

        It 'returns null for plain text' {
            Get-TagFromArg 'Chess' | Should -BeNullOrEmpty
        }
    }

    Context 'Test-IsTagArg' {
        It 'returns true for #tag' {
            Test-IsTagArg '#Chess' | Should -BeTrue
        }

        It 'returns true for +tag' {
            Test-IsTagArg '+Chess' | Should -BeTrue
        }

        It 'returns true for tag:tag' {
            Test-IsTagArg 'tag:Chess' | Should -BeTrue
        }

        It 'returns false for plain text' {
            Test-IsTagArg 'Chess' | Should -BeFalse
        }
    }
}

# ── Find-NotePath ────────────────────────────────────────────────────
Describe 'Find-NotePath' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }
    BeforeEach {
        Get-ChildItem $env:NOTES_DIR -File | Remove-Item -Force
    }

    It 'exact filename match' {
        New-NoteFile 'hello-world'
        $result = Find-NotePath 'hello-world.md'
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'hello-world.md'
    }

    It 'slug basename match' {
        New-NoteFile 'hello-world'
        $result = Find-NotePath 'Hello World'
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'hello-world.md'
    }

    It 'partial substring match on filename' {
        New-NoteFile 'hello-world'
        $result = Find-NotePath 'hello'
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'hello-world.md'
    }

    It 'partial slug match on basename' {
        New-NoteFile 'hello-world-notes'
        $result = Find-NotePath 'Hello World'
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'hello-world-notes.md'
    }

    It 'returns empty array when no match' {
        New-NoteFile 'hello-world'
        $result = Find-NotePath 'zzz-no-match'
        $result | Should -HaveCount 0
    }

    It 'returns empty array when directory is empty' {
        $result = Find-NotePath 'anything'
        $result | Should -HaveCount 0
    }
}

# ── Get-Editor ───────────────────────────────────────────────────────
Describe 'Get-Editor' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
        $script:SavedEditor = $env:EDITOR
        $script:SavedVisual = $env:VISUAL
    }
    AfterAll {
        $env:EDITOR = $script:SavedEditor
        $env:VISUAL = $script:SavedVisual
    }

    It 'returns EDITOR when set' {
        $env:EDITOR = 'myeditor'
        $env:VISUAL = 'myvisual'
        Get-Editor | Should -Be 'myeditor'
    }

    It 'falls back to VISUAL when EDITOR not set' {
        $env:EDITOR = ''
        $env:VISUAL = 'myvisual'
        Get-Editor | Should -Be 'myvisual'
    }

    It 'falls back to notepad when neither set' {
        $env:EDITOR = ''
        $env:VISUAL = ''
        Get-Editor | Should -Be 'notepad'
    }
}

# ── Get-Pager ────────────────────────────────────────────────────────
Describe 'Get-Pager' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
        $script:SavedPager = $env:PAGER
    }
    AfterAll {
        $env:PAGER = $script:SavedPager
    }

    It 'returns PAGER when set' {
        $env:PAGER = 'mypager'
        Get-Pager | Should -Be 'mypager'
    }

    It 'falls back to more.com when not set' {
        $env:PAGER = ''
        Get-Pager | Should -Be 'more.com'
    }
}

# ── Send-ToPager ─────────────────────────────────────────────────────
Describe 'Send-ToPager' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    It 'outputs all lines when output is redirected' {
        $lines = @('line one', 'line two', 'line three')
        $result = Send-ToPager -Lines $lines
        $result | Should -HaveCount 3
        $result[0] | Should -Be 'line one'
        $result[2] | Should -Be 'line three'
    }
}

# ── Get-NoteFilename / Get-NotePath ─────────────────────────────────
Describe 'Get-NoteFilename' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    It 'returns slug with .md extension' {
        Get-NoteFilename 'Hello World' | Should -Be 'hello-world.md'
    }

    It 'handles special characters' {
        Get-NoteFilename 'My Note!@#' | Should -Be 'my-note.md'
    }
}

Describe 'Get-NotePath' {
    BeforeAll {
        . $script:ScriptPath 'help' 6>&1 | Out-Null
    }

    It 'returns full path under NOTES_DIR' {
        $expected = Join-Path $env:NOTES_DIR 'hello-world.md'
        Get-NotePath 'Hello World' | Should -Be $expected
    }
}
