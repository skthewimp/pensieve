# Second-Brain App Literature Survey

Date: 2026-05-18

This survey looks at what builders are currently calling "second brain" systems: personal knowledge bases, AI memory layers, Obsidian/Markdown vaults, RAG systems, graph memory systems, and agent-operated personal operating systems. The sources include GitHub projects, Reddit implementation reports, public LinkedIn posts, public X/Twitter posts available through search, and older PKM patterns that explain why these systems keep reappearing.

## Executive Summary

The category has split into two camps.

The older camp is personal knowledge management: Obsidian, Logseq, Notion, Roam, Zettelkasten, PARA, digital gardens, and local Markdown vaults. These systems work best when the user has a low-friction capture habit and a clear output loop: writing, studying, research, project work, or decision-making. They fail when the user spends more time designing dashboards, folder systems, tags, and plugins than producing useful work.

The newer camp is AI-maintained memory: Claude Code/Codex/Gemini/OpenCode agents operating over Markdown, SQLite/Postgres, vector search, MCP tools, and knowledge graphs. The pattern that caught fire in April 2026 is Andrej Karpathy's "LLM Wiki": raw sources go in, an LLM incrementally compiles and maintains a structured Markdown wiki, and the human mainly curates sources and asks questions. This shifts the bottleneck from manual filing to memory hygiene: source provenance, stale facts, contradictions, permissions, and retrieval quality.

The strongest use cases are not generic "remember everything" apps. They are bounded workflows:

- Research synthesis over articles, papers, books, and web clips.
- Meeting, transcript, and voice-note ingestion into durable decisions, people, projects, and follow-ups.
- Personal operating memory for AI agents: task logs, decision logs, project state, preferences, and mistakes.
- Domain-specific expert memory: GTM playbooks, engineering notes, investor diligence, customer calls, competitive intelligence.
- Study and interview preparation from a large body of notes.
- Coding/project continuity across long agent sessions.

The weakest use cases are open-ended hoarding, graph-view worship, and over-engineered systems with no review or output cadence. Reddit reports repeatedly describe systems turning into "second storage units" or "second jobs."

For Pensieve, the lesson is clear: the app should not simply be a note collector. Its product wedge should be "capture messy life/work input, turn it into durable structured memory, and make that memory useful in specific recurring workflows." Voice capture, timelines, contradictions, wiki pages, people/project memory, and AI chat are aligned with the winning patterns, but the app needs explicit hygiene and output loops to avoid becoming another pile of notes.

## Search Scope

I searched across:

- GitHub topics and repos for `second-brain`, `personal-knowledge-management`, `AI second brain`, Obsidian + Claude Code starter kits, LLM Wiki implementations, RAG/GraphRAG memory systems, and local-first PKM apps.
- Reddit communities including r/ObsidianMD, r/ClaudeCode, r/ClaudeAI, r/LocalLLaMA, r/SideProject, r/ProductivityApps, and related threads.
- Public LinkedIn posts and articles about AI second brains, Obsidian + Claude Code workflows, and business-specific AI memory systems.
- Public X/Twitter search results around Karpathy's LLM Wiki, Garry Tan's GBrain, and builder demos.
- Foundational references: Vannevar Bush's Memex, Zettelkasten, PARA/CODE, Obsidian, RAG, and LLM Wiki.

X and LinkedIn are only partially accessible through public search. Treat social metrics and claims as directional unless backed by a repo or detailed writeup.

## Historical Patterns

### Memex

Vannevar Bush's 1945 "As We May Think" proposed a personal device for storing books, records, communications, annotations, and associative trails. The core idea was not just storage; it was durable trails through knowledge. Modern second-brain apps are still trying to build this: store, link, retrieve, annotate, and reuse personal knowledge. See [The Atlantic's "As We May Think"](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/).

### Zettelkasten

Zettelkasten emphasizes atomic notes, links, and output. Its popular mythology often overstates how automatic insight generation is, but the durable lesson is useful: notes become valuable when they are written as reusable thinking units and revisited in the service of writing/research. This maps well to LLM Wiki entity/concept pages, but only if the system produces output instead of endless filing.

