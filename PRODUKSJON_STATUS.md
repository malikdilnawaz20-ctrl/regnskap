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
- Fem første Auth-brukere er opprettet og bekreftet:
  `malik@kampsportlaget.com`, `carlos@kampsportlaget.com`, `denis@kampsportlaget.com`,
  `dilara@kampsportlaget.com` og `afrim@kampsportlaget.com`.
- Dilara og Afrim er lagt inn i organisasjonen som `medlem`.
- Produksjonsinnlogging er testet for Malik, Dilara og Afrim.
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

1. Vurder om åpen e-postregistrering skal slås av etter at første brukere er opprettet.
2. Bytt midlertidige passord ved første innlogging.
3. Legg inn resten av medlemsregisteret, aktiviteter og grupper.

## Lokal test

Start fra repo-roten:

```bash
python3 -m http.server 8090 --bind 127.0.0.1
```

Åpne:

- Portal: `http://127.0.0.1:8090/`
- App: `http://127.0.0.1:8090/app/`
