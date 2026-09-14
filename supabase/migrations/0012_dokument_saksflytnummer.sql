-- =====================================================================
--  0012 — Saksflytnummer på dokumenter
--
--  Hvert dokument i arkivet får sitt eget nummer:
--
--      SF-7K3M-92Q4
--
--  Åtte tegn fra et alfabet uten I, L, O, U, 0 og 1, så ingen leser
--  en O som en null eller en I som en ener når nummeret skrives av.
--  30^8 ≈ 656 milliarder kombinasjoner.
--
--  Tegnene trekkes med gen_random_bytes, ikke random(). random() er en
--  pseudotilfeldig rekke med en tilstand som kan utledes av tidligere
--  trekk — den som har sett noen nummer kunne regnet seg fram til de
--  neste. gen_random_bytes henter fra operativsystemets kryptografiske
--  kilde, og gir ingen slik åpning. Det er hele poenget her: nummeret
--  skal ikke kunne gjettes.
--
--  Nummeret er unikt på tvers av alle organisasjoner, ikke bare innen
--  én. To klubber i samme installasjon kan aldri få samme nummer.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Felter
-- ---------------------------------------------------------------------

alter table documents
  add column if not exists saksflytnr text,
  add column if not exists stemplet   boolean not null default false;

create unique index if not exists documents_saksflytnr_unik
  on documents (saksflytnr) where saksflytnr is not null;

comment on column documents.saksflytnr is
  'Dokumentets eget nummer, SF-XXXX-XXXX. Tildeles automatisk, gjenbrukes aldri.';
comment on column documents.stemplet is
  'Sann når nummeret er trykket inn i selve filen. Usann når det bare står i Saksflyt.';

-- ---------------------------------------------------------------------
--  2. Generatoren
--
--  Forkastningsutvalg: byteverdier fra 240 og opp hoppes over, slik at
--  alle 30 tegn er like sannsynlige. Uten det ville de seks første
--  tegnene i alfabetet kommet litt oftere enn resten (256 mod 30 = 16),
--  og et skjevt alfabet er et alfabet som lar seg gjette litt lettere.
-- ---------------------------------------------------------------------

create or replace function nytt_saksflytnummer()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  alfabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  n       constant int  := 30;
  tegn text; kode text; b bytea; i int; forsok int := 0;
begin
  loop
    forsok := forsok + 1;

    tegn := '';
    while length(tegn) < 8 loop
      b := gen_random_bytes(16);
      for i in 0..15 loop
        exit when length(tegn) >= 8;
        if get_byte(b, i) < 240 then
          tegn := tegn || substr(alfabet, (get_byte(b, i) % n) + 1, 1);
        end if;
      end loop;
    end loop;

    kode := 'SF-' || substr(tegn, 1, 4) || '-' || substr(tegn, 5, 4);

    exit when not exists (select 1 from documents where saksflytnr = kode);

    if forsok >= 25 then
      raise exception 'Fant ikke et ledig saksflytnummer etter 25 forsøk.';
    end if;
  end loop;

  return kode;
end;
$$;

comment on function nytt_saksflytnummer() is
  'Trekker et ubrukt saksflytnummer. Kalles av appen før opplasting, så nummeret kan stemples inn i filen.';

-- ---------------------------------------------------------------------
--  3. Tildeling
--
--  Appen henter nummeret først, fordi det skal trykkes inn i filen før
--  den lastes opp. Triggeren er sikkerhetsnettet: kommer et dokument
--  inn uten nummer — fra en import, en annen klient, SQL-editoren —
--  får det ett likevel.
-- ---------------------------------------------------------------------

create or replace function sett_saksflytnummer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.saksflytnr is null or btrim(new.saksflytnr) = '' then
    new.saksflytnr := nytt_saksflytnummer();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_saksflytnr on documents;
create trigger trg_saksflytnr before insert on documents
  for each row execute function sett_saksflytnummer();

-- Nummeret følger dokumentet. Det kan ikke byttes etterpå.
create or replace function vern_saksflytnummer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.saksflytnr is not null and new.saksflytnr is distinct from old.saksflytnr then
    raise exception 'Saksflytnummeret følger dokumentet og kan ikke endres.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_vern_saksflytnr on documents;
create trigger trg_vern_saksflytnr before update on documents
  for each row execute function vern_saksflytnummer();

-- ---------------------------------------------------------------------
--  4. Dokumentene som allerede ligger i arkivet
--
--  De får nummer i Saksflyt. Filene deres stemples ikke — de er lastet
--  opp for lenge siden, og stemplet ville ikke stemt med det de som har
--  en kopi liggende allerede har sett.
-- ---------------------------------------------------------------------

do $$
declare r record; ant int := 0;
begin
  for r in select id from documents where saksflytnr is null order by opprettet loop
    update documents set saksflytnr = nytt_saksflytnummer() where id = r.id;
    ant := ant + 1;
  end loop;
  raise notice 'Ga saksflytnummer til % dokument(er).', ant;
end $$;

-- ---------------------------------------------------------------------
--  Kontroll etter kjøring
-- ---------------------------------------------------------------------
--  select saksflytnr, stemplet, mappe, tittel, opprettet
--    from documents order by opprettet;
--
--  select count(*) as uten_nummer from documents where saksflytnr is null;
--  -- forventet: 0
