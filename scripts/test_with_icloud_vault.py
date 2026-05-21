#!/usr/bin/env python3
"""
Exercise Pensieve's real-corpus paths against the private iCloud Obsidian vault.

This script intentionally reads the vault in place and does not write note
contents into the repo.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import sys
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


DEFAULT_RAW_VAULT = Path(
    "/Users/Karthik/Library/Mobile Documents/iCloud~md~obsidian/Documents/SecondBrain/raw"
)
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
MODEL = "claude-sonnet-4-20250514"


@dataclass
class ParsedNote:
    id: str
    path: Path
    title: str
    summary: str
    body: str
    themes: list[str]
    tone: str | None
    created_at: datetime


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Pensieve tests against the iCloud vault.")
    parser.add_argument(
        "--vault-raw",
        type=Path,
        default=Path(os.environ.get("PENSIEVE_VAULT_RAW", DEFAULT_RAW_VAULT)),
        help="Path to SecondBrain/raw markdown folder.",
    )
    parser.add_argument("--min-notes", type=int, default=50)
    parser.add_argument("--sample-limit", type=int, default=80)
    parser.add_argument("--timeout-seconds", type=int, default=120)
    parser.add_argument("--require-llm", action="store_true")
    parser.add_argument("--skip-llm", action="store_true")
    args = parser.parse_args()

    install_timeout(args.timeout_seconds)
    notes = load_notes(args.vault_raw)
    assert_or_exit(len(notes) >= args.min_notes, f"expected at least {args.min_notes} notes, found {len(notes)}")
    assert_or_exit(any(note.themes for note in notes), "expected at least one parsed theme")
    assert_or_exit(any(note.summary.strip() for note in notes), "expected at least one parsed summary")
    assert_or_exit(len({note.id for note in notes}) == len(notes), "expected stable unique note IDs")

    rediscovered = rediscovered_notes(notes)
    validate_rediscovery(rediscovered, notes)

    sample = connection_sample(notes, args.sample_limit)
    assert_or_exit(len(sample) >= min(args.sample_limit, len(notes)), "connection sample did not fill")
    assert_or_exit(any(note.created_at.year < datetime.now().year or note.created_at.month < datetime.now().month for note in sample), "sample should include older notes")

    weekly = weekly_notes(notes)
    assert_or_exit(len(weekly) >= 3, f"expected at least 3 notes in latest-week digest sample, found {len(weekly)}")

    print(f"vault: {args.vault_raw}")
    print(f"notes parsed: {len(notes)}")
    print(f"themes parsed: {len(theme_counts(notes))}")
    print(f"rediscovered notes: {len(rediscovered)}")
    print(f"weekly digest sample: {len(weekly)} notes")
    print(f"connection sample: {len(sample)} notes")
    print("top themes:", ", ".join(f"{theme}={count}" for theme, count in theme_counts(notes).most_common(8)))

    if args.skip_llm:
        print("llm: skipped")
        return 0

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        message = "ANTHROPIC_API_KEY is not set; cannot run LLM backlink test"
        if args.require_llm:
            fail(message)
        print(f"llm: skipped ({message})")
        return 0

    taxonomy = generate_topic_taxonomy(notes, api_key)
    validate_topic_taxonomy(taxonomy, notes)
    print(f"canonical topics: {len(taxonomy)}")
    print("topic coverage:", f"{topic_coverage(taxonomy, notes):.0%}")

    digest = generate_weekly_digest(weekly, api_key)
    validate_weekly_digest(digest, weekly)
    print(f"weekly digest sources: {len(digest.get('sourceNoteIDs', []))}")
    print("weekly digest sections:", ", ".join(present_digest_sections(digest.get("explanation", ""))))

    connections = generate_note_connections(sample, api_key)
    validate_connections(connections, sample)
    print(f"llm connections: {len(connections)}")
    print("llm kinds:", ", ".join(f"{kind}={count}" for kind, count in Counter(c["kind"] for c in connections).items()))
    return 0


def load_notes(raw_vault: Path) -> list[ParsedNote]:
    assert_or_exit(raw_vault.exists(), f"vault path does not exist: {raw_vault}")
    markdown_files = sorted(raw_vault.rglob("*.md"))
    notes: list[ParsedNote] = []
    for path in markdown_files:
        try:
            markdown = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        note = parse_note(markdown, path)
        if note:
            notes.append(note)
    return sorted(notes, key=lambda note: note.created_at, reverse=True)


def install_timeout(seconds: int) -> None:
    if seconds <= 0:
        return

    def timeout_handler(signum: int, frame: Any) -> None:
        raise TimeoutError(f"vault test exceeded {seconds} seconds")

    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(seconds)


def parse_note(markdown: str, path: Path) -> ParsedNote | None:
    frontmatter = parse_frontmatter(markdown)
    body = markdown_without_frontmatter(markdown)
    raw_text = section("Transcription", markdown) or section("Raw Input", markdown) or body
    title = frontmatter.get("title") or heading_title(markdown) or path.stem
    created_at = parse_date(frontmatter.get("date", "")) or date_from_filename(path) or datetime.fromtimestamp(path.stat().st_mtime)
    summary = section("Summary", markdown) or raw_text.strip()
    themes = parse_themes(frontmatter.get("themes"))
    tone = frontmatter.get("emotional_tone")
    note_id = f"secondbrain/raw/{path.name}"
    if not raw_text.strip():
        return None
    return ParsedNote(
        id=note_id,
        path=path,
        title=title.strip(),
        summary=clean_summary(summary),
        body=body,
        themes=themes,
        tone=tone,
        created_at=created_at,
    )


def parse_frontmatter(markdown: str) -> dict[str, str]:
    if not markdown.startswith("---\n"):
        return {}
    end = markdown.find("\n---", 4)
    if end == -1:
        return {}
    values: dict[str, str] = {}
    for line in markdown[4:end].splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"')
    return values


def markdown_without_frontmatter(markdown: str) -> str:
    if not markdown.startswith("---\n"):
        return markdown.strip()
    end = markdown.find("\n---", 4)
    if end == -1:
        return markdown.strip()
    return markdown[end + 4 :].strip()


def heading_title(markdown: str) -> str | None:
    for line in markdown.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return None


def section(name: str, markdown: str) -> str | None:
    lines = markdown.splitlines()
    marker = f"## {name}"
    for idx, line in enumerate(lines):
        if line.strip() != marker:
            continue
        body: list[str] = []
        for body_line in lines[idx + 1 :]:
            if body_line.startswith("## "):
                break
            body.append(body_line)
        text = "\n".join(body).strip()
        return text or None
    return None


def parse_themes(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [
        part.strip().strip('"').lower()
        for part in raw.strip("[]").split(",")
        if part.strip().strip('"')
    ]


def parse_date(raw: str) -> datetime | None:
    if not raw:
        return None
    value = raw.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def date_from_filename(path: Path) -> datetime | None:
    try:
        return datetime.strptime(path.stem, "%Y-%m-%d_%H%M")
    except ValueError:
        return None


def clean_summary(summary: str) -> str:
    lines = [
        line.strip().lstrip("- ").strip()
        for line in summary.splitlines()
        if line.strip()
    ]
    return "\n".join(lines)


def theme_counts(notes: list[ParsedNote]) -> Counter[str]:
    return Counter(theme for note in notes for theme in note.themes)


def weekly_notes(notes: list[ParsedNote]) -> list[ParsedNote]:
    latest = max(note.created_at for note in notes)
    start = latest - timedelta(days=7)
    return sorted(
        [note for note in notes if start <= note.created_at <= latest],
        key=lambda note: note.created_at,
    )


def rediscovered_notes(notes: list[ParsedNote]) -> list[dict[str, Any]]:
    latest = max(note.created_at for note in notes)
    recent_cutoff = latest - timedelta(days=14)
    old_cutoff = latest - timedelta(days=14)
    recent_themes = {
        theme
        for note in notes
        if note.created_at >= recent_cutoff
        for theme in note.themes
    }
    results: list[dict[str, Any]] = []
    for note in notes:
        if note.created_at >= old_cutoff:
            continue
        matches = [theme for theme in note.themes if theme in recent_themes]
        if not matches:
            continue
        results.append({"note": note, "matches": sorted(set(matches)), "score": len(matches)})
    return sorted(
        results,
        key=lambda item: (item["score"], item["note"].created_at),
        reverse=True,
    )


def validate_rediscovery(rediscovered: list[dict[str, Any]], notes: list[ParsedNote]) -> None:
    assert_or_exit(len(rediscovered) >= 5, f"expected at least 5 rediscovered notes, found {len(rediscovered)}")
    latest = max(note.created_at for note in notes)
    old_cutoff = latest - timedelta(days=14)
    top = rediscovered[:8]
    assert_or_exit(all(item["note"].created_at < old_cutoff for item in top), "rediscovery returned notes that are not old enough")
    assert_or_exit(all(item["matches"] for item in top), "rediscovery returned notes without a recent theme match")
    assert_or_exit(len({theme for item in top for theme in item["matches"]}) >= 3, "rediscovery top results are not thematically diverse")


def connection_sample(notes: list[ParsedNote], limit: int) -> list[ParsedNote]:
    sorted_notes = sorted(notes, key=lambda note: note.created_at, reverse=True)
    recent_limit = max(12, limit // 3)
    selected = list(sorted_notes[:recent_limit])
    selected_ids = {note.id for note in selected}
    top_themes = [theme for theme, _ in theme_counts(notes).most_common(20)]

    for theme in top_themes:
        themed = [note for note in sorted_notes if note.id not in selected_ids and theme in note.themes]
        for note in themed[-3:]:
            selected.append(note)
            selected_ids.add(note.id)
            if len(selected) >= limit:
                return sorted(selected, key=lambda note: note.created_at)

    for note in reversed(sorted_notes):
        if note.id in selected_ids:
            continue
        selected.append(note)
        selected_ids.add(note.id)
        if len(selected) >= limit:
            break
    return sorted(selected, key=lambda note: note.created_at)


def topic_cleanup_sample(notes: list[ParsedNote], limit: int) -> list[ParsedNote]:
    sorted_notes = sorted(notes, key=lambda note: note.created_at, reverse=True)
    top_themes = [theme for theme, _ in theme_counts(notes).most_common(limit)]
    selected: list[ParsedNote] = []
    selected_ids: set[str] = set()
    for theme in top_themes:
        match = next((note for note in sorted_notes if note.id not in selected_ids and theme in note.themes), None)
        if not match:
            continue
        selected.append(match)
        selected_ids.add(match.id)
        if len(selected) >= limit:
            return selected
    for note in sorted_notes:
        if note.id in selected_ids:
            continue
        selected.append(note)
        selected_ids.add(note.id)
        if len(selected) >= limit:
            break
    return selected


def generate_topic_taxonomy(notes: list[ParsedNote], api_key: str) -> list[dict[str, Any]]:
    sample = topic_cleanup_sample(notes, 48)
    payload = {
        "model": MODEL,
        "max_tokens": 4096,
        "temperature": 0,
        "system": """You clean up topics for a local-first personal memory app called Pensieve. The current notes have too many overlapping themes. Consolidate raw themes into a small durable topic map for navigation, rediscovery, wiki pages, and weekly digests. This is a taxonomy-only pass.

