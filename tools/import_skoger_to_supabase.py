#!/usr/bin/env python3
"""
Import Skoger og Fjell data through Supabase REST as an authenticated app user.

This is used when the Dashboard SQL editor is impractical. It keeps the same
application/RLS boundary as the web app: the user must be an admin/kasserer in
the organization for inserts to succeed.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from generate_skoger_import_sql import (
    ACCOUNT_CATEGORY,
    ACCOUNT_NAMES,
    DEFAULT_BANK_PDF_DIR,
    DEFAULT_FIKEN,
    DEFAULT_MEMBERS,
    MEMBERSHIP_FEE_NAME,
    MEMBERSHIP_FEE_ORE,
    ORGNR,
    load_bank_statements,
    load_fiken,
    load_members,
    public_transaction_description,
)

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "app" / "config.js"


def read_config():
    text = CONFIG.read_text(encoding="utf-8")
    values = {}
    for line in text.splitlines():
        if line.strip().startswith("export const SUPABASE_URL") or line.strip().startswith("export const SUPABASE_ANON_KEY"):
            left, right = line.split("=", 1)
            values[left.split()[-1]] = right.strip().strip(";").strip('"')
    return values["SUPABASE_URL"], values["SUPABASE_ANON_KEY"]


class Client:
    def __init__(self, url, key, email, password):
        self.url = url.rstrip("/")
        self.key = key
        self.email = email
        self.password = password
        self.token = None

    def request(self, method, path, body=None, headers=None, retry=True):
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        final_headers = {
            "apikey": self.key,
            "Content-Type": "application/json",
        }
        if self.token:
            final_headers["Authorization"] = "Bearer " + self.token
        if headers:
            final_headers.update(headers)
        req = urllib.request.Request(self.url + path, data=data, headers=final_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read()
                return json.loads(raw.decode("utf-8")) if raw else None
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            if retry and exc.code == 429:
                time.sleep(1.2)
                return self.request(method, path, body, headers, retry=False)
            raise RuntimeError(f"{method} {path} feilet {exc.code}: {details}") from exc

    def login(self):
        body = {"email": self.email, "password": self.password}
        auth = self.request("POST", "/auth/v1/token?grant_type=password", body)
        self.token = auth["access_token"]

    def select(self, table, params="select=*"):
        return self.request("GET", f"/rest/v1/{table}?{params}")

    def insert(self, table, rows, upsert=None):
        if not isinstance(rows, list):
            rows = [rows]
        headers = {"Prefer": "return=representation"}
        path = f"/rest/v1/{table}"
        if upsert:
            headers["Prefer"] = "resolution=merge-duplicates,return=representation"
            path += "?on_conflict=" + urllib.parse.quote(upsert, safe=",")
        return self.request("POST", path, rows, headers)

    def patch(self, table, filters, row):
        return self.request("PATCH", f"/rest/v1/{table}?{filters}", row, {"Prefer": "return=representation"})


def q(value):
    return urllib.parse.quote(str(value), safe="")


def single(items, label):
    if not items:
        raise RuntimeError(f"Fant ikke {label}")
    return items[0]


def ensure_account(client, org_id):
    existing = client.select("accounts", f"select=id&organization_id=eq.{org_id}&kontonummer=eq.2220.29.21373")
    if existing:
        return existing[0]["id"]
    row = {
        "organization_id": org_id,
        "navn": "Fiken bankkonto 2220.29.21373",
        "kontonummer": "2220.29.21373",
        "type": "bank",
    }
    return client.insert("accounts", row)[0]["id"]


def ensure_fee(client, org_id):
    found = client.select("fees", f"select=id&organization_id=eq.{org_id}&navn=eq.{q(MEMBERSHIP_FEE_NAME)}")
    if found:
        return found[0]["id"]
    row = {
        "organization_id": org_id,
        "navn": MEMBERSHIP_FEE_NAME,
        "type": "medlemskontingent",
        "intervall": "aarlig",
        "belop_ore": MEMBERSHIP_FEE_ORE,
        "gjelder_fra": "2026-01-01",
    }
    return client.insert("fees", row)[0]["id"]


def ensure_accounting_account(client, org_id, number):
    name = ACCOUNT_NAMES.get(number, f"Konto {number}")
    existing = client.select("accounting_accounts", f"select=id&organization_id=eq.{org_id}&nummer=eq.{number}")
    if existing:
        client.patch("accounting_accounts", f"id=eq.{existing[0]['id']}", {"navn": name, "aktiv": True})
        return existing[0]["id"]
    return client.insert("accounting_accounts", {"organization_id": org_id, "nummer": number, "navn": name})[0]["id"]


def ensure_category(client, org_id, name, direction, number):
    existing = client.select(
        "categories",
        f"select=id&organization_id=eq.{org_id}&navn=eq.{q(name)}&retning=eq.{direction}",
    )
    if existing:
        client.patch("categories", f"id=eq.{existing[0]['id']}", {"konto_nummer": number, "aktiv": True})
        return existing[0]["id"]
    row = {"organization_id": org_id, "navn": name, "retning": direction, "konto_nummer": number}
    return client.insert("categories", row)[0]["id"]


def existing_by(client, table, params):
    return client.select(table, params)


def main():
    email = os.environ.get("SAKSFLYT_IMPORT_EMAIL", "malik@kampsportlaget.com")
    password = os.environ.get("SAKSFLYT_IMPORT_PASSWORD")
    if not password:
        raise SystemExit("Sett SAKSFLYT_IMPORT_PASSWORD i miljoet.")

    url, key = read_config()
    client = Client(url, key, email, password)
    client.login()

    org = single(client.select("organizations", f"select=id,navn&orgnr=eq.{ORGNR}"), "organisasjon")
    org_id = org["id"]
    account_id = ensure_account(client, org_id)
    fee_id = ensure_fee(client, org_id)

    fiken_rows = load_fiken(DEFAULT_FIKEN)
    members = load_members(DEFAULT_MEMBERS)
    bank_statements, _missing = load_bank_statements(DEFAULT_BANK_PDF_DIR)

    for number in sorted({r["konto_nummer"] for r in fiken_rows if r["konto_nummer"]} | {3900, 7790}):
        ensure_accounting_account(client, org_id, number)

    category_ids = {}
    for row in fiken_rows:
        key_cat = (row["category_name"], row["category_direction"], row["konto_nummer"])
        if key_cat not in category_ids:
            category_ids[key_cat] = ensure_category(client, org_id, *key_cat)
    category_ids[("Historisk bankspor - inn", "inntekt", 3900)] = ensure_category(client, org_id, "Historisk bankspor - inn", "inntekt", 3900)
    category_ids[("Historisk bankspor - ut", "utgift", 7790)] = ensure_category(client, org_id, "Historisk bankspor - ut", "utgift", 7790)

    imported_bank = imported_fiken = imported_members = imported_claims = imported_docs = 0

    for stmt in bank_statements:
        doc_title = "Kontoutskrift " + stmt["start_date"][:7]
        docs = existing_by(
            client,
            "documents",
            f"select=id&organization_id=eq.{org_id}&mappe=eq.Regnskap&tittel=eq.{q(doc_title)}&filnavn=eq.{q(stmt['filename'])}",
        )
        if not docs:
            client.insert("documents", {
                "organization_id": org_id,
                "mappe": "Regnskap",
                "tittel": doc_title,
                "filnavn": stmt["filename"],
                "kun_styret": True,
            })
            imported_docs += 1

        bilag = f"BANK-{stmt['year']}-{stmt['month']:02d}"
        direction = stmt["type"] if stmt["type"] != "overforing" else "utgift"
        cat_key = ("Historisk bankspor - inn", "inntekt", 3900) if direction == "inntekt" else ("Historisk bankspor - ut", "utgift", 7790)
        row = {
            "organization_id": org_id,
            "bilagsnummer": bilag,
            "dato": stmt["end_date"],
            "type": direction,
            "beskrivelse": public_transaction_description(stmt["type"], "Historisk bankspor", stmt["end_date"])
            or "Bankbevegelse registrert fra kontoutskrift",
            "belop_ore": stmt["amount_ore"],
            "konto_nummer": 3900 if direction == "inntekt" else 7790,
            "category_id": category_ids[cat_key],
            "account_id": account_id,
            "regnskapsaar": stmt["year"],
        }
        existing = existing_by(client, "transactions", f"select=id&organization_id=eq.{org_id}&bilagsnummer=eq.{q(bilag)}")
        if existing:
            client.patch("transactions", f"id=eq.{existing[0]['id']}", {k: v for k, v in row.items() if k != "organization_id"})
        else:
            client.insert("transactions", row)
            imported_bank += 1

    for row0 in fiken_rows:
        cat_key = (row0["category_name"], row0["category_direction"], row0["konto_nummer"])
        row = {
            "organization_id": org_id,
            "bilagsnummer": row0["bilagsnummer"],
            "dato": row0["dato"],
            "type": row0["type"],
            "beskrivelse": row0["beskrivelse"],
            "belop_ore": row0["belop_ore"],
            "konto_nummer": row0["konto_nummer"],
            "category_id": category_ids[cat_key],
            "account_id": account_id,
            "regnskapsaar": row0["regnskapsaar"],
        }
        existing = existing_by(client, "transactions", f"select=id&organization_id=eq.{org_id}&bilagsnummer=eq.{q(row0['bilagsnummer'])}")
        if existing:
            client.patch("transactions", f"id=eq.{existing[0]['id']}", {k: v for k, v in row.items() if k != "organization_id"})
        else:
            client.insert("transactions", row)
            imported_fiken += 1

    for member in members:
        existing = existing_by(
            client,
            "members",
            f"select=id&organization_id=eq.{org_id}&ekstern_kilde=eq.styreweb&ekstern_id=eq.{member['external_id']}",
        )
        if not existing and member["fodselsdato"]:
            existing = existing_by(
                client,
                "members",
                "select=id"
                f"&organization_id=eq.{org_id}"
                f"&fornavn=eq.{q(member['fornavn'])}"
                f"&etternavn=eq.{q(member['etternavn'])}"
                f"&fodselsdato=eq.{member['fodselsdato']}",
            )
        member_row = {
            "organization_id": org_id,
            "fornavn": member["fornavn"],
            "etternavn": member["etternavn"],
            "fodselsdato": member["fodselsdato"],
            "kjonn": member["kjonn"],
            "epost": member["epost"],
            "status": "aktiv",
            "ekstern_id": member["external_id"],
            "ekstern_kilde": "styreweb",
        }
        if existing:
            member_id = existing[0]["id"]
            client.patch("members", f"id=eq.{member_id}", {k: v for k, v in member_row.items() if k != "organization_id"})
        else:
            member_id = client.insert("members", member_row)[0]["id"]
            imported_members += 1
        claim_params = (
            f"select=id&organization_id=eq.{org_id}&member_id=eq.{member_id}"
            f"&fee_id=eq.{fee_id}&beskrivelse=eq.{q(MEMBERSHIP_FEE_NAME)}"
        )
        claim_row = {
            "organization_id": org_id,
            "member_id": member_id,
            "fee_id": fee_id,
            "beskrivelse": MEMBERSHIP_FEE_NAME,
            "belop_ore": MEMBERSHIP_FEE_ORE,
            "betalt_ore": MEMBERSHIP_FEE_ORE if member["betalt"] else 0,
            "status": "betalt" if member["betalt"] else "ikke_betalt",
            "forfall": "2026-12-31",
        }
        existing_claim = existing_by(client, "payment_claims", claim_params)
        if existing_claim:
            client.patch("payment_claims", f"id=eq.{existing_claim[0]['id']}", {k: v for k, v in claim_row.items() if k != "organization_id"})
        else:
            client.insert("payment_claims", claim_row)
            imported_claims += 1

    client.insert("import_jobs", {
        "organization_id": org_id,
        "type": "fiken_styreweb_bankspor",
        "filnavn": "API-import: fiken_transactions.json + BOK2.xlsx + medlemmer2026.xlsx + kontoutskrifter 2020-2023",
        "antall_lest": len(fiken_rows) + len(members) + len(bank_statements),
        "antall_importert": imported_fiken + imported_bank + imported_members + imported_claims,
        "antall_avvist": 0,
        "status": "fullfort",
    })

    print(json.dumps({
        "organization": org["navn"],
        "bank_transactions_inserted": imported_bank,
        "fiken_transactions_inserted": imported_fiken,
        "members_inserted": imported_members,
        "claims_inserted": imported_claims,
        "documents_inserted": imported_docs,
        "source_bank_statements": len(bank_statements),
        "source_fiken_rows": len(fiken_rows),
        "source_members": len(members),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
