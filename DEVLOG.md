# Pensieve Dev Log

## 2026-05-20 22:55 IST - voice-lock-fix

### User prompts

> Finding one bug. When I try to record a very long voice note, the phone switches off sometime in the middle, and the screen switches off. I don't know if it is still continuing to listen.

> ok install

> update documetnation and github

### Work done

- Fixed long voice recordings being vulnerable to screen sleep by declaring the iOS audio background mode.
- Updated `AudioRecorderService` to disable the idle timer only during active recording, restore the previous setting afterward, and keep active recording metadata inside the service.
- Changed voice-note submission to use a finished recording result containing the recorder-owned URL and recorder-derived duration.
- Built and installed the signed Debug app on `Karthik's iPhone`.
- Documented the voice recording reliability behavior in `README.md`.

## 2026-05-19 22:15 IST

### User prompts

> next task is to get this on to testflight

> ok docuemnt everything. we'll continue tomorow

### Work done

- Prepared the app for TestFlight/App Store packaging.
- Added a real iOS App Store icon asset and wired it into the app icon catalog:
  `Pensieve/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- Verified the icon is App Store-valid: `1024 x 1024`, RGB, no alpha.
- Created a Release iOS archive at `build/Pensieve.xcarchive`.
- Confirmed the archive succeeds for bundle id `com.karthikshashidhar.pensieve`, version `0.1`, build `1`.
- Attempted App Store Connect upload with an ignored local export options plist at
  `build/ExportOptions.plist`.

### Verification

Release archive succeeded with:

```text
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -configuration Release -destination generic/platform=iOS -archivePath build/Pensieve.xcarchive -allowProvisioningUpdates archive
```

The upload/export step failed with:

```text
No provider associated with App Store Connect user
```

### Current blocker

Xcode can development-sign the app with team `DQ23J9RMB2`, but the Apple ID
configured locally does not currently have an App Store Connect provider for
uploading to TestFlight. Before retrying, sign into Xcode with an Apple ID that
has App Store Connect access for team `DQ23J9RMB2`, accept pending Apple
agreements if any, and ensure the app record exists in App Store Connect for
`com.karthikshashidhar.pensieve`.

### Resume tomorrow

After fixing App Store Connect access, retry:

```text
xcodebuild -exportArchive -archivePath build/Pensieve.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/AppStoreUpload -allowProvisioningUpdates
```

If the archive needs to be rebuilt first, rerun the archive command above.

## 2026-05-19 14:20 IST

### User prompts

> yes start wroking thorugh the list of todos now.

> full of unresolved contradictions on top. i dont know if i'll ever resolve them . nothing to "review"

> ok go on

### Work done

- Split topic cleanup into a preview/apply flow so note themes are not rewritten immediately.
- Added topic cleanup diagnostics in Settings:
  - LLM taxonomy vs local fallback source;
  - notes that would be updated;
  - generated topic count;
  - largest generated groups;
  - run time.
- Added related generated insights and related contradictions to generated Wiki topic pages.
- Added single-topic refresh from a generated Wiki topic page.
- Added a Review tab for pending insights, unresolved contradictions, generated topic pages, and likely open-loop notes.
- Added swipe review actions for accepting/dismissing insights and reviewing/dismissing contradictions.
- Moved contradictions to a limited `Tensions To Inspect` section at the bottom of Review and changed the action label to `Seen`.
- Added topic-level review state: pending, useful, stale, needs refresh, dismissed.
- Added topic review actions on Wiki topic pages and Review rows.
- Regenerated the Xcode project so the new Review view is included.
- Updated `README.md` and `PRODUCT_PLAN.md`.

### Current behavior

- `Settings -> Preview Topic Cleanup` builds a cleanup proposal and shows diagnostics.
- `Apply Topic Cleanup` commits the preview by rewriting note themes and regenerating Wiki topics.
- Wiki topic pages now show related insights and contradictions when they share source notes or topic terms.
- Topic pages can be refreshed individually through the toolbar refresh button.
- Review is now its own tab.
- Topic pages stay in Review only when pending, stale, or needing refresh.
- Contradictions no longer dominate Review and can stay unresolved.

### Verification

Simulator build succeeded with:

```text
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'generic/platform=iOS Simulator' build
```

### Next todos

- Add scoped chat filters by date, topic, source type, and review status.
- Improve local note ranking beyond simple term matching.
- Move storage from JSON to SQLite/GRDB or SwiftData once the product flow stabilizes.

## 2026-05-18 17:55 IST

### User prompts

> let's do some literature survey before we go ahead. tonnes of people seem to be building "second brain" kind of apps for themselves.

> question - does pensieve as a standalone app make sense? or should it be a "servered" openclaw kind of app?

> ok good. let's keep the local on-device iOS thing only then.

> ok now based on the current product and literature survey, let's make a product plan

> yeah we have way too many topics now. need one cleanup pass to clean them up. and then to generate proper topics.

> ok it ran but is this sustainable? ideally need LLM for this

> mindmap is not grouped

> document properly and commit everything to git

### Work done

- Added `docs/second-brain-literature-survey.md` covering common second-brain app patterns, use cases, implementation approaches, and failure modes.
- Added `PRODUCT_PLAN.md` with the local-first iOS product direction, non-goals, information architecture, roadmap, and success criteria.
- Chose the standalone local iOS architecture over a hosted/servered OpenClaw-style app.
- Added backup restore and backup schema versioning.
- Added tappable Chat source citations that open referenced notes.
- Added source-backed `Insight` persistence, corpus analysis, review statuses, and Insights UI.
- Added source-backed `WikiTopic` persistence and generated Wiki topic pages.
- Added manual `Settings -> Clean Up Topics`.
- Iterated topic cleanup from timeout-prone all-in-one LLM calls to a staged flow:
  - ask the LLM for a compact 8-16 topic taxonomy;
  - assign all notes locally into that taxonomy;
  - generate topic pages per topic;
  - fall back to a bounded local taxonomy if the LLM taxonomy fails.
- Fixed generated-topic assignment so every note is assigned into the LLM taxonomy instead of sparse representative groups.
- Updated Mindmap to use generated Wiki topic buckets when available and sort groups by note count.
- Installed the updated debug app on the connected iPhone.
- Updated `README.md` and `PRODUCT_PLAN.md` with the current topic cleanup flow and next todo queue.

### Current behavior

- Heavy AI actions remain manual: `Analyze Corpus`, `Find Contradictions`, and `Clean Up Topics`.
- Topic cleanup is LLM-assisted but bounded: one taxonomy call plus per-topic page generation.
- Wiki shows generated topic pages after cleanup, with raw theme fallback.
- Mindmap groups by generated topics after cleanup, with raw theme fallback.
- Existing generated topics may need a rerun after assignment logic changes.

### Verification

Physical-device build succeeded with:

```text
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'generic/platform=iOS' build
```

The debug app was installed on Karthik's connected iPhone with:

```text
xcrun devicectl device install app --device 00008110-000948390C6A801E /Users/Karthik/Library/Developer/Xcode/DerivedData/Pensieve-exjgoqfjmokqludlhbdjgmaokfcc/Build/Products/Debug-iphoneos/Pensieve.app
```

### Next todos

- Add a topic cleanup preview before rewriting note themes.
- Show cleanup diagnostics: LLM vs local fallback, updated note count, generated topic count, largest groups, and last run time.
- Link topic pages to related insights and contradictions.
- Add single-topic refresh.
- Add a review workflow for pending insights, contradictions, topic updates, and open loops.
- Improve retrieval with scoped chat filters and better local ranking.
- Move storage from JSON to SQLite/GRDB or SwiftData once the product flow stabilizes.

## 2026-05-18 10:55 IST

### User prompts

> ok we paused work on this yesterdy. let's pick it up and make it more useful

### Work done

- Added an `Insights` tab that works locally over the imported/captured corpus.
- Added live corpus metrics for note count, theme count, and open contradictions.
- Added recurring theme and recently active theme sections.
- Added heuristic open-loop and decision/plan sections from note text.
- Surfaced unresolved contradictions inside Insights.
- Turned Contradictions rows into navigable detail pages.
- Added contradiction source-note drilldowns for earlier and later linked notes.
- Added a segmented review control for unresolved/reviewed/dismissed status.
- Regenerated the Xcode project so the new Swift file is included.
- Updated `README.md` with the new behavior.

### Verification

Simulator build succeeded with:

```text
xcodebuild -project Pensieve.xcodeproj -scheme Pensieve -destination 'generic/platform=iOS Simulator' build
```

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
