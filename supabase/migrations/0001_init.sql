-- =====================================================================
--  Supabaseregnskap — grunnskjema
--  Multi-tenant foreningssystem: organisasjoner, medlemmer, økonomi
--  Kjøres én gang i Supabase SQL Editor på et TOMT prosjekt.
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- ---------------------------------------------------------------------
-- 1. Oppslagsverdier
-- ---------------------------------------------------------------------

create type org_type      as enum ('idrettslag','forening','kulturorganisasjon','velforening','annet');
create type user_role     as enum ('administrator','styreleder','kasserer','medlemsansvarlig','trener','revisor','medlem');
create type member_status as enum ('aktiv','inaktiv','utmeldt','venteliste');
create type claim_status  as enum ('ikke_betalt','delvis_betalt','betalt','forfalt','fritatt','kansellert');
create type fee_kind      as enum ('medlemskontingent','treningsavgift','aktivitetsavgift','annet');
create type fee_interval  as enum ('engangs','maanedlig','halvaarlig','aarlig');
create type txn_kind      as enum ('inntekt','utgift','overforing');
create type invite_status as enum ('venter','godtatt','trukket');

-- ---------------------------------------------------------------------
-- 2. Brukere og organisasjoner
-- ---------------------------------------------------------------------

-- Én rad per innlogget person. Speiler auth.users, men eies av oss.
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  epost       citext not null,
  fornavn     text,
  etternavn   text,
  telefon     text,
  opprettet   timestamptz not null default now(),
  endret      timestamptz not null default now()
);

create table organizations (
  id            uuid primary key default gen_random_uuid(),
  navn          text not null,
  orgnr         text,
  type          org_type not null default 'idrettslag',
  epost         citext,
  telefon       text,
  adresse       text,
  postnr        text,
  sted          text,
  -- Merkevare er konfigurerbar: produktnavn er ikke låst i koden.
  produktnavn   text not null default 'Foreningssystem',
  logo_url      text,
  aksentfarge   text not null default '#126f69',
  regnskapsaar_start date not null default (date_trunc('year', now())::date),
  opprettet     timestamptz not null default now(),
  endret        timestamptz not null default now()
);
create unique index organizations_orgnr_key on organizations(orgnr) where orgnr is not null;

-- Kobling person <-> organisasjon. Her ligger rolle OG styreverv.
create table organization_users (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id         uuid not null references profiles(id) on delete cascade,
  rolle           user_role not null default 'medlem',
  styreverv       text,                 -- "Styreleder", "Kasserer", "Styremedlem", fritekst
  tittel          text,                 -- "Hovedtrener karate" o.l.
  aktiv           boolean not null default true,
  notat           text,
  opprettet       timestamptz not null default now(),
  unique (organization_id, user_id)
);
create index organization_users_user_idx on organization_users(user_id);

-- Invitasjoner: admin legger inn e-post + navn + verv FØR personen har konto.
-- Når personen registrerer seg, kobles den automatisk på (trigger nederst).
create table invitations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  epost           citext not null,
  fornavn         text,
  etternavn       text,
  telefon         text,
  rolle           user_role not null default 'medlem',
  styreverv       text,
  tittel          text,
  status          invite_status not null default 'venter',
  invitert_av     uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  godtatt         timestamptz,
  unique (organization_id, epost)
);
create index invitations_epost_idx on invitations(epost) where status = 'venter';

-- ---------------------------------------------------------------------
-- 3. Hjelpefunksjoner for tilgangskontroll
--    SECURITY DEFINER for å unngå at RLS kaller seg selv i ring.
-- ---------------------------------------------------------------------

create or replace function er_medlem_av(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from organization_users ou
    where ou.organization_id = org and ou.user_id = auth.uid() and ou.aktiv
  );
$$;

create or replace function har_rolle(org uuid, roller user_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from organization_users ou
    where ou.organization_id = org and ou.user_id = auth.uid()
      and ou.aktiv and ou.rolle = any(roller)
  );
$$;

