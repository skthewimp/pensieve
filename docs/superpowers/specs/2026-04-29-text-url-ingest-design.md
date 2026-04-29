# Text + URL Ingest — Design

**Status:** approved
**Date:** 2026-04-29

## Motivation

Pensieve currently captures only voice. Two real gaps:

1. Loud / public environments where speaking out loud isn't an option.
2. Reacting to something I just read on the web. The URL + my take are both
   signal; today I'd have to record a voice note describing the article.

Also: the main app screen currently devotes most of its real estate to a list
of old notes. That list is rarely useful at capture time. Reclaim that space
for a text box.

## Scope

In:
- New text-input surface on the iOS main screen
- Free-form text submission (no URL)
- Free-form text + one or more URLs in the same submission
- Article fetching via Claude `web_fetch` tool (server-side)
- Same downstream wiki / mindmap ingest pipeline as voice notes

Out (deferred):
- Auto-retry of failed `article_fetched: false` notes
- Share-sheet extension from Safari / other apps
- Pure-URL submissions without any user text (allowed structurally, but no
  special UI affordance for it)
- Mac CLI variant (`pensieve-add`)

## UI

`ContentView`:

- Top: existing record button (unchanged).
- Below: multiline `TextEditor` with placeholder
  `"type a thought, paste a link, or both…"` and a Submit button.
- Toolbar: a notes-list nav icon that pushes the existing `NotesListView`.
  `NotesListView` is currently embedded in `ContentView`; un-embed it.
- Settings icon stays in toolbar.

Submit flow:

1. User taps Submit.
2. URLs extracted from the raw string via `NSDataDetector(types: .link)`.
3. New `ThoughtNote` created with `source = .text` if no URLs, else `.url`.
4. Text box clears immediately. Note appears in `NotesListView` with
   `processing` status.
5. `ClaudeProcessingService` invoked — same status state machine as voice
   notes (transcription stage skipped). `auto-resume stuck notes on launch`
   already covers crash recovery (commit `4a5cc65`).

## Models

`ThoughtNote.swift` additions:

```swift
enum Source: String, Codable { case voice, text, url }

var source: Source
var urls: [URL]              // empty for voice / text
var articleFetched: Bool?    // nil for voice / text; true|false for url
```

## Raw markdown frontmatter

Body schema (title / themes / quotes / connections) is **unchanged**. The
wiki ingest pipeline reads it the same way it reads voice notes.

New frontmatter fields:

```yaml
source: url            # voice | text | url
urls:
  - https://example.com/article
article_fetched: false # only present when source: url
```

## Services

No new service classes. All work fits into existing files.

`ThoughtCaptureService`:

- New entry point: `func submitText(_ raw: String)`.
- Detects URLs, builds `ThoughtNote`, appends to list, hands off to
  `ClaudeProcessingService`.

`ClaudeProcessingService`:

- One method, branches on `note.source`:
  - `voice`: existing prompt, transcript as input.
  - `text`: same prompt, user-typed text replaces the transcript slot.
  - `url`: prompt variant adds the URL list and instructs Claude to fetch
    each article and treat the user's text as their reaction.
- For `url` notes, request includes the `web_fetch` tool:
  ```json
  { "type": "web_fetch_20250910", "name": "web_fetch", "max_uses": <urls.count> }
  ```
- If any URL fails to fetch, Claude is instructed to proceed with remaining
  articles + user text. The response sets `article_fetched: false` on the
  note when any failure occurred.

`ObsidianStorageService.writeNote`:

- Extended to emit the new frontmatter fields.
- No path changes — raw notes still land in `raw/YYYY-MM-DD-HHmm.md`.

No new `@Published` properties on child services, so the
nested-ObservableObject forwarding pattern (the project's most common bug)
is not touched.

## Failure handling

URL fetch failure (paywall, 404, timeout):

- Note is saved anyway.
- Themes/quotes are derived from user text only.
- Frontmatter records `article_fetched: false`.
- No automatic retry in this build.

Multiple URLs in one submission:

- All fetched. Treated as one note with multiple sources.
- Partial failures: `article_fetched: false` if any URL failed; the body
  cites whichever articles were fetched.

Submit with empty text and no URL:

- Submit button disabled.

## Wiki ingest impact

`pensieve-ingest` (Mac side):

- `VaultReader` already passes the full raw note (frontmatter + body) to
  Claude. No code change there — Claude sees `source:` and `urls:`
  naturally.
- `Prompts.swift` system prompt gets one-line addition: raw notes may have
  `source: url` with a `urls:` list; cite the URL in log entries and
  contradictions where relevant.
- `IngestionPatch` and `VaultWriter`: no schema change. URLs flow through
  as cited markdown.
- Mindmap pass: untouched. Tree built from theme content, not source type.

Net Mac-side change: ~5 lines in `Prompts.swift`.

## Testing

Manual only (project has no automated tests).

iOS:

- Text-only submission → raw note has `source: text`, no `urls`.
- Text + URL submission → `source: url`, article fetched, themes
  incorporate the article.
- Paywalled URL (e.g. NYT) → `article_fetched: false`, note still saved,
  themes derived from user text.
- Multi-URL submission with one paywalled and one open → both attempted,
  open one cited, `article_fetched: false`.

Mac ingest:

- Run `pensieve-ingest` on a vault containing mixed source types. Verify
  `log.md` cites URLs for url-sourced notes.

## Out of scope (explicitly)

- Share-sheet extension
- Pure-URL "save for later" UI
- Article re-fetch / retry flow
- Mac CLI ingest entry point
- Read-it-later queue separate from notes list
