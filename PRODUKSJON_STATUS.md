# Produksjonsstatus 2026-08-24

## Status

- Lokal portal fungerer på statisk server.
- `/app/` viser korrekt `Nesten klar` fordi `app/config.js` mangler Supabase URL og anon-nøkkel.
- Supabase SQL-filene ligger klare:
  1. `supabase/migrations/0001_init.sql`
  2. `supabase/migrations/0002_attestering.sql`
  3. `supabase/seed_klubb.sql`
- Git-repoet har to commits og ingen remote satt.
- GitHub CLI er installert, men ikke innlogget.

## Viktig Supabase-avklaring

Chrome viser et eksisterende Supabase-prosjekt:

- Navn: `malikdilnawaz20@gmail.com's Project`
- Organisasjon/prosjektflate: `ResolvePartners`
- URL: `https://eegxkylchxnwklpotqxc.supabase.co`
- Region: `West EU (Ireland)`, ikke Frankfurt.

Ikke kjør Saksflyt-migrasjonene i dette prosjektet uten uttrykkelig godkjenning. Anbefalt produksjonsvalg er nytt Supabase-prosjekt:

- Navn: `saksflyt`
- Region: Frankfurt / `eu-central-1`
- Formål: egne regnskaps- og medlemsdata for Saksflyt.

## Neste sikre steg

1. Opprett nytt Supabase-prosjekt `saksflyt` i Frankfurt.
2. Kjør SQL-filene i rekkefølgen over.
3. Opprett private Storage-buckets: `bilag` og `dokumenter`.
4. Legg inn Storage policies fra `OPPSETT.md`.
5. Opprett de tre brukerne med oppstartspassordet fra `OPPSETT.md`.
6. Kopier `Project URL` og `anon public` til `app/config.js`.
7. Test innlogging lokalt på `http://localhost:8088/app/`.
8. Logg inn i GitHub CLI eller bruk GitHub i Chrome.
9. Opprett/push repo og slå på GitHub Pages for `sakflyt.no`.

## Lokal test

Start fra repo-roten:

```bash
python3 -m http.server 8088
```

Åpne:

- Portal: `http://localhost:8088/`
- App: `http://localhost:8088/app/`