-- Kan administrere organisasjonen (brukere, innstillinger)
create or replace function kan_admin(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select har_rolle(org, array['administrator','styreleder']::user_role[]);
$$;

-- Kan føre økonomi
create or replace function kan_okonomi(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select har_rolle(org, array['administrator','styreleder','kasserer']::user_role[]);
$$;

-- Kan redigere medlemmer
create or replace function kan_medlem(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select har_rolle(org, array['administrator','styreleder','medlemsansvarlig','kasserer']::user_role[]);
$$;

-- ---------------------------------------------------------------------
-- 4. Medlemmer og familier
-- ---------------------------------------------------------------------

create table families (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,           -- "Familien Malik"
  hovedkontakt_epost citext,
  hovedkontakt_telefon text,
  opprettet       timestamptz not null default now()
);
create index families_org_idx on families(organization_id);

-- Ett medlem = én person i organisasjonen. Aldri duplisert per aktivitet.
create table members (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  medlemsnummer   int,
  fornavn         text not null,
  etternavn       text not null,
  fodselsdato     date,
  kjonn           text check (kjonn in ('kvinne','mann','annet') or kjonn is null),
  epost           citext,
  telefon         text,
  adresse         text,
  postnr          text,
  sted            text,
  innmeldt        date not null default current_date,
  utmeldt         date,
  status          member_status not null default 'aktiv',
  family_id       uuid references families(id) on delete set null,
  -- Foresatte for barn under 18
  foresatt1_navn  text,
  foresatt1_epost citext,
  foresatt1_telefon text,
  foresatt2_navn  text,
  foresatt2_epost citext,
  foresatt2_telefon text,
  notat           text,
  -- Forberedt for fremtidig NIF-integrasjon. Fylles kun via godkjent integrasjon.
  ekstern_id      text,
  ekstern_kilde   text,
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now(),
  opprettet_av    uuid references profiles(id)
);
create index members_org_idx on members(organization_id);
create index members_navn_idx on members(organization_id, etternavn, fornavn);
create unique index members_nummer_key on members(organization_id, medlemsnummer) where medlemsnummer is not null;

-- ---------------------------------------------------------------------
-- 5. Aktiviteter og grupper
-- ---------------------------------------------------------------------

create table activities (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,           -- "Karate", "Åpen Hall"
  beskrivelse     text,
  farge           text,
  aktiv           boolean not null default true,
  gren            text,                    -- NIF-gren, valgfri
  opprettet       timestamptz not null default now(),
  unique (organization_id, navn)
);

create table groups (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  activity_id     uuid not null references activities(id) on delete cascade,
  navn            text not null,           -- "Barn 6-9"
  alder_fra       int,
  alder_til       int,
  trener_notat    text,
  aktiv           boolean not null default true,
  opprettet       timestamptz not null default now(),
  unique (activity_id, navn)
);
create index groups_org_idx on groups(organization_id);

create table member_activities (
  member_id   uuid not null references members(id) on delete cascade,
  activity_id uuid not null references activities(id) on delete cascade,
  fra_dato    date not null default current_date,
  til_dato    date,
  primary key (member_id, activity_id)
);

create table member_groups (
  member_id uuid not null references members(id) on delete cascade,
  group_id  uuid not null references groups(id) on delete cascade,
  fra_dato  date not null default current_date,
  til_dato  date,
  primary key (member_id, group_id)
);

-- ---------------------------------------------------------------------
-- 6. Kontingent, avgifter og betalingskrav
--    Medlemskontingent og treningsavgift er BEVISST skilt via fee_kind.
-- ---------------------------------------------------------------------

create table fees (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,            -- "Medlemskontingent 2026"
  type            fee_kind not null,
  intervall       fee_interval not null default 'aarlig',
  belop_ore       bigint not null check (belop_ore >= 0),
  activity_id     uuid references activities(id) on delete set null,
  group_id        uuid references groups(id) on delete set null,
  familiesats_ore bigint,                   -- tak per familie
  soskenrabatt_pst numeric(5,2),            -- rabatt fra og med barn nr. 2
  gjelder_fra     date not null default current_date,
  gjelder_til     date,
  aktiv           boolean not null default true,
  opprettet       timestamptz not null default now()
);
create index fees_org_idx on fees(organization_id);

create table payment_claims (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  member_id       uuid not null references members(id) on delete cascade,
  fee_id          uuid references fees(id) on delete set null,
  beskrivelse     text not null,
  belop_ore       bigint not null check (belop_ore >= 0),
  betalt_ore      bigint not null default 0 check (betalt_ore >= 0),
  forfall         date not null,
  status          claim_status not null default 'ikke_betalt',
  fritak_arsak    text,
  kid             text,
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now()
);
create index claims_org_idx on payment_claims(organization_id, status);
create index claims_member_idx on payment_claims(member_id);

-- ---------------------------------------------------------------------
-- 7. Økonomi
--    Brukeren møter "kategori". Kategorien peker på riktig regnskapskonto.
-- ---------------------------------------------------------------------

-- Bankkontoer, Vipps, kontantkasse
create table accounts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,            -- "Driftskonto"
  kontonummer     text,
  type            text not null default 'bank' check (type in ('bank','vipps','kontant','annet')),
  aapningssaldo_ore bigint not null default 0,
  aktiv           boolean not null default true,
  opprettet       timestamptz not null default now()
);
create index accounts_org_idx on accounts(organization_id);

-- Norsk kontoplan (NS 4102-utvalg). Kopieres inn per organisasjon.
create table accounting_accounts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  nummer          int not null,
  navn            text not null,
  klasse          int generated always as (nummer / 1000) stored,
  aktiv           boolean not null default true,
  unique (organization_id, nummer)
);

-- Det brukeren faktisk velger: "Sportsutstyr", "Hall-leie"
create table categories (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,
  retning         txn_kind not null,        -- inntekt eller utgift
  konto_nummer    int,                      -- knytning til kontoplan
  sortering       int not null default 100,
  aktiv           boolean not null default true,
  unique (organization_id, navn, retning)
);

create table projects (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,            -- "Åpen Hall 2026"
  beskrivelse     text,
  tilskuddsgiver  text,
  tilskudd_ore    bigint not null default 0,
  start_dato      date,
  slutt_dato      date,
  rapportfrist    date,
  status          text not null default 'aktiv' check (status in ('planlegges','aktiv','avsluttet','rapportert')),
  opprettet       timestamptz not null default now(),
  unique (organization_id, navn)
);

-- Én rad per økonomisk hendelse. Enkelt for brukeren, sporbart under panseret.
create table transactions (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  bilagsnummer    text not null,            -- "2026-0001"
  dato            date not null,
  type            txn_kind not null,
  beskrivelse     text not null,
  belop_ore       bigint not null check (belop_ore > 0),
  motpart         text,                     -- leverandør eller betaler
  category_id     uuid references categories(id) on delete set null,
  konto_nummer    int,                      -- regnskapskonto, kan overstyres
  account_id      uuid references accounts(id) on delete set null,
  project_id      uuid references projects(id) on delete set null,
  activity_id     uuid references activities(id) on delete set null,
  member_id       uuid references members(id) on delete set null,
  claim_id        uuid references payment_claims(id) on delete set null,
  regnskapsaar    int not null,
  laast           boolean not null default false,
  reversert_av    uuid references transactions(id),
  reverserer      uuid references transactions(id),
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now(),
  unique (organization_id, bilagsnummer)
);
create index txn_org_dato_idx on transactions(organization_id, dato desc);
create index txn_project_idx on transactions(project_id);
create index txn_aar_idx on transactions(organization_id, regnskapsaar);

create table attachments (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  transaction_id  uuid references transactions(id) on delete cascade,
  filnavn         text not null,
  storage_path    text not null,            -- bøtte: bilag
  mime            text,
  storrelse       bigint,
  lastet_opp_av   uuid references profiles(id),
  opprettet       timestamptz not null default now()
);
create index attachments_txn_idx on attachments(transaction_id);

create table budgets (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  aar             int not null,
  category_id     uuid references categories(id) on delete cascade,
  project_id      uuid references projects(id) on delete cascade,
  belop_ore       bigint not null default 0,
  opprettet       timestamptz not null default now()
);
create index budgets_org_aar_idx on budgets(organization_id, aar);

-- Låsing av avsluttede regnskapsår
create table fiscal_years (
  organization_id uuid not null references organizations(id) on delete cascade,
  aar             int not null,
  laast           boolean not null default false,
  laast_av        uuid references profiles(id),
  laast_tid       timestamptz,
  primary key (organization_id, aar)
);

-- ---------------------------------------------------------------------
-- 8. Dokumenter
-- ---------------------------------------------------------------------

create table documents (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  mappe           text not null default 'Andre dokumenter',
  tittel          text not null,
  filnavn         text,
  storage_path    text,
  kun_styret      boolean not null default false,
  lastet_opp_av   uuid references profiles(id),
  opprettet       timestamptz not null default now()
);
create index documents_org_idx on documents(organization_id, mappe);

-- ---------------------------------------------------------------------
-- 9. Revisjonslogg — append-only
-- ---------------------------------------------------------------------

create table audit_logs (
  id              bigserial primary key,
  organization_id uuid references organizations(id) on delete cascade,
  user_id         uuid references profiles(id),
  tabell          text not null,
  rad_id          text,
  handling        text not null,            -- opprettet / endret / slettet
  fra_verdi       jsonb,
  til_verdi       jsonb,
  tidspunkt       timestamptz not null default now()
);
create index audit_org_idx on audit_logs(organization_id, tidspunkt desc);

-- ---------------------------------------------------------------------
-- 10. Abonnement og import
-- ---------------------------------------------------------------------

create table subscriptions (
  organization_id uuid primary key references organizations(id) on delete cascade,
  plan            text not null default 'gratis' check (plan in ('gratis','basis','klubb','pro')),
  status          text not null default 'proveperiode' check (status in ('proveperiode','aktiv','pauset','avsluttet')),
  medlemsgrense   int,
  prove_utlop     date,
  opprettet       timestamptz not null default now()
);

create table import_jobs (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  type            text not null,            -- medlemmer / transaksjoner / bank
  filnavn         text,
  antall_lest     int not null default 0,
  antall_importert int not null default 0,
  antall_avvist   int not null default 0,
  feil            jsonb,
  status          text not null default 'fullfort',
  utfort_av       uuid references profiles(id),
  opprettet       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 11. Bilagsnummer — fortløpende per organisasjon og år, uten hull
-- ---------------------------------------------------------------------

create table voucher_sequences (
  organization_id uuid not null references organizations(id) on delete cascade,
  aar             int not null,
  siste_nr        int not null default 0,
  primary key (organization_id, aar)
);

create or replace function neste_bilagsnummer(p_org uuid, p_aar int)
returns text language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into voucher_sequences (organization_id, aar, siste_nr)
  values (p_org, p_aar, 1)
  on conflict (organization_id, aar)
    do update set siste_nr = voucher_sequences.siste_nr + 1
  returning voucher_sequences.siste_nr into n;
  return p_aar::text || '-' || lpad(n::text, 4, '0');
end;
$$;

create or replace function sett_bilagsnummer()
returns trigger language plpgsql as $$
begin
  if new.regnskapsaar is null then new.regnskapsaar := extract(year from new.dato)::int; end if;
  if new.bilagsnummer is null or new.bilagsnummer = '' then
    new.bilagsnummer := neste_bilagsnummer(new.organization_id, new.regnskapsaar);
  end if;
  return new;
end;
$$;
create trigger trg_bilagsnummer before insert on transactions
  for each row execute function sett_bilagsnummer();

-- ---------------------------------------------------------------------
-- 12. Ny bruker → profil + eventuelle ventende invitasjoner
-- ---------------------------------------------------------------------

create or replace function handter_ny_bruker()
returns trigger language plpgsql security definer set search_path = public as $$
declare inv record;
begin
  insert into profiles (id, epost, fornavn, etternavn)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'fornavn', split_part(coalesce(new.raw_user_meta_data->>'navn',''), ' ', 1)),
    coalesce(new.raw_user_meta_data->>'etternavn', nullif(substr(coalesce(new.raw_user_meta_data->>'navn',''), strpos(coalesce(new.raw_user_meta_data->>'navn',' '), ' ') + 1), ''))
  )
  on conflict (id) do nothing;

  for inv in select * from invitations where epost = new.email and status = 'venter'
  loop
    insert into organization_users (organization_id, user_id, rolle, styreverv, tittel)
    values (inv.organization_id, new.id, inv.rolle, inv.styreverv, inv.tittel)
    on conflict (organization_id, user_id) do nothing;

    update invitations set status = 'godtatt', godtatt = now() where id = inv.id;

    update profiles set
      fornavn   = coalesce(nullif(fornavn,''), inv.fornavn),
      etternavn = coalesce(nullif(etternavn,''), inv.etternavn),
      telefon   = coalesce(telefon, inv.telefon)
    where id = new.id;
  end loop;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handter_ny_bruker();

