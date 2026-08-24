# Oppsett — Saksflyt

Fra tomt til kjørende system. Regn med 20–30 minutter første gang.

Du trenger: en Supabase-konto, en GitHub-konto, og tilgang til DNS for `sakflyt.no`.

---

## 1. Opprett Supabase-prosjektet

1. Gå til [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
2. Navn: `saksflyt`. Region: **Frankfurt (eu-central-1)** — regnskaps- og persondata bør ligge i EØS.
3. Velg et databasepassord og lagre det i passordboksen din. Du trenger det bare hvis du skal koble til databasen direkte.
4. Vent til prosjektet er ferdig satt opp (1–2 minutter).

---

## 2. Kjør databaseskjemaet

Åpne **SQL Editor** i Supabase og kjør filene i denne rekkefølgen. Én om gangen, og se etter «Success» før du går videre.

| Rekkefølge | Fil | Hva den gjør |
|---|---|---|
| 1 | `supabase/migrations/0001_init.sql` | Alle tabeller, rad-nivå-sikkerhet, kontoplan, revisjonslogg |
| 2 | `supabase/migrations/0002_attestering.sql` | Regninger og godkjenning av to personer |
| 3 | `supabase/seed_klubb.sql` | Skoger og Fjell kampsportklubb med aktiviteter, grupper og satser |

Skjemaet er testet mot PostgreSQL 16 og kjører rent på et tomt prosjekt.

---

## 3. Slå på lagring for filer

Under **Storage** → **New bucket**, opprett to bøtter. Begge skal være **private**:

- `bilag` — kvitteringer og fakturaer
- `dokumenter` — vedtekter, protokoller, avtaler

Legg deretter inn tilgangsregler under **Storage → Policies**, slik at bare innloggede brukere i riktig organisasjon når filene:

```sql
create policy "les egne filer" on storage.objects for select
  using (bucket_id in ('bilag','dokumenter')
         and er_medlem_av(((storage.foldername(name))[1])::uuid));

create policy "last opp egne filer" on storage.objects for insert
  with check (bucket_id in ('bilag','dokumenter')
              and er_medlem_av(((storage.foldername(name))[1])::uuid));
```

Filstien begynner alltid med organisasjonens id, så en klubb når aldri en annen klubbs filer.

---

## 4. Opprett de tre brukerne

Under **Authentication → Users → Add user**:

| E-post | Rolle i systemet | Verv |
|---|---|---|
| `malik@kampsportlaget.com` | Administrator | Styreleder |
| `carlos@kampsportlaget.com` | Kasserer | Kasserer |
| `denis@kampsportlaget.com` | Styreleder | Nestleder |

Sett passordet `Drammen2026!` på alle tre, og kryss av for **Auto Confirm User** slik at de slipper å bekrefte e-posten.

Alle kan bytte passord selv etterpå under **Min profil → Velg nytt passord**. Be dem gjøre det ved første innlogging — et delt oppstartspassord bør ikke bli værende.

Rollene settes automatisk av `seed_klubb.sql`. Kjørte du seed-filen før du opprettet brukerne, kobles de på ved første innlogging i stedet. Begge veier virker.

Under **Authentication → Providers** kan du slå av «Enable email signups» når de tre er inne, hvis du ikke vil at fremmede skal kunne registrere seg. Nye brukere legger du da inn under **Innstillinger → Brukere** i systemet.

---

## 5. Legg inn nøklene i koden

Åpne `app/config.js` og fyll inn de to verdiene fra Supabase (**Project Settings → API**):

```js
export const SUPABASE_URL = "https://xxxxxxxx.supabase.co";
export const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

Begge er offentlige av design. Anon-nøkkelen gir ingen tilgang uten innlogging, fordi all tilgangskontroll ligger i rad-nivå-sikkerheten i databasen. **Service role-nøkkelen skal aldri inn i dette prosjektet.**

---

## 6. Publiser på GitHub Pages

```bash
cd ~/Documents/Regnskap/saksflyt
git init
git add .
git commit -m "Saksflyt: første versjon"
git branch -M main
git remote add origin https://github.com/DITT-BRUKERNAVN/saksflyt.git
git push -u origin main
```

Deretter i GitHub, under **Settings → Pages**:

- **Source:** GitHub Actions
- **Custom domain:** `sakflyt.no`
- Kryss av for **Enforce HTTPS** når sertifikatet er klart (kan ta en time)

Arbeidsflyten i `.github/workflows/pages.yml` publiserer automatisk hver gang du dytter til `main`. Den stopper med en tydelig feilmelding hvis `config.js` fortsatt mangler nøkler.

---

## 7. Pek domenet mot GitHub

Hos Domeneshop, under DNS for `sakflyt.no`:

| Type | Navn | Verdi |
|---|---|---|
| A | @ | `185.199.108.153` |
| A | @ | `185.199.109.153` |
| A | @ | `185.199.110.153` |
| A | @ | `185.199.111.153` |
| CNAME | www | `DITT-BRUKERNAVN.github.io.` |

Fjern eventuelle gamle A- eller CNAME-oppføringer på `@` og `www` først. Det tar vanligvis 15 minutter til et par timer før det slår gjennom.

Filen `CNAME` i roten inneholder allerede `sakflyt.no`, så GitHub vet hvilket domene som hører til.

---

## 8. Legg til flere klubber senere

Systemet er bygget for flere organisasjoner i samme database fra første dag. En ny klubb legges inn slik:

1. Logg inn og velg **Opprett organisasjon** — eller kjør en kopi av `seed_klubb.sql` med nytt navn og organisasjonsnummer.
2. Kontoplan, kategorier og abonnement opprettes automatisk.
3. Legg inn brukerne under **Innstillinger → Brukere**.

Hver organisasjon ser bare sine egne data. Det håndheves i databasen, ikke i grensesnittet — en bruker i klubb A får ingenting ut av klubb B selv om vedkommende skulle spørre databasen direkte.

Vil du heller ha helt separate databaser per klubb, oppretter du et Supabase-prosjekt per klubb og kjører de samme filene der. Da må hver klubb ha sin egen `config.js`, og det blir mer å vedlikeholde.

---

## Når noe ikke virker

| Symptom | Sannsynlig årsak |
|---|---|
| «Nesten klar» ved oppstart | `config.js` mangler nøkler |
| «Du har ikke tilgang til å gjøre dette» | Rollen mangler rettigheten. Sjekk Innstillinger → Brukere |
| Innlogging virker, men ingen organisasjon | Seed-filen er ikke kjørt, eller e-posten stemmer ikke med invitasjonen |
| Kvitteringer lastes ikke opp | Storage-bøtta `bilag` mangler, eller reglene i punkt 3 er ikke lagt inn |
| Siden viser gammel versjon | GitHub Pages cacher. Hard refresh med Cmd+Shift+R |

---

## Senere: Norges idrettsforbund

NIF har åpne data på [data.nif.no](https://data.nif.no/index.html). Det er utgangspunktet for en fremtidig integrasjon, men det skal bygges som en egen modul under `integrations/nif`, koblet på først når en formell integrasjonsavtale foreligger. Datamodellen har allerede feltene `ekstern_id` og `ekstern_kilde` på medlemmer, slik at koblingen kan legges inn uten å endre skjemaet.

Systemet skal ikke omtales som NIF-godkjent før en godkjenning faktisk finnes.
