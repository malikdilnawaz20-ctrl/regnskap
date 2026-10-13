# Oppdrag til Codex: EHF-eksport av salgsfaktura (trinn 1 — fil, ikke sending)

Les `CODEX.md` først (regler for kodebasen). Gjør bare det som står her. Ikke rør signering, dokumenter, medlemmer eller regnskapsrapporter.

## Mål

En utstedt faktura (`sales_invoices.status = 'utstedt'`) skal kunne lastes ned som en EHF-fil (UBL 2.1 Invoice, Peppol BIS Billing 3.0 / EHF Billing 3.0) som validerer i https://anskaffelser.dev/service/validator/. Filen lastes opp av kunden i nettbank eller hos et aksesspunkt. Sending bygges senere.

Fra 1.1.2027 er e-faktura B2B pliktig i Norge, så dette må være riktig, ikke bare «virke».

## Leveranse (fire deler)

### 1. `supabase/migrations/0021_ehf.sql` — felter som mangler

```
organizations:  land text not null default 'NO'
                foretaksregistrert boolean not null default false   -- AS/ASA/NUF: true → CompanyLegalForm "Foretaksregisteret"
                ehf_endepunkt text                                   -- normalt org.nr; schemeID 0192
customers:      land text not null default 'NO'
                mvanr text                                           -- BT-48, bare ved omvendt avgiftsplikt
                gate text, postnr text, sted text                    -- strukturert adresse; dagens `adresse` er fritekst og beholdes
sales_invoice_lines:
                enhetskode text not null default 'H87'               -- UN/ECE Rec 20: H87 stk, HUR time, DAY døgn, KGM kg, MTR m, LTR l, EA stk(alt)
                mva_kategori text not null default 'S'
                  check (mva_kategori in ('S','Z','E','G','AE','O'))
                fritak_tekst text                                    -- BT-120, påkrevd ved G og E, forbudt ved Z
sales_invoices: ehf_generert_tid timestamptz, ehf_hash text          -- logg: når filen sist ble laget og SHA-256 av den
```
Alt `add column if not exists`. Ingen nye RLS-regler trengs (kolonner på eksisterende tabeller). Kan kjøres flere ganger.

### 2. `app/ehf.js` — ren modul uten DOM

```js
export function kontrollerEhf(org, faktura, kunde, linjer)  // → [] eller liste av { felt, melding, hvor }
export function lagEhfXml(org, faktura, kunde, linjer)      // → string (XML). Kaster hvis kontrollerEhf gir feil.
export const ENHETSKODER = { stk:'H87', time:'HUR', timer:'HUR', dag:'DAY', døgn:'DAY', kg:'KGM', m:'MTR', l:'LTR' }
```

`kontrollerEhf` skal stoppe FØR XML lages og navngi feltet på norsk og hvor det fylles ut, f.eks.
`{ felt: "Kundens organisasjonsnummer (BT-47/BT-49)", melding: "Mangler.", hvor: "Kundekortet" }`. Obligatorisk:
- faktura: `nummer`, `fakturadato`, `valuta`; `deres_ref` ELLER `bestillingsnr` (PEPPOL-EN16931-R003); type faktura/kreditnota — proforma avvises.
- org: `navn`, `orgnr` (9 siffer), `land`, `faktura_kontonummer` (fra 0003), `mva_registrert` må være true når noen linje har kategori S/Z/E/G/AE.
- kunde: `navn`, `orgnr` (9 siffer) eller `ehf_mottaker` på formen `0192:XXXXXXXXX`, `land`, og for AE også `mvanr`.
- linjer: minst én; `antall > 0`; `pris_ore >= 0` (negativ pris avvises — kreditnota er eget dokument); `enhetskode` må finnes i Rec 20-listen under; kategori S krever sats > 0; Z/E/G/AE/O krever sats 0; G og E krever `fritak_tekst`; Z må ikke ha `fritak_tekst`; O kan ikke blandes med andre kategorier.

