#!/usr/bin/env python3
"""Validate the local pf-svc-income mutation lifecycle with dynamic IDs."""
from __future__ import annotations

import argparse
import json
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def request(base: str, key: str, method: str, path: str, body: object) -> object:
    req = Request(f"{base}{path}", method=method, headers={"X-API-Key": key, "Content-Type": "application/json"})
    req.data = json.dumps(body).encode()
    try:
        with urlopen(req, timeout=30) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f"HTTP {response.status}: {method} {path}")
            raw = response.read()
            return json.loads(raw) if raw else {}
    except HTTPError as error:
        detail = error.read().decode(errors="replace")[:400]
        raise RuntimeError(f"HTTP {error.code}: {method} {path}: {detail}") from error


def first_id(value: object, key: str) -> int:
    values = value.get(key) if isinstance(value, dict) else value
    if not isinstance(values, list) or not values or not isinstance(values[0], dict):
        raise RuntimeError(f"Missing {key} response list")
    identifier = values[0].get("id")
    if not isinstance(identifier, int):
        raise RuntimeError(f"Missing integer {key} id")
    return identifier


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--api-key", required=True)
    args = parser.parse_args()
    token = uuid.uuid4().hex[:10]
    employer = request(args.base_url, args.api_key, "POST", "/payroll/employers", {"employers": [{"name": f"Mutation {token}", "tax_id": f"MUT-{token}", "country_code": "CL"}]})
    employer_id = first_id(employer, "employers")
    contract = request(args.base_url, args.api_key, "POST", "/payroll/contracts", {"contracts": [{"employer_id": employer_id, "started_at": "2024-01-01", "ended_at": None, "is_indefinite": True, "position": "Mutation test"}]})
    contract_id = first_id(contract, "contracts")
    template_id = f"mutation-{token}"
    request(args.base_url, args.api_key, "POST", "/payroll/templates", {"template_id": template_id, "employer_id": employer_id, "employer_match_pattern": f"(?i){token}", "version": 1, "fields": [{"pdf_label_pattern": "(?i)^SUELDO$", "concept_code": "SALARY_BASE", "confidence": 0.9}]})
    request(args.base_url, args.api_key, "PUT", f"/payroll/templates/{template_id}", {"employer_id": employer_id, "employer_match_pattern": f"(?i){token}", "version": 2, "fields": [{"pdf_label_pattern": "(?i)^SUELDO$", "concept_code": "SALARY_BASE", "confidence": 0.95}]})
    request(args.base_url, args.api_key, "DELETE", f"/payroll/templates/{template_id}", {})
    periods = [
        {"employer": f"Mutation {token}", "period_year": 2025, "period_month": 9, "payment_date": "2025-09-28", "worked_days": 0, "employment_contract_kind": "indefinite", "rows": [{"concept_code": "SALARY_BASE", "amount_clp": "1000000"}]},
        {"employer": f"Mutation {token}", "period_year": 2025, "period_month": 10, "payment_date": "2025-10-28", "worked_days": 0, "employment_contract_kind": "indefinite", "rows": [{"concept_code": "SALARY_BASE", "amount_clp": "0"}]},
    ]
    imported = request(args.base_url, args.api_key, "POST", "/payroll/import/json", {"mode": "commit", "periods": periods})
    values = imported.get("periods") if isinstance(imported, dict) else imported
    if not isinstance(values, list) or len(values) < 2:
        raise RuntimeError(f"Commit import did not return two payroll periods: {imported!r}")
    payroll_ids = [item["id"] for item in values]
    request(args.base_url, args.api_key, "GET", f"/payroll/{payroll_ids[0]}", {})
    request(args.base_url, args.api_key, "DELETE", f"/payroll/{payroll_ids[0]}", {})
    request(args.base_url, args.api_key, "DELETE", "/payroll", {"period_ids": [payroll_ids[1]]})
    request(args.base_url, args.api_key, "DELETE", "/payroll/contracts", {"ids": [contract_id]})
    request(args.base_url, args.api_key, "DELETE", "/payroll/employers", {"ids": [employer_id]})
    print("Dynamic mutation lifecycle passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
