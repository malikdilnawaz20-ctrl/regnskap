# Saksflyt

Medlemmer, økonomi og prosjekter for norske foreninger og idrettslag. Bygget for frivillige styrer — ikke for regnskapsførere.

Domene: **sakflyt.no** · Første klubb: **Skoger og Fjell kampsportklubb** (org.nr 912484335)

Kom i gang: **[OPPSETT.md](OPPSETT.md)**

---

## Hvordan det henger sammen

```
sakflyt.no            Portal — velg Regnskap, Medlem eller Saksbehandling
   └── /app/          Selve systemet (statisk nettside, ingen server)
          │
          ▼
     Supabase         PostgreSQL + innlogging + fillagring
                      Rad-nivå-sikkerhet skiller organisasjonene
```

Ingen byggesteg, ingen `npm install`. Rene ES-moduler som kjører rett i nettleseren, publisert gratis via GitHub Pages. Det gjør at systemet er raskt å endre og vanskelig å ødelegge.

---

## Filene

```
index.html                     Portal med de tre produktene
app/
  index.html                   Applikasjonen
  config.js                    Supabase-nøkler og merkevare  ← fylles inn
  styles.css                   Designsystemet. Én kilde for alle sider
  lib.js                       Byggeklosser: kort, tabeller, modaler, Excel
  store.js                     Innlogget bruker, valgt organisasjon, roller
  app.js                       Skall, navigasjon, forside, brukere, innstillinger
  views/
    medlemmer.js               Medlemmer, aktiviteter, familier, Excel-import
    okonomi.js                 Inntekter, utgifter, prosjekter, rapporter, kontingent
    attestering.js             Regninger godkjent av to personer
supabase/
  migrations/0001_init.sql     Tabeller, sikkerhet, kontoplan, revisjonslogg
  migrations/0002_attestering.sql
  seed_klubb.sql               Skoger og Fjell kampsportklubb
.github/workflows/pages.yml    Publiserer automatisk ved push til main
CNAME                          sakflyt.no
```

---

## Prinsippene systemet er bygget på

**Vanlig norsk, ikke regnskapsspråk.** Brukeren registrerer «utgift», ikke «debetpostering». Riktig regnskapskonto ligger på kategorien, under panseret. Avanserte brukere kan overstyre den.

**Én organisasjon ser aldri en annens data.** Hver tabell har `organization_id`, og rad-nivå-sikkerhet i PostgreSQL håndhever det. En skjult knapp i grensesnittet er aldri tilgangskontroll — serveren avviser uansett.

**Penger regnes i øre, som heltall.** Aldri flyttall. `belop_ore` er `bigint`.

**Historikk slettes ikke.** Bokførte bilag korrigeres, de overskrives ikke. Låste regnskapsår avviser endringer i databasen. Revisjonsloggen kan ikke endres eller slettes — heller ikke av en administrator.

**To personer på pengene ut.** En regning må godkjennes av to forskjellige personer før den kan betales. Hvem de to er, settes under Innstillinger → Selskapsinformasjon.

**Excel er inn og ut, aldri lagringsstedet.** Import av medlemslister og gamle regnskap er et konkurransefortrinn. Eksport med lesbare norske kolonnenavn, ikke en databasedump. Dataene tilhører klubben.

**Ett medlem registreres én gang.** Samme person kan gå på karate, MMA og Åpen Hall uten å ligge tre ganger i registeret. Familier og foresatte håndteres som egne relasjoner, så samme e-post på flere barn ikke leses som duplikat.

**Medlemskontingent og treningsavgift er ikke det samme.** De holdes atskilt i datamodellen fordi de rapporteres ulikt.

---

## Roller

| Rolle | Kan |
|---|---|
| Administrator | Alt, inkludert brukere og innstillinger |
| Styreleder | Nesten alt |
| Kasserer | Økonomi, betalinger, rapporter |
| Medlemsansvarlig | Medlemmer og aktiviteter |
| Trener | Se medlemmer og grupper |
| Revisor | Bare lese |
| Medlem | Bare egen informasjon |

---

## Designsystemet

Ett system for hele produktet, definert i `app/styles.css`. Ingen lokale CSS-varianter per side.

| Rolle | Verdi |
|---|---|
| Merkevare | `#087F7A` teal, mørkt sidepanel `#073F43` |
| Flate | `#F6F8FA` bakgrunn, `#FFFFFF` kort |
| Tekst | `#17212B` primær, `#667085` sekundær |
| Ferdig / betalt | Grønn |
| Trenger oppmerksomhet | Oransje |
| Feil / forfalt | Rød |
| Informasjon | Blå |

Teal er produktet. Statusfargene konkurrerer aldri med merkevaren. Status vises alltid med tekst og symbol i tillegg til farge.

Både lys og mørk modus. Temaet følger systeminnstillingen, og knappen nede til høyre overstyrer.

---

## Veien videre

Ferdig: innlogging, organisasjoner og roller, forside, medlemsregister med Excel-import, aktiviteter og grupper, inntekter og utgifter, bilag, prosjektregnskap, rapporter, kontingent og betalingskrav, attestering, dokumentarkiv, revisjonsspor.

Neste: budsjett med avviksvisning, årsmøtepakke, bankimport fra CSV, tilskuddsmodul.

Senere: betalingsintegrasjon, OCR på kvitteringer, AI-forslag til kontering, og — når en formell avtale foreligger — integrasjon mot Norges idrettsforbund via [data.nif.no](https://data.nif.no/index.html).
