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
  select org, 'BANK-2020-01', '2020-01-31', 'utgift', '[Bankspor 1292e86288a917ff] Kontoutskrift 01/2020 - netto bankbevegelse fra Dokument PKTOUTS03@533858244721799053.pdf', 940270, 7790, c.id, 2020
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
  select org, 'BANK-2020-04', '2020-04-30', 'utgift', '[Bankspor 9c41d3027c625b07] Kontoutskrift 04/2020 - netto bankbevegelse fra Dokument PKTOUTS03@565692257350498451.pdf', 985989, 7790, c.id, 2020
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
  select org, 'BANK-2020-05', '2020-05-31', 'inntekt', '[Bankspor 1ca16e25cff8839f] Kontoutskrift 05/2020 - netto bankbevegelse fra Dokument PKTOUTS03@575958712666394765.pdf', 1705240, 3900, c.id, 2020
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
  select org, 'BANK-2020-07', '2020-07-31', 'utgift', '[Bankspor 142c14960c504ded] Kontoutskrift 07/2020 - netto bankbevegelse fra Dokument PKTOUTS03@021785994090626693.pdf', 1641450, 7790, c.id, 2020
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
  select org, 'BANK-2020-08', '2020-08-31', 'utgift', '[Bankspor b3fbacfff49fa621] Kontoutskrift 08/2020 - netto bankbevegelse fra Dokument PKTOUTS03@032775231237276820.pdf', 4836000, 7790, c.id, 2020
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
  select org, 'BANK-2020-09', '2020-09-30', 'utgift', '[Bankspor e08b72c1dd8e4122] Kontoutskrift 09/2020 - netto bankbevegelse fra Dokument PKTOUTS03@043389491810922885.pdf', 1207083, 7790, c.id, 2020
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
  select org, 'BANK-2020-11', '2020-11-30', 'inntekt', '[Bankspor 16710e773d90ebe2] Kontoutskrift 11/2020 - netto bankbevegelse fra Dokument PKTOUTS03@064960942488950403.pdf', 2031900, 3900, c.id, 2020
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
  select org, 'BANK-2020-12', '2020-12-31', 'utgift', '[Bankspor 85eff49f36977cd8] Kontoutskrift 12/2020 - netto bankbevegelse fra Dokument PKTOUTS03@076200963640121238.pdf', 1680200, 7790, c.id, 2020
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
  select org, 'BANK-2021-01', '2021-01-31', 'inntekt', '[Bankspor 97847849f44b65b4] Kontoutskrift 01/2021 - netto bankbevegelse fra Dokument PKTOUTS03@086193649723352451.pdf', 163806, 3900, c.id, 2021
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
  select org, 'BANK-2021-02', '2021-02-28', 'utgift', '[Bankspor be993a1fdc59d8af] Kontoutskrift 02/2021 - netto bankbevegelse fra Dokument PKTOUTS03@996091536519205509.pdf', 302000, 7790, c.id, 2021
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
  select org, 'BANK-2021-03', '2021-03-31', 'utgift', '[Bankspor 8237c3969fd8770c] Kontoutskrift 03/2021 - netto bankbevegelse fra Dokument PKTOUTS03@107758133491203203.pdf', 1000, 7790, c.id, 2021
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
  select org, 'BANK-2021-05', '2021-05-31', 'inntekt', '[Bankspor f65d591649bed67b] Kontoutskrift 05/2021 - netto bankbevegelse fra Dokument PKTOUTS03@129385264488527687.pdf', 202715, 3900, c.id, 2021
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
  select org, 'BANK-2021-09', '2021-09-30', 'utgift', '[Bankspor a5da197ff53dba5b] Kontoutskrift 09/2021 - netto bankbevegelse fra Dokument PKTOUTS03@172522521248486912.pdf', 275579, 7790, c.id, 2021
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
  select org, 'BANK-2021-11', '2021-11-30', 'inntekt', '[Bankspor 44da16be4b557c02] Kontoutskrift 11/2021 - netto bankbevegelse fra Dokument PKTOUTS03@194124487519672843.pdf', 301146, 3900, c.id, 2021
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
  select org, 'BANK-2022-01', '2022-01-31', 'utgift', '[Bankspor ca3e97d454d50343] Kontoutskrift 01/2022 - netto bankbevegelse fra Dokument PKTOUTS03@216070060660160516.pdf', 164639, 7790, c.id, 2022
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
  select org, 'BANK-2022-02', '2022-02-28', 'utgift', '[Bankspor 325174620e0d05b1] Kontoutskrift 02/2022 - netto bankbevegelse fra Dokument PKTOUTS03@226003796183673865.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-03', '2022-03-31', 'utgift', '[Bankspor 6e7055ece1e70136] Kontoutskrift 03/2022 - netto bankbevegelse fra Dokument PKTOUTS03@236928486934611462.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-04', '2022-04-30', 'utgift', '[Bankspor 4047150f2501578a] Kontoutskrift 04/2022 - netto bankbevegelse fra Dokument PKTOUTS03@247188925148196358.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-05', '2022-05-31', 'inntekt', '[Bankspor 1b34545c0529f20e] Kontoutskrift 05/2022 - netto bankbevegelse fra Dokument PKTOUTS03@258523016499702790.pdf', 30325, 3900, c.id, 2022
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
  select org, 'BANK-2022-07', '2022-07-31', 'utgift', '[Bankspor efd62a70c6903dc2] Kontoutskrift 07/2022 - netto bankbevegelse fra Dokument PKTOUTS03@279394073048502787.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-10', '2022-10-31', 'utgift', '[Bankspor 93bcfdd582f652e5] Kontoutskrift 10/2022 - netto bankbevegelse fra Dokument PKTOUTS03@312686558481119744.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-11', '2022-11-30', 'utgift', '[Bankspor d827497baeeeb65d] Kontoutskrift 11/2022 - netto bankbevegelse fra Dokument PKTOUTS03@323301026666880519.pdf', 1000, 7790, c.id, 2022
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
  select org, 'BANK-2022-12', '2022-12-31', 'inntekt', '[Bankspor c6395eff30f98a98] Kontoutskrift 12/2022 - netto bankbevegelse fra Dokument PKTOUTS03@334403996276695044.pdf', 810300, 3900, c.id, 2022
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
  select org, 'BANK-2023-02', '2023-02-28', 'utgift', '[Bankspor bc18d9be4bb213b9] Kontoutskrift 02/2023 - netto bankbevegelse fra Dokument PKTOUTS03@355147641393966088.pdf', 1000, 7790, c.id, 2023
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
  select org, 'BANK-2023-03', '2023-03-31', 'utgift', '[Bankspor 7d5dac070f881452] Kontoutskrift 03/2023 - netto bankbevegelse fra Dokument PKTOUTS03@366101960787749894.pdf', 972100, 7790, c.id, 2023
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
  select org, 'BANK-2023-04', '2023-04-30', 'utgift', '[Bankspor f12945080b29dc76] Kontoutskrift 04/2023 - netto bankbevegelse fra Dokument PKTOUTS03@376009499320307205.pdf', 36418, 7790, c.id, 2023
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
  select org, 'BANK-2023-05', '2023-05-31', 'inntekt', '[Bankspor 45a192bd9b6453d5] Kontoutskrift 05/2023 - netto bankbevegelse fra Dokument PKTOUTS03@387699389829919236.pdf', 116120, 3900, c.id, 2023
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
  select org, 'BANK-2023-08', '2023-08-31', 'utgift', '[Bankspor 1d3f028ef44f6567] Kontoutskrift 08/2023 - netto bankbevegelse fra Dokument PKTOUTS03@420251054226293259.pdf', 8650, 7790, c.id, 2023
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
  select org, 'BANK-2023-09', '2023-09-30', 'inntekt', '[Bankspor ba8a47a44dba4411] Kontoutskrift 09/2023 - netto bankbevegelse fra Dokument PKTOUTS03@430517621201375236.pdf', 164772, 3900, c.id, 2023
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
  select org, 'BANK-2023-10', '2023-10-31', 'inntekt', '[Bankspor 13d87ea0b6c6494c] Kontoutskrift 10/2023 - netto bankbevegelse fra Dokument PKTOUTS03@441851862728451591.pdf', 16024200, 3900, c.id, 2023
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
  select org, 'BANK-2023-11', '2023-11-30', 'utgift', '[Bankspor eb466f736cb3b967] Kontoutskrift 11/2023 - netto bankbevegelse fra Dokument PKTOUTS03@452476432616461312.pdf', 1000, 7790, c.id, 2023
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
  select org, 'BANK-2023-12', '2023-12-31', 'utgift', '[Bankspor dcf795cf8a299a0a] Kontoutskrift 12/2023 - netto bankbevegelse fra Dokument PKTOUTS03@463086392740816897.pdf', 15162101, 7790, c.id, 2023
  from categories c
  where c.organization_id = org and c.navn = 'Historisk bankspor - ut' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;

  -- Fiken transaksjoner
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0001', '2024-01-08', 'inntekt', '[Fiken 849fa0fd743f926e] Fra: Norsk Tipping AS [2024-01-08]', 169724, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0002', '2024-01-19', 'utgift', '[Fiken a620e9dfc4cf812a] Til: 9365.16.14323 [2024-01-19]', 1190000, 7790, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0003', '2024-01-31', 'utgift', '[Fiken d4e3f507d9af959d] 1 Nettgiro m/meld.forfall i dag [2024-01-31]', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0004', '2024-01-31', 'utgift', '[Fiken 1f36e75df70c0e7f] 1 Månedsomk el sikkerhetskort [2024-01-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0005', '2024-02-29', 'utgift', '[Fiken d92a538f87860e59] 1 Månedsomk el sikkerhetskort [2024-02-29]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0006', '2024-03-22', 'inntekt', '[Fiken d1afbe7f2d0d4cbe] Fra: Drammen Idrettsråd [2024-03-22]', 1757400, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0007', '2024-03-25', 'utgift', '[Fiken 0e304f4a9df0fbb9] Til: 3610.84.21813 [2024-03-25]', 1760000, 7790, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0008', '2024-03-31', 'utgift', '[Fiken 6b136a472a9ac65f] 1 Nettgiro m/meld.forfall i dag [2024-03-31]', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0009', '2024-03-31', 'utgift', '[Fiken 3d1a0c1966475ce5] 1 Månedsomk el sikkerhetskort [2024-03-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0010', '2024-04-03', 'inntekt', '[Fiken f86dd135454d5625] Fra: Norges Idrettsforbund og Olympiske [2024-04-03]', 9852500, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0011', '2024-04-05', 'utgift', '[Fiken fb83570ab2c5b0f2] Til: 2480.39.16914 [2024-04-05]', 9852100, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0012', '2024-04-30', 'utgift', '[Fiken 20b157f078a1ccde] 1 Nettgiro m/meld.forfall i dag [2024-04-30]', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0013', '2024-04-30', 'utgift', '[Fiken 9f3a19985f9b4265] 1 Månedsomk el sikkerhetskort [2024-04-30]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0014', '2024-05-10', 'inntekt', '[Fiken 3a1d4ef4c6b68999] Fra: Norsk Tipping AS [2024-05-10]', 166570, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0015', '2024-05-31', 'utgift', '[Fiken ca6516409d31fbd7] 1 Månedsomk el sikkerhetskort [2024-05-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0016', '2024-06-07', 'inntekt', '[Fiken 3b65bf03d03ec0df] Fra: Drammen Idrettsråd [2024-06-07]', 4000000, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0017', '2024-06-11', 'utgift', '[Fiken 1a14426634f550d1] Til: 2480.28.69343 [2024-06-11]', 450000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0018', '2024-06-11', 'utgift', '[Fiken 7cbce975b099a425] 1 Straksbetaling 001 [2024-06-11]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0019', '2024-06-20', 'utgift', '[Fiken 44593d68cb860fb1] Til: 1720.34.40472 [2024-06-20]', 3700000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0020', '2024-06-26', 'inntekt', '[Fiken ad4731deb4c3dd61] Fra: Drammen Idrettsråd [2024-06-26]', 3225300, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0021', '2024-06-28', 'utgift', '[Fiken c575afde4d18aaff] Til: 2480.39.16914 [2024-06-28]', 3238500, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0022', '2024-06-30', 'utgift', '[Fiken 44e8996a0e99a3d2] 2 Nettgiro m/meld.forfall i dag [2024-06-30]', 700, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0023', '2024-06-30', 'utgift', '[Fiken 0c09ebe2cd348804] 1 Månedsomk el sikkerhetskort [2024-06-30]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0024', '2024-07-31', 'utgift', '[Fiken 8c062a0dfab90045] 1 Månedsomk el sikkerhetskort [2024-07-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0025', '2024-08-29', 'inntekt', '[Fiken 68d9d7bf74dd9ffd] Fra: Norsk Tipping AS [2024-08-29]', 622700, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0026', '2024-08-31', 'utgift', '[Fiken 766df13a2813a263] 1 Månedsomk el sikkerhetskort [2024-08-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0027', '2024-09-05', 'utgift', '[Fiken 35409f555c93d5d5] Til: 1720.34.40472 [2024-09-05]', 500000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0028', '2024-09-05', 'utgift', '[Fiken 4a2246af157d7224] 1 Straksbetaling 001 [2024-09-05]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0029', '2024-09-11', 'inntekt', '[Fiken a47c8bf41840c8b5] Fra: Norsk Tipping AS [2024-09-11]', 166615, 3900, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0030', '2024-09-12', 'utgift', '[Fiken b85d5ba944bbd736] Til: 1720.34.40472 [2024-09-12]', 200000, 2920, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0031', '2024-09-12', 'utgift', '[Fiken 2bf7e14429241f66] 1 Straksbetaling 001 [2024-09-12]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0032', '2024-09-23', 'inntekt', '[Fiken 827e7e6d550d9e95] Fra: Norges Idrettsforbund og Olympiske [2024-09-23]', 20922700, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0033', '2024-09-23', 'utgift', '[Fiken ce8334959171818c] Til: 2480.39.16914 [2024-09-23]', 20000000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0034', '2024-09-23', 'utgift', '[Fiken e3a6bb5f81bd8b2f] Til: Drammen kommune [2024-09-23]', 897000, 6300, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0035', '2024-09-30', 'utgift', '[Fiken c8ebefdf062ca4c0] 1 Nettgiro m/kid forfall i dag [2024-09-30]', 200, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0036', '2024-09-30', 'utgift', '[Fiken 7449e677e184edfa] 1 Nettgiro m/meld.forfall i dag [2024-09-30]', 350, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0037', '2024-09-30', 'utgift', '[Fiken c8914085107f9a81] 1 Månedsomk el sikkerhetskort [2024-09-30]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0038', '2024-10-01', 'inntekt', '[Fiken 80ceeaa4d0cabfe5] Fra: Norges Idrettsforbund og Olympiske [2024-10-01]', 8804400, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0039', '2024-10-01', 'utgift', '[Fiken bc0276585b187a00] Til: Skoger og Fjell Karateklubb [2024-10-01]', 8912200, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0040', '2024-10-31', 'utgift', '[Fiken cb26f15071600dba] 1 Månedsomk el sikkerhetskort [2024-10-31]', 1000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0041', '2024-11-18', 'utgift', '[Fiken 2d7fb1f38ff6af07] Pris Faktura Nettbedrift [2024-11-18]', 5500, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0042', '2024-12-01', 'utgift', '[Fiken 633fb9322514934d] Debetrenter U/Dekning [2024-12-01]', 200, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0043', '2024-12-20', 'inntekt', '[Fiken 1265e3926ba6dbe9] Fra: Norges Idrettsforbund og Olympiske [2024-12-20]', 931200, 3440, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0044', '2024-12-23', 'utgift', '[Fiken 14536a7dd9c29704] Pris Faktura Nettbedrift [2024-12-23]', 5000, 7770, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2024-0045', '2024-12-30', 'utgift', '[Fiken a0944180a3c7ac74] Til: Skoger og Fjell Karateklubb [2024-12-30]', 900000, 1921, c.id, 2024
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0046', '2025-01-07', 'inntekt', '[Fiken 87bad0168e916ff8] Fra: Norsk Tipping AS [2025-01-07]', 171815, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0047', '2025-01-14', 'utgift', '[Fiken e485c5b83f368ea6] Bedrterm oppgave Til: 2480.10.35511 [2025-01-14]', 190000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0048', '2025-01-20', 'utgift', '[Fiken 1aadab499513d1aa] Pris Faktura Nettbedrift [2025-01-20]', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0049', '2025-02-17', 'utgift', '[Fiken 2743ed6224f4bfa6] Pris Faktura Nettbedrift [2025-02-17]', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0050', '2025-02-20', 'inntekt', '[Fiken 2072d1678c21b777] Fra: Norsk Tipping AS [2025-02-20]', 520800, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0051', '2025-02-21', 'utgift', '[Fiken 7350b4371a2de943] Bedrterm oppgave Til: 1720.34.40472 [2025-02-21]', 500000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0052', '2025-03-17', 'utgift', '[Fiken feb8cddee099dde2] Pris Faktura Nettbedrift [2025-03-17]', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0053', '2025-04-01', 'inntekt', '[Fiken 345625c334c717d5] Fra: Norges Idrettsforbund og Olympiske [2025-04-01]', 6624300, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0054', '2025-04-02', 'inntekt', '[Fiken 875ea9c62a18ed6e] Fra: Kron & Mynt AS [2025-04-02]', 3080640, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0055', '2025-04-07', 'utgift', '[Fiken 73c1b70ce3b258b3] Til: American Express Europe Sa [2025-04-07]', 945000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0056', '2025-04-11', 'utgift', '[Fiken 6ff895aaf105e506] Bedrterm oppgave Til: Intrum AS [2025-04-11]', 1867245, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0057', '2025-04-11', 'utgift', '[Fiken 393064daa3b9fa60] Bedrterm oppgave Til: Aksjefabrikken AS [2025-04-11]', 1145000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0058', '2025-04-22', 'utgift', '[Fiken f891a0d385bc02d0] Pris Faktura Nettbedrift [2025-04-22]', 5000, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0059', '2025-04-24', 'inntekt', '[Fiken f34fc9a908b0668c] Fra: Drammen Idrettsråd [2025-04-24]', 5000000, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0060', '2025-04-25', 'utgift', '[Fiken 04dc108778f5412b] Bedrterm oppgave Til: 1720.34.40472 [2025-04-25]', 700000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0061', '2025-05-02', 'utgift', '[Fiken 320aa0463ba6a8f5] Bedrterm oppgave Til: Hizzar [2025-05-02]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0062', '2025-05-02', 'utgift', '[Fiken 28c2a63d092a26c9] Bedrterm oppgave Til: Aman [2025-05-02]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0063', '2025-05-05', 'utgift', '[Fiken 74fd3f5e08e43686] Bedrterm oppgave Til: 1720.34.40472 [2025-05-05]', 600000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0064', '2025-05-06', 'utgift', '[Fiken 681782262724ca29] Bedrterm oppgave Til: Solidus AS [2025-05-06]', 160300, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0065', '2025-05-09', 'utgift', '[Fiken 4be6792e59b448f3] Bedrterm oppgave Til: 0539.32.04194 [2025-05-09]', 2000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0066', '2025-05-16', 'utgift', '[Fiken 106f90504fbb3d08] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-05-16]', 987250, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0067', '2025-05-19', 'utgift', '[Fiken f0c18001f0fbdd20] Pris Faktura Nettbedrift [2025-05-19]', 6025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0068', '2025-05-20', 'utgift', '[Fiken 99fd85922ca44500] Bedrterm oppgave Til: 1720.34.40472 [2025-05-20]', 3000000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0069', '2025-05-20', 'utgift', '[Fiken c090c8ae5a7fd5d7] Bedrterm oppgave Til: Drammen kommune [2025-05-20]', 567190, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0070', '2025-06-03', 'utgift', '[Fiken 01967399157a735d] Bedrterm oppgave Til: 1720.34.40472 [2025-06-03]', 400000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0071', '2025-06-05', 'utgift', '[Fiken 7ccbbac11293a597] Bedrterm oppgave Til: 1720.34.40472 [2025-06-05]', 1950000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0072', '2025-06-21', 'utgift', '[Fiken 655b172015dbe3f9] Pris Faktura Nettbedrift [2025-06-21]', 8025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0073', '2025-07-08', 'inntekt', '[Fiken fc955da664d9f64b] Fra: Kron & Mynt AS [2025-07-08]', 3082044, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0074', '2025-07-10', 'utgift', '[Fiken 7d4c77f6df6c879b] Til: Skoger og Fjell Karateklubb [2025-07-10]', 3100000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0075', '2025-07-19', 'utgift', '[Fiken 1155d0352569191b] Pris Faktura Nettbedrift [2025-07-19]', 6000, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0076', '2025-08-16', 'utgift', '[Fiken a19937d46e806409] Pris Faktura Nettbedrift [2025-08-16]', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0077', '2025-08-22', 'inntekt', '[Fiken 9e476ccbd8613276] Fra: Norsk Tipping AS [2025-08-22]', 699500, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0078', '2025-08-25', 'inntekt', '[Fiken faf8963a6803603d] Overførsel [2025-08-25]', 299854, 3200, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Medlemskontingent' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0079', '2025-08-26', 'utgift', '[Fiken 72985d10af4874e8] Bedrterm oppgave Til: 1503.84.72485 [2025-08-26]', 150000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0080', '2025-08-26', 'inntekt', '[Fiken 6497fb33ea5f9bf8] Innskudd Fr 25 Aug 31,99+112,25 [2025-08-26]', 14424, 3200, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Medlemskontingent' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0081', '2025-09-04', 'utgift', '[Fiken 8debaf70d5254438] Bedrterm oppgave Til: 1720.34.40472 [2025-09-04]', 650000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0082', '2025-09-08', 'inntekt', '[Fiken ee11a7518c77129a] Fra: Norsk Tipping AS [2025-09-08]', 107215, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0083', '2025-09-12', 'inntekt', '[Fiken 625d0f2a76b3976a] Fra: Norges Idrettsforbund og Olympiske [2025-09-12]', 21690300, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0084', '2025-09-15', 'utgift', '[Fiken 9b111599dc1e37b6] Bedrterm oppgave Til: Axactor Norway AS [2025-09-15]', 4033715, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0085', '2025-09-15', 'utgift', '[Fiken 8515e4ecce7fa995] Bedrterm oppgave Til: Drammen kommune [2025-09-15]', 2500000, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0086', '2025-09-15', 'utgift', '[Fiken e5df100f48874e86] Bedrterm oppgave Til: Drammen kommune [2025-09-15]', 1349796, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0087', '2025-09-15', 'utgift', '[Fiken ef3e19980709b8fc] Bedrterm oppgave Til: Drammen kommune [2025-09-15]', 1214633, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0088', '2025-09-15', 'utgift', '[Fiken 6b9e001f599d5f4a] Bedrterm oppgave Til: Drammen kommune [2025-09-15]', 446575, 6300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Hall-leie' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0089', '2025-09-17', 'utgift', '[Fiken 7dbf0d8ba60dadb3] Bedrterm oppgave Til: Domeneshop AS [2025-09-17]', 154400, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0090', '2025-09-17', 'utgift', '[Fiken 3fcad39ca42b8699] Bedrterm oppgave Til: Domeneshop AS [2025-09-17]', 102700, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0091', '2025-09-18', 'utgift', '[Fiken f8f457b0fb9748b8] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-09-18]', 802950, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0092', '2025-09-18', 'utgift', '[Fiken b1ada81acb9b63c9] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-09-18]', 180450, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0093', '2025-09-19', 'utgift', '[Fiken 994c2afa3b6aef30] Bedrterm oppgave Til: Karate Combat Norge [2025-09-19]', 1200000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0094', '2025-09-20', 'utgift', '[Fiken efdaef9f5023d17b] Pris Faktura Nettbedrift [2025-09-20]', 5500, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0095', '2025-09-22', 'utgift', '[Fiken 147a01b8d10f7eee] Bedrterm oppgave Til: Aneesa Malik [2025-09-22]', 240000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0096', '2025-09-23', 'inntekt', '[Fiken 8c76d45a163adae8] Fra: Drammen Idrettsråd [2025-09-23]', 5000000, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0097', '2025-09-23', 'inntekt', '[Fiken b203320abc971381] Fra: Drammen Idrettsråd [2025-09-23]', 6037100, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0098', '2025-09-23', 'utgift', '[Fiken e201167223cb1190] Bedrterm oppgave Til: Nesrin [2025-09-23]', 1500000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0099', '2025-09-23', 'utgift', '[Fiken 406005736801d1bc] Bedrterm oppgave Til: Fremtind Forsikring AS [2025-09-23]', 212000, 7500, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Forsikring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0100', '2025-09-23', 'utgift', '[Fiken 1c79af4c09227378] Bedrterm oppgave Til: 2480.10.35511 [2025-09-23]', 86800, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0101', '2025-09-25', 'utgift', '[Fiken afc414580b1f35de] Bedrterm oppgave Til: Norges Kampsportforbund [2025-09-25]', 4000000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0102', '2025-09-25', 'utgift', '[Fiken 001a01bf7d3665f1] Bedrterm oppgave Til: 1720.34.40472 [2025-09-25]', 1700000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0103', '2025-09-25', 'utgift', '[Fiken ac5b7f97418aeb72] Bedrterm oppgave Til: Tf Bank Norge NUF [2025-09-25]', 1000000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0104', '2025-09-25', 'utgift', '[Fiken a1f8b8ef17b1146c] Bedrterm oppgave Til: Fair Collection AS [2025-09-25]', 518270, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0105', '2025-09-25', 'utgift', '[Fiken 8989be50eb9bcad4] Bedrterm oppgave Til: Eurocard [2025-09-25]', 500000, 7140, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Dommer og stevneavgift' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0106', '2025-09-29', 'utgift', '[Fiken 4d69872764daa5c4] Bedrterm oppgave Til: Hizzar [2025-09-29]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0107', '2025-09-29', 'utgift', '[Fiken 4ee42de304762a6e] Bedrterm oppgave Til: Aneesa Malik [2025-09-29]', 120000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0108', '2025-09-30', 'utgift', '[Fiken 4e2bde7a5c1b01af] Bedrterm oppgave Til: Karate Combat Norge [2025-09-30]', 1463000, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0109', '2025-10-03', 'utgift', '[Fiken 4cd6847f151c689b] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-10-03]', 1704800, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0110', '2025-10-06', 'inntekt', '[Fiken be91e69d680f4140] Fra: Kron & Mynt AS [2025-10-06]', 2149118, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0111', '2025-10-08', 'utgift', '[Fiken 224870a07029c9af] Bedrterm oppgave Til: 2220.41.33968 [2025-10-08]', 240000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0112', '2025-10-08', 'utgift', '[Fiken 64870aa5bf2bb0a2] Bedrterm oppgave Til: Aman [2025-10-08]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0113', '2025-10-15', 'utgift', '[Fiken 74f4b6e354e74b10] Bedrterm oppgave Til: Amir Ali [2025-10-15]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0114', '2025-10-16', 'utgift', '[Fiken ee271648c550c188] Bedrterm oppgave Til: If Skadeforsikring NUF [2025-10-16]', 377000, 7500, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Forsikring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0115', '2025-10-16', 'utgift', '[Fiken cc6a97b9f81e4b7f] Bedrterm oppgave Til: Aneesa Malik [2025-10-16]', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0116', '2025-10-20', 'utgift', '[Fiken ebe01726cd4f93ff] Til: Riverty Services Norway AS [2025-10-20]', 373831, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0117', '2025-10-20', 'utgift', '[Fiken 9fddc6787dcb9ac9] Pris Faktura Nettbedrift [2025-10-20]', 12275, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0118', '2025-10-23', 'inntekt', '[Fiken 2a3346bbd9bf9e29] Fra: Fair Collection AS [2025-10-23]', 100, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0119', '2025-10-23', 'inntekt', '[Fiken afa5f113af11ddd7] Fra: Nedre Buskerud Boligbyggelag [2025-10-23]', 750000, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0120', '2025-10-24', 'utgift', '[Fiken 350b91d647378d55] Bedrterm oppgave Til: 1204.62.69215 [2025-10-24]', 4000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0121', '2025-10-24', 'utgift', '[Fiken 0ffb095b17c93be9] Bedrterm oppgave Til: 1720.34.40472 [2025-10-24]', 800000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0122', '2025-10-29', 'utgift', '[Fiken 4dc3476f4ffd29c7] Bedrterm oppgave Til: Aneesa Malik [2025-10-29]', 240000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0123', '2025-10-29', 'utgift', '[Fiken 046a92b76a394b34] Bedrterm oppgave Til: Amir Ali [2025-10-29]', 200000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0124', '2025-10-29', 'utgift', '[Fiken 17f0f40b560b7d73] Bedrterm oppgave Til: Hizzar [2025-10-29]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0125', '2025-10-29', 'utgift', '[Fiken 25c4bf06e2e3eced] Bedrterm oppgave Til: Aneesa Malik [2025-10-29]', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0126', '2025-10-31', 'utgift', '[Fiken ebd51f9ccc6185d7] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-10-31]', 797100, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0127', '2025-10-31', 'utgift', '[Fiken eb3deccfba01c3b1] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-10-31]', 481800, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0128', '2025-10-31', 'utgift', '[Fiken 167ddd2b24d84b59] Bedrterm oppgave Til: 1720.34.40472 [2025-10-31]', 400000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0129', '2025-10-31', 'utgift', '[Fiken 6af4b7f46d6cd731] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-10-31]', 293650, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0130', '2025-10-31', 'utgift', '[Fiken 5e7704351783a2f9] Bedrterm oppgave Til: Aman [2025-10-31]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0131', '2025-11-06', 'utgift', '[Fiken 4e90262cbb6c1f67] Bedrterm oppgave Til: 2480.25.22718 [2025-11-06]', 160000, 1921, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Overføring internkonto' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0132', '2025-11-11', 'inntekt', '[Fiken 34c016c24fc02ed7] Fra: Norges Idrettsforbund og Olympiske [2025-11-11]', 15654800, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0133', '2025-11-12', 'utgift', '[Fiken 67f7a9acc37dbbc6] Bedrterm oppgave Til: Norges Kampsportforbund [2025-11-12]', 1972600, 7490, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Kontingent til forbund' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0134', '2025-11-12', 'utgift', '[Fiken 8b8128f6ba127d99] Bedrterm oppgave Til: Aneesa Malik [2025-11-12]', 60000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0135', '2025-11-14', 'utgift', '[Fiken a0b11c37540ea8c7] Bedrterm oppgave Til: 4111.15.93777 [2025-11-14]', 2250000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0136', '2025-11-15', 'utgift', '[Fiken e4261f580ee2c10b] Pris Faktura Nettbedrift [2025-11-15]', 11025, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0137', '2025-11-17', 'utgift', '[Fiken f9460edcdeeab85a] Bedrterm oppgave Til: Truls [2025-11-17]', 180000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0138', '2025-11-20', 'utgift', '[Fiken d6a2ad852205ad19] Bedrterm oppgave Til: 1204.62.69215 [2025-11-20]', 1000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0139', '2025-11-21', 'utgift', '[Fiken c241ee452310564d] Muhamamd Naeem Iqbal Eur 794,10 [2025-11-21]', 940794, 4300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Varekostnad' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0140', '2025-11-21', 'utgift', '[Fiken aeed2bfb3b66887f] 7990noo07869191 3162956151 [2025-11-21]', 8000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0141', '2025-11-28', 'utgift', '[Fiken dd34866808314ae1] Bedrterm oppgave Til: 2220.35.54846 [2025-11-28]', 2000000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0142', '2025-11-28', 'utgift', '[Fiken 293f07e793954d12] Bedrterm oppgave Til: Amir Ali [2025-11-28]', 300000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0143', '2025-11-28', 'utgift', '[Fiken a12597508df9dbf9] Bedrterm oppgave Til: Aneesa Malik [2025-11-28]', 300000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0144', '2025-11-28', 'utgift', '[Fiken fac6ac05796b5e60] Bedrterm oppgave Til: Aman [2025-11-28]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0145', '2025-11-28', 'utgift', '[Fiken ecfa840ff52caed6] Bedrterm oppgave Til: Hizzar [2025-11-28]', 160000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0146', '2025-11-28', 'utgift', '[Fiken 456e4685924670a3] Bedrterm oppgave Til: Domeneshop AS [2025-11-28]', 54600, 6810, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Nettside og programvare' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0147', '2025-12-01', 'inntekt', '[Fiken 8d56dba38d90e7df] Kreditrenter [2025-12-01]', 800, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0148', '2025-12-01', 'utgift', '[Fiken 72cb66b2b18ab923] Debetrenter U/Dekning [2025-12-01]', 100, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0149', '2025-12-02', 'utgift', '[Fiken 77bc41ab6979855a] Bedrterm oppgave Til: Taki [2025-12-02]', 654700, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0150', '2025-12-02', 'inntekt', '[Fiken c1db869c5e553876] Valuta Retur Valuta [2025-12-02]', 788276, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0151', '2025-12-03', 'inntekt', '[Fiken 3c299977f9901462] Fra: Kron & Mynt AS [2025-12-03]', 1119996, 3900, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre inntekter' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0152', '2025-12-04', 'utgift', '[Fiken e4942655beb82e24] Muhammad Saleem Gbp 562,00 [2025-12-04]', 758380, 4300, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Varekostnad' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0153', '2025-12-04', 'utgift', '[Fiken 3a26e203bfc391f9] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-12-04]', 427900, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0154', '2025-12-04', 'utgift', '[Fiken 4567483ece9fe848] Bedrterm oppgave Til: Yngvar Åge Nilsen [2025-12-04]', 188850, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0155', '2025-12-04', 'utgift', '[Fiken 21806959c93d5b87] 7990noo07888028 3193615270 [2025-12-04]', 8000, 7790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Andre utgifter' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0156', '2025-12-05', 'utgift', '[Fiken 066c46f8ccb0fd4e] Bedrterm oppgave Til: Amir Ali [2025-12-05]', 180000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0157', '2025-12-10', 'utgift', '[Fiken 77e0ec71f90908bd] Bedrterm oppgave Til: Monica [2025-12-10]', 500000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0158', '2025-12-12', 'utgift', '[Fiken 344c0b54ed9ac0ac] Bedrterm oppgave Til: 1720.34.40472 [2025-12-12]', 2150000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0159', '2025-12-16', 'utgift', '[Fiken 0432225f0e3d80bb] Bedrterm oppgave Til: 1720.34.40472 [2025-12-16]', 2260000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0160', '2025-12-18', 'utgift', '[Fiken a014d587c8800b3c] Bedrterm oppgave Til: Reprofil AS [2025-12-18]', 743000, 7320, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Markedsføring' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0161', '2025-12-18', 'utgift', '[Fiken a5de365f952dc63b] Bedrterm oppgave Til: Amir Ali [2025-12-18]', 220000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0162', '2025-12-20', 'utgift', '[Fiken 30500819eedd8699] Pris Faktura Nettbedrift [2025-12-20]', 10675, 7770, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Bankgebyr' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0163', '2025-12-22', 'inntekt', '[Fiken afbf5773a45b9bac] Fra: Norges Idrettsforbund og Olympiske [2025-12-22]', 2156400, 3440, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Offentlig tilskudd' and c.retning = 'inntekt'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0164', '2025-12-23', 'utgift', '[Fiken 36e882aff81a9488] Bedrterm oppgave Til: Hizzar [2025-12-23]', 165000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0165', '2025-12-23', 'utgift', '[Fiken c1e54ec84aedaf74] Bedrterm oppgave Til: Aneesa Malik [2025-12-23]', 140000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0166', '2025-12-30', 'utgift', '[Fiken 67c7dad18d418023] Bedrterm oppgave Til: 1720.34.40472 [2025-12-30]', 410000, 2920, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Mellomregning' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;
  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, konto_nummer, category_id, regnskapsaar)
  select org, 'FIKEN-2025-0167', '2025-12-30', 'utgift', '[Fiken 349ab987fa7ad88c] Bedrterm oppgave Til: Aman [2025-12-30]', 140000, 6790, c.id, 2025
  from categories c
  where c.organization_id = org and c.navn = 'Honorar og tjenester' and c.retning = 'utgift'
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato, type = excluded.type, beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore, konto_nummer = excluded.konto_nummer,
    category_id = excluded.category_id, regnskapsaar = excluded.regnskapsaar;

  -- Styreweb medlemmer og kontingentstatus
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Margareth', 'Abdusalam Ahmadi', '2006-05-14', 'mann', 'ahmadi_007@hotmail.com', 'aktiv', '3a69165ae62943e2', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3a69165ae62943e2' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aziz Aron', 'Ahmad', '2007-05-22', 'mann', 'aron.ahmad0123@gmail.com', 'aktiv', 'b6e977f70d6c9818', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'b6e977f70d6c9818' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Gabriel Amin', 'Ahmad', '2011-11-06', 'mann', 'lmhavet@live.no', 'aktiv', '3f1f12ada0654620', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3f1f12ada0654620' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Sophia', 'Ahmad', '2006-07-28', 'kvinne', 'lmhavet@live.no', 'aktiv', '3f1f12ada0654620', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '3f1f12ada0654620' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mohammed', 'Ahmed', '2008-11-17', 'mann', 'shahzad_ansir@live.no', 'aktiv', '769d4382ead7f094', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '769d4382ead7f094' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Rahat', 'Alizai', '2006-02-07', 'kvinne', 'bashar25@hotmail.com', 'aktiv', '8b4394e93c655027', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '8b4394e93c655027' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Alexandra Valentin', 'Danielsen', '2009-11-01', 'kvinne', 'danielsenalexandra@gmail.com', 'aktiv', '41d8c52cb00a9e23', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '41d8c52cb00a9e23' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Aurora Torsrud', 'Eriksen', '2009-06-21', 'kvinne', 'annemay.eriksen74@gmail.com', 'aktiv', '48c15ebb1a9d6802', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '48c15ebb1a9d6802' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Batin', 'Gökgül', '2005-06-02', null, 'medlem@kampsportlaget.com', 'aktiv', '9a73ceb08ec60779', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '9a73ceb08ec60779' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Hesja Fuad', 'Hamawand', '2002-02-03', null, 'hesja2002@hotmail.com', 'aktiv', '05fbd1f8cfa47457', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = '05fbd1f8cfa47457' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Mustafa S', 'Hashemi', '2009-11-22', 'mann', 'sayidmurtaza@hotmail.com', 'aktiv', 'a7f16af20c4aa1cf', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'a7f16af20c4aa1cf' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;
  insert into members (organization_id, fornavn, etternavn, fodselsdato, kjonn, epost, status, ekstern_id, ekstern_kilde)
  values (org, 'Amaan Ali', 'Malik', '2006-03-29', 'mann', 'amaanalimalik06@gmail.com;gulshen786@hotmail.com', 'aktiv', 'd0db212c190573db', 'styreweb')
  on conflict do nothing
  returning id into member_id;
  if member_id is null then
    select id into member_id from members where organization_id = org and ekstern_kilde = 'styreweb' and ekstern_id = 'd0db212c190573db' limit 1;
  end if;
  if member_id is not null then
    insert into payment_claims (organization_id, member_id, fee_id, beskrivelse, belop_ore, betalt_ore, status, forfallsdato)
    values (org, member_id, fee, 'Medlemskontingent 2026', 45000, 45000, 'betalt', '2026-12-31')
    on conflict do nothing;
  end if;

  insert into import_jobs (organization_id, type, filnavn, antall_lest, antall_importert, antall_avvist, status)
  values (org, 'fiken_styreweb_bankspor', 'fiken_transactions.json + medlemmer2026.xlsx + kontoutskrifter 2020-2023', 211, 211, 0, 'fullfort');
end $$;
