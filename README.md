# Pensieve

Pensieve is the shareable, iPhone-first version of the personal SecondBrain
workflow. It is currently a local-first SwiftUI iOS app backed by an app-local
JSON store, on-device voice transcription, and user-supplied Anthropic API
calls for note processing, chat, and contradiction analysis.

## Current App Status

Built and tested on a physical iPhone with bundle id
`com.karthikshashidhar.pensieve`.

Implemented:

- Voice capture with local audio recording.
- On-device transcription via WhisperKit.
- Text capture.
- URL capture with Anthropic processing.
- Persistent local store in Application Support:
  `Pensieve/local-store.json`.
- Anthropic API key storage in Keychain.
- Capture processing into structured notes.
- Retrieval-backed chat over saved notes.
- Notes tab.
- Wiki tab.
- Insights tab with local corpus summaries and generated source-backed insights.
- Review tab for pending insights, topic pages needing attention, likely open loops, and a small tensions section.
- Mindmap tab grouped by generated topics when available, with theme fallback.
- Contradictions tab backed by saved contradiction records.
- Contradiction detail pages with linked source notes and review status.
- Manual contradiction backfill from the note corpus.
- One-time SecondBrain raw markdown import.
- JSON backup export through the iOS Files sheet.
- JSON backup restore through the iOS Files picker.
- Backup schema versioning for forward migration.
- Chat source citations that open the referenced notes.
- Manual corpus analysis into reviewable insights.
- Manual topic cleanup preview and apply flow into canonical themes and generated Wiki topics.
- Topic cleanup diagnostics showing LLM vs local fallback, affected notes, generated topics, largest groups, and run time.
- Generated topic pages link to related insights and contradictions.
- Single-topic refresh from a generated Wiki topic page.
- Topic-level review state: pending, useful, stale, needs refresh, dismissed.

Not yet implemented:

- SQLite/GRDB storage and migrations.
- Automatic contradiction scans after every capture/import.
- Durable background processing.
- True graph layout for the mindmap.
- TestFlight/App Store packaging.
- OpenAI provider.

## How The App Works Today

### Automatic / Live

- **Notes** update when captures are processed or imported.
- **Wiki** is a live view over saved notes. It does not call an LLM.
- **Mindmap** is a live view over note themes. It does not call an LLM.
  When generated Wiki topics exist, Mindmap uses those topic buckets instead
  of raw themes.
- **Insights** is a live local analysis view over saved notes and contradictions.
- **Chat** retrieves locally saved notes, then sends the question and selected
  context notes to Anthropic.

### Manual

- **SecondBrain import** is a one-time migration action in Settings.
- **Contradiction analysis** runs only when `Settings -> Find Contradictions`
  is tapped.
- **Corpus analysis** runs only when `Settings -> Analyze Corpus` is tapped.
  It generates source-backed insights and stores them locally.
- **Topic cleanup** runs only when `Settings -> Preview Topic Cleanup` is
  tapped and is not applied until `Apply Topic Cleanup` is tapped. It
  consolidates overlapping note themes and generates source-backed Wiki topic
  pages. The current implementation asks the LLM for a compact taxonomy,
  assigns all notes into that taxonomy locally, then asks the LLM to write
  topic pages for the resulting groups. This keeps the expensive LLM work
  bounded while still avoiding hundreds of overlapping raw themes.
- **Single-topic refresh** runs only from a generated Wiki topic page and
  regenerates that page from its linked source notes.
- **Backup export** runs only when `Settings -> Export Pensieve Backup` is
  tapped.
- **Backup restore** runs only when `Settings -> Restore Pensieve Backup` is
  tapped and replaces the local store with the selected JSON backup.

Contradiction analysis is manual for now because it can be slow and costs API
tokens. The current implementation keeps the screen awake while the analysis
runs and retries once after a transient failure.

## App Screens

- **Capture**: record voice, save text, or save URL notes.
- **Notes**: flat list of processed/imported notes.
- **Wiki**: generated topic pages when topic cleanup has run, otherwise a
  browsable theme wiki. Repeated themes are shown first in fallback mode,
  ordered by note count. One-off themes are hidden behind a
  `Show one-off themes` row. Search covers note title, summary, body, themes,
  and generated topics.
- **Insights**: local dashboard for recurring themes, recently active themes,
  generated insights, open-loop-like notes, decision/plan notes, and unresolved
  contradictions.
- **Review**: queue for pending insights, generated topic pages needing
  attention, likely open-loop notes, and a small tensions-to-inspect section.
- **Chat**: ask questions against the saved note corpus.
- **Contradictions**: shows saved contradiction records generated by the manual
  analysis pass, with detail views for source notes and review/dismiss status.