Return only a JSON object with this exact shape:
{"topics":[{"title":"Career","canonicalTheme":"career","aliases":["work","consulting"],"sourceNoteIDs":["uuid from supplied notes"],"relatedThemes":["money"]}],"noteThemeAssignments":[]}

Rules:
- Use 10 to 14 canonical themes for this corpus. Never create one topic per raw theme.
- canonicalTheme values must be lowercase, short, stable nouns or noun phrases.
- Merge near-duplicates and sibling tags aggressively. Examples: work/career/consulting/business/sales/entrepreneurship -> career; identity/self-awareness/clarity/confidence/growth -> self-understanding; priorities/productivity/focus/habits/planning/decisions -> productivity; ai/technology/tools/automation/software -> technology.
- Split only when a topic would otherwise mix genuinely different user-facing review contexts.
- Put raw theme names into aliases so the app can map old notes onto the new canonical topics.
- Cover the high-count raw themes in either canonicalTheme or aliases.
- Do not assign themes note-by-note. Return an empty noteThemeAssignments array.
- sourceNoteIDs must use only IDs from supplied notes.
- Return only JSON.""",
        "messages": [
            {
                "role": "user",
                "content": "Existing theme counts:\n"
                + "\n".join(f"- {theme}: {count}" for theme, count in theme_counts(notes).most_common(120))
                + "\n\nRecent/high-signal note sample:\n"
                + "\n\n---\n\n".join(topic_digest(note) for note in sample),
            }
        ],
    }
    parsed = anthropic_json(payload, api_key, "topic taxonomy")
    topics = parsed.get("topics", [])
    assert_or_exit(isinstance(topics, list), "topic taxonomy did not return a topics array")
    return topics


def generate_weekly_digest(notes: list[ParsedNote], api_key: str) -> dict[str, Any]:
    payload = {
        "model": MODEL,
        "max_tokens": 4096,
        "temperature": 0,
        "system": """You create a weekly review digest for a local-first personal memory app called Pensieve. The digest must be concrete, source-backed, and useful for rediscovery and review.

