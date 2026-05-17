# Pensieve Possibilities

Pensieve now has the important raw material: a real personal note corpus inside
the app, plus capture, transcription, notes, wiki, chat, mindmap, contradictions,
and backup. The next opportunity is to make the app less like a passive note
viewer and more like a personal analysis instrument.

## Current Foundation

The app can already:

- Capture voice, text, and URL notes.
- Transcribe voice locally with WhisperKit.
- Process captures with Anthropic using the user's API key.
- Store captures, notes, chat messages, and contradictions locally.
- Import the existing SecondBrain raw markdown corpus as one-time migration data.
- Browse notes through Notes, Wiki, and Mindmap tabs.
- Ask questions against saved notes through Chat.
- Run manual contradiction analysis over the note corpus.
- Export a full JSON backup through the iOS Files sheet.

Current automation:

- Notes update automatically after capture processing or import.
- Wiki is live from saved notes and themes. It does not call an LLM.
- Mindmap is live from saved note themes. It does not call an LLM.
- Chat is user-triggered and sends selected note context to Anthropic.
- Contradictions are manual through `Settings -> Find Contradictions`.
- Backup is manual through `Settings -> Export Pensieve Backup`.

## What We Can Do Now

### Better Wiki

The current Wiki is a theme-and-note browser. It can become a real personal
wiki by adding generated topic pages for themes like career, relationships,
health, tools, money, creativity, and anxiety.

Each topic page should eventually include:

- A short source-backed summary.
- Recurring subthemes.
- Important notes.
- Open questions.
- Changes over time.
- Links to contradictions and related themes.

### Contradiction Review

Contradictions should become inspectable objects, not just list rows.

Useful next behavior:

- Show earlier note and later note side by side.
- Show dates and source titles.
- Let the user mark a contradiction as reviewed, dismissed, or important.
- Let the user open the source notes from the contradiction detail.
- Use reviewed/dismissed feedback to improve future analysis.

### Life Dashboard

The imported corpus makes a dashboard useful immediately.

Possible sections:

- Top recurring themes.
- Recently active themes.
- Emotional tone over time.
- Repeated open loops.
- Strongest current contradictions.
- Questions the user keeps circling.
- Notes that seem unusually important or frequently connected.

### Ask My Notes

Chat already works over saved notes, but it can become much more useful.

Improvements:

- Cite exact source notes in answers.
- Tap a citation to open the note.
- Ask follow-up questions scoped to a theme or time period.
- Ask questions like "what changed in my thinking about work?" or "what am I
  avoiding?"
- Distinguish clearly between evidence from notes and model inference.

### Weekly Digest

A digest is one of the clearest uses of the corpus.

Weekly output could include:

- What I kept thinking about.
- New themes.
- Repeated concerns.
- Decisions or possible decisions.
- Open loops.
- Contradictions or belief shifts.
- Questions to revisit next week.

This should be generated manually at first to control token cost and avoid
surprise background work.

### Search And Discovery

Search can become more than text matching.

Useful directions:

- Search by theme.
- Search by date range.
- Search by tone.
- Search by source type: voice, text, URL, imported.
- Search for decisions, questions, doubts, plans, people, projects, or repeated
  phrases.

## What Becomes Possible Next

### Theme Consolidation

The imported notes have many overlapping themes. The app should learn a smaller
canonical theme set and map messy themes into it.

Examples:

- `career`, `work`, `consulting`, and `freelance` may partially overlap.
- `mental health`, `anxiety`, `stress`, and `self-awareness` may need hierarchy.
- `ai`, `tools`, `technology`, and `productivity` may need separation by use.

This would make Wiki and Mindmap much cleaner.

### Generated Topic Pages

A topic page should be a durable object generated from many notes, then stored
locally and refreshed when needed.

For example, a `Career` page could include:

- Current state.
- Repeated beliefs.
- Shifts over time.
- Open loops.
- Important decisions.
- Contradictions.
- Representative notes.

This is the highest-leverage next step because it turns note piles into living
knowledge pages.

### Belief-Change Timeline

The corpus is especially good for tracking changes in thinking.

Examples:

- "Earlier I thought X; later I started thinking Y."
- "This anxiety appears repeatedly, but the explanation changes."
- "This theme moves from frustration to strategy."

This overlaps with contradictions, but it should be broader: not every change is
a contradiction.

### Open-Loop Detection

Open loops are unresolved recurring concerns or plans.

Examples:

- A decision repeatedly deferred.
- A project repeatedly mentioned without next action.
- A relationship tension that keeps reappearing.
- A question that remains unanswered across notes.

Open loops could be surfaced in a dedicated view or inside topic pages.

### Decision Tracker

The app can detect and track decisions or likely decisions.

Useful behavior:

- Extract possible decisions from notes.
- Store decision topic, options, reasoning, and date.
- Prompt for follow-up later.
- Let the user mark outcomes.
- Build a personal record of judgment: what seemed true then, what happened
  later.

### Self-Model

Once the corpus is large enough, Pensieve can summarize recurring patterns.

Examples:

- Strengths that recur.
- Anxiety loops.
- Avoided topics.
- Productive environments.
- Social patterns.
- Work patterns.
- Motivations that actually move the user.

This must stay source-backed and inspectable, because overconfident personality
summaries can become misleading.

## Recommended Direction

The strongest product direction is:

> Make Pensieve a personal analysis instrument, not just a notes app.

The next version should focus on source-linked synthesis:

- Keep raw notes as the source of truth.
- Generate durable topic pages from notes.
- Generate source-backed insights, contradictions, open loops, decisions, and
  belief shifts.
- Make every generated claim inspectable through source notes.
- Keep expensive corpus analysis manual at first.
- Later add prompts like "12 new notes are ready to analyze" rather than running
  heavy analysis silently.

## What Should Stay Manual For Now

These should not run automatically yet:

- Full corpus analysis.
- Contradiction scans.
- Weekly digests.
- Topic page regeneration.
- Theme consolidation.

Reasons:

- They cost API tokens.
- They can take time.
- They depend on network availability.
- The user should know when a large personal corpus is sent to Anthropic.

The right near-term automation is lightweight prompting:

- After import: "Analyze imported notes?"
- After several new captures: "Refresh insights?"
- Once a week: "Generate weekly digest?"

## Suggested Next Milestone

Build an `Insights / Analysis` layer.

Minimum new concepts:

- `WikiTopic`: generated topic page backed by source notes.
- `Insight`: source-backed generated object.
- Insight types:
  - `themeSummary`
  - `openLoop`
  - `pattern`
  - `question`
  - `decision`
  - `beliefShift`
  - `contradiction`

Minimum app behavior:

- Add `Analyze Corpus` as a manual action.
- Generate a small set of durable, source-linked outputs.
- Store outputs locally.
- Show generated topic pages in Wiki.
- Show insights either in a new Insights tab or inside Wiki.
- Allow the user to open source notes from generated outputs.

Acceptance criteria:

- The user can run analysis manually.
- The app does not perform expensive background LLM work silently.
- Generated claims are linked to notes.
- Wiki becomes meaningfully smaller and more synthesized than the raw note list.
- Contradictions remain auditable.
- Backup export includes any new generated analysis objects once they exist.
