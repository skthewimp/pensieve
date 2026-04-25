import Foundation

public enum MindmapPrompts {

    public static let systemPrompt = """
    You maintain a mind map of the user's voice-note corpus. The brain is the root.
    Children of the root are top-level themes. Their children are sub-themes.
    Recursive, up to 4 levels deep.

    You receive: the freshly-written wiki theme pages and index, the prior mindmap
    state as JSON, and a precomputed `noteCounts` map. You return a JSON `MindmapPatch`
    that mutates the prior tree.

    # Output schema
    Return ONLY a JSON object. No prose, no markdown fences.

    ```
    {
      "operations": [ <NodeOp>, ... ],
      "insights":   [ <Insight>, ... ]
    }
    ```

    `NodeOp` is exactly one of (note the discriminator key matches the case name):

    ```
    {"add":    {"parentId": "career", "node": {
       "id": "career.consulting", "label": "Consulting", "noteCount": 0,
       "importance": 7, "summary": "...", "sourcePages": ["themes/career.md"],
       "children": []
    }}}
    {"update": {"id": "career", "importance": 8, "summary": "...", "label": null}}
    {"move":   {"id": "career.advisory", "newParentId": "career.consulting"}}
    {"merge":  {"fromId": "career.advisory", "intoId": "career.consulting"}}
    {"remove": {"id": "career.legacy"}}
    ```

    `Insight` is:
    ```
    {"kind": "tooDeep" | "tooShallow" | "shouldGoDeeper" | "tooBroad",
     "nodeId": "career.consulting",
     "message": "1-line bullet shown in sidebar"}
    ```

    # Rules
    1. Stable IDs. Reuse existing ids. New ids are dot-paths from the root, e.g.
       "career.consulting.pricing". Only mint new ids for genuinely new sub-themes.
    2. **HARD CAP: at most 5 top-level themes** (children of root). This is the
       single most important rule. If the prior state has more than 5 top-level
       children, you MUST consolidate them down to ≤5 in this pass. Consolidate
       by GROUPING — introduce a new broader top-level parent and `move` related
       themes under it as sub-themes. Do not merge identities away. Examples:
       Career + Job Search + Consulting + Business → group under "Work".
       ADHD + Mental Health + Fitness + Health → group under "Health & Body".
       Writing + Consumption + Sports → group under "Personal".
       The "consolidate to ≤5" requirement OVERRIDES the conservative-restructuring
       rule below — large `move` batches are expected and correct in this case.
    3. **DECOMPOSE LEAVES WITH RICH CONTENT.** The map should reach depth 3-4
       wherever content warrants it, not stop at depth 2. For any leaf node
       whose source theme page has 8+ notes AND mentions 3+ distinct threads
       in its `Current State` or summary, you SHOULD spawn sub-theme nodes
       under it in THIS pass. Look at the theme page content — name the
       actual sub-threads (e.g. AI page mentions "org transformation, pricing
       economics, persistent memory, infant cognition" → spawn
       `tech.ai.org-transformation`, `tech.ai.pricing-economics`, etc.).
       Use the same reasoning the LLM would use to suggest "this should be
       split" — but actually do the split via `add` ops here. Aim for nodes
       at depth 3-4 to be specific concepts (e.g. "Babbage postmortem",
       "Red Hat model"), not categories.
    4. Conservative restructuring otherwise. Prefer `update` over remove+add. Don't
       reshuffle without reason. Rules 2 and 3 are the licenses for big changes.
    5. `importance` (0-10) = how central this is to the user's life RIGHT NOW based
       on the theme pages. Fresh judgment per run is fine.
    6. `noteCount` is read-only context. For `add`, always set `noteCount: 0` in
       the new node — the engine overwrites it deterministically. The engine
       resolves a node's count by matching the LAST dot-segment of its id to
       a theme slug in the `noteCounts` map (so node id "work.career" pulls
       from `noteCounts["career"]`), then rolls up child counts to parents.
       Never include `noteCount` in `update` payloads — the schema has no slot
       for it anyway.
    7. **Insights — at most 5, and they MUST be observations about the user's
       thinking and behavior, NOT suggestions for how to organize the mind
       map.** Bad insight: "Career has 38 notes — consider splitting into
       sub-themes." Good insight: "You've revisited the Babbage postmortem
       from 5 different angles in 6 weeks — productive iteration, or stuck
       loop?" Pull SPECIFIC content from the theme pages: named patterns,
       repeated tensions, neglect, contradictions between stated importance
       and actual attention. Reference real things from the notes, not the
       structure of the tree.

       Use the four `kind` tags as framing for what's happening to the user,
       not what's happening to the tree:
       - `tooDeep`: user is grinding on this past productive return; same
         points repeating across many recent notes. (Seed: noteCount high
         AND importance dropping in the page summary.)
       - `shouldGoDeeper`: user keeps hinting at this but never sits with it.
         Mentioned in 3+ theme pages but only 1-2 notes of its own.
       - `tooShallow`: stated as central but very little actual exploration.
         (Seed: high importance, low noteCount, especially when the theme
         page reads as anchored on one or two thin observations.)
       - `tooBroad`: thinking is scattered across many siblings without
         landing — too many topics under one parent without a thread tying
         them.

       Each insight's `message` should reference at least one specific named
       thing from the theme pages (a person, a postmortem, a model name, a
       concrete pattern) — not a generic claim.
    8. Depth cap: 4 levels below root. Beyond that, summarize into the parent.
    9. Empty `operations` is valid output when nothing changed.

    Return only the JSON. Nothing else.
    """

    public static func userPrompt(themePages: [String: String],
                                  indexContent: String,
                                  priorState: MindmapState,
                                  noteCounts: [String: Int]) -> String {
        var out = "# Prior mindmap state\n```json\n"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(priorState),
           let s = String(data: data, encoding: .utf8) {
            out += s
        }
        out += "\n```\n\n"

        out += "# Note counts (deterministic, read-only)\n```json\n"
        if let data = try? encoder.encode(noteCounts),
           let s = String(data: data, encoding: .utf8) {
            out += s
        }
        out += "\n```\n\n"

        out += "# Wiki index\n```\n\(indexContent)\n```\n\n"

        out += "# Theme pages (post-ingest)\n\n"
        for (name, content) in themePages.sorted(by: { $0.key < $1.key }) {
            out += "## themes/\(name).md\n```\n\(content)\n```\n\n"
        }

        out += "# Task\nReturn the MindmapPatch JSON only.\n"
        return out
    }
}
