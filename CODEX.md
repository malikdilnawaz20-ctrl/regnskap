# Brief til Codex

Dette prosjektet er ferdig satt opp og testet. **Ikke riv ned fungerende kode.** Les `README.md` og `OPPSETT.md` før du endrer noe.

Repoet er committet på en kjent god versjon. Går noe galt: `git checkout .`

---

## Slik er systemet bygget

Statisk nettside, rene ES-moduler, ingen byggesteg og ingen `npm install`. Data ligger i Supabase (PostgreSQL), og all tilgangskontroll er rad-nivå-sikkerhet i databasen — ikke i grensesnittet.

Kontrakten alle visninger følger:

```js
// app/views/dinvisning.js
import { el, kort, kpi, merke, tabell, skjemaModal, bekreft, toast, visFeil,
         knapp, kr, kr0, tilOre, dato, tomTilstand, eksporterExcel, db } from "../lib.js";
import { S, kanOkonomi, kanMedlem, erAdmin, velgFra, settInn, paaNytt } from "../store.js";

export const dinView = {
  tittel: "Din side",
  undertekst: "Én setning om hva siden er til for.",
  async bygg() { /* henter data, returnerer én DOM-node */ }
};
```

Registrer den så i `app/app.js`: legg en linje i `RUTER`, og legg id-en inn i riktig gruppe i `HOVEDNAV`.

---

## Regler som ikke skal brytes

**Ingen ny CSS per side.** Alt finnes i `app/styles.css`. Trenger du noe som ikke finnes, legg komponenten der og gjenbruk den — ikke lag en lokal variant.

**Penger er heltall i øre.** `tilOre()` inn, `kr()` / `kr0()` ut. Aldri flyttallsregning på beløp.

**Vanlig norsk i grensesnittet.** «Registrer utgift», ikke «debetpostering». Kassereren i et idrettslag er ikke regnskapsfører.

**Alltid `error` fra Supabase.** `const { data, error } = await …; if (error) throw error;` og pakk kallet i try/catch med `visFeil(e, "Handlingen")`.

**Aldri `innerHTML` med data fra databasen.** Bruk `el()` og tekstnoder. `html:`-attributtet er kun for ikoner fra `svg()`.

**Ingen knapper uten funksjon.** Er noe ikke bygget, ikke lag knappen.

**Skjul aldri en knapp som eneste tilgangskontroll.** Serveren avviser uansett — men skjul den *også*, slik at brukeren ikke møter en feilmelding.

**Sjekk mobil.** Sidepanelet blir bunnavigasjon under 900 px. Tabeller ligger i `.tablewrap` med vannrett rulling; siden selv skal aldri rulle sideveis.

---

## Neste oppgaver, i prioritert rekkefølge

Ta én om gangen. Hver av dem er en ny fil, så du trenger ikke røre noe som virker.

### 1. Budsjett — `app/views/budsjett.js`

Tabellen `budgets` finnes allerede (`organization_id`, `aar`, `category_id`, `project_id`, `belop_ore`).

- Årsvelger. Én rad per kategori: **Budsjett | Faktisk | Avvik**, der «Faktisk» summeres fra `transactions` for samme år og kategori.
- Avvik vises med farge og fortegn: grønt når det er penger igjen på en utgiftspost, rødt ved overforbruk.
- Inntekter og utgifter i hver sin bolk, med sum og forventet resultat nederst.
- Rediger beløp direkte i tabellen, lagre alt i én omgang.
- Hold det enkelt. Ingen fordeling per måned.

### 2. Årsmøtepakke — `app/views/arsmote.js`

Én knapp: **Lag årsmøtepakke**. Den samler resultatregnskap, balanse, medlemsstatistikk, prosjektoversikt og budsjett for valgt år i én Excel-fil med ett ark per del, og lesbare norske kolonnenavn.

Gjenbruk rapportfunksjonene som allerede finnes i `app/views/okonomi.js` — ikke skriv dem på nytt.

### 3. Bankimport — utvid `app/views/okonomi.js`

Samme veiviser som importen av historisk regnskap, men for kontoutskrift:

- Velg fil, koble kolonner (dato, tekst, beløp inn, beløp ut eller fortegn, referanse).
- Finn sannsynlige duplikater før import: samme dato og samme beløp som en transaksjon som allerede finnes. Vis dem, la brukeren velge.
- Skriv en rad i `import_jobs` med antall lest, importert og avvist.

### 4. Tilskuddsmodul

Ny tabell `grants` (tilskuddsgiver, søknadsbeløp, innvilget, søknadsdato, rapporteringsfrist, prosjekt, status). Legg den i `supabase/migrations/0003_tilskudd.sql`, med rad-nivå-sikkerhet etter samme mønster som `projects`.

Status: planlegges, søkt, innvilget, avslått, rapportering pågår, ferdig rapportert. Frister skal dukke opp i «Trenger oppmerksomhet» på forsiden.

---

## Ikke gjør dette ennå

Ikke bygg NIF-integrasjon. Åpne data ligger på [data.nif.no](https://data.nif.no/index.html), men integrasjonen skal ligge i en egen modul under `integrations/nif` og kobles på først når en formell avtale foreligger. Datamodellen har allerede `ekstern_id` og `ekstern_kilde` på medlemmer.

Ikke bygg betalingsintegrasjon, OCR eller AI-forslag. Kjerneproduktet skal stå støtt først.

Ikke bytt rammeverk. Det finnes ingen byggekjede med vilje — det er derfor systemet kan publiseres gratis og endres raskt.
