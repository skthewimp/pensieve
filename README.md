# Pensieve

Pensieve is the planned shareable, iPhone-first version of the personal
SecondBrain app.

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
    func updateMemory(_ request: MemoryUpdateRequest) async throws -> MemoryPatch
    func chat(_ request: ChatRequest) async throws -> ChatResponse
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
- Export data
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
- Add tabs: Capture, Notes, Chat, Contradictions, Mindmap, Settings.
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

### Phase 6: Contradictions

- Extend capture processing or memory update prompts to identify
  contradictions.
- Store source-backed contradictions locally.
- Add Contradictions tab with review/dismiss states.

### Phase 7: Mindmap

- Store graph nodes/edges locally.
- Add simple visual graph/tab.
- Connect notes, themes, contradictions, and insights.

### Phase 8: TestFlight Readiness

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
