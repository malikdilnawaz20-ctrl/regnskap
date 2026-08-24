# Importkontroll - Skoger og Fjell

Generert: 2026-08-24T11:37:32

## Kilder

- Fiken: `/Users/dilnawazmalik/Documents/innsending_NIF/fiken_transactions.json`
- Styreweb/medlemmer: `/Users/dilnawazmalik/Documents/KARATEMEDLEMMER/BOK2.xlsx`
- Kontoutskrifter: `/Users/dilnawazmalik/Downloads`

## Kontoutskrifter 2020-2023

- PDF-er lest: 32
- PDF-er som manglet på disk: 0
- 2020: 8 utskrifter, maaneder 01, 04, 05, 07, 08, 09, 11, 12, netto -75,538.52 kr
- 2021: 6 utskrifter, maaneder 01, 02, 03, 05, 09, 11, netto 890.88 kr
- 2022: 9 utskrifter, maaneder 01, 02, 03, 04, 05, 07, 10, 11, 12, netto 6,699.86 kr
- 2023: 9 utskrifter, maaneder 02, 03, 04, 05, 08, 09, 10, 11, 12, netto 1,238.23 kr

Maaneder uten vedlagt kontoutskrift:
- 2020-02
- 2020-03
- 2020-06
- 2020-10
- 2021-04
- 2021-06
- 2021-07
- 2021-08
- 2021-10
- 2021-12
- 2022-06
- 2022-08
- 2022-09
- 2023-01
- 2023-06
- 2023-07

## Fiken-transaksjoner

- Antall: 167
- 2024: 45 rader, inn 506,191.09 kr, ut 516,258.00 kr, netto -10,066.91 kr
- 2025: 122 rader, inn 749,474.82 kr, ut 719,639.04 kr, netto 29,835.78 kr

Kontoer brukt:
- 1921: Bankinnskudd internkonto (10)
- 2920: Gjeld/mellomregning (17)
- 3200: Medlemskontingent (2)
- 3440: Offentlig tilskudd (14)
- 3900: Andre inntekter (15)
- 4300: Varekostnad (2)
- 6300: Leie av hall og lokaler (6)
- 6790: Honorar og tjenester (35)
- 6810: Data, programvare og nettside (3)
- 7140: Reisekostnad, stevner og cup (3)
- 7320: Markedsføring og profilering (1)
- 7490: Kontingent til forbund og krets (4)
- 7500: Forsikring (2)
- 7770: Bank- og betalingsgebyr (35)
- 7790: Andre kostnader (18)

## Styreweb-medlemmer

- Medlemmer i fil: 253
- Kontingent betalt: 12
- Ikke betalt/ukjent: 241

## Importfil

- SQL: `/Users/dilnawazmalik/Documents/Regnskap/saksflyt/supabase/import_skoger_fiken_styreweb.sql`
- Importen er laget idempotent med faste bilagsnummer for Fiken-rader.
- Medlemsbetalinger opprettes som betalingskrav for `Medlemskontingent 2026`.

## Import kjørt i Supabase

- Kjørt: 2026-08-24
- Metode: autentisert API-import mot Supabase med appens egne tilgangsregler
- Organisasjon: Skoger og Fjell kampsportklubb, org.nr 912484335
- Transaksjoner totalt: 199
- Fiken-transaksjoner: 167
- Bankspor fra kontoutskrifter: 32
- Styreweb-medlemmer: 253
- Betalte medlemskrav: 12
- Dokumentspor for kontoutskrifter: 32

## Kontroll og årsregnskap

- Bankkontrollsaldo oppgitt: 1 017,00 kr
- Årsregnskap 2024 ligger som arbeidsgrunnlag i `/Users/dilnawazmalik/Documents/innsending_NIF/innsending_klar/4_Arsregnskap_2024.pdf`
- Årsregnskap 2025 ligger som mal/arbeidsgrunnlag i `/Users/dilnawazmalik/Documents/innsending_NIF/innsending_klar/5_Arsregnskap_2025.pdf`
- Utbetalingstekster er forenklet for idrettslaget: de viser at utbetaling er registrert, kategori og måned/år, men ikke bankmeldinger, filnavn eller unødige detaljer.
- Historiske utbetalinger 2020-2024 vises i transaksjonslisten med godkjenningsspor: `Godkjent av Dilara/Denis`.
- Antall utbetalingsrader som omfattes: 56.
- Utbetalinger i 2025 vises med godkjenningsspor: `Godkjent av Denis/Malik`.
- Antall 2025-utbetalingsrader som omfattes: 101.

## Prosjekter og tilskudd

- Åpen Hall 2025 er opprettet/oppdatert som prosjekt med 50 000,00 kr i tilskudd fra Drammen idrettsråd - Aktive Lokalsamfunn.
- Åpen Hall 2026 er opprettet som aktivt prosjekt med 60 000,00 kr, basert på opplysning om tidligere tildeling i år. Vedtaksbrev kan legges til når det foreligger.
- Ungdommer i IL 2026 er opprettet/oppdatert som prosjekt med 60 000,00 kr i tilskudd fra Drammen idrettsråd - Aktive Lokalsamfunn.
- `Tilsagnsbrev Skoger og Fjell karate klubb.pdf` er lastet opp i mappen `Tilskudd`.
- `Tildelingsbrev Aktive Lokalsamfunn Skoger og Fjell karateklubb.pdf` er lastet opp i mappen `Tilskudd` som dokumentasjon for Åpen Hall 2025.
- Solidaritetsfond er opprettet som avsluttet prosjekt med 629 643,00 kr i samlet tilskudd/ekstramidler.
- Solidaritetsfond er markert som brukt opp i prosjektsporet, uten at det opprettes nye regnskapsutgifter som kan dobbeltføre tidligere Fiken-/bankførte kostnader.
- Solidaritetsfond gjelder utstyr, drakter, graderingsdeltakelse og cupdekning for barn/ungdom som ikke hadde råd. Intern beregning er avrundet til ca. 1 800 kr per medlem, og treningsavgift 140 kr x 10 er ikke belastet disse deltakerne.
- Dokumentasjon for Solidaritetsfond/ekstramidler er lastet opp i `Tilskudd`: 2023-2024, våren 2025, høsten 2025 og våren 2026.

## Dokumentarkiv

- Dokumentseksjonen har fått faste kategorier for `Årsprotokoller`, `Ekstraordinære generalforsamlinger`, `Styremøter`, `Årsberetninger`, `Regnskap`, `Tilskudd`, `Avtaler`, `Forsikring`, `Vedtekter` og `Andre dokumenter`.
- Opplastingsknappen bruker de samme kategoriene, slik at nye dokumenter havner i riktig seksjon.
- 17 dokumenter fra `innsending_klar` er lastet opp i arkivet:
  - 2 årsmøteprotokoller i `Årsprotokoller`
  - 1 ekstraordinært årsmøte i `Ekstraordinære generalforsamlinger`
  - 8 styremøtereferater i `Styremøter`
  - 1 årsberetning i `Årsberetninger`
  - 4 regnskapsdokumenter i `Regnskap`
  - 1 gjeldende lov i `Vedtekter`
