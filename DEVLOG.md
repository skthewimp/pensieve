# Pensieve Dev Log

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
