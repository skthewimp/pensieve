# Pensieve Dev Log

## 2026-05-17 13:55 IST

### User prompts

> ok let's do one thing. just for ME< let's import all the raw notes from SecondBrain (there is a fair corpus there) so we can test all teh capabitlies.

> btw this import is a one time thing. because i sued a differnet version of this. after this is done, this button can go. that said - we need a way to backup the notes.

> ok the notes have been imported but nothing in my contradictions / etc.

> network connection got lost ehwnee my phone went to sleep

> ok great. are you building the wiki as well? if so that also needds to be accessibl from the app

> whoa there's way too many things in the wiki. but ordering it by number of things is good. also - when does the wiki and contradictions run? is therea n automatic thing to this

> ok great. document evertyt hing and push to git.

### Work done

- Published the standalone app to the new `skthewimp/pensieve` GitHub repo after moving the previous `pensieve` repo aside as `SecondBrain`.
- Added persistent JSON storage in Application Support.
- Added Keychain-backed Anthropic API key settings.
- Wired real Anthropic processing for text and URL captures.
- Added audio recording and on-device WhisperKit transcription for voice notes.
- Added retrieval-backed chat over locally saved notes.
- Added a one-time SecondBrain raw markdown importer.
- Imported the existing personal corpus from the iCloud/Obsidian raw notes folder on-device.
- Added duplicate-safe imported note upserts via `sourceIdentifier`.
- Added full-store JSON backup export through the iOS Files sheet.
- Added manual contradiction analysis/backfill over the imported note corpus.
- Added one retry for contradiction analysis and disabled auto-sleep while the analysis is running.
- Added a Wiki tab backed by saved notes.
- Reduced Wiki theme noise by showing repeated themes first, ordered by note count, with one-off themes hidden behind a disclosure row.
- Updated `README.md` with current app state, manual vs automatic behavior, backup/import details, and on-device build/install commands.

### Current behavior

- Wiki is automatic/live from saved notes and themes.
- Mindmap is automatic/live from saved note themes.
- Notes are automatic after capture processing or import.
- Chat is user-triggered and sends selected note context to Anthropic.
- Contradictions are manual via `Settings -> Find Contradictions`.
- Backup is manual via `Settings -> Export Pensieve Backup`.
- SecondBrain import is a one-time migration tool and can be removed after the corpus is safely migrated.

### Verification

Physical-device builds succeeded with:

```text
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'id=00008110-000948390C6A801E' -allowProvisioningUpdates build
```

The debug app was installed repeatedly on Karthik's connected iPhone with
`xcrun devicectl device install app`. Command-line launch sometimes failed when
the device was locked or the device tunnel timed out, but installation
succeeded.

### Remaining gaps

- Add backup restore.
- Move storage from JSON to SQLite/GRDB with migrations.
- Add post-import/post-capture analysis prompts or automatic analysis settings.
- Add contradiction review/dismiss/detail UI.
- Improve mindmap beyond theme grouping.
- Remove the one-time SecondBrain importer after migration.
- Package for TestFlight.

## 2026-05-17 11:30 IST

### User prompts

> ok let's do one thing . let's rebuild for this. maybe make a separte app actually called 'Pensieve' (let the secondbrain be my personal app). way i'm thinking about this is - everything one the iphone. voice transcriptions; text/  url inputs; on device transcription of voice, get text from URLs, etc. and create notes and store tehm on device.  and then there will be a chatbot within the app. contradictions tab. mindmap tab. etc. etc

> on device chat also can go thorugh anthropic API itself. we'll just use Anthropic as LLM of cohice now. later on extend it to openai also.

> ok great. now create a separate Pensieve folder where we'll build this. summarise this conversation into a markdown that can be put there so that we can start wokr onthis. be detailed.

> wait - pensieve is in which folder? don't nest it inside here.

> ok great. let's siwthc to that folder and start building.

### Decisions

- Keep `SecondBrain` as the personal Obsidian/Mac workflow.
- Build `Pensieve` as a separate iPhone-first app in `/Users/Karthik/Documents/work/Pensieve`.
- Position the app as local-first with cloud LLM processing.
- Use on-device transcription for voice.
- Store captures, notes, chat history, contradictions, and mindmap state locally.
- Use Anthropic as the first LLM provider.
- Keep the LLM boundary provider-neutral so OpenAI can be added later.
- Use Obsidian/markdown only as an optional export path later, not as the source of truth.

### Work done

- Created standalone project folder.
- Added detailed architecture brief in `README.md`.
- Scaffolded a SwiftUI iOS app with XcodeGen.
- Added bundle id `com.karthikshashidhar.pensieve`.
- Set Apple Developer team to `DQ23J9RMB2`.
- Added the initial tab shell:
  - Capture
  - Notes
  - Chat
  - Contradictions
  - Mindmap
  - Settings
- Added initial domain models:
  - `Capture`
  - `MemoryNote`
  - `Contradiction`
  - `ChatMessage`
- Added initial service boundaries:
  - `LocalStore`
  - `InMemoryLocalStore`
  - `LLMProvider`
  - `AnthropicProvider`
  - `CaptureService`
- Generated `Pensieve.xcodeproj`.
- Ran a simulator build check successfully.
- Initialized git in the standalone Pensieve folder.

### Problems hit

- The first scaffold accidentally landed inside the old `SecondBrain` folder because the editing tool was still rooted there.
- Moved the generated scaffold out to `/Users/Karthik/Documents/work/Pensieve`.
- Restored `SecondBrain` to a clean git state after the move.
- The first `xcodebuild` attempt failed because sandboxing blocked Xcode from writing DerivedData and SourcePackages. Reran with approval and the build succeeded.

### Verification

```text
xcodegen generate
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'generic/platform=iOS Simulator' build
```

Result: build succeeded.

### Next steps

- Replace `InMemoryLocalStore` with SQLite/GRDB.
- Add Keychain storage for the Anthropic API key.
- Port the working audio recording and Whisper transcription path from `SecondBrain`.
- Add URL fetching/readability extraction.
- Replace placeholder `AnthropicProvider` with the real Claude API implementation.
- Add local retrieval for chat.