### PARA and CODE

Tiago Forte's "Building a Second Brain" popularized CODE: capture, organize, distill, express, and PARA: projects, areas, resources, archives. The strongest part for app design is not the folder scheme; it is the "express" step. Knowledge is only useful when it re-enters work. Recent Reddit discussions echo this: people who start with daily notes, voice dictation, and weekly review report better outcomes than people who start with complex folder/plugin systems.

### Obsidian and Local Markdown

Obsidian became the default substrate because it stores notes as local Markdown, supports links/graph views/plugins, and is human-readable and portable. Obsidian's own site emphasizes local storage, open formats, note links, graph view, Canvas, plugins, and Publish. See [Obsidian](https://obsidian.md/).

The AI wave uses Obsidian less as a note app and more as an IDE for a knowledge codebase: Markdown files are the database, the agent edits them, and the human reviews them.

## The 2026 Turning Point: LLM Wiki

Karpathy's [LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) is the most important recent reference. It frames the problem this way:

- RAG retrieves raw chunks at query time and re-derives synthesis every time.
- LLM Wiki compiles knowledge once into a persistent interlinked wiki.
- Raw sources stay immutable.
- The wiki is LLM-generated and maintained.
- A schema file such as `CLAUDE.md` or `AGENTS.md` tells the agent how to ingest, query, and lint.
- `index.md` and `log.md` help the agent navigate and preserve chronology.
- At moderate scale, a well-maintained index can avoid embedding infrastructure; at larger scale, hybrid search such as `qmd` or a database becomes useful.

The key quote-equivalent idea: the wiki is a compounding artifact, not a transient chat answer. Every ingest, query, comparison, contradiction, and new synthesis can be filed back into the system.

Karpathy explicitly names use cases: personal tracking, research, reading books, business/team wikis, competitive analysis, due diligence, trip planning, course notes, and hobby deep-dives. He also frames Obsidian as the IDE, the LLM as the programmer, and the wiki as the codebase.

This idea triggered a wave of implementations. The gist itself shows 5,000+ stars and 5,000+ forks as of public GitHub rendering, which is unusually high for a plain idea file.

## Representative GitHub Projects

### GBrain

