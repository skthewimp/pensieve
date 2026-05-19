# Pensieve Product Plan

Date: 2026-05-18

Pensieve should be a local-first, on-device iOS memory app. It should not become a hosted OpenClaw/GBrain-style server product. The winning product shape is a private iPhone app that captures messy personal input, turns it into inspectable structured memory, and helps the user review, correct, and reuse that memory.

The core product loop:

```text
Capture -> Distill -> Link -> Use -> Review -> Correct
```

This plan is based on the current app state, `POSSIBILITIES.md`, and the second-brain literature survey in `docs/second-brain-literature-survey.md`.

## Product Thesis

Most second-brain systems fail because they become note piles, dashboard projects, or infrastructure hobbies. Pensieve should avoid that by staying opinionated:

- Capture should be fast enough to use every day.
- Raw captures should remain local and inspectable.
- AI should create structured memory, not just summaries.
- Generated claims should link back to source notes.
- Review and correction should be first-class, because stale or false memory is worse than forgetting.
- Expensive LLM work should be explicit and user-triggered.
- The app should be useful without Obsidian, a Mac, a server, MCP, background agents, or cloud sync.

The product promise:

> Pensieve is a private memory instrument for iPhone: capture thoughts, find patterns, track how your thinking changes, and turn raw notes into source-backed insight.

## Non-Goals

For now, Pensieve should not be:

- A hosted second-brain server.
- An OpenClaw/GBrain clone.
- A team knowledge base.
- A general file/document manager.
- A full Obsidian replacement.
- A passive lifelogging system that captures everything automatically.
- A social/collaborative app.
- A hidden cloud-memory service.

Optional sync or server features can be reconsidered later, but the default architecture should remain local-first iOS.

## Current Foundation

Already implemented:

- Voice capture.
- On-device transcription with WhisperKit.
- Text capture.
- URL capture with Anthropic web fetch.
- App-local JSON store in Application Support.
- Anthropic API key in Keychain.
- Capture processing into `MemoryNote`.
- Notes, Wiki, Insights, Chat, Mindmap, Contradictions, Settings.
- Retrieval-backed chat over saved notes.
- Manual contradiction analysis.
- Contradiction detail and status.
- One-time SecondBrain raw markdown import.
- JSON backup export.

Current data model:

- `Capture`: raw voice/text/URL input and processing state.
- `MemoryNote`: processed note with title, summary, body, themes, tone, source identifier.
- `Contradiction`: topic, before/after notes, explanation, status, confidence.
- `Insight`: generated source-backed finding with review status.
- `WikiTopic`: generated source-backed topic page with canonical theme, aliases, sources, subthemes, questions, and related themes.
- `ChatMessage`: chat history and note context.

Current architectural constraint:

- Local JSON store is good enough for the prototype, but long-term structured memory wants SQLite/GRDB or SwiftData with migrations.

## Product Principles

### 1. Local First, Explicit Cloud AI

Pensieve is local-first, not fully offline. The precise privacy line:

- Audio recording: on device.
- Transcription: on device.
- Raw captures and notes: on device.
- Search, local views, review state: on device.
- Anthropic/OpenAI processing: explicit user-configured cloud call.

The app should show when a corpus-sized operation will send notes to an LLM.

### 2. Raw Source Is Sacred

Raw captures should never be silently rewritten. Generated memory can evolve, but the original text/transcript/URL/source metadata remains the audit trail.

### 3. Source-Backed Synthesis

Every generated topic, insight, contradiction, belief shift, open loop, or decision should include source note IDs. If a claim cannot be traced, it should be treated as inference, not memory.

### 4. Review Beats Automation

The app should prompt the user to review generated memory instead of silently creating a new reality. This matters especially for contradictions, self-models, decisions, and recurring patterns.

### 5. Bounded Workflows Beat Generic Memory

The strongest use cases are specific:

- "What have I been thinking about X?"
- "How has my thinking changed?"
- "What open loops keep recurring?"
- "What contradictions should I review?"
- "What did I decide?"
- "Prepare me for this person/project/topic."
- "Turn these notes into a memo/post/plan."

## Target User

Initial target user:

- Captures voice/text notes frequently.
- Thinks through work, relationships, writing, projects, decisions, and self-reflection.
- Wants synthesis but does not want to maintain Obsidian or agent infrastructure.
- Is comfortable supplying an API key for explicit AI features.
- Cares about privacy, source traceability, and local ownership.

