#!/usr/bin/env python3
"""Create disposable pf-svc-income fixtures and write their runtime IDs."""
from __future__ import annotations

import argparse
import json
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def call(base_url: str, key: str, method: str, path: str, body: object | None = None) -> object:
    headers = {"X-API-Key": key, "Content-Type": "application/json"}
    request = Request(f"{base_url}{path}", method=method, headers=headers)
    if body is not None:
        request.data = json.dumps(body).encode()
    try:
        with urlopen(request, timeout=30) as response:
            return json.loads(response.read())
    except HTTPError as error:
        detail = error.read().decode(errors="replace")[:500]
        raise RuntimeError(f"HTTP {error.code}: {method} {path}: {detail}") from error


def first_id(payload: object, key: str) -> int:
    values = payload.get(key) if isinstance(payload, dict) else payload
    if not isinstance(values, list) or not values or not isinstance(values[0], dict):
        raise RuntimeError(f"Response did not contain a non-empty {key} list")
    identifier = values[0].get("id")
    if not isinstance(identifier, int):
        raise RuntimeError(f"Response did not contain an integer {key} id")
    return identifier


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--api-key", required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    token = uuid.uuid4().hex[:10]
    employer = call(
        arguments.base_url,
        arguments.api_key,
        "POST",
        "/payroll/employers",
        {"employers": [{"name": f"PFLOCAL Fixture {token}", "tax_id": f"PFLOCAL-{token}", "country_code": "CL"}]},
    )
    employer_id = first_id(employer, "employers")
    employer_name = employer[0]["name"] if isinstance(employer, list) else employer["employers"][0]["name"]
    contract = call(
        arguments.base_url,
        arguments.api_key,
        "POST",
        "/payroll/contracts",
        {"contracts": [{"employer_id": employer_id, "started_at": "2024-01-01", "ended_at": None, "is_indefinite": True, "position": "Postman fixture"}]},
    )
    contract_id = first_id(contract, "contracts")
    committed = call(
        arguments.base_url,
        arguments.api_key,
        "POST",
        "/payroll/import/json",
        {"mode": "commit", "periods": [{"employer": employer_name, "period_year": 2025, "period_month": 9, "payment_date": "2025-09-28", "worked_days": 0, "rows": [{"concept_code": "SALARY_BASE", "amount_clp": "0"}]}]},
    )
    periods = committed.get("periods", []) if isinstance(committed, dict) else []
    period_id = periods[0]["id"] if periods and periods[0].get("id") else 0
    arguments.output.write_text(
        json.dumps({"employer_id": employer_id, "employer_name": employer_name, "contract_id": contract_id, "period_id": period_id, "template_id": f"fixture-{token}"}) + "\n",
        encoding="utf-8",
    )
    print(f"Prepared pf-svc-income fixtures: employer={employer_id}, period={period_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