Return only a JSON object with this exact shape:
{"insights":[{"kind":"weeklyDigest","title":"Week of short date range","explanation":"A concise markdown-style digest with sections: Recurring themes, Open loops, Decisions or possible decisions, Rediscovered threads, Questions for next week.","sourceNoteIDs":["uuid from supplied notes"],"themes":["theme"],"confidence":0.0}]}

Rules:
- Return exactly one insight.
- The kind must be weeklyDigest.
- sourceNoteIDs must only contain IDs from supplied notes.
- Include source-grounded specifics, not generic advice.
- Include the five requested sections in the explanation.
- Do not diagnose the user or invent facts absent from notes.
- confidence must be between 0 and 1.
- Return only JSON.""",
        "messages": [
            {
                "role": "user",
                "content": "Generate a weekly digest for this latest-week corpus slice:\n\n"
                + "\n\n---\n\n".join(connection_digest(note) for note in notes),
            }
        ],
    }
    parsed = anthropic_json(payload, api_key, "weekly digest")
    insights = parsed.get("insights", [])
    assert_or_exit(isinstance(insights, list) and insights, "Anthropic returned no weekly digest insight")
    return insights[0]


def generate_note_connections(notes: list[ParsedNote], api_key: str) -> list[dict[str, Any]]:
    payload = {
        "model": MODEL,
        "max_tokens": 8192,
        "temperature": 0,
        "system": """You connect notes retrospectively for a local-first personal memory app called Pensieve. Find meaningful backlinks and coherent thought threads that a simple keyword search would miss.