This is a power-user consumer product, not a mass-market journaling app yet.

## Core Information Architecture

Pensieve should organize memory into these layers:

### Raw Captures

The original voice/text/URL import:

- Capture kind.
- Created date.
- Raw text/transcript.
- URL/audio metadata.
- Processing status.
- Source identifier.

### Processed Notes

The first-pass AI distillation:

- Title.
- Summary.
- Body.
- Themes.
- Emotional tone.
- Key quotes.
- Connections.
- Source capture.

### Generated Memory Objects

Next-phase durable synthesis:

- `WikiTopic`: source-backed topic page.
- `Insight`: source-backed generated finding.
- `OpenLoop`: recurring unresolved issue/question/project.
- `Decision`: extracted or user-confirmed decision.
- `BeliefShift`: changed view over time.
- `Contradiction`: conflicting claims or meaningful tension.

### Review State

The user's judgment over generated memory:

- Pending.
- Accepted.
- Dismissed.
- Important.
- Superseded.
- Needs follow-up.

## Proposed Data Model Additions

These can start as Codable structs in the JSON store, then move to SQLite/GRDB.

```swift
struct WikiTopic: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var canonicalTheme: String
    var summary: String
    var currentUnderstanding: String
    var recurringSubthemes: [String]
    var openQuestions: [String]
    var sourceNoteIDs: [UUID]
    var relatedTopicIDs: [UUID]
    var contradictionIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
}
```

```swift
enum InsightKind: String, Codable {
    case themeSummary
    case pattern
    case openLoop
    case question
    case decision
    case beliefShift
}

enum ReviewStatus: String, Codable {
    case pending
    case accepted
    case dismissed
    case important
    case superseded
}

struct Insight: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: InsightKind
    var title: String
    var explanation: String
    var sourceNoteIDs: [UUID]
    var themes: [String]
    var confidence: Double?
    var status: ReviewStatus
    var createdAt: Date
    var updatedAt: Date
}
```

Do not over-model entities yet. People/projects can initially be themes or extracted insight metadata. Add dedicated `Person` / `Project` models only after there is clear UI demand.

## Core Screens

### Capture

Role: fastest possible input.

Near-term improvements:

- Make processing state visible.
- Show "pending review" after a note is processed.
- Preserve raw transcript access.
- Add a "process later" path if API key/network is missing.

### Notes

Role: raw and processed note browser.

Near-term improvements:

- Better filters: voice/text/URL/imported, theme, tone, date.
- Show source capture and generated fields clearly.
- Tap from note to related topic/insights/contradictions.

### Wiki

Role: synthesized topic memory, not just theme buckets.

Next version:

- Show generated `WikiTopic` pages first.
- Keep current theme browser as fallback.
- Topic pages should include current understanding, recurring subthemes, source notes, open questions, contradictions, and related topics.

### Insights

Role: dashboard for what deserves attention.

Sections:

- Recently active themes.
- New generated insights.
- Open loops.
- Decisions and possible decisions.
- Belief shifts.
- Important unresolved contradictions.
- Notes ready for analysis.

### Chat

Role: ask source-backed questions.

Near-term improvements:

- Show citations as tappable note chips.
- Let user scope by theme/date.
- Distinguish "from your notes" vs "model inference."
- Add starter prompts:
  - "What changed in my thinking this month?"
  - "What am I avoiding?"
  - "What open loops mention work?"
  - "Summarize my notes about health."

### Contradictions

Role: memory correction and belief-change review.

Near-term improvements:

- Keep side-by-side source note detail.
- Add statuses beyond reviewed/dismissed if useful: important, superseded.
- Let a reviewed contradiction create an `Insight` or update a `WikiTopic`.

### Settings

Role: trust, data ownership, expensive actions.

Must include:

- API key.
- Export backup.
- Restore backup.
- Analyze Corpus.
- Generate Weekly Digest.
- Find Contradictions.
- Clear/delete options eventually.
- Privacy explanation for LLM calls.

## Manual Analysis Actions

Heavy analysis should remain manual.

### Analyze Corpus

Input:

- Notes since last analysis, or full corpus if requested.

Output:

- Topic summaries.
- Insights.
- Open loops.
- Decisions.
- Belief shifts.
- Candidate contradictions.

Acceptance criteria:

- User sees estimated scope before running.
- Generated objects are stored locally.
- Every object has source note IDs.
- User can open source notes.

### Refresh Topic Pages

Input:

- Notes grouped by top themes.

