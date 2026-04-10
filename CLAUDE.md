# Pensieve — Project Guide

Voice-driven personal wiki. Talk into your phone, a structured wiki builds itself.

## Architecture

```
Phone (iOS)                              Mac
┌─────────────────────┐                 ┌────────────────────────────┐
│ 1. Record voice     │                 │ Obsidian (browse wiki)     │
│ 2. WhisperKit       │   iCloud sync   │                            │
│    (on-device)      │   via Obsidian  │ Daily launchd (10:17am):   │
│ 3. Claude API       │ ─────────────→  │   pensieve-ingest (Swift)  │
│    (theme extract)  │                 │   → direct Claude API call │
│ 4. Save .md to      │                 │   → applies JSON patch     │
│    Obsidian vault   │                 │                            │
└─────────────────────┘                 └────────────────────────────┘
```

### Phone pipeline
Record audio → WhisperKit transcribes on-device → Claude API (claude-sonnet-4-6) extracts title, themes, emotional tone, key quotes, connections → saves structured markdown to `raw/` in Obsidian vault.

### Mac wiki ingestion
`scripts/pensieve-ingest/` is a Swift Package. The `pensieve-ingest` binary (installed to `~/.local/bin/`) runs daily via a launchd user agent at `~/Library/LaunchAgents/com.karthikshashidhar.pensieve.ingest.plist`. It finds unprocessed notes in `raw/` (by diffing against `wiki/log.md`), makes a single direct Claude API call with the wiki state + new notes, and applies the returned JSON patch to theme pages, timeline, contradictions, log, and index. `PensieveIngestCore` (the library target) is platform-agnostic so it can be imported into the iOS app for phone-only ingestion later.

Requires Full Disk Access granted to `/Users/Karthik/.local/bin/pensieve-ingest` so launchd-spawned runs can access the iCloud vault. API key is set via `ANTHROPIC_API_KEY` in the launchd plist's `EnvironmentVariables`.

### Obsidian vault location
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/SecondBrain/`

Syncs automatically between phone and Mac via iCloud.

## Code Layout

```
iOS/
  SecondBrain/
    SecondBrainApp.swift          # App entry point
    Models/
      ThoughtNote.swift           # Note model with processing status
      ClaudeResponse.swift        # Claude API request/response types
    Services/
      ThoughtCaptureService.swift # Main orchestrator (record→transcribe→process→save)
      AudioRecorderService.swift  # AVAudioRecorder wrapper
      TranscriptionService.swift  # WhisperKit integration
      ClaudeProcessingService.swift # Claude API for theme extraction
      ObsidianStorageService.swift  # Vault linking, markdown file writing
    Views/
      ContentView.swift           # Main screen (nav title: "Pensieve")
      RecordingView.swift         # Start/stop recording UI
      NotesListView.swift         # List of captured notes
      NoteDetailView.swift        # Single note detail
      SettingsView.swift          # API key, vault picker, vault sync, stats
  project.yml                    # xcodegen spec
  SecondBrain.xcodeproj/         # Generated Xcode project

wiki/
  CLAUDE.md                      # Wiki maintenance schema (for Claude Code ingestion)
  raw/                           # Raw voice note markdowns (auto-populated)
  wiki/                          # LLM-maintained wiki pages
    index.md
    timeline.md
    log.md
    themes/                      # Topic pages (career, ai, consulting, etc.)
    tensions/
      contradictions.md          # The most important page
    insights/

scripts/
  pensieve-ingest/                 # Swift Package
    Package.swift
    Sources/
      PensieveIngest/              # CLI entry point (main.swift)
      PensieveIngestCore/          # Reusable library
        IngestEngine.swift         # Orchestrator
        ClaudeClient.swift         # Direct Anthropic API client
        VaultReader.swift          # Reads raw/ and wiki/ files
        VaultWriter.swift          # Applies IngestionPatch to the vault
        Prompts.swift              # System + user prompts
        Models.swift               # RawNote, IngestionPatch, etc.
```

## Key Technical Details

### Build & deploy
- Bundle ID: `com.karthikshashidhar.secondbrain`
- Team: `6APL9VM8C3`
- Build: `xcodegen generate` then `xcodebuild -project SecondBrain.xcodeproj -scheme SecondBrain`
- Phone device ID may change; use `xcrun xctrace list devices` to find current ID
- `xcodebuild install` wipes app data including cached WhisperKit model

### SwiftUI nested ObservableObject pattern
SwiftUI does NOT observe `@Published` properties on nested `ObservableObject`s. `ThoughtCaptureService` holds `audioRecorder` and `storageService` as plain properties. Their published state must be forwarded via Combine:

```swift
storageService.$isVaultLinked
    .receive(on: DispatchQueue.main)
    .assign(to: &$isVaultLinked)
```

This has been the single most common bug in this project. If adding new observable state to a child service, it MUST be forwarded through `ThoughtCaptureService`.

### WhisperKit model persistence
The model (~150MB) downloads from HuggingFace on first launch and caches in `Documents/huggingface/models/`. The code checks for cached `.mlmodelc` files before downloading. Only re-downloads if cache is empty (e.g., after app reinstall).

### Obsidian vault linking
Uses iOS security-scoped bookmarks to persist folder access. User picks vault via `UIDocumentPickerViewController`, app saves bookmark to `UserDefaults`. On launch, restores bookmark and re-accesses the folder.

## Current State (April 2026)

- App is functional, installed on user's phone
- Wiki ingestion rewritten as a Swift binary (`pensieve-ingest`) that does a single direct Claude API call — ~33x cheaper than the old agentic Claude Code path (~$0.01/note vs ~$0.36/note on a measured 10-note run)
- User is in "collect data for a week" mode — do NOT add features unless asked

### Pending manual action
**Grant Full Disk Access to `/Users/Karthik/.local/bin/pensieve-ingest`** in System Settings → Privacy & Security → Full Disk Access. Until this is done, the daily 10:17am launchd run will fail with "Operation not permitted" because launchd-spawned binaries can't read the iCloud Obsidian vault without FDA. Test after granting: `launchctl kickstart -k gui/$(id -u)/com.karthikshashidhar.pensieve.ingest && sleep 3 && cat /tmp/pensieve-ingest.log`

### Deferred work (user explicitly deferred these)
1. **Retrieval/resurfacing** — daily digests, "you're going in circles" alerts, related past notes on new capture. Waiting for usage data.
2. **Phone-only wiki ingestion** — currently needs Mac. Path is now clear: `PensieveIngestCore` is platform-agnostic and can be imported into the iOS app as a local SPM dependency via `project.yml`. The nontrivial part is swapping `FileManager` direct paths for the iOS security-scoped bookmark code that already exists in `ObsidianStorageService.swift`.
3. **Prompt caching optimization** — current runs show `cache_read/write: 0/0` because the system prompt is under the 1024-token cache minimum. Padding the system prompt with concrete examples (or caching the user-message block containing the wiki state) would cut cost by another ~30-50%. Not urgent at current cost level.
4. **Action item routing** — extract tasks from notes, push to external systems.
5. **Blog post revision** — first draft written, may revise after more usage.

## GitHub
Repo: `github.com/skthewimp/pensieve`