Return only a JSON object with this exact shape:
{"connections":[{"kind":"backlink","title":"short title","explanation":"two or three concrete source-grounded sentences","sourceNoteIDs":["uuid from supplied notes"],"themes":["theme"],"confidence":0.0}]}

Allowed kind values:
- backlink: a recent note is meaningfully illuminated by one or more older notes.
- thread: three or more notes together form a coherent thought, recurring concern, decision arc, or evolving idea.

Rules:
- sourceNoteIDs must only contain IDs from supplied notes.
- Each connection must include at least 2 sourceNoteIDs.
- Prefer 6 to 12 high-signal connections over volume.
- Prefer non-obvious connections grounded in content, not just shared tags.
- Keep explanations to one or two sentences.
- Explain the value of reviewing the notes together.
- Do not diagnose the user or invent facts absent from notes.
- confidence must be between 0 and 1.
- Return only JSON.""",
        "messages": [
            {
                "role": "user",
                "content": "Generate retrospective note connections from this corpus sample:\n\n"
                + "\n\n---\n\n".join(connection_digest(note) for note in notes),
            }
        ],
    }
    parsed = anthropic_json(payload, api_key, "connection")
    return parsed.get("connections", [])


def anthropic_json(payload: dict[str, Any], api_key: str, label: str) -> dict[str, Any]:
    last_error: json.JSONDecodeError | None = None
    for attempt in range(2):
        attempt_payload = dict(payload)
        if attempt:
            attempt_payload["system"] = (
                str(payload["system"])
                + "\nRetry requirement: return compact syntactically valid JSON only. Escape all quotes and newlines inside string values."
            )
        request = urllib.request.Request(
            ANTHROPIC_URL,
            data=json.dumps(attempt_payload).encode("utf-8"),
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            body = json.loads(response.read().decode("utf-8"))
        text = "\n\n".join(
            block.get("text", "")
            for block in body.get("content", [])
            if block.get("type") == "text"
        )
        try:
            parsed = json.loads(extract_json(text))
            assert_or_exit(isinstance(parsed, dict), f"Anthropic returned non-object {label} JSON")
            return parsed
        except json.JSONDecodeError as error:
            last_error = error
    fail(f"Anthropic returned malformed {label} JSON after retry: {last_error}")


def connection_digest(note: ParsedNote) -> str:
    excerpt = note.body.strip()[:650]
    themes = ", ".join(note.themes) if note.themes else "none"
    created = note.created_at.astimezone(timezone.utc).isoformat() if note.created_at.tzinfo else note.created_at.isoformat()
    return f"""ID: {note.id}