-- ---------------------------------------------------------------------
-- 13. Oppdater "endret"-tidspunkt
-- ---------------------------------------------------------------------

create or replace function sett_endret()
returns trigger language plpgsql as $$
begin new.endret := now(); return new; end; $$;

create trigger trg_endret_members before update on members
  for each row execute function sett_endret();
create trigger trg_endret_txn before update on transactions
  for each row execute function sett_endret();
create trigger trg_endret_claims before update on payment_claims
  for each row execute function sett_endret();
create trigger trg_endret_org before update on organizations
  for each row execute function sett_endret();

-- ---------------------------------------------------------------------
-- 14. Revisjonslogg via trigger
-- ---------------------------------------------------------------------

create or replace function logg_endring()
returns trigger language plpgsql security definer set search_path = public as $$
declare org uuid;
begin
  org := coalesce(
    case when tg_op = 'DELETE' then (to_jsonb(old)->>'organization_id') else (to_jsonb(new)->>'organization_id') end
  )::uuid;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, fra_verdi, til_verdi)
  values (
    org, auth.uid(), tg_table_name,
    case when tg_op = 'DELETE' then old.id::text else new.id::text end,
    lower(tg_op),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger trg_logg_txn after insert or update or delete on transactions
  for each row execute function logg_endring();
create trigger trg_logg_members after insert or update or delete on members
  for each row execute function logg_endring();
create trigger trg_logg_ou after insert or update or delete on organization_users
  for each row execute function logg_endring();
create trigger trg_logg_claims after insert or update or delete on payment_claims
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
-- 15. Låste år og bokførte bilag kan ikke endres fritt
-- ---------------------------------------------------------------------

create or replace function vern_transaksjon()
returns trigger language plpgsql as $$
declare aar_laast boolean;
begin
  select laast into aar_laast from fiscal_years
   where organization_id = coalesce(new.organization_id, old.organization_id)
     and aar = coalesce(new.regnskapsaar, old.regnskapsaar);

  if coalesce(aar_laast, false) then
    raise exception 'Regnskapsåret er låst. Bruk en korrigering i stedet for å endre bilaget.';
  end if;

  if tg_op = 'DELETE' and coalesce(old.laast, false) then
    raise exception 'Bokførte bilag kan ikke slettes. Reverser bilaget i stedet.';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
create trigger trg_vern_txn before update or delete on transactions
  for each row execute function vern_transaksjon();

-- =====================================================================
--  16. RAD-NIVÅ-SIKKERHET
--  Ingen organisasjon skal noen gang se en annen organisasjons data.
-- =====================================================================

alter table profiles            enable row level security;
alter table organizations       enable row level security;
alter table organization_users  enable row level security;
alter table invitations         enable row level security;
alter table families            enable row level security;
alter table members             enable row level security;
alter table activities          enable row level security;
alter table groups              enable row level security;
alter table member_activities   enable row level security;
alter table member_groups       enable row level security;
alter table fees                enable row level security;
alter table payment_claims      enable row level security;
alter table accounts            enable row level security;
alter table accounting_accounts enable row level security;
alter table categories          enable row level security;
alter table projects            enable row level security;
alter table transactions        enable row level security;
alter table attachments         enable row level security;
alter table budgets             enable row level security;
alter table fiscal_years        enable row level security;
alter table documents           enable row level security;
alter table audit_logs          enable row level security;
alter table subscriptions       enable row level security;
alter table import_jobs         enable row level security;
alter table voucher_sequences   enable row level security;

-- Profiler: du ser deg selv, og folk i organisasjoner du er med i.
create policy profil_selv on profiles for select using (
  id = auth.uid() or exists (
    select 1 from organization_users a
    join organization_users b on a.organization_id = b.organization_id
    where a.user_id = auth.uid() and b.user_id = profiles.id
  )
);
create policy profil_endre_selv on profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- Organisasjoner
create policy org_les on organizations for select using (er_medlem_av(id));
create policy org_endre on organizations for update using (kan_admin(id)) with check (kan_admin(id));
-- Enhver innlogget bruker kan opprette en ny organisasjon (onboarding).
create policy org_opprett on organizations for insert with check (auth.uid() is not null);

-- Medlemskap i organisasjon
create policy ou_les on organization_users for select using (
  user_id = auth.uid() or er_medlem_av(organization_id)
);
create policy ou_skriv on organization_users for insert with check (
  kan_admin(organization_id)
  -- eller: den som nettopp opprettet organisasjonen kobler seg selv på
  or (user_id = auth.uid() and not exists (
        select 1 from organization_users x where x.organization_id = organization_users.organization_id))
);
create policy ou_endre on organization_users for update using (kan_admin(organization_id)) with check (kan_admin(organization_id));
create policy ou_slett on organization_users for delete using (kan_admin(organization_id) and user_id <> auth.uid());

-- Invitasjoner
create policy inv_les on invitations for select using (kan_admin(organization_id));
create policy inv_skriv on invitations for insert with check (kan_admin(organization_id));
create policy inv_endre on invitations for update using (kan_admin(organization_id)) with check (kan_admin(organization_id));
create policy inv_slett on invitations for delete using (kan_admin(organization_id));

-- Generisk mønster for organisasjonsdata
do $$
declare t text;
begin
  foreach t in array array['families','activities','groups','accounts','accounting_accounts',
                           'categories','projects','budgets','documents','import_jobs'] loop
    execute format('create policy %1$s_les on %1$s for select using (er_medlem_av(organization_id));', t);
    execute format('create policy %1$s_skriv on %1$s for insert with check (er_medlem_av(organization_id) and not har_rolle(organization_id, array[''revisor'']::user_role[]));', t);
    execute format('create policy %1$s_endre on %1$s for update using (er_medlem_av(organization_id) and not har_rolle(organization_id, array[''revisor'']::user_role[])) with check (er_medlem_av(organization_id));', t);
    execute format('create policy %1$s_slett on %1$s for delete using (kan_admin(organization_id));', t);
  end loop;
end $$;

-- Medlemmer: trener ser, men bare medlemsansvarlig/kasserer/admin kan endre
create policy members_les on members for select using (er_medlem_av(organization_id));
create policy members_skriv on members for insert with check (kan_medlem(organization_id));
create policy members_endre on members for update using (kan_medlem(organization_id)) with check (kan_medlem(organization_id));
create policy members_slett on members for delete using (kan_admin(organization_id));

-- Koblingstabeller uten egen organization_id: arv fra medlemmet
create policy ma_les on member_activities for select using (
  exists (select 1 from members m where m.id = member_id and er_medlem_av(m.organization_id)));
create policy ma_skriv on member_activities for all using (
  exists (select 1 from members m where m.id = member_id and kan_medlem(m.organization_id)))
  with check (exists (select 1 from members m where m.id = member_id and kan_medlem(m.organization_id)));

create policy mg_les on member_groups for select using (
  exists (select 1 from members m where m.id = member_id and er_medlem_av(m.organization_id)));
create policy mg_skriv on member_groups for all using (
  exists (select 1 from members m where m.id = member_id and kan_medlem(m.organization_id)))
  with check (exists (select 1 from members m where m.id = member_id and kan_medlem(m.organization_id)));

-- Økonomi: alle i org kan lese, bare kasserer/styreleder/admin kan skrive
create policy fees_les on fees for select using (er_medlem_av(organization_id));
create policy fees_skriv on fees for all using (kan_okonomi(organization_id)) with check (kan_okonomi(organization_id));

create policy claims_les on payment_claims for select using (er_medlem_av(organization_id));
create policy claims_skriv on payment_claims for all using (kan_okonomi(organization_id)) with check (kan_okonomi(organization_id));

create policy txn_les on transactions for select using (er_medlem_av(organization_id));
create policy txn_skriv on transactions for insert with check (kan_okonomi(organization_id));
create policy txn_endre on transactions for update using (kan_okonomi(organization_id)) with check (kan_okonomi(organization_id));
create policy txn_slett on transactions for delete using (kan_okonomi(organization_id) and not laast);

create policy att_les on attachments for select using (er_medlem_av(organization_id));
create policy att_skriv on attachments for all using (kan_okonomi(organization_id)) with check (kan_okonomi(organization_id));

create policy fy_les on fiscal_years for select using (er_medlem_av(organization_id));
create policy fy_skriv on fiscal_years for all using (kan_admin(organization_id)) with check (kan_admin(organization_id));

create policy sub_les on subscriptions for select using (er_medlem_av(organization_id));
create policy sub_skriv on subscriptions for all using (kan_admin(organization_id)) with check (kan_admin(organization_id));

create policy vs_les on voucher_sequences for select using (er_medlem_av(organization_id));

-- Revisjonslogg: lesbar for admin/styreleder/revisor. Ingen kan endre eller slette.
create policy audit_les on audit_logs for select using (
  har_rolle(organization_id, array['administrator','styreleder','revisor','kasserer']::user_role[])
);
-- Bevisst: ingen INSERT/UPDATE/DELETE-policy. Bare triggerne (security definer) skriver.

-- I tillegg: en hard sperre som gir en tydelig feilmelding i stedet for at
-- en sletting stille berører null rader.
create or replace function vern_revisjonslogg()
returns trigger language plpgsql as $$
begin
  raise exception 'Revisjonsloggen kan ikke endres eller slettes.';
end;
$$;
create trigger trg_vern_audit before update or delete on audit_logs
  for each row execute function vern_revisjonslogg();

-- =====================================================================
--  17. Standarddata for en ny organisasjon
-- =====================================================================

create or replace function opprett_standarddata(org uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into accounting_accounts (organization_id, nummer, navn) values
    (org,1920,'Bankinnskudd, driftskonto'),
    (org,1930,'Bankinnskudd, prosjektkonto'),
    (org,1900,'Kontantkasse'),
    (org,1500,'Kundefordringer / krav til medlemmer'),
    (org,2400,'Leverandørgjeld'),
    (org,3200,'Medlemskontingent'),
    (org,3210,'Trenings- og aktivitetsavgift'),
    (org,3400,'Offentlig tilskudd'),
    (org,3440,'Andre tilskudd og gaver'),
    (org,3600,'Utleieinntekt'),
    (org,3900,'Andre inntekter'),
    (org,4300,'Innkjøp av varer for videresalg'),
    (org,5000,'Lønn og honorar'),
    (org,5330,'Godtgjørelse til tillitsvalgte'),
    (org,5800,'Refusjon og trenerhonorar'),
    (org,6300,'Leie av hall og lokaler'),
    (org,6540,'Sportsutstyr og inventar'),
    (org,6560,'Rekvisita og forbruksmateriell'),
    (org,6700,'Regnskap, revisjon og honorarer'),
    (org,6800,'Kontorkostnad'),
    (org,6810,'Data, programvare og nettside'),
    (org,6900,'Telefon og porto'),
    (org,7100,'Reise og transport'),
    (org,7140,'Reisekostnad, stevner og cup'),
    (org,7320,'Markedsføring og profilering'),
    (org,7400,'Kontingent til forbund og krets'),
    (org,7500,'Forsikring'),
    (org,7710,'Møter, kurs og oppdatering'),
    (org,7770,'Bank- og betalingsgebyr'),
    (org,7790,'Andre kostnader')
  on conflict do nothing;

  insert into categories (organization_id, navn, retning, konto_nummer, sortering) values
    (org,'Medlemskontingent','inntekt',3200,10),
    (org,'Treningsavgift','inntekt',3210,20),
    (org,'Offentlig tilskudd','inntekt',3400,30),
    (org,'Sponsor og gaver','inntekt',3440,40),
    (org,'Utleie','inntekt',3600,50),
    (org,'Kiosk og salg','inntekt',3900,60),
    (org,'Andre inntekter','inntekt',3900,90),
    (org,'Hall-leie','utgift',6300,10),
    (org,'Sportsutstyr','utgift',6540,20),
    (org,'Trenerhonorar','utgift',5800,30),
    (org,'Dommer og stevneavgift','utgift',7140,40),
    (org,'Reise og transport','utgift',7100,50),
    (org,'Mat og bevertning','utgift',7710,60),
    (org,'Rekvisita','utgift',6560,70),
    (org,'Forsikring','utgift',7500,80),
    (org,'Kontingent til forbund','utgift',7400,90),
    (org,'Nettside og programvare','utgift',6810,100),
    (org,'Regnskap og revisjon','utgift',6700,110),
    (org,'Markedsføring','utgift',7320,120),
    (org,'Bankgebyr','utgift',7770,130),
    (org,'Andre utgifter','utgift',7790,900)
  on conflict do nothing;

  insert into accounts (organization_id, navn, type) values
    (org,'Driftskonto','bank')
  on conflict do nothing;

  insert into subscriptions (organization_id, plan, status, medlemsgrense, prove_utlop)
  values (org, 'gratis', 'proveperiode', 50, current_date + 30)
  on conflict do nothing;
end;
$$;

-- Kall standarddata automatisk når en organisasjon opprettes
create or replace function etter_ny_org()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform opprett_standarddata(new.id);
  return new;
end;
$$;
create trigger trg_ny_org after insert on organizations
  for each row execute function etter_ny_org();

-- =====================================================================
--  18. Visninger for dashbordet
-- =====================================================================

create or replace view v_org_okonomi
with (security_invoker = true) as
select
  t.organization_id,
  t.regnskapsaar,
  sum(t.belop_ore) filter (where t.type = 'inntekt') as inntekt_ore,
  sum(t.belop_ore) filter (where t.type = 'utgift')  as utgift_ore,
  coalesce(sum(t.belop_ore) filter (where t.type = 'inntekt'), 0)
    - coalesce(sum(t.belop_ore) filter (where t.type = 'utgift'), 0) as resultat_ore
from transactions t
group by t.organization_id, t.regnskapsaar;

create or replace view v_prosjekt_status
with (security_invoker = true) as
select
  p.id as project_id, p.organization_id, p.navn, p.tilskudd_ore,
  coalesce(sum(t.belop_ore) filter (where t.type = 'utgift'), 0) as brukt_ore,
  coalesce(sum(t.belop_ore) filter (where t.type = 'inntekt'), 0) as mottatt_ore,
  p.tilskudd_ore - coalesce(sum(t.belop_ore) filter (where t.type = 'utgift'), 0) as gjenstaar_ore
from projects p
left join transactions t on t.project_id = p.id
group by p.id;

-- Ferdig.