- **Mindmap**: generated-topic note browser after topic cleanup, with raw theme
  grouping as fallback.
- **Settings**: API key, backup export, contradiction analysis, and one-time
  SecondBrain import.

## Current Topic Cleanup Flow

`Settings -> Clean Up Topics` is the main taxonomy maintenance action.

The flow is:

1. Send a compact note digest to Anthropic and request 8-16 canonical topics.
2. Assign every local note to one to three of those topics using local scoring
   over note title, summary, body, current themes, topic title, aliases, and
   related terms.
3. Rewrite each note's themes to the cleaned canonical topics.
4. Generate and persist source-backed `WikiTopic` pages for the largest topics.
5. Refresh Wiki and Mindmap from the saved topics.

If the LLM taxonomy request fails, the app falls back to a bounded local
taxonomy so cleanup still finishes.

After topic cleanup runs:

- Wiki should show generated topic pages.
- Mindmap should show grouped topic sections sorted by note count.
- Notes should have fewer, broader themes.

## One-Time SecondBrain Import

The migration imports raw markdown notes from the personal SecondBrain Obsidian
corpus. The source folder used for testing was:

```text
/Users/Karthik/Library/Mobile Documents/iCloud~md~obsidian/Documents/SecondBrain/raw
```

The importer reads `.md` files, parses frontmatter where present, extracts
summary/transcription/raw input sections, and writes duplicate-safe captures and
notes into the local Pensieve store. It keys imported notes with
`sourceIdentifier` values like:

```text
secondbrain/raw/<filename>.md
```

This import button is migration-only and can be removed after the corpus is
successfully moved into Pensieve.

## Backup

Settings includes `Export Pensieve Backup`, which exports the entire local
store as JSON:

- captures
- notes
- contradictions
- insights
- wiki topics
- chat messages

Backups include a `schemaVersion` field. Existing unversioned backups are still
readable as version 1 snapshots.

The backup file is saved through the iOS Files exporter and should be placed in
iCloud Drive or another durable location. Settings also includes
`Restore Pensieve Backup`, which imports one of these JSON files and replaces
the app-local store.

## Development

Generate the Xcode project:

```sh
xcodegen generate
```

Build for the connected iPhone:

```sh
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'id=00008110-000948390C6A801E' -allowProvisioningUpdates build
```

Install the latest debug build:

```sh
xcrun devicectl device install app --device 00008110-000948390C6A801E /Users/Karthik/Library/Developer/Xcode/DerivedData/Pensieve-exjgoqfjmokqludlhbdjgmaokfcc/Build/Products/Debug-iphoneos/Pensieve.app
```

Launch while the phone is unlocked:

```sh
xcrun devicectl device process launch --device 00008110-000948390C6A801E com.karthikshashidhar.pensieve
```

If `devicectl` reports the device is locked, unlock the phone and open the app
manually. The install can succeed even when command-line launch fails.

## Context

The current `SecondBrain` app is a personal workflow:

```text
iPhone app
  records voice, captures text/URLs, transcribes voice locally
        ↓
Obsidian/iCloud markdown vault
  raw notes are written as markdown files
        ↓
Mac launchd job
  runs pensieve-ingest against the vault
        ↓
Obsidian wiki
  themes, timeline, contradictions, mindmap, logs
```

That is good for one trusted power user, but too fragile for TestFlight or App
Store distribution. It assumes the user has an Obsidian vault, iCloud folder
access, a Mac, a launchd job, local scripts, and a particular markdown layout.

Pensieve should be a separate app, not a direct continuation of that workflow.
`SecondBrain` remains the personal Obsidian/Mac stack. `Pensieve` becomes the
clean local-first iPhone product.

## Product Direction

Pensieve is a local-first memory app for iPhone.

Inputs:

- Voice notes
- Text notes
- URL notes

Processing:

- Voice is transcribed on device.
- URL content is fetched/extracted into readable text.
- Captures are processed with an LLM.
- Notes, derived memory state, chat history, contradictions, and mindmap state
  are stored locally on the iPhone.

Views:

- Capture
- Notes
- Wiki
- Chat
- Contradictions
- Mindmap
- Settings

The product should not require Obsidian, iCloud folders, a Mac helper process,
Full Disk Access, launchd, or manual filesystem setup.

## Privacy Position

The accurate positioning is:

```text
Local-first app, cloud LLM processing.
```

On device:

- Audio recording
- Whisper transcription
- Text and URL capture
- Local note database
- Search / retrieval index
- Chat UI
- Contradictions state
- Mindmap state

Remote:

