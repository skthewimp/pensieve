# TestFlight Notes: Rediscovery Review

## What Changed

This build focuses on making Pensieve better at helping you revisit old notes.

- Weekly Digest: generates a source-backed review of the latest week of notes.
- Retrospective Connections: finds backlinks and multi-note threads across time.
- Rediscovered Notes: surfaces older notes that connect to recent themes.
- Related Notes and Backlinks: note detail screens now show nearby notes and LLM-generated connections.
- Topic Cleanup: consolidates noisy raw themes into a smaller set of canonical topics.

There are no social features in this build.

## What To Try

1. Add or import a meaningful set of notes.
2. Open Settings.
3. Confirm the Anthropic API key is configured.
4. Run Clean Up Topics.
5. Review the preview and apply it if the topics look sensible.
6. Run Generate Weekly Digest.
7. Run Connect Notes Retrospectively.
8. Open Insights and review:
   - Weekly Digests
   - Rediscovered Notes
   - Retrospective Connections
9. Open a note detail page and check Related Notes and Backlinks.
10. Quit and reopen the app to confirm generated items persist.

## Useful Feedback

Focus feedback on whether the output is genuinely useful:

- Are the canonical topics too broad, too narrow, or mislabeled?
- Does the weekly digest feel grounded in actual notes?
- Are rediscovered notes worth revisiting?
- Do backlinks connect notes in a surprising but defensible way?
- Are any generated explanations generic, repetitive, or unsupported?
- Did anything disappear after relaunch?
- Did any screen feel cluttered or confusing?

## Known Limits

- LLM features require an Anthropic API key.
- Generated outputs depend on the quality and volume of available notes.
- Topic cleanup is meant to create durable review topics, not preserve every raw tag.
- Backlinks are intentionally selective; missing a weak connection is better than flooding the app.
