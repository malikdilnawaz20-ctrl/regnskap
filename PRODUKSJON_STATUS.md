# Produksjonsstatus 2026-08-24

## Status

- Lokal portal fungerer på statisk server.
- Supabase-prosjektet `saksflyt` er opprettet i organisasjonen `ResolvePartners`.
- `app/config.js` er fylt med Supabase URL og publishable key.
- Supabase SQL-filene er kjørt:
  1. `supabase/migrations/0001_init.sql`
  2. `supabase/migrations/0002_attestering.sql`
  3. `supabase/seed_klubb.sql`
- Storage-buckets `bilag` og `dokumenter` er opprettet med organisasjonsstyrte policies.
- GitHub-repoet `malikdilnawaz20-ctrl/regnskap` er opprettet og publisert med GitHub Pages.
- `sakflyt.no` svarer fra GitHub Pages.

## Viktig Supabase-avklaring

Produksjonsprosjektet som brukes nå:

- Navn: `saksflyt`
- Organisasjon/prosjektflate: `ResolvePartners`
- URL: `https://bunqdzvtocayqlddcjmf.supabase.co`
- Region: `Central EU (Frankfurt)`, `eu-central-1`

Det gamle Supabase-prosjektet `https://eegxkylchxnwklpotqxc.supabase.co` brukes ikke til Saksflyt Regnskap.

## Gjenstår

1. Opprett de tre første brukerne i Supabase Auth.
2. Test innlogging lokalt på `http://127.0.0.1:8090/app/`.
3. Kontroller appen på `https://sakflyt.no/app/`.
4. Vurder om åpen e-postregistrering skal slås av etter at første brukere er opprettet.

## Lokal test

Start fra repo-roten:

```bash
python3 -m http.server 8090 --bind 127.0.0.1
```

Åpne:

- Portal: `http://127.0.0.1:8090/`
- App: `http://127.0.0.1:8090/app/`
