-- =====================================================================
--  0010 — Innmelding: familiemedlemskap med selvregistrering
--
--  Foreldre fyller ut ett skjema for hele familien på en offentlig
--  lenke, uten innlogging. Innmeldingen havner i en køtabell som
--  medlemsansvarlig godkjenner — først da opprettes familie og
--  medlemmer i det ekte registeret.
--
--  Fødselsnummer:
--    - lagres kryptert (pgp_sym_encrypt), aldri i klartekst
--    - nøkkelen ligger i en tabell uten en eneste policy, så den er
--      utilgjengelig via API uansett rolle
--    - leses bare gjennom les_fodselsnummer(), som krever rolle og
--      skriver en linje i revisjonssporet for hvert eneste oppslag
--    - slettes fra innmeldingskøen når medlemmet er opprettet
--    - members-tabellen får aldri fødselsnummer — den har fødselsdato
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nøkkellager
-- ---------------------------------------------------------------------

create table if not exists krypto_nokler (
  navn      text primary key,
  nokkel    text not null,
  opprettet timestamptz not null default now()
);
alter table krypto_nokler enable row level security;
-- Bevisst uten policyer: ingen rolle kan lese eller skrive via API.
-- Bare security definer-funksjonene under når inn hit.

insert into krypto_nokler (navn, nokkel)
values ('fodselsnummer', encode(gen_random_bytes(32), 'base64'))
on conflict (navn) do nothing;

-- ---------------------------------------------------------------------
-- 2. Validering av fødselsnummer (MOD11), uten sideeffekter
-- ---------------------------------------------------------------------

-- Fødselsdato ut av fødselsnummer. Håndterer D-nummer (dag + 40) og
-- århundreregelen i individnummeret. Returnerer null hvis datoen ikke
-- finnes — det avslører tastefeil som MOD11 alene slipper gjennom.
create or replace function fnr_fodselsdato(p_fnr text)
returns date language plpgsql immutable as $$
declare
  f text := regexp_replace(coalesce(p_fnr, ''), '\s', '', 'g');
  dag int; mnd int; aar int; ind int; aarhundre int;
begin
  if f !~ '^\d{11}$' then return null; end if;

  dag := substr(f, 1, 2)::int;
  mnd := substr(f, 3, 2)::int;
  aar := substr(f, 5, 2)::int;
  ind := substr(f, 7, 3)::int;

  if dag between 41 and 71 then dag := dag - 40; end if;   -- D-nummer
  if mnd between 41 and 52 then return null; end if;       -- H-nummer, ikke gyldig medlemsnummer
  if dag < 1 or dag > 31 or mnd < 1 or mnd > 12 then return null; end if;

  if    ind between 0   and 499 then aarhundre := 1900;
  elsif ind between 500 and 749 and aar >= 54 then aarhundre := 1800;
  elsif ind between 500 and 999 and aar <= 39 then aarhundre := 2000;
  elsif ind between 900 and 999 and aar >= 40 then aarhundre := 1900;
  else return null;
  end if;

  return make_date(aarhundre + aar, mnd, dag);
exception when others then
  return null;
end;
$$;

create or replace function fnr_gyldig(p_fnr text)
returns boolean language plpgsql immutable as $$
declare
  f text := regexp_replace(coalesce(p_fnr, ''), '\s', '', 'g');
  v1 int[] := array[3,7,6,1,8,9,4,5,2];
  v2 int[] := array[5,4,3,2,7,6,5,4,3,2];
  s1 int := 0; s2 int := 0; k1 int; k2 int; i int;
begin
  if f !~ '^\d{11}$' then return false; end if;

  for i in 1..9 loop
    s1 := s1 + v1[i] * substr(f, i, 1)::int;
  end loop;
  k1 := 11 - (s1 % 11);
  if k1 = 11 then k1 := 0; end if;
  if k1 = 10 or k1 <> substr(f, 10, 1)::int then return false; end if;

  for i in 1..10 loop
    s2 := s2 + v2[i] * substr(f, i, 1)::int;
  end loop;
  k2 := 11 - (s2 % 11);
  if k2 = 11 then k2 := 0; end if;
  if k2 = 10 or k2 <> substr(f, 11, 1)::int then return false; end if;

  return fnr_fodselsdato(f) is not null;