Output:

- `WikiTopic` pages.

Acceptance criteria:

- Wiki becomes smaller and more useful than the raw note list.
- Topic pages show source-backed current understanding.

### Weekly Digest

Input:

- Notes from the last 7 days.

Output:

- Main themes.
- New patterns.
- Decisions.
- Open loops.
- Contradictions/belief shifts.
- Questions for next week.

Acceptance criteria:

- Digest is saved as an `Insight` or future `Digest` object.
- Sources are linked.
- User can dismiss or mark items important.

### Find Contradictions

Already implemented manually. Keep it manual, improve review and integration with topic pages.

## Roadmap

### Phase 0: Product Alignment

Goal: make the app direction explicit.

Tasks:

- Add product plan. Done in this document.
- Keep architecture local-only.
- Treat server/MCP/cloud sync as non-goals.

### Phase 1: Trust and Data Durability

Goal: make the local app safe to use seriously.

Features:

- Restore from JSON backup.
- Add backup schema version.
- Add visible privacy copy for AI calls.
- Improve failed/pending capture recovery.
- Add source links from chat answers to notes.

Why first:

- If this app becomes a personal memory store, data loss and opaque AI calls are unacceptable.

### Phase 2: Source-Linked Insights

Goal: turn notes into reviewable memory objects.

Features:

- Add `Insight` model and store support. Done.
- Add manual `Analyze Corpus`. Done.
- Generate high-signal insights from corpus. Done.
- Show insights in Insights tab. Done.
- Open source notes from each insight. Done.
- Review status: pending, accepted, dismissed, important, superseded. Done.

Why second:

- This is the smallest step from "notes app" to "memory instrument."

### Phase 3: Generated Wiki Topics

Goal: make Wiki a true synthesis layer.

Features:

- Add `WikiTopic` model and store support. Done.
- Generate topic pages for canonical themes. Done.
- Topic cleanup into a bounded LLM taxonomy with local note assignment. Done.
- Wiki display for generated topic pages, with raw theme fallback. Done.
- Mindmap grouping by generated topics, with raw theme fallback. Done.
- Topic page view with summary, current understanding, sources, open questions, and related themes. Done.
- Related insights and contradictions on topic pages. Done.
- Topic cleanup preview/diagnostics before rewriting themes. Done.
- Single-topic refresh from generated Wiki topic pages. Done.

Why third:

- The literature survey shows that durable compiled pages are more valuable than transient chat/RAG answers.

### Phase 4: Review Loop

Goal: make correction a core habit.

Features:

- Daily/weekly review screen or Insights section. Started with a Review tab.
- "New notes ready to analyze."
- "Open loops to revisit." Started with heuristic open-loop notes.
- "Contradictions to review." Done for unresolved contradictions.
- "Topic pages changed." Started with generated topic page queue.
- Dismiss/accept/important actions everywhere. Done for insights and contradictions; topic pages now support useful/stale/needs refresh/dismissed.

Why fourth:

- Second-brain systems fail when review is absent.

### Phase 5: Search and Retrieval Upgrade

Goal: improve recall without server infrastructure.

Features:

- SQLite/GRDB migration.
- Full-text search.
- Better local ranking by title, theme, recency, source type.
- Optional semantic embeddings later, only if needed and feasible on-device/API-assisted.
- Scoped chat by date/theme/source type.

Why fifth:

- Current simple term matching is fine for prototype, but corpus growth will make retrieval quality a product limiter.

### Phase 6: Memory Hygiene

Goal: prevent stale/false memory.

Features:

- Confidence/provenance labels.
- Stale insight detection.
- Superseded belief/decision states.
- Contradiction-to-topic integration.
- Mistake/correction log.

Why sixth:

- This is the long-term differentiator versus generic note summarizers.

## Near-Term Build Order

Recommended next 6 implementation tasks:

1. Backup restore and backup schema version. Done.
2. Tappable note citations in Chat. Done.
3. `Insight` model + local store persistence. Done.
4. Manual `Analyze Corpus` LLM endpoint. Done.
5. Insights review UI with source-note links. Done.
6. `WikiTopic` model + generated topic page prototype. Next.
   - Topic cleanup into canonical themes. Done.
   - Generated `WikiTopic` persistence and Wiki display. Done.
   - Mindmap now uses generated topics when available. Done.

Avoid starting with SQLite migration unless the JSON store is actively blocking these features. Product learning matters more right now than storage elegance, but backup schema versioning should happen before adding many new object types.

