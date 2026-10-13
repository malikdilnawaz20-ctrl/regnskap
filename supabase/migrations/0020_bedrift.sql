-- =====================================================================
--  0020 — Bedrift som organisasjonstype
--
--  Første bedriftskunde: Solarconsulting AS (org.nr 931 949 837).
--  En bedrift har ikke medlemmer, men har mva, kunder og leverandører.
--
--    organizations.type = 'bedrift'   egen kontoplan og kategorier
--    organizations.mva_registrert     NULL = ikke valgt ennå; spørres ved
--                                     første innlogging, endres under
--                                     Innstillinger → Selskapsinformasjon
--    transactions.mva_sats / mva_ore  mva på bilag (beløpet er inkl. mva)
--
--  KJØRES I TO OMGANGER: steg 1 alene først (ny enum-verdi må være
--  committet før den kan brukes), deretter resten.
-- =====================================================================

-- ---------------------------------------------------------------------
--  STEG 1 — kjør denne linjen alene og vent på «Success»
-- ---------------------------------------------------------------------
alter type org_type add value if not exists 'bedrift';

-- ---------------------------------------------------------------------
--  STEG 2 — resten
-- ---------------------------------------------------------------------
alter table organizations
  add column if not exists mva_registrert boolean,
  add column if not exists mva_termin     text not null default 'tomaanedlig'
    check (mva_termin in ('tomaanedlig','aarlig'));
comment on column organizations.mva_registrert is 'NULL = ikke valgt. Spørres ved første innlogging for bedrifter.';

alter table transactions
  add column if not exists mva_sats numeric(5,2) not null default 0,
  add column if not exists mva_ore  bigint not null default 0 check (mva_ore >= 0);
comment on column transactions.mva_sats is 'Mva-sats på bilaget. belop_ore er inkl. mva; mva_ore er mva-delen.';

-- Kontoplan og kategorier for en bedrift (NS 4102-nummer)
create or replace function opprett_standarddata_bedrift(org uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into accounting_accounts (organization_id, nummer, navn) values
    (org,1500,'Kundefordringer'),
    (org,1920,'Bankinnskudd, driftskonto'),
    (org,1950,'Bankinnskudd, skattetrekk'),
    (org,2000,'Aksjekapital'),
    (org,2050,'Annen egenkapital'),
    (org,2400,'Leverandørgjeld'),
    (org,2600,'Forskuddstrekk'),
    (org,2700,'Utgående mva'),
    (org,2710,'Inngående mva'),
    (org,2740,'Oppgjørskonto mva'),
    (org,2770,'Skyldig arbeidsgiveravgift'),
    (org,3000,'Salgsinntekt, avgiftspliktig'),
    (org,3100,'Salgsinntekt, avgiftsfri'),
    (org,3900,'Andre driftsinntekter'),
    (org,4300,'Innkjøp av varer for videresalg'),
    (org,5000,'Lønn til ansatte'),
    (org,5400,'Arbeidsgiveravgift'),
    (org,6300,'Leie av lokaler'),
    (org,6540,'Inventar og utstyr'),
    (org,6560,'Rekvisita'),
    (org,6700,'Regnskap og revisjon'),
    (org,6720,'Juridisk og annen rådgivning'),
    (org,6800,'Kontorkostnad'),
    (org,6810,'Data, programvare og nettside'),
    (org,6900,'Telefon og internett'),
    (org,7100,'Bilkostnad og kjøregodtgjørelse'),
    (org,7140,'Reisekostnad'),
    (org,7320,'Markedsføring'),
    (org,7500,'Forsikring'),
    (org,7770,'Bankgebyr'),
    (org,7790,'Annen driftskostnad'),
    (org,8050,'Renteinntekt'),
    (org,8150,'Rentekostnad')
  on conflict do nothing;

  insert into categories (organization_id, navn, retning, konto_nummer, sortering) values
    (org,'Konsulentinntekt','inntekt',3000,10),
    (org,'Salg uten mva','inntekt',3100,20),
    (org,'Andre inntekter','inntekt',3900,90),
    (org,'Leie av lokaler','utgift',6300,10),
    (org,'Programvare og IT','utgift',6810,20),
    (org,'Telefon og internett','utgift',6900,30),
    (org,'Reise','utgift',7140,40),
    (org,'Bil og kjøring','utgift',7100,50),
    (org,'Markedsføring','utgift',7320,60),
    (org,'Regnskap og rådgivning','utgift',6700,70),
    (org,'Forsikring','utgift',7500,80),
    (org,'Kontor og rekvisita','utgift',6800,90),
    (org,'Inventar og utstyr','utgift',6540,100),
    (org,'Lønn','utgift',5000,110),
    (org,'Bankgebyr','utgift',7770,120),
    (org,'Andre utgifter','utgift',7790,900)
  on conflict do nothing;

  insert into accounts (organization_id, navn, type) values (org,'Driftskonto','bank')
  on conflict do nothing;

  insert into subscriptions (organization_id, plan, status, medlemsgrense, prove_utlop)
  values (org, 'basis', 'proveperiode', null, current_date + 30)
  on conflict do nothing;
end;
$$;

-- Riktig standarddata ut fra type
create or replace function etter_ny_org()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type = 'bedrift' then perform opprett_standarddata_bedrift(new.id);
  else perform opprett_standarddata(new.id);
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
--  Solarconsulting AS + invitasjon til kontakt@solarconsulting.no.
--  Brukeren opprettes i Supabase Auth etterpå; triggeren handter_ny_bruker
--  kobler den til organisasjonen som administrator.
-- ---------------------------------------------------------------------
do $$
declare org uuid;
begin
  select id into org from organizations where orgnr = '931949837';
  if org is null then
    insert into organizations (navn, orgnr, type, epost)
    values ('Solarconsulting AS', '931949837', 'bedrift', 'kontakt@solarconsulting.no')
    returning id into org;
  end if;
  insert into invitations (organization_id, epost, fornavn, etternavn, rolle, status)
  values (org, 'kontakt@solarconsulting.no', 'Solar', 'Consulting', 'administrator', 'venter')
  on conflict (organization_id, epost) do nothing;
end $$;

-- Kontroll
select o.navn, o.type, o.mva_registrert, i.epost, i.status,
       (select count(*) from categories c where c.organization_id = o.id) as kategorier
  from organizations o left join invitations i on i.organization_id = o.id
 where o.orgnr = '931949837';