[garrytan/gbrain](https://github.com/garrytan/gbrain) is the most ambitious public implementation. It describes itself as an agent brain for OpenClaw/Hermes, with Markdown/page memory, people/company entities, timelines, hybrid search, typed links, MCP tooling, skills, recurring jobs, and evals. The README claims Garry Tan's production deployment had 17,888 pages, 4,383 people, 723 companies, and 21 autonomous cron jobs. The repo had 16.7k stars when checked.

Implementation pattern:

- TypeScript/Bun CLI.
- PGLite/Postgres-style local database.
- Hybrid search plus graph links.
- MCP server for Claude Code, Cursor, Windsurf, ChatGPT/remote clients.
- Skills for ingestion, enrichment, meeting processing, voice notes, book analysis, research, citation fixing, and maintenance.
- "Brain-first lookup" before external calls.
- Nightly consolidation/dream-cycle style maintenance.

What seems to work:

- Rich people/company/project memory.
- Meeting and transcript ingestion.
- Typed facts and temporal trajectories.
- Agent memory for long-running workflows.

Risks:

- Heavy setup compared with simple Markdown.
- Strong dependence on frontier models.
- Privacy/governance complexity if exposed over remote MCP.
- Operational cost at high query volume.

### Open Brain / OB1

[NateBJones-Projects/OB1](https://github.com/NateBJones-Projects/OB1) frames itself as "one database, one AI gateway, one chat channel." It is less an Obsidian vault and more a memory infrastructure layer that any AI can plug into. The repo had 3.2k stars on the GitHub topic page when checked.

Implementation pattern:

- Supabase/Postgres-style memory.
- Vector search.
- Slack/Discord capture.
- MCP server.
- Import recipes for ChatGPT exports, Perplexity, Obsidian, X/Twitter data exports, Instagram, Google Takeout, Gmail, journals, etc.
- Skills for auto-capture, competitive analysis, financial review, deal memos, research synthesis, meeting synthesis, and work operating-model extraction.

What seems to work:

- Cross-tool AI memory.
- Importing existing digital exhaust.
- Structured business workflows.
- Community extension model.

Risks:

- More infrastructure than many personal users need.
- Memory can become a dumping ground unless schema/routing is disciplined.

### Reor

[reorproject/reor](https://github.com/reorproject/reor) is a private, local AI personal knowledge management app. It is local-first, Markdown-oriented, and tagged around RAG, vector database, LanceDB, Ollama, and llama.cpp. GitHub topics showed 8.6k stars.

Implementation pattern:

- Desktop/local app.
- Local notes.
- Local or user-controlled models.
- RAG-style search and chat.

What seems to work:

- Privacy-first positioning.
- Lower barrier than building your own agent stack.
- Good fit for users who want an app, not a folder/CLI system.

Risks:

- App products compete with Obsidian plus agent workflows.
- RAG alone may feel less compounding than LLM Wiki unless it also writes durable summaries and relationships.

### Nicholas Spisak's `second-brain`

[NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain) is a direct LLM Wiki implementation for Obsidian. It installs skills for setup, ingest, query, and lint. It supports Claude Code, Codex, Cursor, Gemini CLI, and other agent skill systems.

Implementation pattern:

- Obsidian as viewer.
- Raw sources folder.
- LLM-generated wiki.
- Agent skills: `/second-brain`, `/second-brain-ingest`, `/second-brain-query`, `/second-brain-lint`.
- Optional `qmd` for hybrid search as the wiki grows.

What seems to work:

- Good minimal instantiation of Karpathy's pattern.
- The "lint" operation acknowledges that memory hygiene is core, not optional.

Risks:

- Still depends on user discipline around ingest and source curation.
- Not much evidence yet of long-term use beyond early adoption.

### `llm-wiki-agent`

[SamurAIGPT/llm-wiki-agent](https://github.com/SamurAIGPT/llm-wiki-agent) describes a personal knowledge base that builds and maintains itself from dropped sources. It works with Claude Code, Codex, OpenCode, and Gemini CLI, with no API key required by the repo itself.

Implementation pattern:

- Markdown wiki.
- Agent-operated ingestion.
- Persistent interlinked pages.
- CLI/agent compatibility.

What seems to work:

- Strong alignment with the LLM Wiki wave.
- Portable across agent clients.

Risk:

- Same broad risk as other agent-maintained wikis: consistency, provenance, stale facts, and link integrity.

### Obsidian + Claude PKM Starter Kits

[ballred/obsidian-claude-pkm](https://github.com/ballred/obsidian-claude-pkm) is a starter kit for an Obsidian + Claude Code PKM system. GitHub topics showed 1.5k stars.

Implementation pattern:

- Obsidian vault structure.
- Claude Code operating instructions.
- Goal tracking and personal knowledge workflows.

What seems to work:

- Reduces setup friction for people who want the pattern but not the design work.

Risk:

- Starter kits can encourage copying someone else's brain structure instead of developing a workflow that matches the user's real capture/output habits.

### COG Second Brain

[huytieu/COG-second-brain](https://github.com/huytieu/COG-second-brain) is a self-evolving second brain with skills, worker agents, and people CRM, inspired by Garry Tan's gstack/gbrain. It explicitly combines compiled truth plus timeline pages, people enrichment, agent workflows, Zettelkasten, PARA, and GTD.

Implementation pattern:

- Markdown files.
- Multiple worker agents.
- 17 AI skills.
- People CRM.
- Daily braindumps.

What seems to work:

- The people/project CRM angle is practical.
- "Clone, onboard, braindump daily" is a clear behavior loop.

Risk:

- Multi-agent setups can become complex quickly.

### Knowledge Nexus / GraphRAG

[Jallermax/knowledge-nexus](https://github.com/Jallermax/knowledge-nexus) is a GraphRAG second-brain project that ingests sources, builds knowledge graphs, and queries/explores connections. It includes Notion/Pocket/web sources, AI entity/topic extraction, Neo4j-style graph thinking, and local storage.

Implementation pattern:

- Ingestion providers.
- Entity/topic extraction.
- Graph database.
- AI-generated insights.
- Retrieval and exploration.

What seems to work:

- Better for people who care about semantic relationships and discovery, not just search.

Risks:

- Graph construction is expensive and brittle if entity resolution is poor.
- Personal projects often stall before the graph becomes useful.

### Browser and Web Memory

[memex-life/memex](https://github.com/memex-life/memex) is a Chrome extension that captures browsing content and metadata, chunks it, stores it locally, and exposes chat over browsing history. It is directly inspired by "total recall" for web browsing.

Implementation pattern:

- Browser extension.
- Script injection to capture page text.
- Backend service because LangChainJS browser support was insufficient.
- Database plus chat UI.

What seems to work:

- Passive capture is compelling for web-heavy research.

Risks:

- Privacy concerns.
- Capturing everything creates noisy memory unless there is strong filtering/summarization.
- Browser history is often less valuable than intentionally curated sources.

### Obsidian Smart Second Brain

[your-papa/obsidian-smart2brain](https://github.com/your-papa/obsidian-smart2brain) is an Obsidian plugin for chat with notes using RAG, reference links, and offline/private operation with local models.

Implementation pattern:

- Obsidian plugin.
- Embeddings over vault.
- Chat interface.
- Source note references.
- Offline option.

What seems to work:

- Low friction for existing Obsidian users.
- Source links reduce hallucination risk.

Risk:

- RAG over existing notes does not solve capture, synthesis, contradiction tracking, or memory evolution by itself.

## Social/Community Build Reports

### Reddit: Claude Code + Obsidian + QMD

A detailed r/ClaudeCode post describes a persistent assistant named Vox using Claude Code, Obsidian, and QMD. The stack includes:

- Claude Code as acting agent.
- Obsidian as memory substrate.
- QMD as semantic/hybrid retrieval.
- `CLAUDE.md` as procedural memory.
- Daily notes/session digests.
- Dashboard index.
- Reflection queue.
- Async instruction folder.
- Calendar workflow.
- Limited home automation hooks.

The author says the system works better than expected and feels like continuity rather than chat memory. The open problems are exactly the hard ones: contradiction tracking, confidence/sources, stale memory, retrieval routing, promise tracking, and proactive behavior boundaries. See the [Reddit thread](https://www.reddit.com/r/ClaudeCode/comments/1rn38wh/i_built_a_persistent_ai_assistant_with_claude/).

Useful lesson: the most successful personal systems distinguish memory types:

- Working memory: context window and crash buffer.
- Episodic memory: daily/session notes.
- Semantic memory: stable facts.
- Procedural memory: operating instructions.
- Identity/preferences: core files.
- Retrieval: QMD/search.

### Reddit: 25-Tool AI Second Brain

A r/ClaudeAI post describes a 25-tool system around Claude Code, Obsidian, Ollama, SQLite, bge-m3 embeddings, Express, and React. It includes live session ingestion, hourly sync, voice transcription, web clipping, git stats, daily digest, reflection-to-memory promotion, auto-tagging, frontmatter validation, context package generation, semantic search, codebase indexing, knowledge graph MCP, spaced repetition, pruning, contradiction detection, scheduled research, canvas generation, dashboards, and proactive alerts. See the [Reddit thread](https://www.reddit.com/r/ClaudeAI/comments/1sbtb34/i_gave_claude_code_a_knowledge_graph_spaced/).

Useful lesson: the frontier of hobby builds is no longer note-taking. It is a small personal data platform with:

- Capture pipelines.
- Batch jobs.
- Indexing.
- Hygiene checks.
- Dashboards.
- Agent-readable context packages.
- Model cost monitoring.

Risk: this can become a maintenance burden unless the user enjoys operating infrastructure.

### Reddit: GraphThulhu MCP

A r/ClaudeAI post describes `graphthulhu`, an MCP tool connecting AI agents to Obsidian or Logseq knowledge graphs. The discussion frames a tradeoff between intentional graph structure and low-friction automatic extraction. See the [thread](https://www.reddit.com/r/ClaudeAI/comments/1rcns6i/second_brain_powered_by_ai_mcp_called_graphthulhu/).

Useful lesson: graph structure is valuable when it is already meaningful, but automatic capture is necessary for most users.

### Reddit: Obsidian Advice and Failure Modes

In r/ObsidianMD, experienced users repeatedly warn beginners not to overfit to other people's systems or install 50-100 plugins. The strongest advice is to start writing, use a daily journal, optionally voice dictation, link things worth revisiting, and review weekly. See [Building Second Brain using Obsidian](https://www.reddit.com/r/ObsidianMD/comments/191a6zd/building_second_brain_using_obsidian/).

Other Reddit posts describe the "second brain" trap:

- Effort justification: because the system took work, it feels valuable even if it is not producing insight.
- Graph view illusion: seeing connections is not the same as understanding.
- Second job: systems that demand constant manual triage.
- Second storage unit: half-processed notes dumped across Apple Notes, Obsidian, Notion, and task apps.

Useful lesson: capture and review beat taxonomy. A system should make the next useful action obvious.

### LocalLLaMA: RAG for Technical Docs

A r/LocalLLaMA thread describes building a RAG second brain over 3-4k technical documents with code snippets. Suggestions include PostgreSQL with vector embeddings plus metadata JSONB, Jina embeddings, and R2R/GraphRAG-style systems. See the [thread](https://www.reddit.com/r/LocalLLaMA/comments/1gfqzs0).

Useful lesson: for large technical corpora, retrieval quality matters more than pretty note structures. Metadata, code-aware chunking, and hybrid search are important.

## LinkedIn and X/Twitter Patterns

### Business-Specific AI Second Brains

LinkedIn has a visible business/consulting wave: people packaging their own workflows, playbooks, templates, and client knowledge into agent-readable repos. [AI Second Brain by Iwo Szapar](https://www.linkedin.com/company/ai-second-brain) describes a Claude Code based GTM system with agents, skills, tool integrations, SEO workflows, positioning workshops, competitor research, content generation, CRM/data integrations, and claimed time savings for knowledge workers.

Useful lesson: domain-specific second brains are easier to monetize and evaluate than generic PKM. A GTM second brain can run keyword maps, content gaps, ICP work, call prep, proposals, and content repurposing. The output is concrete.

### Plain Files, Git, and Skills

Mark Hernandez's public LinkedIn post argues that people quickly outgrow a single memory file. His setup uses plain Markdown, Git, structured memory, 50+ skills, and isolation boundaries between client and personal contexts. See [his post](https://www.linkedin.com/posts/nycmark_the-ai-second-brain-went-viral-millions-activity-7449445044744425472-CVI8).

Useful lesson: permissions and context isolation become core product features once the memory contains real client/work/personal data.

### Enterprise Knowledge Work

Brian Madden's LinkedIn article describes moving decades of enterprise IT knowledge into plain text files maintained by AI. His key claim is that the shift is not an app but a pattern: coding agents can operate on knowledge bases the same way they operate on codebases. He also raises governance, ownership, sharing, provenance, and economics of expertise. See [the article](https://www.linkedin.com/pulse/i-built-second-brain-using-ai-its-changed-way-work-future-madden-0tote).

Useful lesson: the enterprise question is not "which notes app?" It is "what happens when tacit knowledge becomes file-backed, shareable, and agent-readable?"

### Karpathy and GBrain on X

Public X search shows Karpathy's LLM Wiki idea rapidly turned into builder projects. Garry Tan's GBrain announcement said it helps OpenClaw/Hermes agents get recall over 10,000+ Markdown files and that it mirrors his own setup. See [Garry Tan's X post](https://x.com/garrytan/status/2042497872114090069).

Other X posts show rapid adaptations:

- Agent memory repos built from Karpathy's idea.
- Obsidian as IDE / LLM as programmer framing.
- X bookmarks and social content ingested into self-improving agent systems.
- Video walkthroughs for Claude Code + Obsidian.
- Cross-platform desktop apps implementing LLM Wiki.

Useful lesson: many builders are not waiting for polished apps. They are using agents to instantiate patterns directly.

## What Use Cases Work Well

### 1. Research and Synthesis

Works when:

- Sources are curated.
- The question/domain is bounded.
- The system produces summaries, entity pages, contradictions, and synthesis pages.
- Outputs are reused: memos, briefs, essays, presentations, literature reviews.

Common implementation:

- Raw source folder.
- Web clipper/PDF importer.
- LLM ingest.
- Wiki pages by concept/entity/source.
- `index.md`, `log.md`, citations.
- Hybrid search when corpus grows.

Why it works:

- Research naturally accumulates over weeks/months.
- Cross-source synthesis is painful manually and useful when automated.

### 2. Meetings, People, and Project Memory

Works when:

- Meetings/transcripts are captured automatically.
- Decisions and action items are extracted.
- People and companies get durable pages.
- Updates append to timelines instead of overwriting history.

Common implementation:

- Transcript/voice ingestion.
- Entity extraction.
- People/company/project pages.
- Decision log.
- Task/action log.
- Follow-up reminders.

Why it works:

- The value is immediate before calls, reviews, and follow-ups.
- It reduces "what did we decide?" overhead.

### 3. AI Agent Continuity

Works when:

- Each session starts by loading a small state package.
- Each session ends by writing back summary, decisions, facts, and open loops.
- The agent has procedural memory and mistake logs.
- Retrieval is scoped to the current project/client.

Common implementation:

- `CLAUDE.md` / `AGENTS.md`.
- `MEMORY.md`.
- Session digests.
- Handoff JSON.
- Mistakes/lessons file.
- Search tool or MCP memory server.

Why it works:

- It addresses a real pain in long-running AI work: context resets.

### 4. Learning and Study

Works when:

- Lecture notes/readings are ingested.
- Concepts are normalized across courses.
- Gaps are flagged.
- The system generates study guides, interview prep, and spaced review prompts.

Common implementation:

- Obsidian vault.
- Course/topic pages.
- Concept graph.
- AI synthesis.
- Spaced repetition.

Why it works:

- Students need repeated retrieval and synthesis, not just storage.

### 5. Domain-Specific Work Systems

Works when:

- The brain contains reusable playbooks and workflows.
- Commands/skills map to real work outputs.
- The system connects to business tools.

Examples:

- GTM research and content.
- Investor diligence and deal memos.
- Engineering project review.
- Competitive intelligence.
- Personal CRM.

Why it works:

- There is a clear measure of value: saved time, better memos, better prep, fewer dropped balls.

## What Fails

### Over-Collection

Passive capture can overwhelm the user. Browser history, RSS, chats, meeting transcripts, voice notes, and bookmarks produce too much material. Without filtering, summarization, deduplication, and review, the second brain becomes a searchable landfill.

### Over-Organization

People lose weeks designing folders, dashboards, graph views, tags, and templates. The system feels productive but does not produce work. This failure mode is common in Obsidian/Notion discussions.

### RAG Without Memory Evolution

Plain RAG answers questions over existing notes but does not improve the notes. It is useful search, not a compounding second brain. The current wave prefers systems that write back durable summaries, relationships, decisions, and contradictions.

### Stale and Contradictory Memory

Personal facts change. Project state changes. Preferences change. Old advice becomes wrong. If the memory layer cannot track confidence, source, date, validity, and supersession, the assistant will confidently retrieve obsolete information.

### Missing Permissions and Context Isolation

A real second brain contains sensitive personal and client information. Once agents can read/write it, boundaries matter:

- Which memories can be used for which client?
- Which tools can write to the brain?
- Which sources are trusted?
- What is visible to remote MCP clients?
- What must never be shared?

### No Output Loop

Notes that never become writing, decisions, reminders, plans, briefs, or better conversations are just archived anxiety.

## Common Implementation Patterns

### Minimal LLM Wiki

Best for: research, writing, learning, early product prototype.

Structure:

```text
raw/
  articles/
  transcripts/
  PDFs/
wiki/
  index.md
  log.md
  concepts/
  people/
  projects/
  sources/
AGENTS.md or CLAUDE.md
```

Operations:

- Ingest one source.
- Update pages.
- Append log.
- Query wiki.
- Save good answers back.
- Lint for broken links, stale claims, missing pages.

### Obsidian + Agent

Best for: users who want a human-readable app and agent automation.

Stack:

- Obsidian vault.
- Claude Code/Codex/Gemini/OpenCode.
- Web Clipper.
- Git sync.
- Dataview/Templater/Calendar optionally.
- QMD or local search optionally.

Operations:

- Capture daily notes and voice notes.
- Agent organizes/refactors.
- Agent maintains indexes and dashboards.
- Human reads in Obsidian.

### RAG/Vector Memory

Best for: large corpora, technical docs, search-heavy use.

Stack:

- Postgres + pgvector, LanceDB, ChromaDB, SQLite vec, Qdrant, or similar.
- Chunking pipeline.
- Metadata tables.
- Embedding model.
- Hybrid search.
- Reranker optional.

Operations:

- Ingest documents.
- Chunk and embed.
- Query with metadata filters.
- Cite sources.

Weakness:

- Does not automatically create a durable conceptual model unless paired with synthesis.

### Graph Memory / GraphRAG

Best for: people/company/project networks, concept maps, explicit relationships.

Stack:

- Entity extraction.
- Relation extraction.
- Graph database or graph tables.
- Typed edges.
- Temporal facts.
- Graph traversal tools exposed over MCP.

Operations:

- Extract entities from every page/meeting/source.
- Create/update people/company/concept pages.
- Query neighborhoods, paths, bridges, communities.

Weakness:

- Entity resolution and stale edges are hard.

### Agent Operating System

Best for: advanced users and heavy AI workflows.

Stack:

- Markdown/Git repo or database.
- Skills/commands.
- MCP tools.
- Capture pipelines.
- Cron jobs.
- Handoff/state files.
- Guardrails and context isolation.

Operations:

- Startup: load current state.
- Work: search brain before acting.
- Shutdown: summarize, write back, update tasks, log mistakes.
- Nightly: consolidate, dedupe, detect contradictions.

Weakness:

- Too complex for normal consumers unless hidden behind product UX.

## Design Implications for Pensieve

### Product Positioning

Pensieve should not position itself as "yet another notes app." The emerging wedge is:

> A local-first AI memory system that turns voice notes, transcripts, chats, and raw captures into a maintained personal wiki with timelines, contradictions, people/project memory, and useful outputs.

The strongest differentiator is not capture alone. It is conversion from raw messy input into durable, inspectable memory.

### Core User Workflows

Prioritize workflows that create immediate value:

1. Capture a voice note and turn it into structured memory.
2. Ask "what have I been thinking about X?" and get cited answers from notes.
3. See a timeline of how an idea/person/project changed.
4. Detect contradictions or stale beliefs.
5. Prepare for a meeting/person/project from prior memory.
6. Turn a cluster of notes into a memo/blog/plan.
7. End a session/day with action items, decisions, and unresolved questions.

### Data Model

Pensieve should represent memory as more than notes:

- Raw captures: audio, transcript, imported text, source metadata.
- Notes/wiki pages: synthesized durable pages.
- Entities: people, organizations, projects, concepts, places.
- Events/timeline entries: dated claims and updates.
- Decisions: what was decided, when, why.
- Tasks/promises: follow-ups and open loops.
- Contradictions: conflicting claims with source links.
- Confidence/provenance: explicit, inferred, user-confirmed, stale.

### Retrieval

A good retrieval stack should combine:

- Keyword search for exact recall.
- Semantic search for fuzzy association.
- Recency and source filters.
- Entity graph traversal.
- "Current truth" versus historical timeline.

For early versions, local SQLite plus FTS and embeddings may be enough. Graph features can start as typed relations in tables rather than a full graph database.

### AI Behavior

The agent should:

- Cite source captures/notes.
- Say when memory is missing.
- Prefer user-confirmed facts over inferred facts.
- Mark stale or contradictory claims.
- Ask before overwriting important memories.
- Keep raw source immutable.
- Log every material write.

### UX Lessons

Make the first screen about the actual memory workflow, not a marketing dashboard:

- Fast voice/text capture.
- Inbox of unprocessed captures.
- Daily/weekly review.
- Wiki/timeline views.
- Contradictions view.
- Chat with citations.
- People/project pages.

Avoid making users choose a taxonomy upfront. Let structure emerge, then let the AI suggest organization.

### Privacy

Local-first is a real advantage in this category. Users are putting intimate notes, clients, meetings, health, finance, and identity into these systems. Pensieve should be explicit about:

- What stays local.
- What goes to model providers.
- Which notes are used for which query.
- Export format.
- Deletion and redaction.
- Per-project/person privacy boundaries.

## Recommended Product Direction

Build Pensieve around a simple loop:

```text
Capture -> Distill -> Link -> Use -> Review -> Correct
```

The loop should be visible in product behavior:

- Capture: voice/text/import.
- Distill: transcript summary, facts, themes, tasks.
- Link: people/projects/concepts/timelines.
- Use: chat, meeting prep, memos, decisions.
- Review: daily/weekly inbox and memory changes.
- Correct: contradictions, stale facts, mistaken inferences.

The most important missing feature in many second-brain systems is "correct." Users do not only need the AI to remember; they need it to forget, supersede, and revise safely.

## Source Index

Foundational:

- [Vannevar Bush, "As We May Think"](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/)
- [Obsidian official site](https://obsidian.md/)
- [Karpathy LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)

GitHub:

- [GitHub topic: second-brain](https://github.com/topics/second-brain)
- [GitHub topic: personal-knowledge-management](https://github.com/topics/personal-knowledge-management)
- [garrytan/gbrain](https://github.com/garrytan/gbrain)
- [NateBJones-Projects/OB1](https://github.com/NateBJones-Projects/OB1)
- [reorproject/reor](https://github.com/reorproject/reor)
- [NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain)
- [SamurAIGPT/llm-wiki-agent](https://github.com/SamurAIGPT/llm-wiki-agent)
- [ballred/obsidian-claude-pkm](https://github.com/ballred/obsidian-claude-pkm)
- [huytieu/COG-second-brain](https://github.com/huytieu/COG-second-brain)
- [Jallermax/knowledge-nexus](https://github.com/Jallermax/knowledge-nexus)
- [memex-life/memex](https://github.com/memex-life/memex)
- [your-papa/obsidian-smart2brain](https://github.com/your-papa/obsidian-smart2brain)

Reddit:

- [Claude Code + Obsidian + QMD persistent assistant](https://www.reddit.com/r/ClaudeCode/comments/1rn38wh/i_built_a_persistent_ai_assistant_with_claude/)
- [25-tool Claude Code + Obsidian + Ollama second brain](https://www.reddit.com/r/ClaudeAI/comments/1sbtb34/i_gave_claude_code_a_knowledge_graph_spaced/)
- [GraphThulhu MCP second brain](https://www.reddit.com/r/ClaudeAI/comments/1rcns6i/second_brain_powered_by_ai_mcp_called_graphthulhu/)
- [Building Second Brain using Obsidian](https://www.reddit.com/r/ObsidianMD/comments/191a6zd/building_second_brain_using_obsidian/)
- [RAG second brain for technical docs](https://www.reddit.com/r/LocalLLaMA/comments/1gfqzs0)

LinkedIn/X:

- [Brian Madden: AI second brain and future of knowledge work](https://www.linkedin.com/pulse/i-built-second-brain-using-ai-its-changed-way-work-future-madden-0tote)
- [AI Second Brain by Iwo Szapar](https://www.linkedin.com/company/ai-second-brain)
- [Mark Hernandez: building beyond second brain with Claude Code](https://www.linkedin.com/posts/nycmark_the-ai-second-brain-went-viral-millions-activity-7449445044744425472-CVI8)
- [Garry Tan GBrain announcement on X](https://x.com/garrytan/status/2042497872114090069)
