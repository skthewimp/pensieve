# Testing With The iCloud Vault

Pensieve should be tested against the real SecondBrain iCloud vault before calling product changes done.

Default private vault path:

```text
/Users/Karthik/Library/Mobile Documents/iCloud~md~obsidian/Documents/SecondBrain/raw
```

The test bed reads this folder in place. It does not copy note contents into the repo.

## Standard Gate

Run:

```bash
scripts/test_after_update.sh
```

This performs:

- iOS simulator build with `xcodebuild`.
- Real-vault parse/import validation.
- Topic cleanup validation that compresses raw themes into a small canonical topic set and covers high-count raw themes.
- Rediscovery validation against the vault, including non-empty older-note resurfacing and thematic diversity.
- Latest-week digest sampling from the real vault.
- Required LLM weekly digest test with source IDs, all expected sections, themes, confidence, and minimum substance checks.
- Required LLM backlink/thread test with valid source IDs, backlink/thread mix, non-thin explanations, confidence, and cross-week connections.

The script automatically sources the existing private local key file at:

```text
/Users/Karthik/Documents/work/stalker-mac/.env
```

Do not print or commit the key. If neither `ANTHROPIC_API_KEY` nor the private `.env` key is available, the gate should fail.

## Feature-Aware Gate

The gate must be adjusted when a feature has a specific product output. Build success and generic smoke tests are not enough.

For each feature, add assertions that check the output shape and usefulness. Examples:

- Weekly digest: expected sections, valid source note IDs, enough cited notes, grounded themes, non-trivial explanation length.
- Topic cleanup: raw themes must collapse into a small canonical set, aliases must cover high-count raw themes, and the taxonomy must include core user-facing areas.
- Rediscovery: real older notes are resurfaced, they share themes with recent notes, and the top results are not all one theme.
- Retrospective connections: valid backlinks and threads, no unknown source IDs, at least some connections bridge different weeks, explanations are substantial.

For changes that touch LLM prompts, note connections, insights, wiki synthesis, corpus analysis, rediscovery, or digest behavior, the standard gate already runs the required LLM tests. To run only the vault/LLM harness:

```bash
ANTHROPIC_API_KEY=... scripts/test_with_icloud_vault.py --require-llm
```

The harness should grow with the product. If a new release-critical feature has its own expected output, add a dedicated validator before calling the work done.

## Alternate Vault Path

Use `PENSIEVE_VAULT_RAW` when testing a copied or alternate vault:

```bash
PENSIEVE_VAULT_RAW=/path/to/raw scripts/test_after_update.sh
```
