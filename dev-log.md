# Second Brain - Dev Log

## Project Genesis

**Date:** 2026-04-07 to 2026-04-09
**Built with:** Claude Code (Claude Opus 4.6)

---

## Context

Karthik shared a link to Andrej Karpathy's viral "LLM Wiki" gist - a pattern for building personal knowledge bases where an LLM incrementally builds and maintains a structured wiki from raw sources, rather than doing RAG-style retrieval from scratch every time.

The conversation evolved from "how do I use this?" into designing a personal system. The key constraint: Karthik has ADHD and his therapist recommended a "safe second brain" but didn't say how to implement it. The problem wasn't just note-taking - it was tracking how his thinking evolves over time (especially around career decisions) and spotting when he's going in circles.

## Prompts and Decisions

### Session 1 (2026-04-07)

**Prompt:** "this seems to have gone viral. how can i use it? [karpathy gist link]"

Fetched the gist, summarized the LLM Wiki pattern, asked what domain to apply it to.

**Prompt:** "Okay, do I know what to use this for?"

Checked memory - knew about writing voice, data science background, Babbage Insight. Suggested a research/writing wiki since his writing is built on cross-domain connections.

**Prompt:** [Long voice-transcribed message about ADHD, therapist's recommendation, needing zero-friction input, existing voice notes app]

This was the key design moment. Three critical constraints emerged:
1. Input must be dead simple (just talk)
2. The system must organize itself (no manual categorization)
3. Need to track thought evolution and circular patterns

Found the existing NotesAgent app at `/Users/Karthik/Documents/work/NotesAgent/`. Read through the full codebase - iOS app records audio, syncs to Mac via TCP, Mac runs Whisper + Ollama, saves to Apple Notes.

**Decision: Redesign the architecture.** The TCP sync was fragile (Mac had to be running). New approach: do everything on the phone.
- WhisperKit for on-device transcription (no network needed)
- Claude API instead of Ollama (better at nuanced theme extraction, and user is fine paying for API)
- Save markdown to Obsidian vault instead of Apple Notes
- Eliminate Mac server entirely

**Prompt:** "I don't know how much space I have on my iCloud drive and stuff"

Addressed the iCloud concern - markdown files are ~3KB each, even years of heavy use would be under 100MB. Obsidian on iOS syncs vaults via iCloud for free (not Obsidian Sync, which is paid).

**Prompt:** "can you create a folder for this, start coding, write the documentation..."

Built the entire project structure in one session:
- 11 Swift source files (models, services, views)
- Wiki scaffold (CLAUDE.md schema, index, timeline, contradictions page)
- Implementation plan
- Karpathy gist saved as reference
- README with architecture diagram

Key architectural decisions:
- `ThoughtCaptureService` orchestrates the pipeline: record → transcribe → Claude API → save markdown
- `ClaudeProcessingService` returns structured JSON: title, summary, themes, emotional tone, key quotes, connections
- `ObsidianStorageService` writes markdown with YAML frontmatter to the vault's raw directory
- Wiki CLAUDE.md schema includes rules like "never judge", "flag patterns don't prescribe", "the contradictions page is the most valuable page"

### Session 2 (2026-04-09)

**Prompt:** "ok let's set this up today"

Started with Xcode project generation. Had `xcodegen` available, so generated the project from a `project.yml` spec.

**Build issues encountered (and resolved):**
1. Bundle ID `com.secondbrain.app` was taken on Apple's servers → changed to `com.karthikshashidhar.secondbrain`
2. iOS 26.4 platform wasn't properly installed in Xcode → ran `xcodebuild -downloadPlatform iOS` (8.46 GB download)
3. Transitive SPM dependency issue (OrderedCollections not resolving for swift-jinja) → added swift-collections as explicit dependency
4. Precompiled module errors with yyjson → resolved after iOS platform install enabled scheme-based builds

**Build succeeded** after platform install. Deployed to phone.

**Prompt:** "it says 'no audio context was detected'"

First recording attempt failed. Likely tapped too quickly - needed to hold long enough for actual audio.

**Prompt:** "can you provide clean buttons both for start/stop and hold to record?"

Redesigned RecordingView with two recording modes:
1. Hold-to-record (press and hold mic button, release to stop)
2. Tap start/stop (explicit start button, then red stop button appears)

**Bug fix:** `isConfigured` property wasn't `@Published`, so the UI didn't update when the API key was saved. Settings showed "Configured" but the main screen button stayed gray. Fixed by making it a `@Published` stored property.

**Layout fix:** Notes list was overlapping the recording buttons because RecordingView had a `maxHeight: 280` constraint that was too small for the new two-button layout. Changed to `fixedSize(horizontal: false, vertical: true)` so the recording area takes the space it needs.

## Technical Notes

### Why WhisperKit over Apple Speech Framework
WhisperKit runs OpenAI's Whisper models on the iPhone's Neural Engine. Better accuracy than Apple's built-in speech recognition, especially for stream-of-consciousness speech with mixed vocabulary. Runs fully on-device - no network needed for transcription.

### Why Claude API over local Ollama
The original NotesAgent used Ollama (qwen2.5:7b-instruct) for summarization. For the second brain, we need more nuanced processing - theme extraction, emotional tone detection, identifying connections to other topics. Claude is significantly better at this kind of structured analysis. Also eliminates the Mac dependency since Ollama only ran on the Mac server.

### Wiki Schema Design (CLAUDE.md)
The CLAUDE.md is the most important file in the project. It tells Claude Code how to maintain the wiki. Key design choices:
- Theme pages are chronological within - each entry is dated, showing evolution
- `> [!shift]` and `> [!contradiction]` callouts for when thinking changes
- Contradictions page is explicitly called out as "the most valuable page"
- Rule: "Never judge. This is a safe space."
- Rule: "Flag patterns, don't prescribe."
- Wikilinks (`[[page]]`) for Obsidian graph view compatibility

### Obsidian Sync Strategy
Three options documented in the plan:
1. iCloud via Obsidian (simplest - Obsidian on iOS stores vaults in iCloud by default)
2. Manual file transfer via Finder
3. Dedicated iCloud container

Went with option 1 as the recommended approach. Storage is negligible (~3KB per note).

## Stack

- **iOS App:** Swift, SwiftUI, iOS 17+
- **On-device transcription:** WhisperKit (Whisper base model, ~150MB)
- **Theme extraction:** Claude API (claude-sonnet-4-6)
- **Wiki browser:** Obsidian (free)
- **Wiki maintenance:** Claude Code
- **Project generation:** xcodegen