- Anthropic API for note processing, contradiction detection, memory updates,
  and chat answers

Important privacy copy for TestFlight and later App Store builds:

- Audio stays on device.
- Voice transcription happens on device.
- Notes are stored on device.
- Text selected for processing is sent to Anthropic using the user's API key.
- No shared developer-owned Anthropic API key should ship in the app.

For the first shareable version, use BYO Anthropic API key stored in Keychain.
Later, the app can add OpenAI or a backend-owned LLM gateway if the product
direction justifies it.

## Target Architecture

```text
Pensieve iOS app
  Capture UI
  AudioRecorder
  WhisperTranscriber
  URLTextExtractor
  LocalStore
  MemoryIndexer
  LLMProvider
  MemoryEngine
  ChatEngine
```

High-level flow:

```text
User records voice / enters text / enters URL
        ↓
Save raw capture locally
        ↓
Normalize input
  voice -> on-device transcript
  url   -> readable article text + user note
  text  -> raw text
        ↓
Send normalized input to Anthropic
        ↓
Receive structured result / patch
        ↓
Apply result to local store
        ↓
Update Notes, Themes, Contradictions, Mindmap, Chat context
```

## Storage

Use an app-native local store as the source of truth. Do not use markdown files
as canonical storage in Pensieve.

Preferred first choice: SQLite via GRDB.

Reasoning:

- The app will need stable migrations.
- Notes, captures, themes, contradictions, and chat history are relational.
- Chat needs local retrieval.
- Search should eventually use SQLite FTS.
- Mindmap views need graph-ish queries over notes, themes, and edges.
- SQLite is more explicit and controllable than SwiftData for this product.

Potential local schema:

```text
captures
  id
  type                  voice | text | url
  created_at
  raw_text
  transcript
  source_urls
  audio_file_path
  processing_status     pending | processing | processed | failed
  error_message

notes
  id
  capture_id
  title
  summary
  body
  emotional_tone
  created_at
  updated_at

note_themes
  note_id
  theme_id

themes
  id
  name
  current_state
  source_count
  created_at
  updated_at

contradictions
  id
  topic
  before_note_id
  after_note_id
  explanation
  status                unresolved | reviewed | dismissed
  confidence
  created_at
  updated_at

mindmap_nodes
  id
  kind                  note | theme | contradiction | insight
  ref_id
  label
  metadata_json

mindmap_edges
  id
  source_node_id
  target_node_id
  kind
  weight
  metadata_json

chat_threads
  id
  title
  created_at
  updated_at

chat_messages
  id
  thread_id
  role                  user | assistant | system
  content
  context_note_ids
  created_at
```

Audio files can live in app documents/application support with database rows
pointing to the local file path.

## LLM Provider Layer

Use Anthropic as the first and only LLM implementation, but design the boundary
so OpenAI can be added later.

```swift
protocol LLMProvider {
    func processCapture(_ input: CaptureProcessingInput) async throws -> CaptureProcessingResult
    func chat(_ request: ChatRequest) async throws -> ChatResponse
    func findContradictions(in notes: [MemoryNote]) async throws -> [Contradiction]
}
```

Initial implementation:

```swift
final class AnthropicProvider: LLMProvider {
    // Claude API implementation
}
```

Future implementation:

```swift
final class OpenAIProvider: LLMProvider {
    // OpenAI API implementation
}
```

The app should not spread Anthropic-specific request/response details across
views or storage code. Anthropic should be behind the provider boundary.

## Chat

Chat should use local retrieval. Do not send the whole note database to the LLM
on every message.

Flow:

```text
User asks a question
        ↓
MemoryIndexer searches local notes/themes/contradictions
        ↓
Select compact source excerpts
        ↓
Send question + selected context to Anthropic
        ↓
Receive answer
        ↓
Store chat message and source references locally
```

First retrieval implementation can be simple:

- SQLite FTS over notes, transcripts, summaries, and theme names
- Select top matching notes
- Include source ids and short excerpts in the prompt

Later retrieval can add:

- Embeddings
- Hybrid keyword/vector search
- Theme-aware search
- Time-aware search
- User-pinned memories

## Tabs

### Capture

Primary capture surface.

Expected controls:

- Record / stop voice note
- Text input
- URL input
- Processing status
- Recent capture queue

The capture workflow should stay lower friction than any downstream
architecture concern.

### Notes

Reverse chronological memory list.

Expected views:

- Note list
- Note detail
- Source transcript/raw text
- Themes
- Related notes
- Processing status/errors

### Wiki

Browse the saved note corpus as a lightweight personal wiki.

Current behavior:

