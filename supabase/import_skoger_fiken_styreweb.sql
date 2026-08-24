-- =====================================================================
--  Import fra Fiken, Styreweb og kontoutskrifter for Skoger og Fjell kampsportklubb
--  Generert lokalt. Idempotent: kan kjores flere ganger uten duplikater.
-- =====================================================================

create unique index if not exists members_styreweb_ext_key
  on members (organization_id, ekstern_kilde, ekstern_id)
  where ekstern_kilde is not null and ekstern_id is not null;

create unique index if not exists payment_claims_import_member_fee_desc_key
  on payment_claims (organization_id, member_id, fee_id, beskrivelse);

create unique index if not exists documents_import_file_key
  on documents (organization_id, mappe, tittel, filnavn);

do $$
declare
  org uuid;
  fee uuid;
  member_id uuid;
begin
  select id into org from organizations where orgnr = '912484335';
  if org is null then
    raise exception 'Fant ikke organisasjon 912484335';
  end if;

  insert into accounts (organization_id, navn, kontonummer, type)
  values (org, 'Fiken bankkonto 2220.29.21373', '2220.29.21373', 'bank')
  on conflict do nothing;

  insert into fees (organization_id, navn, type, intervall, belop_ore, gjelder_fra)
  values (org, 'Medlemskontingent 2026', 'medlemskontingent', 'aarlig', 45000, '2026-01-01')
  on conflict do nothing;
  select id into fee from fees where organization_id = org and navn = 'Medlemskontingent 2026' limit 1;

  -- Kontoplan/kategorier brukt i Fiken-importen
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 1921, 'Bankinnskudd internkonto') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 2920, 'Gjeld/mellomregning') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 3200, 'Medlemskontingent') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 3440, 'Offentlig tilskudd') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 3900, 'Andre inntekter') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 4300, 'Varekostnad') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 6300, 'Leie av hall og lokaler') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 6790, 'Honorar og tjenester') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 6810, 'Data, programvare og nettside') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7140, 'Reisekostnad, stevner og cup') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7320, 'Markedsføring og profilering') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7490, 'Kontingent til forbund og krets') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7500, 'Forsikring') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7770, 'Bank- og betalingsgebyr') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into accounting_accounts (organization_id, nummer, navn) values (org, 7790, 'Andre kostnader') on conflict (organization_id, nummer) do update set navn = excluded.navn;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Andre inntekter', 'inntekt', 3900) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Andre utgifter', 'utgift', 7790) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Bankgebyr', 'utgift', 7770) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Dommer og stevneavgift', 'utgift', 7140) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Forsikring', 'utgift', 7500) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Hall-leie', 'utgift', 6300) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Honorar og tjenester', 'utgift', 6790) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Kontingent til forbund', 'utgift', 7490) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Markedsføring', 'utgift', 7320) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Medlemskontingent', 'inntekt', 3200) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Mellomregning', 'inntekt', 2920) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Mellomregning', 'utgift', 2920) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Nettside og programvare', 'utgift', 6810) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Offentlig tilskudd', 'inntekt', 3440) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Overføring internkonto', 'utgift', 1921) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values (org, 'Varekostnad', 'utgift', 4300) on conflict (organization_id, navn, retning) do update set konto_nummer = excluded.konto_nummer, aktiv = true;
  insert into categories (organization_id, navn, retning, konto_nummer) values
    (org, 'Historisk bankspor - inn', 'inntekt', 3900),
    (org, 'Historisk bankspor - ut', 'utgift', 7790)
  on conflict (organization_id, navn, retning) do update set aktiv = true;

  -- Kontoutskrifter 2020-2023. Importert som maanedlige netto bankspor, ikke detaljlinjer.
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-01', 'Dokument PKTOUTS03@533858244721799053.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-01', '2020-01-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, januar 2020', 940270, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-04', 'Dokument PKTOUTS03@565692257350498451.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-04', '2020-04-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, april 2020', 985989, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-05', 'Dokument PKTOUTS03@575958712666394765.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-05', '2020-05-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 1705240, 3900, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-07', 'Dokument PKTOUTS03@021785994090626693.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-07', '2020-07-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, juli 2020', 1641450, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-08', 'Dokument PKTOUTS03@032775231237276820.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-08', '2020-08-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, august 2020', 4836000, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-09', 'Dokument PKTOUTS03@043389491810922885.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-09', '2020-09-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, september 2020', 1207083, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-11', 'Dokument PKTOUTS03@064960942488950403.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-11', '2020-11-30', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 2031900, 3900, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2020-12', 'Dokument PKTOUTS03@076200963640121238.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2020-12', '2020-12-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, desember 2020', 1680200, 7790, c.id, 2020
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-01', 'Dokument PKTOUTS03@086193649723352451.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-01', '2021-01-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 163806, 3900, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-02', 'Dokument PKTOUTS03@996091536519205509.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-02', '2021-02-28', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, februar 2021', 302000, 7790, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-03', 'Dokument PKTOUTS03@107758133491203203.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-03', '2021-03-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, mars 2021', 1000, 7790, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-05', 'Dokument PKTOUTS03@129385264488527687.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-05', '2021-05-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 202715, 3900, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-09', 'Dokument PKTOUTS03@172522521248486912.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-09', '2021-09-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, september 2021', 275579, 7790, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2021-11', 'Dokument PKTOUTS03@194124487519672843.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2021-11', '2021-11-30', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 301146, 3900, c.id, 2021
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-01', 'Dokument PKTOUTS03@216070060660160516.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-01', '2022-01-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, januar 2022', 164639, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-02', 'Dokument PKTOUTS03@226003796183673865.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-02', '2022-02-28', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, februar 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-03', 'Dokument PKTOUTS03@236928486934611462.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-03', '2022-03-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, mars 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-04', 'Dokument PKTOUTS03@247188925148196358.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-04', '2022-04-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, april 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-05', 'Dokument PKTOUTS03@258523016499702790.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-05', '2022-05-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 30325, 3900, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-07', 'Dokument PKTOUTS03@279394073048502787.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-07', '2022-07-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, juli 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-10', 'Dokument PKTOUTS03@312686558481119744.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-10', '2022-10-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, oktober 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-11', 'Dokument PKTOUTS03@323301026666880519.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-11', '2022-11-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, november 2022', 1000, 7790, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2022-12', 'Dokument PKTOUTS03@334403996276695044.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2022-12', '2022-12-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 810300, 3900, c.id, 2022
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-02', 'Dokument PKTOUTS03@355147641393966088.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-02', '2023-02-28', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, februar 2023', 1000, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-03', 'Dokument PKTOUTS03@366101960787749894.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-03', '2023-03-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, mars 2023', 972100, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-04', 'Dokument PKTOUTS03@376009499320307205.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-04', '2023-04-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, april 2023', 36418, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-05', 'Dokument PKTOUTS03@387699389829919236.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-05', '2023-05-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 116120, 3900, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-08', 'Dokument PKTOUTS03@420251054226293259.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-08', '2023-08-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, august 2023', 8650, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-09', 'Dokument PKTOUTS03@430517621201375236.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-09', '2023-09-30', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 164772, 3900, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-10', 'Dokument PKTOUTS03@441851862728451591.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-10', '2023-10-31', 'inntekt', 'Bankbevegelse registrert fra kontoutskrift', 16024200, 3900, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - inn' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-11', 'Dokument PKTOUTS03@452476432616461312.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-11', '2023-11-30', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, november 2023', 1000, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into documents (organization_id, mappe, tittel, filnavn, kun_styret)
  values (org, 'Regnskap', 'Kontoutskrift 2023-12', 'Dokument PKTOUTS03@463086392740816897.pdf', true)
  on conflict do nothing;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'BANK-2023-12', '2023-12-31', 'utgift', 'Utbetaling registrert i regnskapet - historisk bankspor, desember 2023', 15162101, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;

  -- Fiken transaksjoner
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0001', '2024-01-08', 'inntekt', 'Fra: Norsk Tipping AS [2024-01-08]', 169724, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0002', '2024-01-19', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, januar 2024', 1190000, 7790, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0003', '2024-01-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, januar 2024', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0004', '2024-01-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, januar 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0005', '2024-02-29', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, februar 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0006', '2024-03-22', 'inntekt', 'Fra: Drammen Idrettsråd [2024-03-22]', 1757400, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0007', '2024-03-25', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, mars 2024', 1760000, 7790, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0008', '2024-03-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, mars 2024', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0009', '2024-03-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, mars 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0010', '2024-04-03', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2024-04-03]', 9852500, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0011', '2024-04-05', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, april 2024', 9852100, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0012', '2024-04-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, april 2024', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0013', '2024-04-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, april 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0014', '2024-05-10', 'inntekt', 'Fra: Norsk Tipping AS [2024-05-10]', 166570, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0015', '2024-05-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, mai 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0016', '2024-06-07', 'inntekt', 'Fra: Drammen Idrettsråd [2024-06-07]', 4000000, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0017', '2024-06-11', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, juni 2024', 450000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0018', '2024-06-11', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juni 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0019', '2024-06-20', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, juni 2024', 3700000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0020', '2024-06-26', 'inntekt', 'Fra: Drammen Idrettsråd [2024-06-26]', 3225300, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0021', '2024-06-28', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, juni 2024', 3238500, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0022', '2024-06-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juni 2024', 700, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0023', '2024-06-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juni 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0024', '2024-07-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juli 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0025', '2024-08-29', 'inntekt', 'Fra: Norsk Tipping AS [2024-08-29]', 622700, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0026', '2024-08-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, august 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0027', '2024-09-05', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, september 2024', 500000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0028', '2024-09-05', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0029', '2024-09-11', 'inntekt', 'Fra: Norsk Tipping AS [2024-09-11]', 166615, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0030', '2024-09-12', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, september 2024', 200000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0031', '2024-09-12', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0032', '2024-09-23', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2024-09-23]', 20922700, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0033', '2024-09-23', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, september 2024', 20000000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0034', '2024-09-23', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, september 2024', 897000, 6300, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0035', '2024-09-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2024', 200, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0036', '2024-09-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2024', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0037', '2024-09-30', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0038', '2024-10-01', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2024-10-01]', 8804400, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0039', '2024-10-01', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, oktober 2024', 8912200, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0040', '2024-10-31', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, oktober 2024', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0041', '2024-11-18', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, november 2024', 5500, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0042', '2024-12-01', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, desember 2024', 200, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0043', '2024-12-20', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2024-12-20]', 931200, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0044', '2024-12-23', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, desember 2024', 5000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0045', '2024-12-30', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, desember 2024', 900000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0046', '2025-01-07', 'inntekt', 'Fra: Norsk Tipping AS [2025-01-07]', 171815, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0047', '2025-01-14', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, januar 2025', 190000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0048', '2025-01-20', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, januar 2025', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0049', '2025-02-17', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, februar 2025', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0050', '2025-02-20', 'inntekt', 'Fra: Norsk Tipping AS [2025-02-20]', 520800, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0051', '2025-02-21', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, februar 2025', 500000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0052', '2025-03-17', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, mars 2025', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0053', '2025-04-01', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2025-04-01]', 6624300, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0054', '2025-04-02', 'inntekt', 'Fra: Kron & Mynt AS [2025-04-02]', 3080640, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0055', '2025-04-07', 'utgift', 'Utbetaling registrert i regnskapet - dommer og stevneavgift, april 2025', 945000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0056', '2025-04-11', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, april 2025', 1867245, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0057', '2025-04-11', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, april 2025', 1145000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0058', '2025-04-22', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, april 2025', 5000, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0059', '2025-04-24', 'inntekt', 'Fra: Drammen Idrettsråd [2025-04-24]', 5000000, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0060', '2025-04-25', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, april 2025', 700000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0061', '2025-05-02', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, mai 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0062', '2025-05-02', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, mai 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0063', '2025-05-05', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, mai 2025', 600000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0064', '2025-05-06', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, mai 2025', 160300, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0065', '2025-05-09', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, mai 2025', 2000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0066', '2025-05-16', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, mai 2025', 987250, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0067', '2025-05-19', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, mai 2025', 6025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0068', '2025-05-20', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, mai 2025', 3000000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0069', '2025-05-20', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, mai 2025', 567190, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0070', '2025-06-03', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, juni 2025', 400000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0071', '2025-06-05', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, juni 2025', 1950000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0072', '2025-06-21', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juni 2025', 8025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0073', '2025-07-08', 'inntekt', 'Fra: Kron & Mynt AS [2025-07-08]', 3082044, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0074', '2025-07-10', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, juli 2025', 3100000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0075', '2025-07-19', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, juli 2025', 6000, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0076', '2025-08-16', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, august 2025', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0077', '2025-08-22', 'inntekt', 'Fra: Norsk Tipping AS [2025-08-22]', 699500, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0078', '2025-08-25', 'inntekt', 'Overførsel [2025-08-25]', 299854, 3200, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Medlemskontingent' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0079', '2025-08-26', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, august 2025', 150000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0080', '2025-08-26', 'inntekt', 'Innskudd Fr 25 Aug 31,99+112,25 [2025-08-26]', 14424, 3200, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Medlemskontingent' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0081', '2025-09-04', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, september 2025', 650000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0082', '2025-09-08', 'inntekt', 'Fra: Norsk Tipping AS [2025-09-08]', 107215, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0083', '2025-09-12', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2025-09-12]', 21690300, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0084', '2025-09-15', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, september 2025', 4033715, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0085', '2025-09-15', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, september 2025', 2500000, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0086', '2025-09-15', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, september 2025', 1349796, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0087', '2025-09-15', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, september 2025', 1214633, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0088', '2025-09-15', 'utgift', 'Utbetaling registrert i regnskapet - hall-leie, september 2025', 446575, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0089', '2025-09-17', 'utgift', 'Utbetaling registrert i regnskapet - nettside og programvare, september 2025', 154400, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0090', '2025-09-17', 'utgift', 'Utbetaling registrert i regnskapet - nettside og programvare, september 2025', 102700, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0091', '2025-09-18', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, september 2025', 802950, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0092', '2025-09-18', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, september 2025', 180450, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0093', '2025-09-19', 'utgift', 'Utbetaling registrert i regnskapet - kontingent til forbund, september 2025', 1200000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0094', '2025-09-20', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, september 2025', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0095', '2025-09-22', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, september 2025', 240000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0096', '2025-09-23', 'inntekt', 'Fra: Drammen Idrettsråd [2025-09-23]', 5000000, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0097', '2025-09-23', 'inntekt', 'Fra: Drammen Idrettsråd [2025-09-23]', 6037100, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0098', '2025-09-23', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, september 2025', 1500000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0099', '2025-09-23', 'utgift', 'Utbetaling registrert i regnskapet - forsikring, september 2025', 212000, 7500, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Forsikring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0100', '2025-09-23', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, september 2025', 86800, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0101', '2025-09-25', 'utgift', 'Utbetaling registrert i regnskapet - kontingent til forbund, september 2025', 4000000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0102', '2025-09-25', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, september 2025', 1700000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0103', '2025-09-25', 'utgift', 'Utbetaling registrert i regnskapet - dommer og stevneavgift, september 2025', 1000000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0104', '2025-09-25', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, september 2025', 518270, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0105', '2025-09-25', 'utgift', 'Utbetaling registrert i regnskapet - dommer og stevneavgift, september 2025', 500000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0106', '2025-09-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, september 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0107', '2025-09-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, september 2025', 120000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0108', '2025-09-30', 'utgift', 'Utbetaling registrert i regnskapet - kontingent til forbund, september 2025', 1463000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0109', '2025-10-03', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 1704800, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0110', '2025-10-06', 'inntekt', 'Fra: Kron & Mynt AS [2025-10-06]', 2149118, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0111', '2025-10-08', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, oktober 2025', 240000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0112', '2025-10-08', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0113', '2025-10-15', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0114', '2025-10-16', 'utgift', 'Utbetaling registrert i regnskapet - forsikring, oktober 2025', 377000, 7500, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Forsikring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0115', '2025-10-16', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0116', '2025-10-20', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, oktober 2025', 373831, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0117', '2025-10-20', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, oktober 2025', 12275, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0118', '2025-10-23', 'inntekt', 'Fra: Fair Collection AS [2025-10-23]', 100, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0119', '2025-10-23', 'inntekt', 'Fra: Nedre Buskerud Boligbyggelag [2025-10-23]', 750000, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0120', '2025-10-24', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, oktober 2025', 4000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0121', '2025-10-24', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, oktober 2025', 800000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0122', '2025-10-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 240000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0123', '2025-10-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 200000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0124', '2025-10-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0125', '2025-10-29', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0126', '2025-10-31', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 797100, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0127', '2025-10-31', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 481800, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0128', '2025-10-31', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, oktober 2025', 400000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0129', '2025-10-31', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 293650, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0130', '2025-10-31', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, oktober 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0131', '2025-11-06', 'utgift', 'Utbetaling registrert i regnskapet - overføring internkonto, november 2025', 160000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0132', '2025-11-11', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2025-11-11]', 15654800, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0133', '2025-11-12', 'utgift', 'Utbetaling registrert i regnskapet - kontingent til forbund, november 2025', 1972600, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0134', '2025-11-12', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0135', '2025-11-14', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, november 2025', 2250000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0136', '2025-11-15', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, november 2025', 11025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0137', '2025-11-17', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 180000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0138', '2025-11-20', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, november 2025', 1000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0139', '2025-11-21', 'utgift', 'Utbetaling registrert i regnskapet - varekostnad, november 2025', 940794, 4300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Varekostnad' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0140', '2025-11-21', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, november 2025', 8000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0141', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, november 2025', 2000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0142', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 300000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0143', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 300000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0144', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0145', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, november 2025', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0146', '2025-11-28', 'utgift', 'Utbetaling registrert i regnskapet - nettside og programvare, november 2025', 54600, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0147', '2025-12-01', 'inntekt', 'Kreditrenter [2025-12-01]', 800, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0148', '2025-12-01', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, desember 2025', 100, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0149', '2025-12-02', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 654700, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0150', '2025-12-02', 'inntekt', 'Valuta Retur Valuta [2025-12-02]', 788276, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0151', '2025-12-03', 'inntekt', 'Fra: Kron & Mynt AS [2025-12-03]', 1119996, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0152', '2025-12-04', 'utgift', 'Utbetaling registrert i regnskapet - varekostnad, desember 2025', 758380, 4300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Varekostnad' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0153', '2025-12-04', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 427900, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0154', '2025-12-04', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 188850, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0155', '2025-12-04', 'utgift', 'Utbetaling registrert i regnskapet - andre utgifter, desember 2025', 8000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0156', '2025-12-05', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 180000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0157', '2025-12-10', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 500000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0158', '2025-12-12', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, desember 2025', 2150000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0159', '2025-12-16', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, desember 2025', 2260000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0160', '2025-12-18', 'utgift', 'Utbetaling registrert i regnskapet - markedsføring, desember 2025', 743000, 7320, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Markedsføring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0161', '2025-12-18', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 220000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0162', '2025-12-20', 'utgift', 'Utbetaling registrert i regnskapet - bankgebyr, desember 2025', 10675, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0163', '2025-12-22', 'inntekt', 'Fra: Norges Idrettsforbund og Olympiske [2025-12-22]', 2156400, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0164', '2025-12-23', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 165000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0165', '2025-12-23', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 140000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0166', '2025-12-30', 'utgift', 'Utbetaling registrert i regnskapet - mellomregning, desember 2025', 410000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0167', '2025-12-30', 'utgift', 'Utbetaling registrert i regnskapet - honorar og tjenester, desember 2025', 140000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;

  -- Styreweb medlemmer og kontingentstatus
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Margareth', 'Abdusalam Ahmadi', '2006-05-14', null, 'ahmadi_007@hotmail.com', 'aktiv', '5d74db859920cea0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5d74db859920cea0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Fiyinfoluwa Joshua', 'Adebayo', '2009-07-13', null, 'reginaomokaro@yahoo.com', 'aktiv', '76e65078502c3c3c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '76e65078502c3c3c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aziz Aron', 'Ahmad', '2007-05-22', null, 'aron.ahmad0123@gmail.com', 'aktiv', 'd405794eeec4319b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd405794eeec4319b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Gabriel Amin', 'Ahmad', '2011-11-06', null, 'lmhavet@live.no', 'aktiv', 'a8af578820d5463b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a8af578820d5463b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sophia', 'Ahmad', '2006-07-28', null, 'lmhavet@live.no', 'aktiv', '33c0ac302bfd7894', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '33c0ac302bfd7894' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Idel', 'Ahmed', '2005-04-23', null, null, 'aktiv', '103eaf77a5d3a906', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '103eaf77a5d3a906' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohammed', 'Ahmed', '2008-11-17', null, 'shahzad_ansir@live.no', 'aktiv', 'db2182798e5b8c9b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'db2182798e5b8c9b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Zeynab', 'Ahmed', '2007-06-19', null, null, 'aktiv', '3242897825ef1452', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3242897825ef1452' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Devran', 'Aktas', '2010-07-06', null, 'aktasramazan29@gmail.com', 'aktiv', '8fde9a4f54cede71', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8fde9a4f54cede71' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hacer', 'Aktas', '1985-08-19', null, null, 'aktiv', '3fc5c5b223a09bf3', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3fc5c5b223a09bf3' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hcer', 'Aktas', '1985-08-19', null, null, 'aktiv', 'e5dd0d52531090ae', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e5dd0d52531090ae' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hilal Ahu', 'Aktas', '2005-11-15', null, null, 'aktiv', 'c3bd1c838232427e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c3bd1c838232427e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ramazan', 'Aktas', '1984-03-01', null, 'aktasramazan29@gmail.com', 'aktiv', '4b6bf2cc68db9876', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '4b6bf2cc68db9876' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Haakon', 'Alexander', '2008-09-30', null, 'edmjohan@online.no', 'aktiv', '29568f33804cf17a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '29568f33804cf17a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Rahat', 'Alizai', '2006-02-07', null, 'bashar25@hotmail.com', 'aktiv', '5682e89a30e0768a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5682e89a30e0768a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Emir Ramazan', 'Almaz', '2003-04-04', null, 'erkekali@hotmail.com', 'aktiv', '91f7c2d0cb1214fa', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '91f7c2d0cb1214fa' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Irem', 'Almaz', '2006-06-29', null, 'post@marienlystfk.no', 'aktiv', 'b3fb20b1f35d8092', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b3fb20b1f35d8092' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Regina Omokaro', 'Amienmwanyomwan', '1988-05-12', null, null, 'aktiv', 'cb677fb04cb2d8f6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'cb677fb04cb2d8f6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Teo Kongsness', 'Andersen', '2008-11-05', null, 'pedrovanteo@gmail.com;mon_jensen@hotmail.com', 'aktiv', 'ea944e4f24bbfd22', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ea944e4f24bbfd22' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Berna', 'Aricigil', '2008-02-17', null, 'berna8aricigil@gmail.com', 'aktiv', 'e293ee608ee66058', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e293ee608ee66058' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Unnnur', 'Arnesdottir', '1988-08-08', null, 'unnur.arnesdottir@gmail.com', 'aktiv', '06787dfb87d85fea', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '06787dfb87d85fea' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Darin', 'Arshad', '2009-10-08', null, 'derya@live.no', 'aktiv', '93965cff9d9dceec', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '93965cff9d9dceec' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Haron', 'Asadi', '2004-05-13', null, null, 'aktiv', 'ff6a2d5d8261e236', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ff6a2d5d8261e236' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Madina', 'Asadi', '2007-09-21', null, 'madinajan971@icloud.com', 'aktiv', '2e585e6ad40702ee', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2e585e6ad40702ee' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ruben Tørstad', 'Aulie', '2002-02-13', null, 'aulie.ruben2879@gmail.com;mona.aulie@yahoo.no', 'aktiv', 'd7ae32b30562da5a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd7ae32b30562da5a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Shujah Hussain', 'Awan', '1978-03-26', null, 'shujah@fotomalik.no', 'aktiv', 'e58591a97688be36', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e58591a97688be36' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Morten', 'Bakken', '1986-04-13', null, 'bakken.morten@hotmail.com', 'aktiv', 'ea399f16c15080ae', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ea399f16c15080ae' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Philip Fossum', 'Bakken', '2012-04-15', null, 'kine.marie89@hotmail.com', 'aktiv', '98e4409bf460f4e7', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '98e4409bf460f4e7' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ruya', 'Bardakcioglu', '2009-08-12', null, null, 'aktiv', '2d2b35b1941bdbbe', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2d2b35b1941bdbbe' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Erkan', 'Barsan', '1981-11-17', null, null, 'aktiv', 'cf7194b1803bfd71', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'cf7194b1803bfd71' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohammed Saiid', 'Bashir', '2005-09-15', null, 'eimana27@hotmail.com', 'aktiv', '99a20136650164b6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '99a20136650164b6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Afrim', 'Bekteshi', '1978-07-09', null, 'medlem@kampsportlaget.com', 'aktiv', '6ac55640305ed18c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '6ac55640305ed18c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Eron Afrim', 'Bekteshi', '2007-10-31', null, 'buba30@hotmail.com;eronersaema_afrim@hotmail.com', 'aktiv', '84a5d12c9c34ca57', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '84a5d12c9c34ca57' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Eliza M', 'Bhasjwah', '2008-12-12', null, null, 'aktiv', '00335a69f008c492', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '00335a69f008c492' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Emilie Eriksen', 'Bjerkehagen', '2002-01-17', null, 'emilie.bjerkehagen@hotmail.com', 'aktiv', 'e0c80747f4d51c39', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e0c80747f4d51c39' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Anne Hofmo', 'Bjølgerud', '1981-09-15', null, 'anne@kampsport.no', 'aktiv', '61d697654f6c2594', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '61d697654f6c2594' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Leah Kristel', 'Bjørge', '2011-07-08', null, 'lindakristensen88@gmail.com;leahkb11@gmail.com', 'aktiv', '99f4f6def80f4f08', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '99f4f6def80f4f08' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Helene Janniche', 'Bjørklund', '2009-08-24', null, 'suzy_bjorklund@bigpond.com', 'aktiv', '85f4c9a846501bbe', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '85f4c9a846501bbe' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hedda', 'Brenne', '2009-01-14', null, 'heddabg09@icloud.com;brede.gulbrandsen@pg-flowsolutions.com;brenneirina@gmail.com;irina@isolasjon.no', 'aktiv', '261778ae38fa944f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '261778ae38fa944f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Imre Marius', 'Brenne', '2014-02-04', null, 'brenneirina@gmail.com', 'aktiv', '79a2ec488204ea19', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '79a2ec488204ea19' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Irina', 'Brenne', '1989-06-05', null, 'brenneirina@gmail.com', 'aktiv', 'defabdaf2997fd83', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'defabdaf2997fd83' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jonas Aleksander', 'Bråthen-Bjørk', '2003-11-06', null, 'kibraat@online.no', 'aktiv', 'fd1ee53677b26981', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'fd1ee53677b26981' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Gulcicek', 'Cetgin', '1987-06-23', null, null, 'aktiv', '1fd53e19a8d4dc6c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '1fd53e19a8d4dc6c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Carlos Leonardo', 'Clavijo Ferrer', '1987-08-15', null, 'carlosleonardo1987@live.no;carlos@kampsportlaget.com', 'aktiv', 'bb5c5e2a1eae8cdf', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bb5c5e2a1eae8cdf' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Alexandra Valentin', 'Danielsen', '2009-11-01', null, 'danielsenalexandra@gmail.com', 'aktiv', 'ba2a966b4d262d0f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ba2a966b4d262d0f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ole Janik', 'Danielsen', '1973-04-27', null, 'oleregnskap@gmail.com', 'aktiv', '949b34f7f5245b79', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '949b34f7f5245b79' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Zainab', 'Dicko', '1985-11-30', null, null, 'aktiv', '93436bdc8306c8bd', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '93436bdc8306c8bd' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Adnan', 'Durakovic-Grønhaug', '2009-11-20', null, 'senada.durakovic@gmail.com', 'aktiv', '750d777bbf1347e8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '750d777bbf1347e8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Lamija', 'Durakovic-Grønhaug', '2007-10-17', null, 'har@ikke.no', 'aktiv', '9ee37a8acb2ff62c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9ee37a8acb2ff62c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Christiell', 'Eek', '2009-12-12', null, 'veronica.x@live.no', 'aktiv', '9b7f693850503556', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9b7f693850503556' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohamed Amin', 'el Kredimi', '2005-01-14', null, 'bibi78@live.no', 'aktiv', 'a6ca156be4820b9e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a6ca156be4820b9e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Anne May', 'Eriksen', '1974-10-22', null, 'annemay.eriksen74@gmail.com', 'aktiv', 'd4583d459b304f26', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd4583d459b304f26' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aurora Torsrud', 'Eriksen', '2009-06-21', null, 'annemay.eriksen74@gmail.com', 'aktiv', 'adaa252fe06191ae', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'adaa252fe06191ae' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Janne', 'Eriksen', '1972-12-28', null, 'janne@kampsportlaget.com', 'aktiv', 'cb2d61325f2a1720', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'cb2d61325f2a1720' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ove Freddy', 'Eriksen', '1948-08-29', null, 'ovewenche@ebnett.no', 'aktiv', 'c8ee41aca6c8f873', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c8ee41aca6c8f873' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Wenche Monica', 'Eriksen', '1952-11-03', null, 'ovewenche@ebnett.no', 'aktiv', 'de8d61573b6d1286', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'de8d61573b6d1286' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Casper', 'Evensen', '2011-09-19', null, 'christine.wermskog@gmail.com', 'aktiv', '9b236b2bbfeca6e5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9b236b2bbfeca6e5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Rebeen', 'Falahi', '1980-05-09', null, 'rebeen@hotmail.no', 'aktiv', '0386703478dedccf', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0386703478dedccf' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sampo', 'Faye', '2009-10-01', null, null, 'aktiv', '0d07608830d91154', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0d07608830d91154' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sompo', 'Faye', '2009-10-01', null, 'nuhadicko@hotmail.com;nuhadicko@hotmail.com;sompofaye2009@outlook.com', 'aktiv', '5ba8fefc50350553', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5ba8fefc50350553' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Marius Alexander', 'Fimland-Hansen', '1987-02-12', null, 'hansenmarius@live.no', 'aktiv', 'b747ada606a753e9', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b747ada606a753e9' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Benjamin Kooijman', 'Fossum', '1981-07-11', null, 'assistenttrener.fotball@vear.no', 'aktiv', '7ba7f08eea41726f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7ba7f08eea41726f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Theo Blix', 'Fossum', '2012-01-25', null, 'benjamin.vearif@gmail.com;rebelpapi81@gmail.com', 'aktiv', '0606ba4a2fb22a4b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0606ba4a2fb22a4b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Linn Tangvold', 'Fredheim', '1986-07-02', null, 'lvolsen@hotmail.com', 'aktiv', '72ae4cf0fbc6d4c5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '72ae4cf0fbc6d4c5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Kaleb Darko', 'Garpe', '2006-09-02', null, null, 'aktiv', '112dc8839054fd50', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '112dc8839054fd50' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Efe Murat', 'Gezen', '2003-01-28', null, 'efegezen123@gmail.com', 'aktiv', '3a6957e587d63386', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3a6957e587d63386' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mustafa', 'Gezen', '1999-11-29', null, 'mustii_gezen@hotmail.com', 'aktiv', '01bd696e7d6086f0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '01bd696e7d6086f0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Nesrin', 'Gezen', '1987-02-26', null, 'nesrin_gezen87@hotmail.com', 'aktiv', '06d645788814dd39', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '06d645788814dd39' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Zeynep', 'Gezen', '1995-05-08', null, 'zeynep_gezen@hotmail.com', 'aktiv', 'bea2ef48fd4946c6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bea2ef48fd4946c6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Julian Mehren', 'Green', '2011-07-17', null, 'elise.green@hotmail.no', 'aktiv', '60671658df2d9851', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '60671658df2d9851' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jonas Brenne', 'Gundersen', '2011-04-17', null, 'brenneirina@gmail.com', 'aktiv', '3172ed0e21fbb54d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3172ed0e21fbb54d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ismihan', 'Gundønmez', '1962-07-20', null, null, 'aktiv', 'bcdd30097b8194c0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bcdd30097b8194c0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Veysel', 'Gundønmez', '1962-02-12', null, null, 'aktiv', 'f228b68b03d257a2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f228b68b03d257a2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Filip Gabriel', 'Gustafson', '2007-10-01', null, 'filip.gabriel.gustafson@gmail.com;kjersti_berge@hotmail.com', 'aktiv', '0583117acdc13340', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0583117acdc13340' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Isak Aleksander', 'Gustafson', '2006-04-29', null, 'isak.aleksander.gustafson@gmail.com', 'aktiv', '42937f360a2fee47', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '42937f360a2fee47' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Joakim', 'Gustavsen', '2001-02-01', null, 'gustavsenyvonne@gmail.com', 'aktiv', '569a64d7d1d12473', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '569a64d7d1d12473' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Yvonne Kristensen', 'Gustavsen', '1963-02-19', null, 'gustavsenyvonne@gmail.com', 'aktiv', '03e132a2f3dda92f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '03e132a2f3dda92f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Batin', 'Gökgül', '2005-06-02', null, 'medlem@kampsportlaget.com', 'aktiv', '95607a0a44e9db37', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '95607a0a44e9db37' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Idris', 'Gökgül', '2003-07-19', null, 'kadet_1@hotmail.com', 'aktiv', 'b8d17b4ddbc7e5d0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b8d17b4ddbc7e5d0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Osman Mustafa', 'Gøkmen', '2010-09-14', null, 'ismet.gokmen@hotmail.com', 'aktiv', 'fae14c71765843e4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'fae14c71765843e4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sara', 'Hafiz', '1982-05-07', null, 'rasoolmohabbat@yahoo.com', 'aktiv', '4be2ae1aa61afa6d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '4be2ae1aa61afa6d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Veronica Viktoria', 'Halland', '1980-04-15', null, 'vero9c@hotmail.com', 'aktiv', '98ba8d1997e69302', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '98ba8d1997e69302' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Monica Synnøve Strand', 'Halvorsen', '1984-05-06', null, 'monica.strand@hotmail.com;kim@dintrikker.no', 'aktiv', '545c308f2b9d6af2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '545c308f2b9d6af2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hesja Fuad', 'Hamawand', '2002-02-03', null, 'hesja2002@hotmail.com', 'aktiv', 'b82cd2b4a5f4c05c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b82cd2b4a5f4c05c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hafsa', 'Hamdi', '2003-10-17', null, 'samwajdi@hotmail.com', 'aktiv', 'b8c1845f548ec1fe', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b8c1845f548ec1fe' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohammed', 'Hamdi', '2009-01-10', null, 'samwajdi@hotmail.com', 'aktiv', '53bfe7e0232d459f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '53bfe7e0232d459f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Yassir', 'Hamdi', '2007-07-08', null, 'samwajdi@hotmail.com', 'aktiv', '69925d8e7ce7a72e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '69925d8e7ce7a72e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Melina Ros', 'Hammer', '2011-04-28', null, 'unnur.arnesdottir@gmail.com;stephanhammer@live.com', 'aktiv', 'a34f3ee142ce7fc6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a34f3ee142ce7fc6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aili Aurora', 'Hansen', '2011-01-17', null, 'aili.aurora2011@gmail.com;linda-kristiansen@live.no;lk@asent.no', 'aktiv', 'ffc7a3b972a3352d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ffc7a3b972a3352d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Alexander', 'Hansen', '2005-11-30', null, 'hansenmarius@live.no', 'aktiv', '2968e25033323f46', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2968e25033323f46' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Camilla Reiersen', 'Hansen', '1988-04-21', null, 'camma_16@hotmail.com', 'aktiv', 'c90d655f4125315f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c90d655f4125315f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Linda', 'Hansen', '1988-10-20', null, 'linda.hansen603@hotmail.com', 'aktiv', '3e023c37b619fa60', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3e023c37b619fa60' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Lucas Mathias', 'Hansen', '2012-01-27', null, 'lucas.mathias.hansen@hotmail.com', 'aktiv', '560820d33d9bf255', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '560820d33d9bf255' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Marita Sofie', 'Hansen', '2002-08-30', null, 'otterstadjanne@gmail.com', 'aktiv', 'c61b48421be4dd18', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c61b48421be4dd18' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tore Opdal', 'Hansen', '1986-08-04', null, null, 'aktiv', '73a635dd13e77e33', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '73a635dd13e77e33' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mustafa S', 'Hashemi', '2009-11-22', null, 'sayidmurtaza@hotmail.com', 'aktiv', 'a4642bb1bd1a4436', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a4642bb1bd1a4436' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sebastian', 'Hausken', '2002-10-09', null, 'ellitoll@online.no', 'aktiv', '8e056dc53dc8481c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8e056dc53dc8481c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Henriette Låker', 'Hedemark', '1992-12-14', null, 'henriette.w.l@hotmail.com', 'aktiv', '8b6d7165cc48d606', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8b6d7165cc48d606' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Camilla Tybring', 'Heimtun', '1986-05-08', null, 'cth80@hotmail.com', 'aktiv', 'dfd6c62bb04c1b73', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'dfd6c62bb04c1b73' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Markus Tybring', 'Heimtun', '2015-04-21', null, 'oystein.82@hotmail.com;cth80@hotmail.com', 'aktiv', 'e3c49e7ff0c9985a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e3c49e7ff0c9985a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Øystein', 'Heimtun', '1982-10-09', null, 'cth80@hotmail.com', 'aktiv', 'afe75774dacb7b29', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'afe75774dacb7b29' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Andreas Enger', 'Helgerud', '1984-08-23', null, 'andreas.helgerud.ah@gmail.com', 'aktiv', 'a5422945fe5ab0ce', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a5422945fe5ab0ce' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Morten', 'Hellingsrud', '1970-02-09', null, 'mortyhell@hotmail.com', 'aktiv', 'e7c7e13e0fef0f80', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e7c7e13e0fef0f80' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Therese Ernestus', 'Hellingsrud', '1975-06-26', null, 'therese.hellingsrud@hafslund.no;tess.hell@hotmail.no', 'aktiv', '8c991db4dce0f015', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8c991db4dce0f015' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mikael Skille', 'Henriksen', '1990-10-04', null, 'mikael.s.henriksen@hotmail.com', 'aktiv', '308998ae3be8a11f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '308998ae3be8a11f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mona Grete', 'Henriksen', '1950-03-10', null, 'm-g-h@online.no', 'aktiv', 'ce0b8670a3e901cb', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ce0b8670a3e901cb' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Kim Andre', 'Hermansen', '1988-03-13', null, 'austad66@hotmail.com', 'aktiv', '4e1da51cedb290f1', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '4e1da51cedb290f1' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mathias Dreessen', 'Hermansen', '2011-10-19', null, 'austad66@hotmail.com', 'aktiv', 'a20329482586f051', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a20329482586f051' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Leon', 'Hoff', '2006-08-13', null, null, 'aktiv', 'fe9b546bc8beffc5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'fe9b546bc8beffc5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mina', 'Holmgreen', '2002-10-01', null, 'ingvild.holmgreen72@gmail.com', 'aktiv', '0ac64c9f2903534b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0ac64c9f2903534b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Daarin', 'Hussain', '2009-06-22', null, 'darin_2009@live.no', 'aktiv', '2e3a958eb89f9238', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2e3a958eb89f9238' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Elias Sopp', 'Håheim', '2001-11-09', null, 'haheimelias@gmail.com;msopp@yahoo.no', 'aktiv', 'dcd245223ea7b983', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'dcd245223ea7b983' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Alexander Martinsen', 'Høyer', '1984-04-26', null, 'alexander@hoyerdrift.no', 'aktiv', '7ade77b798425f28', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7ade77b798425f28' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Leander Braathen', 'Høyer', '2012-08-14', null, 'lexander84@gmail.com', 'aktiv', 'a481a0c73eb472ab', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a481a0c73eb472ab' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Casper', 'Iddberg', '2009-08-19', null, 'andreaswwessel@gmail.com', 'aktiv', 'd140e4bc69592b76', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd140e4bc69592b76' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ina Hjemli', 'Iddberg', '1987-11-07', null, 'inaiddberg@hotmail.com', 'aktiv', '37198de0bc7ce8bd', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '37198de0bc7ce8bd' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sander', 'Iddberg', '2007-07-20', null, 'andreaswwessel@gmail.com', 'aktiv', '03ddbd93e358fe7a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '03ddbd93e358fe7a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jan', 'Isaksen', '1959-03-28', null, 'jisaksen@hotmail.com', 'aktiv', 'c80f19917b6a1f30', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c80f19917b6a1f30' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Are', 'Johansen', '1988-06-07', null, 'arejohansen@hotmail.no', 'aktiv', 'fffd3c402ad5e009', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'fffd3c402ad5e009' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Christian Kollerud', 'Johansen', '2005-05-27', null, 'horse123@online.no', 'aktiv', '40d0c25288303a85', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '40d0c25288303a85' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Daniel Leander', 'Johansen', '2009-11-04', null, 'johansen_213@hotmail.com;s.therese92@gmail.com', 'aktiv', '68328a4ad8e2c63a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '68328a4ad8e2c63a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Steve', 'Johansen', '1986-10-16', null, 'kyokushin.86.sn@gmail.com', 'aktiv', '4f408c4300f1e4c1', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '4f408c4300f1e4c1' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mikael Sjødal Jensen', 'Jordan', '1986-10-19', null, 'mikael.s.jensen@gmail.com', 'aktiv', '1b020cbc5a121318', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '1b020cbc5a121318' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Benjamin Alexander', 'Jørgensen', '2006-04-25', null, 'benjalexx1@gmail.com;haheltne40@gmail.com', 'aktiv', 'b94b7dbfced16999', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b94b7dbfced16999' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Steve Alex', 'Jørgensen-Romanakis', '1971-05-19', null, 'steve.jo@online.no', 'aktiv', '0c8bfdc2f047169a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0c8bfdc2f047169a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aleyna Gülsüm', 'Karagøz', '2005-05-04', null, 'emine_aleyna42@hotmail.com', 'aktiv', 'aaa51b93531bdde0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'aaa51b93531bdde0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Rida Tabassum', 'Khatana', '2009-09-14', null, 'ridakhatana1409@gmail.com;umer-khatana@hotmail.com', 'aktiv', 'afdb7c6e25de0855', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'afdb7c6e25de0855' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Max Kongsness', 'Knudsen', '2016-01-27', null, 'niclas_knudsen@hotmail.com', 'aktiv', '8299de1e9ffbca93', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8299de1e9ffbca93' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mia Kongsness', 'Knudsen', '2013-04-03', null, 'mon_jensen@hotmail.com', 'aktiv', '5a9ad552234643d2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5a9ad552234643d2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Monica Kongsness', 'Knudsen', '1987-06-15', null, 'mon_jensen@hotmail.com', 'aktiv', 'c839690cd8cd3176', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c839690cd8cd3176' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Nicklas Kongsness', 'Knudsen', '1988-03-10', null, 'nicklas.knudsen@nordicwaterproofing.com;nicklas.knudsen@grundig.com;nicklas_knudsen@hotmail.com', 'aktiv', 'dd572ff5b2546ee1', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'dd572ff5b2546ee1' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Linda Gustavsen', 'Kristensen', '1988-11-25', null, 'lindakristensen88@gmail.com', 'aktiv', '3d1b700a738f6ea6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3d1b700a738f6ea6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Linda', 'Kristiansen', '1984-08-22', null, 'lk@asent.no', 'aktiv', 'bd0bed3b7b3c5ccb', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bd0bed3b7b3c5ccb' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Truls Waaler', 'Kristiansen', '1988-06-07', null, 'truls.w.k@gmail.com', 'aktiv', 'eb26344cab6eaf21', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'eb26344cab6eaf21' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tefik', 'Kuyu', '2005-07-26', null, null, 'aktiv', '90b458aeae3efb20', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '90b458aeae3efb20' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Carlos', 'Leonardo', '1987-08-15', null, 'carlos@kampsportlaget.com', 'aktiv', '54ac214e2ef0cb95', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '54ac214e2ef0cb95' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Damien Alexander Slatter', 'Linussen', '2010-10-25', null, 'michslatter@yahoo.no', 'aktiv', 'a28be14fa5cef787', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a28be14fa5cef787' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Abas Ali Raphael Malik', 'Lunde', '1999-02-09', null, 'bassomalik@gmail.com', 'aktiv', '26f563231b372402', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '26f563231b372402' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Eva Yasmine Noor', 'Lunde', '1997-03-01', null, 'yaslunde@gmail.com;yasmine@kampsportlaget.com', 'aktiv', '04d2786f6c24cd37', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '04d2786f6c24cd37' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jørgen Rudolph', 'Låker', '1971-10-10', null, 'jlaaker@hotmail.com;jorgen.laaker@gmail.com', 'aktiv', 'bf3d8bfa8f832952', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bf3d8bfa8f832952' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Émilie Truong', 'Låker', '2013-08-09', null, 'stephy.truong@gmail.com', 'aktiv', 'add1c2579d0a6894', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'add1c2579d0a6894' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ali Hamza', 'Malik', '1996-05-21', null, 'ali_hamza_malik@hotmail.com', 'aktiv', 'bc484a16118e32dc', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'bc484a16118e32dc' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ali Hassan', 'Malik', '1993-01-19', null, 'alihassan.malik@hotmail.com', 'aktiv', '6d8a2808b3ffe979', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '6d8a2808b3ffe979' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Amaan Ali', 'Malik', '2006-03-29', null, 'amaanalimalik06@gmail.com;gulshen786@hotmail.com', 'aktiv', 'db1c777c6f4b8cd0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'db1c777c6f4b8cd0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Amir', 'Malik', '2009-03-02', null, 'malikdilnawaz20@gmail.com', 'aktiv', '08e7b3115d77fc7d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '08e7b3115d77fc7d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aneesa', 'Malik', '2008-04-04', null, 'malik@myhreadvokat.no', 'aktiv', '5d29cb8a3c4528aa', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5d29cb8a3c4528aa' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Dilnawaz', 'Malik', '1975-06-18', null, 'malikdilnawaz20@gmail.com;malik@aktivadvokat.no;malik@myhreadvokat.no', 'aktiv', 'f87bac93968b8b47', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f87bac93968b8b47' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Elias', 'Malik', '2013-04-21', null, 'malikdilnawaz20@gmail.com', 'aktiv', 'eab788bf5ecea29d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'eab788bf5ecea29d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Gulshen', 'Malik', '1978-05-16', null, null, 'aktiv', 'ccbec081f39dee93', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ccbec081f39dee93' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hajra Mehrin', 'Malik', '1994-11-02', null, 'mehrinmalik@hotmail.com', 'aktiv', '57f80c24caf35514', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '57f80c24caf35514' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Saif Ali', 'Malik', '1999-06-23', null, null, 'aktiv', 'da597eb696812149', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'da597eb696812149' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Shujah Hussain', 'Malik', '1978-03-26', null, null, 'aktiv', '6b59caf66c1cc2e3', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '6b59caf66c1cc2e3' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Astrid Gudrun Andrea', 'Melø', '1972-05-18', null, 'andreameloe@yahoo.com;andrea.melo@vestrevike.no', 'aktiv', '48c7dbc335418c44', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '48c7dbc335418c44' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hector', 'Mendana Morales', '2005-08-08', null, 'morales1492@yahoo.es', 'aktiv', 'a339e963a016481a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a339e963a016481a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Marielle Møkkelgård', 'Menovi', '2011-05-03', null, 'monicamn2009@hotmail.com', 'aktiv', 'ccae4f1b2cb02bff', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ccae4f1b2cb02bff' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Lina', 'Mockute', '1980-04-30', null, null, 'aktiv', '15764fa1591adb97', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '15764fa1591adb97' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Alina Isabell Eek', 'Moen', '2011-03-17', null, 'srm@meetcon.no;veronica.x@live.no', 'aktiv', 'e5c89b7fef8f8316', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e5c89b7fef8f8316' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ali', 'Mohammad', '2005-06-30', null, null, 'aktiv', '8329d0157d4ec1d4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8329d0157d4ec1d4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Marwa', 'Mohammad', '2004-12-05', null, null, 'aktiv', '47b1e128e825951e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '47b1e128e825951e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Yusuf', 'Mohammad', '2006-10-16', null, null, 'aktiv', '7610c23f0db5e299', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7610c23f0db5e299' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Batuhan', 'Mor', '2009-03-27', null, 'batuhan1987@icloud.com;tatliperi_87@hotmail.com', 'aktiv', 'f50341463856dea8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f50341463856dea8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Bauthan', 'Mor', '2009-03-27', null, null, 'aktiv', '7cfabe33cfb7ea55', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7cfabe33cfb7ea55' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ömer', 'Mor', '1985-10-13', null, 'kucukbey64@hotmail.com', 'aktiv', 'b52baaad45d82d12', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b52baaad45d82d12' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Cicilie Skarra', 'Muggerud', '1979-05-14', null, 'cicilie_m@hotmail.com', 'aktiv', '2b8f72d7704173fb', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2b8f72d7704173fb' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ranko Sarkawt', 'Mustafa', '2009-12-22', null, 'sarkawt84@hotmail.com', 'aktiv', '7ea6609d44efb6f5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7ea6609d44efb6f5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sima Sarkawt', 'Mustafa', '2008-08-09', null, 'sarkawt84@hotmail.com', 'aktiv', 'c2c757be9c43cbb8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c2c757be9c43cbb8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'David Anwar', 'Myhre', '2000-05-06', null, 'david.myhre@me.com', 'aktiv', 'd102db0d50c24b1c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd102db0d50c24b1c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Monica', 'Møkkelgård-Nordli', '1989-03-24', null, 'monicamn2009@hotmail.com', 'aktiv', '2e6669676e602bfc', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2e6669676e602bfc' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Bent', 'Nilsen', '1979-09-02', null, 'jearytte@gmail.com', 'aktiv', '2fb97a1e3d4ae65c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2fb97a1e3d4ae65c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jannike', 'Nilsen', '1984-07-04', null, 'jannikenilsen84@gmail.com;jannikenilsen84@hotmail.com', 'aktiv', 'a4b1cf2d9e3d3218', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a4b1cf2d9e3d3218' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jessica Rytter', 'Nilsen', '2011-04-18', null, 'tonjenakkestad@gmail.com', 'aktiv', 'a9be4c0ee32692fc', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a9be4c0ee32692fc' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Liv Øydis', 'Nilsen', '1966-09-19', null, 'liv@sossecurity.no', 'aktiv', 'c80fd1c21a971232', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c80fd1c21a971232' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Glenn Tore', 'Nordmarken', '1988-11-11', null, 'glenn.t.nordmarken@gmail.com;glenn.t.hagen@gmail.com', 'aktiv', '48ee1d166bcf5bd3', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '48ee1d166bcf5bd3' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Oliver Melby', 'Nordmarken', '2009-09-30', null, 'oliver.m.nordmarken@gmail.com;glenn.t.hagen@gmail.com', 'aktiv', '2ea9b070ca205e39', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2ea9b070ca205e39' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Kenan', 'Oguz', '2011-03-05', null, 'ayseoguz@hotmail.com', 'aktiv', '4c508d93e159b354', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '4c508d93e159b354' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Charlotte', 'Olsen', '1992-04-09', null, 'charlotte0908@hotmail.com', 'aktiv', '3e85e3d97c7bcdd1', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3e85e3d97c7bcdd1' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Veronica', 'Oskasin', '1987-08-24', null, 'veronica.x@live.no', 'aktiv', '89792e848ecbd6a9', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '89792e848ecbd6a9' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Janne', 'Otterstad', '1951-09-30', null, 'otterstadjanne@gmail.com', 'aktiv', '1add4439f2e7bd5f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '1add4439f2e7bd5f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Thea Muggerud', 'Ourdahl', '2009-11-18', null, 'cicilie_m@hotmail.com', 'aktiv', '724466352a136723', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '724466352a136723' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Karolis', 'Petrikas', '2009-09-22', null, 'mockute.lina80@gmail.com', 'aktiv', 'c7b793522fb399df', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c7b793522fb399df' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Kladias', 'Petrikas', '2001-12-27', null, null, 'aktiv', '14486b7a7e6e6086', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '14486b7a7e6e6086' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Klaidas', 'Petrikas', '2001-12-27', null, null, 'aktiv', '5e8af709ae57bec0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '5e8af709ae57bec0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Trishant', 'Puvirananyam', '2005-10-16', null, null, 'aktiv', '50d710da33e3d386', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '50d710da33e3d386' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tiba', 'Puviranjan', '1981-06-08', null, null, 'aktiv', '1dd96ba88f721a7b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '1dd96ba88f721a7b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Trishant', 'Puviranjan', '2005-10-16', null, null, 'aktiv', '66ff32e06100362b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '66ff32e06100362b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Muhammad Hashim', 'Qayum', '2007-05-13', null, 'zubair.qayum@gmail.com', 'aktiv', 'ab7e9cd2472640b9', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ab7e9cd2472640b9' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ariz', 'Rasool', '2009-05-08', null, 'ariz.rasool@icloud.no;sara_hafiz@hotmail.com', 'aktiv', '3fcba5343a7485a4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3fcba5343a7485a4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohid', 'Rasool', '2006-06-25', null, 'sara_hafiz@hotmail.com', 'aktiv', 'e17c0f1db452c280', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e17c0f1db452c280' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Benjamin', 'Reiersen Hasnen', '2009-03-26', null, 'camma_16@hotmail.com', 'aktiv', 'eb4d580f0be407d4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'eb4d580f0be407d4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ida', 'Risberg', '1974-12-29', null, 'idaweum@gmail.com', 'aktiv', '7c09f9f78398f3a6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7c09f9f78398f3a6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Iselin Cassandra', 'Rislien', '2007-10-27', null, 'steve.sande.karate@gmail.com', 'aktiv', '6fd76eda3bb7fbd2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '6fd76eda3bb7fbd2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Christopher', 'Rogulj', '1976-02-01', null, 'rogulj7@hotmail.com', 'aktiv', '9da2630a261dd700', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9da2630a261dd700' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Bwar Sirwan', 'Rostam', '2000-09-09', null, 'bwar.rostam@gmail.com', 'aktiv', '63a60b869ab01f83', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '63a60b869ab01f83' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jack Thomas', 'Rytter', '2014-02-11', null, 'malin@malinhansen.no', 'aktiv', '622acb15bbb0dd11', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '622acb15bbb0dd11' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Jeanette', 'Rytter', '1984-02-25', null, 'jearytte@gmail.com', 'aktiv', '7cf8907bb9b05789', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7cf8907bb9b05789' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Leif Tony', 'Rytter', '1986-12-12', null, 'tony.rytter@gmail.com;modum.karate@gmail.com', 'aktiv', 'a5c2ca012d5d480f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a5c2ca012d5d480f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Didrik Antzée Nordås', 'Røed', '2006-08-09', null, 'didrik.a.n.roed@gmail.com', 'aktiv', 'cfe7020af2ee1bcd', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'cfe7020af2ee1bcd' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Edvard', 'Røed', '2002-03-14', null, 'edvard_roed@hotmail.com', 'aktiv', '970fa3c82069eabb', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '970fa3c82069eabb' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Halal', 'Saber', '1905-06-30', null, null, 'aktiv', '563898c51550e4b3', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '563898c51550e4b3' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Vijan', 'Saber', '1905-06-27', null, null, 'aktiv', '9e1512e1ce1cdb3e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9e1512e1ce1cdb3e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Vina', 'Saber', '1905-06-25', null, null, 'aktiv', 'a9eefbdc625698c1', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a9eefbdc625698c1' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tural', 'Sardar', '1982-04-18', null, 'sardar.tural@gmail.com', 'aktiv', 'f6ab818c9535349f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f6ab818c9535349f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ida Elisabeth Bakken', 'Schwanborg', '1991-11-11', null, 'bolstadsch@gmail.com', 'aktiv', 'ccd0f1568b9d716f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ccd0f1568b9d716f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Esma Gøzlek', 'Secici', '1994-01-29', null, 'esma_gozlek@hotmail.com', 'aktiv', 'a2a0781df564856b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a2a0781df564856b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Adrian Rytter', 'Sending', '2006-09-14', null, 'adrian.sending@gmail.com;aage.sending@gmail.com', 'aktiv', '91a863066fd882f4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '91a863066fd882f4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Erion', 'Shala', '2008-03-06', null, 'shalamergim@hotmail.com', 'aktiv', 'a5cf9a000935c7b8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a5cf9a000935c7b8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'David Robert', 'Slatter', '1986-06-17', null, 'davidslattern@gmail.com', 'aktiv', '033b85b6752e228b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '033b85b6752e228b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Elander Andersson', 'Slatter', '2015-02-03', null, 'davidslattern@gmail.com', 'aktiv', 'cd7543a1f83b9664', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'cd7543a1f83b9664' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Kim Tommy Langtvedt', 'Slatter', '1980-06-09', null, 'kim@dintrikker.no', 'aktiv', 'ddb86f992fab1776', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ddb86f992fab1776' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Lise Mari Andersson', 'Slatter', '1989-08-23', null, 'lise.mari.a@hotmail.com', 'aktiv', 'fd8ef2956592e74a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'fd8ef2956592e74a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Malin Aleksandra Strand', 'Slatter', '2007-07-08', null, 'slattermalin07@gmail.com;malinslatter07@gmail.com', 'aktiv', 'f5c6fe64b25d2f79', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f5c6fe64b25d2f79' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Michelle Therese', 'Slatter', '1990-07-26', null, 'michslatter@yahoo.no', 'aktiv', '9dadbc09e2311ef2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9dadbc09e2311ef2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Milian Andersson', 'Slatter', '2011-01-18', null, 'lise.mari.a@hotmail.com', 'aktiv', '128dd21f38f76710', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '128dd21f38f76710' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Oliver Vesetrud', 'Slatter', '2002-07-19', null, 'oliver420360@gmail.com;solstraale_05@hotmail.com', 'aktiv', '7d9fe9fd112b79fe', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '7d9fe9fd112b79fe' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'TOBIAS STRAND', 'SLATTER', '2010-09-16', null, 'kim@slatter.no', 'aktiv', '98d0c0ec0078ef7d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '98d0c0ec0078ef7d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Håkon Bjarre', 'Solbakken', '1993-06-06', null, 'cecilie.bjarre@hotmail.com', 'aktiv', '200d3d93951bafc0', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '200d3d93951bafc0' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Katharina', 'Spinner', '1971-04-12', null, 'spinnerkatharina@hotmail.com', 'aktiv', 'ca03986dfe43f88f', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ca03986dfe43f88f' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Noah Maximilian', 'Spinner', '2000-02-11', null, 'spinner.noah@gmail.com', 'aktiv', '9a5cc44d5d2e9e6b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9a5cc44d5d2e9e6b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Yannick Samuel', 'Spinner', '2002-07-06', null, 'spinnerkatharina@hotmail.com', 'aktiv', 'a09bbfec1564bffd', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a09bbfec1564bffd' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Troya Emilie Isdahl', 'Stallvik', '2005-01-10', null, 'troyaemilie@gmail.com;runarivar@gmail.com', 'aktiv', 'c2860fc5e09d1ab4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c2860fc5e09d1ab4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hedda Kristoffersen', 'Steinbakk', '2003-05-16', null, 'ladymonja@hotmail.com', 'aktiv', '2971a8e752b5f1d4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2971a8e752b5f1d4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mari', 'Stensvik', '1975-07-19', null, 'maristensvik@me.com', 'aktiv', 'c0232be0d8aca138', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'c0232be0d8aca138' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sillie Therese Johansen', 'Stordahl', '1992-12-24', null, 's.therese92@gmail.com', 'aktiv', '039182762c8e9fdd', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '039182762c8e9fdd' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Joakim Rudningen', 'Strømnes', '2002-06-07', null, 'joakimstroemnes@gmail.com;linna_r_o@hotmail.com', 'aktiv', 'ac0fe972eddd380e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ac0fe972eddd380e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Drilon', 'Sylaj', '2006-09-09', null, 'drilonthedon@gmail.com', 'aktiv', 'edef277f93ced22b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'edef277f93ced22b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Siv', 'Sørensen', '2002-04-26', null, 'espen.sorensen@plastmo.no', 'aktiv', '0eec8b10d863ee2b', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0eec8b10d863ee2b' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Dursun Mert', 'Tekin', '2009-01-31', null, 'alitekin332@hotmail.com', 'aktiv', '1dc7db41bd596531', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '1dc7db41bd596531' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Dursun Mert', 'Tekin', '2009-07-31', null, 'alitekin332@hotmail.com', 'aktiv', '40198b438a852327', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '40198b438a852327' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mie Elisabeth Schwanborg', 'Thoresen', '2010-10-29', null, 'bolstadsch@gmail.com;christian_343@hotmail.com;thoresenchristian1@gmail.com', 'aktiv', 'd8133667be6caae6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd8133667be6caae6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Elin', 'Thuen', '1980-10-07', null, 'elin.thuen@gmail.com', 'aktiv', 'eec2f80f451e9936', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'eec2f80f451e9936' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Melika Amalie', 'Thuen', '2008-12-01', null, 'elin.thuen@gmail.com', 'aktiv', 'd354e734545cee37', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd354e734545cee37' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Stephanie', 'Truong', '1977-01-17', null, 'stephy.truong@gmail.com', 'aktiv', 'd8c0da06272bda6e', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd8c0da06272bda6e' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Wiktoria Elzbieta', 'Trzpiot', '2001-10-19', null, null, 'aktiv', '9a27dd5373d43c62', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9a27dd5373d43c62' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tony Alexander', 'Tufte-Helgerud', '2008-08-02', null, 'tufte_m87@hotmail.com', 'aktiv', '9e5497170aef8423', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9e5497170aef8423' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Türkan', 'Tug', '1981-10-24', null, 'turkantug@hotmail.com', 'aktiv', 'a5309cf787891de4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a5309cf787891de4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Stian André', 'Tunstrøm', '2006-05-19', null, 'stian.tunstrom@gmail.com;kent.tunstrom@yahoo.com', 'aktiv', 'e12cd71c6c35683d', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'e12cd71c6c35683d' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Christina Sund', 'Tveiten', '1990-10-08', null, 'c.s.t@live.no', 'aktiv', '9b4fa61e5ebd2db6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9b4fa61e5ebd2db6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sude', 'Unsal', '2009-04-24', null, 'cancan_525@hotmail.com', 'aktiv', '0107e33269c367a5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0107e33269c367a5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Harni', 'Varathan', '2007-09-05', null, 'harnivarathan36@gmail.com;varathanba@gmail.com', 'aktiv', '638f725f4c9ce1c6', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '638f725f4c9ce1c6' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Nerushanth', 'Varathan', '2005-05-23', null, 'varathanba@gmail.com', 'aktiv', '9fa7ea8dccbebb48', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9fa7ea8dccbebb48' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Denis Valentin', 'Vera', '1955-06-07', null, 'denis@kyokushinkai.info', 'aktiv', 'ef609bfeaddb7827', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'ef609bfeaddb7827' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mathias Førde', 'Vogt', '2009-11-29', null, 'anita.forde@online.no;thomas.vogt@online.no', 'aktiv', 'f7eb556de0ab4940', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f7eb556de0ab4940' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Christine', 'Wermskog', '1988-11-09', null, 'christine.wermskog@gmail.com', 'aktiv', 'f62b0758b4c33ff4', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f62b0758b4c33ff4' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Robin Andreas Iddberg', 'Wessel', '2015-05-23', null, 'andreaswwessel@gmail.com;inaiddberg@gmail.com', 'aktiv', '618559c303242eb8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '618559c303242eb8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Ida', 'Weum', '1975-12-29', null, 'idaweum@gmail.com', 'aktiv', '0336bad579cd5e03', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '0336bad579cd5e03' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Elise', 'Winge', '1989-05-04', null, 'elise.green@hotmail.no', 'aktiv', '191ae4496fbc0cc8', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '191ae4496fbc0cc8' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Dilara', 'Yildirim', '1994-09-27', null, 'malikdilnawaz20@gmail.com;dilara@norwaykarate.no', 'aktiv', '2248bae8daa82768', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '2248bae8daa82768' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Arda Mehmet', 'Zeybek', '2006-04-17', null, 'ardazeybek0404@gmail.com;ozlemzeybek@live.no', 'aktiv', 'f9024e82e904068c', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'f9024e82e904068c' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Tugba', 'Zeybek', '1998-07-16', null, null, 'aktiv', '18e4575e9f0f7882', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '18e4575e9f0f7882' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Gamze', 'Özdil', '2005-06-08', null, null, 'aktiv', '41fd7abea409762a', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '41fd7abea409762a' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Albin', 'Øvre-Söderberg', '2005-05-02', null, 'ainaovre@gmail.com', 'aktiv', '203ba0674cf617c9', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '203ba0674cf617c9' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Berra Eldem', 'Øzkara', '2007-03-07', null, 'berra.oz1998@gmail.com;hasrettir79@hotmail.com', 'aktiv', '463ffefd9faff8c5', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '463ffefd9faff8c5' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Eren Berkay', 'Øzkara', '2005-11-08', null, 'erenozkara32@gmail.com', 'aktiv', 'a1280a4b42a6bdab', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a1280a4b42a6bdab' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfall)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 0, 'ikke_betalt', '2026-12-31')
    on conflict do nothing;
  end if;

  insert into import_jobs (organization_id, type, filnavn, antall_lest, antall_importert, antall_avvist, status)
  values (org, 'fiken_styreweb_bankspor', 'fiken_transactions.json + medlemmer2026.xlsx + kontoutskrifter 2020-2023', 452, 452, 0, 'fullfort');
end $$;
