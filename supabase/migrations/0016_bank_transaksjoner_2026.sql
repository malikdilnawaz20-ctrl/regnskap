-- Banktransaksjoner for Skoger og Fjell kampsportklubb, 2026
-- Kilde: Transaksjoner_2026-09-16-2.xlsx (01.01–31.07) og Transaksjoner_2026-09-16.xlsx (01.08–16.09).
-- Idempotent: samme bilagsnummer oppdateres ved ny kjøring.

do $$
declare
  org uuid;
  account_id uuid;
begin
  select id into org from organizations where orgnr = '912484335' limit 1;
  if org is null then return; end if;

  select id into account_id
    from accounts
   where organization_id = org
     and (kontonummer = '2220.29.21373' or navn ilike '%2220.29.21373%')
   order by (kontonummer = '2220.29.21373') desc, opprettet
   limit 1;

  if account_id is null then
    insert into accounts (organization_id, navn, kontonummer, type, aapningssaldo_ore)
    values (org, 'Driftskonto', '2220.29.21373', 'bank', 3003137)
    returning id into account_id;
  else
    update accounts
       set navn = 'Driftskonto', kontonummer = '2220.29.21373', type = 'bank',
           aapningssaldo_ore = 3003137, aktiv = true
     where id = account_id;
  end if;

  insert into transactions
    (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore, motpart, account_id, regnskapsaar)
  values
    (org, 'BANK-2026-28303261800', '2026-01-13', 'utgift', 'Nesrin (22201122035)', 350000, 'Nesrin'::text, account_id, 2026),
    (org, 'BANK-2026-75697811715', '2026-01-13', 'inntekt', 'NORSK TIPPING AS', 99896, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-28989892200', '2026-01-16', 'utgift', 'AXACTOR NORWAY AS (22000757105)', 1858367, 'AXACTOR NORWAY AS'::text, account_id, 2026),
    (org, 'BANK-2026-26076089200', '2026-01-19', 'utgift', 'Omkostninger', 11025, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-30163627500', '2026-01-21', 'utgift', 'Amir Ali (24802869378)', 220000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-20260122-01', '2026-01-22', 'inntekt', 'Skoger & Fjell Karate Klubb', 662910, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-79211780001', '2026-01-22', 'inntekt', 'NORGES IDRETTSFORBUND OG OLYMP', 194200, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-31817947900', '2026-01-31', 'utgift', 'Aman (60324214642)', 160000, 'Aman'::text, account_id, 2026),
    (org, 'BANK-2026-31818875100', '2026-01-31', 'utgift', 'Hizzar (12149077772)', 160000, 'Hizzar'::text, account_id, 2026),
    (org, 'BANK-2026-31818959900', '2026-01-31', 'utgift', 'Monica (22601600580)', 160000, 'Monica'::text, account_id, 2026),
    (org, 'BANK-2026-31819010300', '2026-01-31', 'utgift', 'Amir Ali (24802869378)', 180000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-32416886300', '2026-02-02', 'utgift', 'Truls (22204133968)', 160000, 'Truls'::text, account_id, 2026),
    (org, 'BANK-2026-62686260282', '2026-02-04', 'inntekt', 'NORSK TIPPING AS', 705161, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-35918579900', '2026-02-18', 'utgift', 'Til konto: 1720 34 40472', 500000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-36317130200', '2026-02-20', 'utgift', 'Til konto: 1720 34 40472', 470000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-33490679700', '2026-02-23', 'utgift', 'Omkostninger', 9025, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-38565278100', '2026-03-03', 'utgift', 'Hizzar (12149077772)', 160000, 'Hizzar'::text, account_id, 2026),
    (org, 'BANK-2026-38565335500', '2026-03-03', 'utgift', 'Amir Ali (24802869378)', 180000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-39587362100', '2026-03-23', 'utgift', 'Omkostninger', 6500, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-67787420001', '2026-03-30', 'inntekt', 'NORGES IDRETTSFORBUND OG OLYMP', 9445600, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-44767540500', '2026-03-31', 'utgift', 'Drammen kommune (32073011301)', 3000000, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-44985354800', '2026-04-01', 'utgift', 'Amir Ali (24802869378)', 240000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-44985692700', '2026-04-01', 'utgift', 'Elias (24802869394)', 88000, 'Elias'::text, account_id, 2026),
    (org, 'BANK-2026-45947147200', '2026-04-07', 'utgift', 'Til konto: 1720 34 40472', 1000000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-00000000617', '2026-04-08', 'inntekt', 'KRON & MYNT AS', 1520393, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-46652088000', '2026-04-09', 'utgift', 'Til konto: 1720 34 40472', 1500000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-00265447085', '2026-04-16', 'inntekt', 'Drammen Idrettsråd', 8200000, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-45557619700', '2026-04-20', 'utgift', 'Omkostninger', 9340, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-49248301800', '2026-04-20', 'utgift', 'Amir Ali (24802869378)', 400000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-49248358800', '2026-04-20', 'utgift', 'Elias (24802869394)', 88000, 'Elias'::text, account_id, 2026),
    (org, 'BANK-2026-49248430500', '2026-04-20', 'utgift', 'Hizzar (12149077772)', 160000, 'Hizzar'::text, account_id, 2026),
    (org, 'BANK-2026-49248776800', '2026-04-20', 'utgift', 'Subhan (12246573857)', 88000, 'Subhan'::text, account_id, 2026),
    (org, 'BANK-2026-49461530200', '2026-04-21', 'utgift', 'Til konto: 8317 46 18588', 1000000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-50184418700', '2026-04-24', 'utgift', 'Til konto: 1720 34 40472', 650000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-50730996800', '2026-04-27', 'utgift', 'Drammen kommune (32073011301)', 380436, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-50731249700', '2026-04-27', 'utgift', 'Drammen kommune (32073011301)', 520973, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-51029608600', '2026-04-28', 'utgift', 'Yngvar Åge Nilsen (31442012515)', 357400, 'Yngvar Åge Nilsen'::text, account_id, 2026),
    (org, 'BANK-2026-51150372500', '2026-04-29', 'utgift', 'Til konto: 1720 34 40472', 2700000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-51470301000', '2026-04-30', 'utgift', 'GJENSIDIGE FORSIKRING ASA (60050608460)', 1393200, 'GJENSIDIGE FORSIKRING ASA'::text, account_id, 2026),
    (org, 'BANK-2026-82201841694', '2026-05-08', 'inntekt', 'NORSK TIPPING AS', 92359, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-53961667500', '2026-05-11', 'utgift', 'Truls (22204133968)', 200000, 'Truls'::text, account_id, 2026),
    (org, 'BANK-2026-53962974900', '2026-05-11', 'utgift', 'Monica (22601600580)', 120000, 'Monica'::text, account_id, 2026),
    (org, 'BANK-2026-54237708400', '2026-05-12', 'utgift', 'Fujimae (49101753823)', 552700, 'Fujimae'::text, account_id, 2026),
    (org, 'BANK-2026-55077801400', '2026-05-15', 'utgift', 'Til konto: 1720 34 40472', 1100000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-51818787300', '2026-05-18', 'utgift', 'Omkostninger', 14310, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-56647608300', '2026-05-22', 'utgift', 'Yngvar Åge Nilsen (31442012515)', 1192200, 'Yngvar Åge Nilsen'::text, account_id, 2026),
    (org, 'BANK-2026-56725796900', '2026-05-22', 'utgift', 'Saga Energi AS (60750633512)', 1026703, 'Saga Energi AS'::text, account_id, 2026),
    (org, 'BANK-2026-57512791400', '2026-05-27', 'utgift', 'Amir Ali (24802869378)', 440000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-57512893700', '2026-05-27', 'utgift', 'Elias (24802869394)', 95000, 'Elias'::text, account_id, 2026),
    (org, 'BANK-2026-57513064300', '2026-05-27', 'utgift', 'Hizzar (12149077772)', 166000, 'Hizzar'::text, account_id, 2026),
    (org, 'BANK-2026-57513216600', '2026-05-27', 'utgift', 'Subhan (12246573857)', 95000, 'Subhan'::text, account_id, 2026),
    (org, 'BANK-2026-59132535400', '2026-06-03', 'utgift', 'Til konto: 1520 26 78456', 605269, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-00294554345', '2026-06-10', 'inntekt', 'AXACTOR NORWAY AS', 118997, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-61509696300', '2026-06-12', 'utgift', 'Ahmet (12268483975)', 120000, 'Ahmet'::text, account_id, 2026),
    (org, 'BANK-2026-60248481800', '2026-06-22', 'utgift', 'Omkostninger', 12280, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-00304364381', '2026-06-24', 'inntekt', 'Drammen Idrettsråd', 5743900, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-64902477600', '2026-06-26', 'utgift', 'Til konto: 1720 34 40472', 850000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-65471908600', '2026-06-29', 'utgift', 'Amir Ali (24802869378)', 380000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-65471996300', '2026-06-29', 'utgift', 'Elias (24802869394)', 95000, 'Elias'::text, account_id, 2026),
    (org, 'BANK-2026-65472062800', '2026-06-29', 'utgift', 'Subhan (12246573857)', 140000, 'Subhan'::text, account_id, 2026),
    (org, 'BANK-2026-65472136900', '2026-06-29', 'utgift', 'Hizzar (12149077772)', 140000, 'Hizzar'::text, account_id, 2026),
    (org, 'BANK-2026-65472424200', '2026-06-29', 'utgift', 'Ahmet (12268483975)', 140000, 'Ahmet'::text, account_id, 2026),
    (org, 'BANK-2026-65472876900', '2026-06-29', 'utgift', 'Taki (15038016161)', 400200, 'Taki'::text, account_id, 2026),
    (org, 'BANK-2026-65976196000', '2026-07-01', 'utgift', 'Til konto: 1720 34 40472', 700000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-66285175800', '2026-07-02', 'utgift', 'Til konto: 6032 66 12033', 1400000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-00000000715', '2026-07-07', 'inntekt', 'KRON & MYNT AS', 1642106, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-67476812600', '2026-07-07', 'utgift', 'American Express Europe SA (15060321334)', 1274292, 'American Express Europe SA'::text, account_id, 2026),
    (org, 'BANK-2026-68014122700', '2026-07-10', 'utgift', 'Drammen kommune (32072933981)', 250000, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-68014445600', '2026-07-10', 'utgift', 'Drammen kommune (32072933981)', 462500, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-68014872700', '2026-07-10', 'utgift', 'Fremtind Forsikring AS (90011700771)', 107300, 'Fremtind Forsikring AS'::text, account_id, 2026),
    (org, 'BANK-2026-66724584300', '2026-07-20', 'utgift', 'Omkostninger', 12450, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-70531824800', '2026-07-21', 'utgift', 'Til konto: 1720 34 40472', 1000000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-75531073300', '2026-08-13', 'utgift', 'EFFEKTUS AS (86011665200)', 59000, 'EFFEKTUS AS'::text, account_id, 2026),
    (org, 'BANK-2026-72697668900', '2026-08-17', 'utgift', 'Omkostninger', 9910, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-81019061442', '2026-08-27', 'inntekt', 'NORSK TIPPING AS', 655621, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-47950585000', '2026-08-28', 'utgift', 'Elias (24802869394)', 95000, 'Elias'::text, account_id, 2026),
    (org, 'BANK-2026-47950592000', '2026-08-28', 'utgift', 'Amir Ali (24802869378)', 240000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-21583210001', '2026-09-02', 'inntekt', 'NORGES IDRETTSFORBUND OG OLYMP', 25167700, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-48807870000', '2026-09-03', 'utgift', 'Til konto: 1520 15 85772', 1225000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-48807993000', '2026-09-03', 'utgift', 'Yngvar Åge Nilsen (31442012515)', 581600, 'Yngvar Åge Nilsen'::text, account_id, 2026),
    (org, 'BANK-2026-48882414000', '2026-09-03', 'utgift', 'Truls (22204133968)', 240000, 'Truls'::text, account_id, 2026),
    (org, 'BANK-2026-48938654000', '2026-09-04', 'utgift', 'Drammen kommune (32073011301)', 2927750, 'Drammen kommune'::text, account_id, 2026),
    (org, 'BANK-2026-49018070000', '2026-09-04', 'utgift', 'Yngvar Åge Nilsen (31442012515)', 2535700, 'Yngvar Åge Nilsen'::text, account_id, 2026),
    (org, 'BANK-2026-49316708000', '2026-09-08', 'utgift', 'Amir Ali (24802869378)', 600000, 'Amir Ali'::text, account_id, 2026),
    (org, 'BANK-2026-43500971755', '2026-09-09', 'inntekt', 'NORSK TIPPING AS', 95750, 'SKOGER OG FJELL KAMPSPORTKLUBB'::text, account_id, 2026),
    (org, 'BANK-2026-49703759000', '2026-09-10', 'utgift', 'AXACTOR NORWAY AS (22000757105)', 1441200, 'AXACTOR NORWAY AS'::text, account_id, 2026),
    (org, 'BANK-2026-49853849000', '2026-09-11', 'utgift', 'Til konto: 1720 34 40472', 4300000, 'FOLIO'::text, account_id, 2026),
    (org, 'BANK-2026-50295165000', '2026-09-14', 'utgift', 'Fremtind Forsikring AS (90011700771)', 107300, 'Fremtind Forsikring AS'::text, account_id, 2026)
  on conflict (organization_id, bilagsnummer) do update set
    dato = excluded.dato,
    type = excluded.type,
    beskrivelse = excluded.beskrivelse,
    belop_ore = excluded.belop_ore,
    motpart = excluded.motpart,
    account_id = excluded.account_id,
    regnskapsaar = excluded.regnskapsaar;

  insert into import_jobs (organization_id, type, filnavn, antall_lest, antall_importert, antall_avvist, status)
  select org, 'bank', 'Transaksjoner_2026-09-16-2.xlsx + Transaksjoner_2026-09-16.xlsx', 88, 88, 0, 'fullfort'
   where not exists (
     select 1 from import_jobs
      where organization_id = org and type = 'bank'
        and filnavn = 'Transaksjoner_2026-09-16-2.xlsx + Transaksjoner_2026-09-16.xlsx'
   );
end $$;
