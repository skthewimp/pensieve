# LLM Wiki — Andrej Karpathy

> Source: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
> Saved: 2026-04-07

## The Core Idea

Instead of RAG (re-deriving knowledge from raw docs on every query), the LLM **incrementally builds and maintains a persistent wiki** — a structured, interlinked collection of markdown files. When you add a new source, the LLM reads it, extracts key information, and integrates it into the existing wiki — updating entity pages, revising topic summaries, noting contradictions, strengthening or challenging the evolving synthesis.

**The wiki is a persistent, compounding artifact.** Cross-references are already there. Contradictions have been flagged. Synthesis reflects everything you've read.

## Architecture (Three Layers)

1. **Raw sources** — curated collection of source documents. Immutable. LLM reads but never modifies.
2. **The wiki** — LLM-generated markdown files. Summaries, entity pages, concept pages, comparisons, overview, synthesis. LLM owns this layer entirely.
3. **The schema** — a document (CLAUDE.md) that tells the LLM how the wiki is structured, conventions, and workflows.

## Operations

- **Ingest**: Drop a new source → LLM reads it, writes summary, updates index, updates relevant entity/concept pages. A single source might touch 10-15 wiki pages.
- **Query**: Ask questions → LLM searches relevant pages, synthesizes answer with citations. Good answers can be filed back into the wiki as new pages.
- **Lint**: Periodically health-check. Look for contradictions, stale claims, orphan pages, missing cross-references, data gaps.

## Indexing and Logging

- **index.md** — content-oriented catalog of everything in the wiki. LLM reads this first to find relevant pages.
- **log.md** — chronological, append-only record of what happened and when (ingests, queries, lint passes).

## Key Insight

> The tedious part of maintaining a knowledge base is not the reading or the thinking — it's the bookkeeping. LLMs don't get bored, don't forget to update a cross-reference, and can touch 15 files in one pass. The wiki stays maintained because the cost of maintenance is near zero.

> The human's job is to curate sources, direct the analysis, ask good questions, and think about what it all means. The LLM's job is everything else.