Date: {created}
Title: {note.title}
Themes: {themes}
Tone: {note.tone or "unknown"}
Summary:
{note.summary}
Excerpt:
{excerpt}"""


def topic_digest(note: ParsedNote) -> str:
    excerpt = note.body.strip()[:240]
    themes = ", ".join(note.themes) if note.themes else "none"
    created = note.created_at.astimezone(timezone.utc).isoformat() if note.created_at.tzinfo else note.created_at.isoformat()
    return f"""ID: {note.id}
Date: {created}
Title: {note.title}
Current Themes: {themes}
Summary:
{note.summary}
Excerpt:
{excerpt}"""


def extract_json(text: str) -> str:
    stripped = text.strip()
    if stripped.startswith("```"):
        lines = stripped.splitlines()
        stripped = "\n".join(lines[1:-1]).strip()
    start = stripped.find("{")
    end = stripped.rfind("}")
    if start == -1 or end == -1 or end < start:
        return stripped
    return stripped[start : end + 1]


def validate_connections(connections: list[dict[str, Any]], notes: list[ParsedNote]) -> None:
    assert_or_exit(len(connections) >= 3, f"expected at least 3 LLM connections, found {len(connections)}")
    valid_ids = {note.id for note in notes}
    kind_counts = Counter(connection.get("kind") for connection in connections)
    assert_or_exit(kind_counts["backlink"] >= 2, "expected at least 2 backlink connections")
    assert_or_exit(kind_counts["thread"] >= 1, "expected at least 1 thread connection")
    cross_period_count = 0
    for idx, connection in enumerate(connections):
        kind = connection.get("kind")
        assert_or_exit(kind in {"backlink", "thread"}, f"connection {idx} has invalid kind: {kind}")
        ids = connection.get("sourceNoteIDs", [])
        assert_or_exit(isinstance(ids, list) and len(ids) >= 2, f"connection {idx} has too few source IDs")
        assert_or_exit(all(note_id in valid_ids for note_id in ids), f"connection {idx} cites unknown source IDs")
        assert_or_exit(connection.get("title", "").strip(), f"connection {idx} missing title")
        explanation = connection.get("explanation", "").strip()
        assert_or_exit(len(explanation.split()) >= 12, f"connection {idx} explanation is too thin")
        confidence = connection.get("confidence")
        assert_or_exit(isinstance(confidence, (int, float)) and 0 <= confidence <= 1, f"connection {idx} invalid confidence")
        source_dates = [note.created_at for note in notes if note.id in ids]
        if source_dates and max(source_dates) - min(source_dates) >= timedelta(days=7):
            cross_period_count += 1
    assert_or_exit(cross_period_count >= 2, "expected at least 2 connections that bridge different weeks")


def validate_topic_taxonomy(topics: list[dict[str, Any]], notes: list[ParsedNote]) -> None:
    assert_or_exit(8 <= len(topics) <= 16, f"expected 8-16 canonical topics, found {len(topics)}")
    canonical = [normalized(topic.get("canonicalTheme", "")) for topic in topics]
    assert_or_exit(len(set(canonical)) == len(canonical), "canonical topics contain duplicates")
    assert_or_exit(all(topic for topic in canonical), "canonical topic missing canonicalTheme")
    assert_or_exit(all(len(topic.split()) <= 3 for topic in canonical), "canonical topics should be short")
    assert_or_exit("career" in canonical, "taxonomy should include career")
    assert_or_exit(any(topic in canonical for topic in {"technology", "ai tools"}), "taxonomy should include technology or ai tools")
    assert_or_exit(any(topic in canonical for topic in {"self-understanding", "identity"}), "taxonomy should include self-understanding or identity")
    assert_or_exit(topic_coverage(topics, notes) >= 0.75, "taxonomy does not cover enough high-count raw themes")
    raw_count = len(theme_counts(notes))
    assert_or_exit(len(topics) <= raw_count * 0.15, "taxonomy did not compress raw themes enough")


def topic_coverage(topics: list[dict[str, Any]], notes: list[ParsedNote]) -> float:
    covered: set[str] = set()
    for topic in topics:
        fields = [topic.get("canonicalTheme", ""), topic.get("title", "")]
        fields.extend(topic.get("aliases", []) if isinstance(topic.get("aliases"), list) else [])
        fields.extend(topic.get("relatedThemes", []) if isinstance(topic.get("relatedThemes"), list) else [])
        covered.update(normalized(field) for field in fields if isinstance(field, str))

    high_count = [theme for theme, count in theme_counts(notes).items() if count >= 3]
    if not high_count:
        return 1
    matched = sum(1 for theme in high_count if normalized(theme) in covered)
    return matched / len(high_count)


def validate_weekly_digest(digest: dict[str, Any], notes: list[ParsedNote]) -> None:
    assert_or_exit(digest.get("kind") == "weeklyDigest", f"weekly digest has wrong kind: {digest.get('kind')}")
    valid_ids = {note.id for note in notes}
    ids = digest.get("sourceNoteIDs", [])
    assert_or_exit(isinstance(ids, list) and len(ids) >= min(5, len(notes)), "weekly digest cites too few source notes")
    assert_or_exit(all(note_id in valid_ids for note_id in ids), "weekly digest cites unknown source IDs")
    assert_or_exit(digest.get("title", "").strip(), "weekly digest missing title")
    explanation = digest.get("explanation", "").strip()
    assert_or_exit(len(explanation.split()) >= 90, "weekly digest explanation is too thin")
    sections = present_digest_sections(explanation)
    assert_or_exit(len(sections) == 5, f"weekly digest missing sections: {', '.join(sorted(set(DIGEST_SECTIONS) - set(sections)))}")
    confidence = digest.get("confidence")
    assert_or_exit(isinstance(confidence, (int, float)) and 0 <= confidence <= 1, "weekly digest invalid confidence")
    themes = [theme for theme in digest.get("themes", []) if isinstance(theme, str) and theme.strip()]
    assert_or_exit(len(themes) >= 2, "weekly digest should include at least 2 themes")


DIGEST_SECTIONS = [
    "recurring themes",
    "open loops",
    "decisions or possible decisions",
    "rediscovered threads",
    "questions for next week",
]


def present_digest_sections(explanation: str) -> list[str]:
    lowered = explanation.lower()
    return [section for section in DIGEST_SECTIONS if section in lowered]


def normalized(value: str) -> str:
    return value.strip().lower()


def assert_or_exit(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


if __name__ == "__main__":
    raise SystemExit(main())