end;
$$;

create or replace function fnr_maskert(p_fnr text)
returns text language sql immutable as $$
  select case
    when p_fnr ~ '^\d{11}$' then substr(p_fnr, 1, 6) || ' *****'
    else '***********'
  end;
$$;

-- ---------------------------------------------------------------------
-- 3. Kryptering
--    pgcrypto ligger i skjemaet "extensions" i Supabase. Funksjoner med
--    fast search_path må derfor ta det med, ellers finnes ikke pgp_sym_encrypt.
-- ---------------------------------------------------------------------

create or replace function krypter_fnr(p_fnr text)
returns bytea language plpgsql security definer set search_path = public, extensions as $$
declare n text;
begin
  select nokkel into n from krypto_nokler where navn = 'fodselsnummer';
  if n is null then raise exception 'Krypteringsnøkkel mangler'; end if;
  return pgp_sym_encrypt(p_fnr, n, 'cipher-algo=aes256');
end;
$$;
revoke execute on function krypter_fnr(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Tabeller
-- ---------------------------------------------------------------------

do $$ begin
  create type innmelding_status as enum ('ny','under_behandling','godkjent','avvist');
exception when duplicate_object then null; end $$;

-- Én offentlig lenke per organisasjon. Slug i URL-en, ikke org-id,
-- så adressen kan byttes hvis den lekker eller misbrukes.
create table if not exists innmelding_lenker (
  organization_id uuid primary key references organizations(id) on delete cascade,
  slug            text not null unique check (slug ~ '^[a-z0-9-]{4,60}$'),
  aapen           boolean not null default true,
  tittel          text,
  ingress         text,
  gratis_drakt    boolean not null default true,
  krev_fodselsnummer boolean not null default true,
  grener          text[] not null default array['Kickboxing','Karate','Bryting'],
  opprettet       timestamptz not null default now()
);

create table if not exists innmeldinger (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  referanse       text not null unique,
  status          innmelding_status not null default 'ny',
  familienavn     text not null,
  adresse         text not null,
  postnr          text not null,
  sted            text not null,
  kontakt_navn    text not null,
  kontakt_epost   citext not null,
  kontakt_telefon text not null,
  notat           text,
  innsendt        timestamptz not null default now(),
  behandlet       timestamptz,
  behandlet_av    uuid references profiles(id),
  avvist_grunn    text,
  family_id       uuid references families(id) on delete set null
);
create index if not exists innmeldinger_org_idx on innmeldinger(organization_id, status, innsendt desc);

create table if not exists innmelding_personer (
  id              uuid primary key default gen_random_uuid(),
  innmelding_id   uuid not null references innmeldinger(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  sortering       int not null default 0,
  rolle           text not null check (rolle in ('voksen','barn')),
  fornavn         text not null,
  etternavn       text not null,
  fodselsdato     date not null,
  fnr_kryptert    bytea,
  fnr_maskert     text not null,
  epost           citext,
  telefon         text,
  draktstorrelse  text,
  gren            text,
  samtykke_bilder boolean not null default false,
  member_id       uuid references members(id) on delete set null
);
create index if not exists innmelding_personer_idx on innmelding_personer(innmelding_id, sortering);

alter table innmelding_lenker    enable row level security;
alter table innmeldinger         enable row level security;
alter table innmelding_personer  enable row level security;

-- ---------------------------------------------------------------------
-- 5. Tilgang
--    Skjemaet skriver ikke direkte til tabellene — det kaller
--    send_innmelding(). Derfor finnes det ingen INSERT-policy for anon.
-- ---------------------------------------------------------------------

drop policy if exists inl_les on innmelding_lenker;
create policy inl_les on innmelding_lenker for select using (er_medlem_av(organization_id));
drop policy if exists inl_skriv on innmelding_lenker;
create policy inl_skriv on innmelding_lenker for all
  using (kan_admin(organization_id)) with check (kan_admin(organization_id));

drop policy if exists inm_les on innmeldinger;
create policy inm_les on innmeldinger for select using (kan_medlem(organization_id));
drop policy if exists inm_endre on innmeldinger;
create policy inm_endre on innmeldinger for update
  using (kan_medlem(organization_id)) with check (kan_medlem(organization_id));
drop policy if exists inm_slett on innmeldinger;
create policy inm_slett on innmeldinger for delete using (kan_admin(organization_id));

-- Merk: kolonnen fnr_kryptert er lesbar som chiffertekst for
-- medlemsansvarlig, men uten nøkkelen betyr den ingenting.
drop policy if exists inp_les on innmelding_personer;
create policy inp_les on innmelding_personer for select using (kan_medlem(organization_id));
drop policy if exists inp_endre on innmelding_personer;
create policy inp_endre on innmelding_personer for update
  using (kan_medlem(organization_id)) with check (kan_medlem(organization_id));
drop policy if exists inp_slett on innmelding_personer;
create policy inp_slett on innmelding_personer for delete using (kan_admin(organization_id));

-- ---------------------------------------------------------------------
-- 6. Offentlig oppslag: hva skjemaet skal vise
-- ---------------------------------------------------------------------

create or replace function innmelding_skjema(p_slug text)
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare r record;
begin
  select l.*, o.navn as orgnavn, o.orgnr
    into r
    from innmelding_lenker l
    join organizations o on o.id = l.organization_id
   where l.slug = lower(trim(p_slug));

  if not found then
    return jsonb_build_object('funnet', false);
  end if;

  return jsonb_build_object(
    'funnet', true,
    'aapen', r.aapen,
    'klubb', r.orgnavn,
    'orgnr', r.orgnr,
    'tittel', coalesce(r.tittel, 'Innmelding — familiemedlemskap'),
    'ingress', r.ingress,
    'gratis_drakt', r.gratis_drakt,
    'krev_fodselsnummer', r.krev_fodselsnummer,
    'grener', to_jsonb(r.grener)
  );
end;
$$;
grant execute on function innmelding_skjema(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 7. Innsending
-- ---------------------------------------------------------------------

create or replace function send_innmelding(
  p_slug     text,
  p_familie  jsonb,
  p_personer jsonb
) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  l           innmelding_lenker%rowtype;
  ny_id       uuid;
  ref         text;
  p           jsonb;
  i           int := 0;
  antall      int;
  fnr         text;
  fdato       date;
  nylige      int;
  krev_fnr    boolean;
begin
  select * into l from innmelding_lenker where slug = lower(trim(p_slug));
  if not found then raise exception 'Fant ikke innmeldingsskjemaet.'; end if;
  if not l.aapen then raise exception 'Innmeldingen er stengt for øyeblikket.'; end if;
  krev_fnr := l.krev_fodselsnummer;

  -- Enkel bremse mot søppel: maks 20 innsendinger per klubb per time.
  select count(*) into nylige
    from innmeldinger
   where organization_id = l.organization_id
     and innsendt > now() - interval '1 hour';
  if nylige >= 20 then
    raise exception 'For mange innmeldinger på kort tid. Prøv igjen om en stund.';
  end if;

  antall := jsonb_array_length(coalesce(p_personer, '[]'::jsonb));
  if antall < 1 then raise exception 'Legg inn minst én person.'; end if;
  if antall > 15 then raise exception 'Maks 15 personer i én innmelding.'; end if;

  if coalesce(trim(p_familie->>'etternavn'), '') = '' then raise exception 'Familienavn mangler.'; end if;
  if coalesce(trim(p_familie->>'kontakt_navn'), '') = '' then raise exception 'Navnet på foresatt/kontaktperson mangler.'; end if;
  if coalesce(trim(p_familie->>'adresse'), '') = '' then raise exception 'Adresse mangler.'; end if;
  if coalesce(trim(p_familie->>'postnr'), '') !~ '^\d{4}$' then raise exception 'Postnummer må være fire siffer.'; end if;
  if coalesce(trim(p_familie->>'sted'), '') = '' then raise exception 'Poststed mangler.'; end if;
  if coalesce(trim(p_familie->>'kontakt_epost'), '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-postadressen ser ikke riktig ut.'; end if;
  if coalesce(regexp_replace(p_familie->>'kontakt_telefon', '\D', '', 'g'), '') !~ '^\d{8,15}$' then raise exception 'Telefonnummeret ser ikke riktig ut.'; end if;

  ref := 'INN-' || to_char(now(), 'YYYY') || '-' ||
         upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));

  insert into innmeldinger (
    organization_id, referanse, familienavn, adresse, postnr, sted,
    kontakt_navn, kontakt_epost, kontakt_telefon, notat
  ) values (
    l.organization_id, ref,
    'Familien ' || trim(p_familie->>'etternavn'),
    trim(p_familie->>'adresse'),
    trim(p_familie->>'postnr'),
    trim(p_familie->>'sted'),
    trim(p_familie->>'kontakt_navn'),
    lower(trim(p_familie->>'kontakt_epost')),
    trim(p_familie->>'kontakt_telefon'),
    nullif(trim(coalesce(p_familie->>'notat', '')), '')
  ) returning id into ny_id;

  for p in select * from jsonb_array_elements(p_personer) loop
    i := i + 1;

    if coalesce(trim(p->>'fornavn'), '') = '' or coalesce(trim(p->>'etternavn'), '') = '' then
      raise exception 'Person %: navn mangler.', i;
    end if;
    if coalesce(p->>'rolle', '') not in ('voksen','barn') then
      raise exception 'Person %: mangler om det er voksen eller barn.', i;
    end if;

    fnr := regexp_replace(coalesce(p->>'fodselsnummer', ''), '\s', '', 'g');

    if fnr = '' then
      if krev_fnr then
        raise exception 'Person %: fødselsnummer mangler.', i;
      end if;
      fdato := (p->>'fodselsdato')::date;
      if fdato is null then raise exception 'Person %: fødselsdato mangler.', i; end if;
    else
      if not fnr_gyldig(fnr) then
        raise exception 'Person %: fødselsnummeret er ikke gyldig. Sjekk sifrene.', i;
      end if;
      fdato := fnr_fodselsdato(fnr);
    end if;

    if fdato > current_date then raise exception 'Person %: fødselsdato er i fremtiden.', i; end if;

    insert into innmelding_personer (
      innmelding_id, organization_id, sortering, rolle, fornavn, etternavn,
      fodselsdato, fnr_kryptert, fnr_maskert, epost, telefon,
      draktstorrelse, gren, samtykke_bilder
    ) values (
      ny_id, l.organization_id, i,
      p->>'rolle', trim(p->>'fornavn'), trim(p->>'etternavn'),
      fdato,
      case when fnr = '' then null else krypter_fnr(fnr) end,
      case when fnr = '' then to_char(fdato, 'DDMMYY') || ' —' else fnr_maskert(fnr) end,
      nullif(lower(trim(coalesce(p->>'epost', ''))), ''),
      nullif(trim(coalesce(p->>'telefon', '')), ''),
      nullif(trim(coalesce(p->>'draktstorrelse', '')), ''),
      nullif(trim(coalesce(p->>'gren', '')), ''),
      coalesce((p->>'samtykke_bilder')::boolean, false)
    );
  end loop;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (l.organization_id, null, 'innmeldinger', ny_id::text, 'mottatt',
          jsonb_build_object('referanse', ref, 'antall_personer', antall));

  return jsonb_build_object('ok', true, 'referanse', ref, 'antall', antall);
end;
$$;
grant execute on function send_innmelding(text, jsonb, jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Oppslag av fødselsnummer — alltid logget
-- ---------------------------------------------------------------------

create or replace function les_fodselsnummer(p_person_id uuid)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  rad innmelding_personer%rowtype;
  n   text;
  klar text;
begin
  select * into rad from innmelding_personer where id = p_person_id;
  if not found then raise exception 'Fant ikke personen.'; end if;
  if not kan_medlem(rad.organization_id) then
    raise exception 'Du har ikke tilgang til å se fødselsnummer.';
  end if;
  if rad.fnr_kryptert is null then return null; end if;

  select nokkel into n from krypto_nokler where navn = 'fodselsnummer';
  klar := pgp_sym_decrypt(rad.fnr_kryptert, n);

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (rad.organization_id, auth.uid(), 'innmelding_personer', p_person_id::text, 'lest_fodselsnummer',
          jsonb_build_object('navn', rad.fornavn || ' ' || rad.etternavn));

  return klar;
end;
$$;
grant execute on function les_fodselsnummer(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Godkjenning — oppretter familie og medlemmer
-- ---------------------------------------------------------------------

create or replace function godkjenn_innmelding(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  inm      innmeldinger%rowtype;
  fam_id   uuid;
  p        innmelding_personer%rowtype;
  ny_med   uuid;
  antall   int := 0;
  foresatt text;
  f_tlf    text;
  f_epost  text;
begin
  select * into inm from innmeldinger where id = p_id;
  if not found then raise exception 'Fant ikke innmeldingen.'; end if;
  if not kan_medlem(inm.organization_id) then
    raise exception 'Du har ikke tilgang til å godkjenne innmeldinger.';
  end if;
  if inm.status = 'godkjent' then raise exception 'Innmeldingen er allerede godkjent.'; end if;

  insert into families (organization_id, navn, hovedkontakt_epost, hovedkontakt_telefon)
  values (inm.organization_id, inm.familienavn, inm.kontakt_epost, inm.kontakt_telefon)
  returning id into fam_id;

  foresatt := inm.kontakt_navn;
  f_tlf    := inm.kontakt_telefon;
  f_epost  := inm.kontakt_epost;

  for p in select * from innmelding_personer where innmelding_id = p_id order by sortering loop
    insert into members (
      organization_id, fornavn, etternavn, fodselsdato,
      epost, telefon, adresse, postnr, sted,
      family_id, status,
      foresatt1_navn, foresatt1_epost, foresatt1_telefon,
      notat, opprettet_av
    ) values (
      inm.organization_id, p.fornavn, p.etternavn, p.fodselsdato,
      p.epost, p.telefon, inm.adresse, inm.postnr, inm.sted,
      fam_id, 'aktiv',
      case when p.rolle = 'barn' then foresatt end,
      case when p.rolle = 'barn' then f_epost end,
      case when p.rolle = 'barn' then f_tlf end,
      nullif(concat_ws(' · ',
        'Innmeldt via skjema ' || inm.referanse,
        nullif(p.gren, ''),
        case when p.draktstorrelse is not null then 'Draktstørrelse ' || p.draktstorrelse end,
        case when p.samtykke_bilder then 'Samtykke bilder: ja' else 'Samtykke bilder: nei' end
      ), ''),
      auth.uid()
    ) returning id into ny_med;

    update innmelding_personer
       set member_id = ny_med,
           fnr_kryptert = null,
           fnr_maskert = 'slettet ved godkjenning'
     where id = p.id;

    antall := antall + 1;
  end loop;

  update innmeldinger
     set status = 'godkjent', behandlet = now(), behandlet_av = auth.uid(), family_id = fam_id
   where id = p_id;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (inm.organization_id, auth.uid(), 'innmeldinger', p_id::text, 'godkjent',
          jsonb_build_object('referanse', inm.referanse, 'family_id', fam_id, 'antall_medlemmer', antall));

  return jsonb_build_object('ok', true, 'family_id', fam_id, 'antall', antall);
end;
$$;
grant execute on function godkjenn_innmelding(uuid) to authenticated;

create or replace function avvis_innmelding(p_id uuid, p_grunn text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare inm innmeldinger%rowtype;
begin
  select * into inm from innmeldinger where id = p_id;
  if not found then raise exception 'Fant ikke innmeldingen.'; end if;
  if not kan_medlem(inm.organization_id) then
    raise exception 'Du har ikke tilgang til å behandle innmeldinger.';
  end if;

  update innmelding_personer
     set fnr_kryptert = null, fnr_maskert = 'slettet ved avvisning'
   where innmelding_id = p_id;

  update innmeldinger
     set status = 'avvist', behandlet = now(), behandlet_av = auth.uid(),
         avvist_grunn = nullif(trim(coalesce(p_grunn, '')), '')
   where id = p_id;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (inm.organization_id, auth.uid(), 'innmeldinger', p_id::text, 'avvist',
          jsonb_build_object('referanse', inm.referanse, 'grunn', p_grunn));

  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function avvis_innmelding(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 10. Oppbevaringstid: ubehandlede fødselsnummer slettes etter 90 dager
--     Kalles av en planlagt jobb, eller manuelt.
-- ---------------------------------------------------------------------

create or replace function rydd_gamle_innmeldinger()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update innmelding_personer p
     set fnr_kryptert = null, fnr_maskert = 'slettet etter 90 dager'
    from innmeldinger i
   where p.innmelding_id = i.id
     and p.fnr_kryptert is not null
     and i.innsendt < now() - interval '90 days';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function rydd_gamle_innmeldinger() from public, anon;

-- ---------------------------------------------------------------------
-- 11. Lenke for Skoger og Fjell kampsportklubb
-- ---------------------------------------------------------------------

insert into innmelding_lenker (organization_id, slug, tittel, ingress, gratis_drakt, grener)
select id, 'skoger-og-fjell',
       'Innmelding — familiemedlemskap',
       'Familiemedlemskap er gratis, og alle barn i familien får drakt uten kostnad. Fyll ut én gang for hele familien.',
       true,
       array['Kickboxing','Karate','Bryting']
  from organizations
 where orgnr = '912484335'
on conflict (organization_id) do nothing;

-- ---------------------------------------------------------------------
-- 12. Innstramming av rettigheter
--     Supabase gir anon og authenticated SELECT på alle tabeller i public
--     og EXECUTE på alle funksjoner som standard. Rad-nivå-sikkerheten
--     stopper radene uansett, men rettigheten tas bort i tillegg, slik at
--     et glemt policy-hull aldri kan bli til et datautslipp.
-- ---------------------------------------------------------------------

revoke all on krypto_nokler        from anon, authenticated;
revoke all on innmeldinger         from anon;
revoke all on innmelding_personer  from anon;
revoke all on innmelding_lenker    from anon;

revoke execute on function les_fodselsnummer(uuid)      from public, anon;
revoke execute on function godkjenn_innmelding(uuid)    from public, anon;
revoke execute on function avvis_innmelding(uuid, text) from public, anon;
revoke execute on function rydd_gamle_innmeldinger()    from public, anon, authenticated;
revoke execute on function krypter_fnr(text)            from public, anon, authenticated;

grant execute on function les_fodselsnummer(uuid)             to authenticated;
grant execute on function godkjenn_innmelding(uuid)           to authenticated;
grant execute on function avvis_innmelding(uuid, text)        to authenticated;
grant execute on function send_innmelding(text, jsonb, jsonb) to anon, authenticated;
grant execute on function innmelding_skjema(text)             to anon, authenticated;
