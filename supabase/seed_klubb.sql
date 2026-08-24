-- =====================================================================
--  Oppstart for Skoger og Fjell kampsportklubb
--  Kjøres ÉN gang i Supabase SQL Editor, etter 0001 og 0002.
--
--  Forutsetning: de tre brukerne er allerede opprettet under
--  Authentication → Users i Supabase (se OPPSETT.md, punkt 4).
--  Rekkefølgen spiller ingen rolle — kjører du dette først, kobles
--  brukerne på automatisk første gang de logger inn.
-- =====================================================================

do $$
declare
  org uuid;
  u_malik  uuid;
  u_carlos uuid;
  u_denis  uuid;
begin

  ---------------------------------------------------------------------
  -- 1. Organisasjonen
  ---------------------------------------------------------------------
  select id into org from organizations where orgnr = '912484335';

  if org is null then
    insert into organizations (navn, orgnr, type, sted, produktnavn)
    values ('Skoger og Fjell kampsportklubb', '912484335', 'idrettslag', 'Drammen', 'Saksflyt')
    returning id into org;
    raise notice 'Opprettet organisasjon %', org;
  else
    raise notice 'Organisasjonen finnes allerede (%)', org;
  end if;

  ---------------------------------------------------------------------
  -- 2. Brukere som allerede har logget inn kobles på med én gang.
  --    De som ikke finnes ennå, får en invitasjon som brukes automatisk
  --    ved første innlogging.
  ---------------------------------------------------------------------
  select id into u_malik  from auth.users where email = 'malik@kampsportlaget.com';
  select id into u_carlos from auth.users where email = 'carlos@kampsportlaget.com';
  select id into u_denis  from auth.users where email = 'denis@kampsportlaget.com';

  -- Dilnawaz Malik — administrator og styreleder
  if u_malik is not null then
    insert into profiles (id, epost, fornavn, etternavn)
    values (u_malik, 'malik@kampsportlaget.com', 'Dilnawaz', 'Malik')
    on conflict (id) do update set fornavn = excluded.fornavn, etternavn = excluded.etternavn;

    insert into organization_users (organization_id, user_id, rolle, styreverv)
    values (org, u_malik, 'administrator', 'Styreleder')
    on conflict (organization_id, user_id) do update
      set rolle = excluded.rolle, styreverv = excluded.styreverv;
  else
    insert into invitations (organization_id, epost, fornavn, etternavn, rolle, styreverv)
    values (org, 'malik@kampsportlaget.com', 'Dilnawaz', 'Malik', 'administrator', 'Styreleder')
    on conflict (organization_id, epost) do nothing;
  end if;

  -- Carlos — kasserer og attestant 1
  if u_carlos is not null then
    insert into profiles (id, epost, fornavn, etternavn)
    values (u_carlos, 'carlos@kampsportlaget.com', 'Carlos', '')
    on conflict (id) do nothing;

    insert into organization_users (organization_id, user_id, rolle, styreverv)
    values (org, u_carlos, 'kasserer', 'Kasserer')
    on conflict (organization_id, user_id) do update
      set rolle = excluded.rolle, styreverv = excluded.styreverv;
  else
    insert into invitations (organization_id, epost, fornavn, rolle, styreverv)
    values (org, 'carlos@kampsportlaget.com', 'Carlos', 'kasserer', 'Kasserer')
    on conflict (organization_id, epost) do nothing;
  end if;

  -- Denis — styreleder-rolle (nestleder) og attestant 2
  if u_denis is not null then
    insert into profiles (id, epost, fornavn, etternavn)
    values (u_denis, 'denis@kampsportlaget.com', 'Denis', '')
    on conflict (id) do nothing;

    insert into organization_users (organization_id, user_id, rolle, styreverv)
    values (org, u_denis, 'styreleder', 'Nestleder')
    on conflict (organization_id, user_id) do update
      set rolle = excluded.rolle, styreverv = excluded.styreverv;
  else
    insert into invitations (organization_id, epost, fornavn, rolle, styreverv)
    values (org, 'denis@kampsportlaget.com', 'Denis', 'styreleder', 'Nestleder')
    on conflict (organization_id, epost) do nothing;
  end if;

  ---------------------------------------------------------------------
  -- 3. Hvem attesterer regninger
  --    Carlos og Denis. Begge må godkjenne før en regning kan betales.
  ---------------------------------------------------------------------
  if u_carlos is not null and u_denis is not null then
    update organizations
       set attestant1 = u_carlos, attestant2 = u_denis, krev_to_attestanter = true
     where id = org;
    raise notice 'Attestering satt opp: Carlos og Denis';
  else
    raise notice 'Attestanter settes under Innstillinger når begge har logget inn første gang.';
  end if;

  ---------------------------------------------------------------------
  -- 4. Aktiviteter klubben driver
  ---------------------------------------------------------------------
  insert into activities (organization_id, navn, beskrivelse) values
    (org, 'Karate',      'Tradisjonell karate for alle aldre'),
    (org, 'Kickboxing',  'Kickboxing, nybegynnere og viderekomne'),
    (org, 'MMA',         'Mixed martial arts'),
    (org, 'Åpen Hall',   'Lavterskeltilbud, gratis for deltakerne')
  on conflict (organization_id, navn) do nothing;

  ---------------------------------------------------------------------
  -- 5. Grupper under karate
  ---------------------------------------------------------------------
  insert into groups (organization_id, activity_id, navn, alder_fra, alder_til)
  select org, a.id, g.navn, g.fra, g.til
  from activities a,
       (values ('Barn 6–9', 6, 9), ('Barn 10–12', 10, 12),
               ('Ungdom', 13, 17), ('Voksne', 18, null),
               ('Konkurransegruppe', null, null)) as g(navn, fra, til)
  where a.organization_id = org and a.navn = 'Karate'
  on conflict (activity_id, navn) do nothing;

  ---------------------------------------------------------------------
  -- 6. Bankkontoer
  ---------------------------------------------------------------------
  insert into accounts (organization_id, navn, type) values
    (org, 'Prosjektkonto Åpen Hall', 'bank'),
    (org, 'Vipps', 'vipps'),
    (org, 'Kontantkasse', 'kontant')
  on conflict do nothing;

  ---------------------------------------------------------------------
  -- 7. Satser — medlemskontingent og treningsavgift holdes atskilt
  ---------------------------------------------------------------------
  insert into fees (organization_id, navn, type, intervall, belop_ore, gjelder_fra)
  values
    (org, 'Medlemskontingent 2026',        'medlemskontingent', 'aarlig',     45000,  '2026-01-01'),
    (org, 'Treningsavgift karate, halvår', 'treningsavgift',    'halvaarlig', 150000, '2026-01-01'),
    (org, 'Treningsavgift MMA, halvår',    'treningsavgift',    'halvaarlig', 175000, '2026-01-01')
  on conflict do nothing;

  raise notice 'Ferdig. Logg inn på sakflyt.no og sjekk Innstillinger → Brukere.';
end $$;
