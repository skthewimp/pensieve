# Second Brain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a voice-driven personal wiki ("second brain") that captures thoughts via an iPhone app, processes them with on-device transcription and Claude API, and saves structured markdown to an Obsidian vault for wiki maintenance by Claude Code.

**Architecture:** iOS app (SwiftUI) records audio → WhisperKit transcribes on-device → Claude API extracts themes/summary/tone → markdown saved to Obsidian vault directory → Claude Code on Mac ingests raw notes into a structured wiki with cross-references, contradiction tracking, and timeline.

**Tech Stack:** Swift/SwiftUI (iOS 17+), WhisperKit (on-device Whisper), Claude API (Anthropic), Obsidian (wiki browser), Claude Code (wiki maintenance)

---

### Task 1: Create Xcode Project

**Files:**
- Create: Xcode project `SecondBrain.xcodeproj` (via Xcode GUI)

All Swift source files are already written in `iOS/SecondBrain/`. This task creates the Xcode project to build them.

- [ ] **Step 1: Open Xcode and create new iOS App project**
  - Product Name: `SecondBrain`
  - Team: Karthik's development team (6APL9VM8C3)
  - Organization Identifier: `com.secondbrain`
  - Interface: SwiftUI
  - Language: Swift
  - Deployment Target: iOS 17.0
  - Save into: `/Users/Karthik/Documents/work/SecondBrain/iOS/`

- [ ] **Step 2: Delete Xcode's auto-generated files**
  - Delete the auto-generated `ContentView.swift`, `SecondBrainApp.swift`, etc.
  - Drag in all files from `iOS/SecondBrain/` (Models/, Services/, Views/, SecondBrainApp.swift, Info.plist)

- [ ] **Step 3: Add WhisperKit SPM dependency**
  - File → Add Package Dependencies
  - URL: `https://github.com/argmaxinc/WhisperKit`
  - Version: Up to Next Major (latest)
  - Add to target: SecondBrain

- [ ] **Step 4: Build and fix any compile errors**
  - Target should be an actual iPhone (WhisperKit requires arm64)
  - Fix any import or API issues

- [ ] **Step 5: Commit**
  ```bash
  git add iOS/
  git commit -m "feat: create Xcode project with WhisperKit dependency"
  ```

---

### Task 2: Test Audio Recording

- [ ] **Step 1: Run on iPhone, test recording**
  - Grant microphone permission
  - Record a short thought
  - Verify audio file saved

- [ ] **Step 2: Verify recording appears in list**

---

### Task 3: Test Transcription Pipeline

- [ ] **Step 1: Record a thought and verify WhisperKit transcribes it**
  - First run will download the Whisper model (~150MB)
  - Check that transcription appears in note detail view

- [ ] **Step 2: If transcription quality is poor, upgrade model**
  - In `TranscriptionService.swift`, change `"base"` to `"small"` for better accuracy
  - Trade-off: slower but more accurate

---

### Task 4: Test Claude API Integration

- [ ] **Step 1: Get Anthropic API key from console.anthropic.com**

- [ ] **Step 2: Enter API key in app Settings**

- [ ] **Step 3: Record a thought and verify full pipeline completes**
  - Status should progress: Recorded → Transcribing → Thinking → Saving → Done
  - Check note detail view shows themes, summary, emotional tone

- [ ] **Step 4: Verify markdown file created**
  - Connect phone to Mac via Finder
  - Navigate to SecondBrain app container → Documents → SecondBrainVault → raw/
  - Verify .md file exists with correct format

---

### Task 5: Set Up Obsidian Vault Sync

Two options depending on preference:

**Option A: iCloud (recommended, minimal space used)**

- [ ] **Step 1: Move vault to iCloud container**
  - Modify `ObsidianStorageService.swift` to use iCloud container URL instead of local Documents
  - Add iCloud capability to Xcode project (CloudKit or iCloud Documents)
  - The vault will be ~KB in size even after hundreds of notes

- [ ] **Step 2: Open vault in Obsidian on Mac**
  - Install Obsidian on Mac if needed
  - Open vault from: `~/Library/Mobile Documents/iCloud~com~secondbrain/Documents/SecondBrainVault/`

**Option B: Manual file transfer (no cloud)**

- [ ] **Step 1: Connect phone to Mac via Finder**
  - Go to phone → Files → SecondBrain
  - Drag `SecondBrainVault` folder to Mac at `~/Documents/work/SecondBrain/wiki/`

- [ ] **Step 2: Open vault in Obsidian on Mac**

**Option C: Obsidian with iCloud vault (simplest)**

- [ ] **Step 1: Install Obsidian on iPhone**
- [ ] **Step 2: Create vault in Obsidian (stored in iCloud by default)**
- [ ] **Step 3: Modify `ObsidianStorageService.swift` to write directly to Obsidian's iCloud vault location**
  - Path: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/SecondBrain/`
- [ ] **Step 4: Open same vault on Mac via Obsidian**

---

### Task 6: Set Up Wiki Ingestion on Mac

**Files:**
- Already created: `wiki/CLAUDE.md` (schema)
- Already created: `wiki/wiki/index.md`, `log.md`, `timeline.md`, `tensions/contradictions.md`

- [ ] **Step 1: Open Claude Code in the wiki directory**
  ```bash
  cd ~/Documents/work/SecondBrain/wiki
  claude
  ```

- [ ] **Step 2: Test ingestion with a sample raw note**
  - Create a test note in `raw/2026-04-07_test.md`
  - Tell Claude: "ingest new notes"
  - Verify Claude creates/updates theme pages, timeline, index, log

- [ ] **Step 3: Iterate on CLAUDE.md schema**
  - Adjust based on what works and what doesn't
  - The schema is meant to be co-evolved with use

---

### Task 7: (Optional) Automate Ingestion

- [ ] **Step 1: Create a cron job or Claude Code scheduled trigger**
  ```bash
  # Option: cron job that runs Claude Code ingestion daily
  # Or use Claude Code's /schedule feature
  ```

- [ ] **Step 2: Or just run manually**
  - `cd ~/Documents/work/SecondBrain/wiki && claude "ingest any new notes from raw/"`
  - This is fine for now; automate later if needed

---

## Notes

### Storage math (why iCloud space is not a concern)
- Each raw note markdown: ~2-3 KB
- 10 notes/day × 365 days = 3,650 files × 3 KB = ~11 MB/year
- Wiki pages (themes, tensions, etc.): maybe 50 KB total
- Even after years of heavy use: < 100 MB
- Free iCloud tier is 5 GB

### What's NOT in this plan
- macOS server app (eliminated — everything runs on phone)
- TCP sync (eliminated — using file system/iCloud)
- Ollama dependency (eliminated — using Claude API)
- Apple Notes integration (eliminated — using Obsidian)

### Privacy
- Audio: stays on phone, never uploaded
- Transcription: runs on phone via WhisperKit (no network)
- Only the transcription TEXT is sent to Claude API for theme extraction
- Markdown files sync via iCloud (encrypted in transit and at rest by Apple)