## Next Todo Queue

The app now has the core memory-object loop. The next work should make it safer
to run repeatedly and easier to judge.

### 1. Topic Cleanup Trust Pass

Goal: make `Clean Up Topics` auditable before it mutates the corpus.

Tasks:

- Show a preview before saving: proposed topics, note counts, and sample notes.
- Show whether the run used the LLM taxonomy or local fallback.
- Add a "rerun cleanup" affordance that replaces existing generated topics.
- Show "last cleaned at" and topic count in Settings.
- Add a lightweight cleanup report after completion: updated notes, generated topics, largest groups, and unassigned/fallback notes.

### 2. Topic Page Integration

Goal: make generated topic pages the central synthesis surface.

Tasks:

- Link topic pages to matching generated insights.
- Link topic pages to matching contradictions.
- Show recently added source notes inside each topic.
- Add topic-level review state: useful, stale, needs refresh, dismissed.
- Add "refresh this topic" for a single topic instead of rerunning the whole corpus. Done.

### 3. Review Workflow

Goal: turn generated memory into a habit rather than a pile.

Tasks:

- Add a Review screen or Insights section for pending generated items. Done.
- Group pending items by type: insights, contradictions, stale topics, open loops. Started.
- Add accept/dismiss/important actions consistently across Insight, WikiTopic, and Contradiction surfaces. Partial: insights and contradictions have actions; WikiTopic needs status.
- Add a weekly review action that produces a source-backed digest.

### 4. Retrieval Quality

Goal: make Chat and source linking work well as the corpus grows.

Tasks:

- Add scoped chat filters by date, topic, source type, and review status.
- Improve local note ranking beyond simple term matching.
- Add full-text search through SQLite/GRDB or SwiftData before semantic embeddings.
- Keep citations visible for every source-backed answer.

### 5. Storage Migration

Goal: move from prototype JSON to durable structured storage when product behavior stabilizes.

Tasks:

- Pick SQLite/GRDB or SwiftData.
- Define migrations for captures, notes, contradictions, insights, wiki topics, and chat messages.
- Preserve JSON backup import/export as a portability layer.
- Add defensive migration tests with older backup snapshots.

## LLM Prompting Direction

Current capture processing extracts title, summary, themes, tone, quotes, and connections. Keep that.

Add a new corpus-analysis prompt that returns structured JSON:

```json
{
  "insights": [
    {
      "kind": "openLoop",
      "title": "Unresolved work direction",
      "explanation": "The notes repeatedly return to...",
      "sourceNoteIDs": ["..."],
      "themes": ["career"],
      "confidence": 0.82
    }
  ],
  "topicPages": [
    {
      "title": "Career",
      "canonicalTheme": "career",
      "summary": "...",
      "currentUnderstanding": "...",
      "recurringSubthemes": ["consulting", "writing", "independence"],
      "openQuestions": ["..."],
      "sourceNoteIDs": ["..."],
      "relatedThemes": ["money", "identity"]
    }
  ]
}
```

Rules:

- Return source note IDs only from provided notes.
- Prefer fewer, higher-signal outputs.
- Mark inference clearly.
- Do not produce personality diagnoses.
- Do not invent facts absent from notes.
- If evidence is thin, return fewer objects.

## Success Criteria

Pensieve is working if:

- The user captures notes more often because capture is low friction.
- The user opens Insights/Wiki to understand patterns, not just to browse notes.
- Generated insights are source-backed and reviewable.
- Chat answers lead back to notes.
- Contradictions and belief shifts feel useful rather than spooky.
- The app can be trusted as a local memory store.
- Weekly review produces concrete decisions, open loops, or writing/planning material.

Pensieve is failing if:

- It becomes a flat note list with summaries.
- It requires the user to maintain taxonomy manually.
- It silently sends large corpora to an LLM.
- Generated insights cannot be audited.
- The app accumulates stale claims with no correction mechanism.
- The user spends time organizing instead of thinking, deciding, or creating.

## Product Tagline Options

- Private memory for thoughts that should not disappear.
- A local-first thinking instrument for iPhone.
- Capture your thoughts. See what they become.
- Your notes, turned into source-backed insight.
- A private second brain that remembers where every idea came from.

Best current positioning:

> Pensieve is a local-first iPhone app that turns voice notes and raw thoughts into source-backed personal memory: topics, patterns, contradictions, open loops, and decisions you can review and trust.
