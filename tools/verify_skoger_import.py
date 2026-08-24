#!/usr/bin/env python3
"""Kontrollerer produksjonsimporten for Skoger og Fjell i Supabase."""

import json
import os
import sys
import urllib.parse
import urllib.request

from import_skoger_to_supabase import Client, read_config, single


EMAIL = os.environ.get("SAKSFLYT_IMPORT_EMAIL", "malik@kampsportlaget.com")
PASSWORD = os.environ.get("SAKSFLYT_IMPORT_PASSWORD")


def count(client, table, query):
    request = urllib.request.Request(
        f"{client.url}/rest/v1/{table}?{query}",
        method="HEAD",
        headers={
            "apikey": client.key,
            "Authorization": f"Bearer {client.token}",
            "Prefer": "count=exact",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        content_range = response.headers.get("content-range", "0-0/0")
    return int(content_range.rsplit("/", 1)[1])


def q(value):
    return urllib.parse.quote(str(value), safe="")


def main():
    if not PASSWORD:
        print("Mangler SAKSFLYT_IMPORT_PASSWORD", file=sys.stderr)
        sys.exit(2)

    url, anon_key = read_config()
    client = Client(url, anon_key, EMAIL, PASSWORD)
    client.login()
    org = single(client.select("organizations", "select=id,navn&orgnr=eq.912484335"), "organisasjon")
    org_id = org["id"]
    org_filter = f"organization_id=eq.{org_id}"

    checks = {
        "transactions_total": count(client, "transactions", f"select=id&{org_filter}"),
        "transactions_fiken": count(client, "transactions", f"select=id&{org_filter}&bilagsnummer=like.FIKEN-*"),
        "transactions_bankspor": count(client, "transactions", f"select=id&{org_filter}&bilagsnummer=like.BANK-*"),
        "members_styreweb": count(client, "members", f"select=id&{org_filter}&ekstern_kilde=eq.styreweb"),
        "paid_claims": count(client, "payment_claims", f"select=id&{org_filter}&status=eq.betalt"),
        "documents_bankspor": count(client, "documents", f"select=id&{org_filter}&mappe=eq.{q('Regnskap')}&tittel=like.Kontoutskrift%25"),
        "import_jobs_done": count(client, "import_jobs", f"select=id&{org_filter}&type=eq.fiken_styreweb_bankspor&status=eq.fullfort"),
    }

    print(json.dumps({"organization": org["navn"], **checks}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
