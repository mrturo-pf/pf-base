#!/usr/bin/env python3
"""Validate the transition improvement manifest and generate agent context."""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

PRIORITIES = {"critical", "high", "medium", "low"}
LEVELS = {"S", "M", "L"}
TYPES = {
    "security",
    "privacy",
    "architecture",
    "data/schema",
    "api/contract",
    "reliability",
    "performance",
    "cost",
    "observability",
    "developer-experience",
    "tooling",
    "documentation",
    "testing",
    "operations",
    "process",
}


def https_url(value: Any, *, nullable: bool = False) -> bool:
    if value is None and nullable:
        return True
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def validate(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    improvements = manifest.get("improvements")
    if manifest.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if not isinstance(improvements, list) or not improvements:
        return [*errors, "improvements must be a non-empty list"]

    seen_ids: set[str] = set()
    seen_slugs: set[str] = set()
    active_priorities: set[int] = set()
    for index, item in enumerate(improvements):
        prefix = f"improvements[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        item_id = item.get("id")
        slug = item.get("slug")
        if not isinstance(item_id, str) or not re.match(r"^(?:IMP|HIST)-\d+$", item_id):
            errors.append(f"{prefix}.id must use IMP-XXX or HIST-XXX format")
        elif item_id in seen_ids:
            errors.append(f"duplicate id: {item_id}")
        else:
            seen_ids.add(item_id)
        if not isinstance(slug, str) or not slug:
            errors.append(f"{prefix}.slug must be non-empty")
        elif slug in seen_slugs:
            errors.append(f"duplicate slug: {slug}")
        else:
            seen_slugs.add(slug)

        if item.get("level") not in LEVELS:
            errors.append(f"{prefix}.level is invalid")
        if item.get("priority") is not None and item.get("priority") not in PRIORITIES:
            errors.append(f"{prefix}.priority is invalid")
        if item.get("type") is not None and item.get("type") not in TYPES:
            errors.append(f"{prefix}.type is invalid")
        if not isinstance(item.get("owner"), str) or not item["owner"]:
            errors.append(f"{prefix}.owner must be non-empty")
        if not isinstance(item.get("affected"), list) or (not item["affected"] and item.get("metadata_status") != "historical; priority and type not inferred"):
            errors.append(f"{prefix}.affected must be a non-empty list unless historical metadata is incomplete")
        if not https_url(item.get("project_url")):
            errors.append(f"{prefix}.project_url must be HTTPS")
        if not https_url(item.get("issue_url"), nullable=True):
            errors.append(f"{prefix}.issue_url must be HTTPS or null")
        if not https_url(item.get("plan_url")):
            errors.append(f"{prefix}.plan_url must be HTTPS")
        if not isinstance(item.get("next_action"), str) or not item["next_action"]:
            errors.append(f"{prefix}.next_action must be non-empty")

    return errors


def generate_context(manifest: dict[str, Any]) -> str:
    items = manifest["improvements"]
    lines = [
        "# Generated PF Improvement Context",
        "",
        "> Generated from `docs/proposals/improvements.json`. Do not edit manually.",
        "",
        f"- Schema version: `{manifest['schema_version']}`",
        f"- Items: `{len(items)}`",
        "",
        "## Improvement references",
        "",
        "Current status, priority, and progress are authoritative in the GitHub Project.",
        "Query the Project before making planning decisions; this generated file stores no task state.",
        "",
    ]
    for item in sorted(manifest["improvements"], key=lambda value: value["id"]):
        lines.extend(
            [
                f"### {item['id']} — {item['slug']}",
                "",
                f"- Level: `{item['level']}`; type: `{item['type'] or 'unclassified'}`",
                f"- Owner: `{item['owner']}`",
                f"- Affected: {', '.join(f'`{repo}`' for repo in item['affected']) or 'none'}",
                f"- Next action: {item['next_action']}",
                f"- Plan: {item['plan_url']}",
                f"- Issue: {item['issue_url'] or 'pending coordination issue'}",
                "",
            ]
        )
    return "\n".join(lines)


def generate_dashboard(manifest: dict[str, Any]) -> str:
    rows = []
    for item in sorted(manifest["improvements"], key=lambda value: value["id"]):
        rows.append(
            "<tr>"
            f"<td><strong>{html.escape(item['id'])}</strong><br>{html.escape(item['slug'])}</td>"
            f"<td>{html.escape(item['level'])}</td>"
            f"<td>{html.escape(item['owner'])}</td>"
            f"<td>{html.escape(item['next_action'])}</td>"
            f"<td><a href=\"{html.escape(item['plan_url'], quote=True)}\">plan</a></td>"
            "</tr>"
        )
    return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>PF Ecosystem Improvements</title>
<style>
body{font-family:system-ui,sans-serif;line-height:1.5;margin:2rem;color:#17202a;background:#f7f9fb}
main{max-width:1200px;margin:auto}table{border-collapse:collapse;width:100%;background:#fff}
th,td{border:1px solid #d9e2ec;padding:.7rem;text-align:left;vertical-align:top}
th{background:#e8eef5}a{color:#075985}caption{text-align:left;font-size:1.5rem;font-weight:700;margin-bottom:1rem}
</style>
</head>
<body><main><table><caption>PF Ecosystem Improvements</caption>
<thead><tr><th>ID / slug</th><th>Level</th><th>Owner</th><th>Next action</th><th>Canonical plan</th></tr></thead>
<tbody>""" + "\n".join(rows) + """</tbody></table>
<p>Generated from <code>docs/proposals/improvements.json</code>. Do not edit manually.</p>
</main></body></html>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("docs/proposals/improvements.json"))
    parser.add_argument("--write-generated", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    errors = validate(manifest)
    if errors:
        for error in errors:
            print(f"error: {error}")
        return 1

    print(f"Validated {len(manifest['improvements'])} improvements")
    if args.write_generated:
        output_dir = Path("docs/generated")
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "improvements.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        (output_dir / "agent-context.md").write_text(
            generate_context(manifest), encoding="utf-8"
        )
        (output_dir / "improvements-dashboard.html").write_text(
            generate_dashboard(manifest), encoding="utf-8"
        )
        print(f"Generated outputs in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
