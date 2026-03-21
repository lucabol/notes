# Pager Support for Visualization Commands

**Date:** 2025-07-22 · **Author:** Morpheus · **Status:** Proposed

## Decision

Added pager support to `show`, `list`, and `search` commands via `Get-Pager` and `Send-ToPager` helper functions.

## Approach

- **Default pager:** `more.com` (Windows). Override via `$env:PAGER`.
- **Pager invocation:** Only when content exceeds the terminal screen height (`[Console]::WindowHeight - 2` lines). Small output goes straight to `Write-Output`.
- **Redirected output:** When `[Console]::IsOutputRedirected` is `$true` (pipes, CI), pager is skipped — plain `Write-Output` is used.
- **Search refactored:** `Invoke-SearchNotes` was changed from `Write-Host` with color parameters to `Write-Output` with plain-text lines, making the output pageable and pipeline-friendly.

## Testability

The pager is never invoked during tests because:
1. Test data is small (fits on one screen), so the size threshold prevents pager use.
2. `[Console]::IsOutputRedirected` provides an additional safety check for CI/pipe contexts.

All 26 existing tests pass without modification.

## Trade-offs

- Search output no longer has colored highlights. Acceptable since pager compatibility and pipeline-friendliness outweigh the cosmetic benefit.
- If `[Console]::WindowHeight` cannot be read (no console), falls back to plain `Write-Output`.