- Repeated themes are shown first, ordered by note count.
- One-off themes are hidden behind a disclosure row.
- Search covers note title, summary, body, and themes.
- Theme pages link to the notes in that theme.

### Chat

Question-answering over the local memory store using Anthropic.

Expected behavior:

- Persist chat threads locally
- Retrieve local context before each answer
- Show source notes used for an answer
- Avoid pretending the model knows notes that were not retrieved

### Contradictions

Surface source-backed shifts, reversals, or tensions in the user's thinking.

Expected states:

- Unresolved
- Reviewed
- Dismissed

Each contradiction should show:

- Topic
- Earlier position with source note/date
- Later position with source note/date
- Explanation of the tension
- Confidence/status

Contradictions are trust-sensitive. They must be auditable and easy to inspect.

### Mindmap

Visual graph of memory structure.

Initial version can be simple:

- Themes as primary nodes
- Notes connected to themes
- Contradictions connected to relevant themes/notes

Avoid making the first version too elaborate. The first goal is useful
navigation, not a beautiful graph engine.

### Settings

Expected settings:

- Anthropic API key
- LLM provider selection, initially Anthropic only
- Privacy explanation
- Export Pensieve backup
- One-time SecondBrain import while migration is still needed
- Manual contradiction analysis/backfill
- Delete all local data
- Optional Obsidian/markdown export later
- Diagnostics for failed processing

API keys must be stored in Keychain, not UserDefaults.

## Relationship To Existing Code

Potentially reusable from `SecondBrain`:

- `AudioRecorderService`
- `TranscriptionService`
- WhisperKit model loading and caching approach
- Text and URL capture UI ideas
- Claude client request patterns
- Existing prompt ideas from `PensieveIngestCore`
- Structured patch concept from `IngestionPatch`

Do not directly reuse as canonical architecture:

- `ObsidianStorageService`
- `VaultReader`
- `VaultWriter`
- Markdown vault as source of truth
- Mac `launchd` ingestion assumption

The old ingestion code is useful as a reference for prompts and memory update
semantics, but Pensieve should apply patches to the local store rather than to
markdown files.

## MVP Build Plan

### Phase 1: New App Skeleton

- Create a new iOS app target/folder named `Pensieve`.
- Bundle id: `com.karthikshashidhar.pensieve`.
- Use the paid Apple Developer team.
- Add tabs: Capture, Notes, Wiki, Chat, Contradictions, Mindmap, Settings.
- Add basic app icon/display name/versioning.

### Phase 2: Local Capture

- Voice recording.
- On-device Whisper transcription.
- Text capture.
- URL capture.
- Save raw captures locally.
- Show capture status and recent captures.

### Phase 3: Local Store

- Add SQLite/GRDB.
- Create migrations for captures and notes.
- Store audio file references.
- Store processed note fields.
- Add basic Notes tab backed by local database.

### Phase 4: Anthropic Processing

- Store Anthropic API key in Keychain.
- Add `LLMProvider` protocol.
- Add `AnthropicProvider`.
- Process captures into structured notes.
- Persist notes, themes, and source links locally.
- Add processing error handling and retry.

### Phase 5: Chat

- Add chat threads/messages.
- Add local retrieval over notes.
- Send compact context to Anthropic.
- Store answers and source references.

### Phase 6: Wiki

- Add a wiki browser over saved notes.
- Group notes by recurring themes.
- Keep search available across the full corpus.

### Phase 7: Contradictions

- Extend capture processing or memory update prompts to identify
  contradictions.
- Store source-backed contradictions locally.
- Add Contradictions tab with review/dismiss states.

### Phase 8: Mindmap

- Store graph nodes/edges locally.
- Add simple visual graph/tab.
- Connect notes, themes, contradictions, and insights.

### Phase 9: TestFlight Readiness

- Add privacy copy.
- Add export/delete data controls.
- Add first-run API key setup.
- Add graceful handling for no API key / bad API key / no network.
- Archive and upload to App Store Connect.
- Start with internal TestFlight.

## Deliberately Deferred

Do not start with:

- Backend accounts
- Subscriptions
- Shared developer-owned Anthropic key
- CloudKit sync
- OpenAI implementation
- Web app
- Team/multi-user features
- Obsidian as required setup

These can come later if real usage justifies them.

## Current Decision Summary

- Build a new app named `Pensieve`.
- Keep `SecondBrain` as the personal app.
- Pensieve is local-first but uses Anthropic for LLM processing and chat.
- Use on-device transcription for voice.
- Store notes and memory state on device.
- Build provider-neutral LLM interfaces, Anthropic first, OpenAI later.
- Use local retrieval for chat rather than sending the whole database.
- Use Obsidian/markdown only as an optional export path later.