`lagEhfXml` — bruk `docs/ehf-mapping.md` som fasit. Faste verdier:
- `cbc:CustomizationID` = `urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0` (tegnrett)
- `cbc:ProfileID` = `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0`
- `cbc:InvoiceTypeCode` 380 (faktura). Kreditnota: eget rotelement `CreditNote` med 381 og `cac:BillingReference/cac:InvoiceDocumentReference/cbc:ID` = fakturaen som krediteres (`krediterer` → dens `nummer`).
- Selger: `cbc:EndpointID schemeID="0192"` = orgnr; `PartyLegalEntity/CompanyID schemeID="0192"` = orgnr; `RegistrationName` = navn; `PartyTaxScheme/CompanyID` = `NO<orgnr>MVA` når mva_registrert, med `TaxScheme/ID` = `VAT`; `CompanyLegalForm` = `Foretaksregisteret` når foretaksregistrert.
- Kjøper: `EndpointID schemeID="0192"`, `CompanyID schemeID="0192"`, `RegistrationName`, `PostalAddress` med `Country/IdentificationCode`.
- `cac:PaymentMeans/cbc:PaymentMeansCode` = `30`, `PayeeFinancialAccount/cbc:ID` = kontonummer uten mellomrom/punktum, `cbc:PaymentID` = KID hvis fakturaen har det.
- `cac:InvoicePeriod` fra `levering_fra`/`levering_til` når satt.
- Beløp: regn i øre, avrund én gang per linje. `LineExtensionAmount` = round(antall × pris_ore)/100 med to desimaler. `TaxSubtotal` per (kategori, sats). `LegalMonetaryTotal`: LineExtensionAmount, TaxExclusiveAmount, TaxInclusiveAmount, PayableAmount — alle med `currencyID`. Summene MÅ stemme med `faktura.netto_ore/mva_ore/brutto_ore`; avvik → kast feil (ikke generer).
- Kategori O: ingen `cbc:Percent`, `TaxExemptionReasonCode` = `VATEX-EU-O`. AE: `VATEX-EU-AE`. G/E: `TaxExemptionReason` = fritak_tekst.
- XML-escape alle tekster (`&`, `<`, `>`, `"`). Datoer `YYYY-MM-DD`. Beløp alltid to desimaler med punktum.

### 3. Grensesnitt i `app/views/faktura.js`

- På en utstedt faktura (og kreditnota): knapp **«Last ned EHF»** ved siden av PDF. Den kjører `kontrollerEhf`; er listen tom, lastes `<nummer>.xml` ned (`application/xml`) og `sales_invoices.ehf_generert_tid`/`ehf_hash` oppdateres. Ellers vises en modal «EHF kan ikke lages ennå» med listen over felt + hvor de fylles ut — og ingen fil lages.
- Kundekortet får feltene gate, postnr, sted, land (select med NO først), mvanr, og beholder ehf_mottaker (hint: «0192:organisasjonsnummer»).
- Linjeredigering: enhet blir en select med norske navn (stk, time, dag, kg, m, l) som lagrer `enhetskode`; mva-velgeren utvides til kategori: «25 %», «15 %», «12 %», «0 % — fritatt (Z)», «0 % — unntatt (E)», «0 % — utførsel (G)», «0 % — omvendt avgiftsplikt (AE)». Valg av E/G åpner et felt for fritaksbegrunnelse.
- Selskapsinformasjon (`app/app.js`, funksjonen `selskap`/`redigerOrg`): felt for land, «Registrert i Foretaksregisteret» (ja/nei) og kontonummer hvis det ikke allerede redigeres der.
- Følg kontrakten i CODEX.md: `el()`, ingen `innerHTML` med data, feil via `visFeil`, ingen ny CSS.

### 4. Test: `tools/test-ehf.mjs`

Node-skript uten avhengigheter som importerer `app/ehf.js`, bygger en faktura med to linjer (25 % og 0 % Z), kjører `kontrollerEhf` (forvent tom liste), `lagEhfXml`, og sjekker: CustomizationID tegnrett, at summene stemmer (netto/mva/brutto), at `BuyerReference` finnes, at `unitCode="H87"`, og at en faktura uten kundens orgnr gir feil som nevner «Kundekortet». Kjør med `node tools/test-ehf.mjs`; skal skrive `OK` og avslutte med kode 0.

## Ikke gjør

- Ikke send noe til Peppol. Ikke legg inn API-nøkler eller aksesspunkt.
- Ikke endre nummerserie eller utstedelsesflyt.
- Ikke installer npm-pakker. Ingen byggesteg.
- Ikke endre `supabase/migrations/0001`–`0020`.

## Ferdig når

`node --check` går rent på endrede filer, `node tools/test-ehf.mjs` skriver OK, og en XML laget fra testen validerer uten feil på anskaffelser.dev (lim inn manuelt). Skriv en kort oppsummering i `docs/ehf-status.md`: hva som er gjort, hva som gjenstår for sending.
