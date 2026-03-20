# Squad Decisions

## Active Decisions

### CLI Design — Slug Format, Defaults, Editor Chain

**Date:** 2025-03-20 · **Author:** Morpheus · **Status:** Accepted

- **Slug format:** lowercase, spaces→hyphens, strip non-alphanumeric (except hyphens), collapse consecutive hyphens, trim edges. E.g. `"Hello World 2024!"` → `hello-world-2024.md`.
- **Notes directory:** `$env:NOTES_DIR` if set; otherwise `$HOME/notes`. Auto-created on first use.
- **Editor fallback:** `$env:EDITOR` → `$env:VISUAL` → `notepad`.
- **Script structure:** `param()` with positional `$Command`/`$Arguments`; `-Force` parsed from remaining args; each command is a separate function dispatched via `switch`.
- **Search:** Case-insensitive regex (`-imatch`) with `[regex]::Escape()`.
- **Add:** Creates file with `# Title` heading before opening editor; rejects duplicate slugs.

### Test Strategy — Pester v5, 26 Tests

**Date:** 2025-07-13 · **Author:** Tank · **Status:** Accepted

- **Isolation:** Each run uses a unique temp dir via `$env:NOTES_DIR`; cleaned in `AfterAll`.
- **Non-interactive:** No-op batch script as `$env:EDITOR` so add/edit never open a real editor.
- **Cleanup:** `BeforeEach` wipes `*.md` to prevent cross-test pollution.
- **Coverage:** All 6 commands + help/default; happy paths, missing args, not-found, duplicates, special chars.
- **Known gaps:** `remove` without `-Force` (needs `Read-Host` mock), concurrent access, very long titles, editor integration verification.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
