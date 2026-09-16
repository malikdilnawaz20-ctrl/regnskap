-- =====================================================================
--  0015 — Sletting av dokumenter i arkivet
--
--  Administratorer har alltid kunnet slette rader i documents
--  (documents_slett i 0001), men grensesnittet hadde ingen knapp, og
--  lagringen hadde ingen regel som lot filene fjernes. Denne
--  migrasjonen gjør sletting trygg nok til å slås på:
--
--    1. Et slettet saksflytnummer blir stående i slettede_saksflytnr,
--       så det aldri kan deles ut på nytt til et annet dokument.
--    2. Slettingen skrives i revisjonsloggen med hele raden som den var.
--    3. Administratorer kan fjerne filene fra bøtta «dokumenter» —
--       bare i sin egen organisasjons mappe.
--
--  Kan kjøres flere ganger.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Nummer som er brukt og slettet
-- ---------------------------------------------------------------------

create table if not exists slettede_saksflytnr (
  saksflytnr      text primary key,
  -- Bevisst uten fremmednøkkel: nummeret skal være sperret også etter at
  -- organisasjonen er borte, og en fremmednøkkel ville stoppet sletting
  -- av en organisasjon (dokumentene slettes da i samme operasjon).
  organization_id uuid not null,
  document_id     uuid not null,
  tittel          text,
  filnavn         text,
  mappe           text,
  slettet_av      uuid references profiles(id) on delete set null,
  slettet_tid     timestamptz not null default now()
);
alter table slettede_saksflytnr
  drop constraint if exists slettede_saksflytnr_organization_id_fkey;
create index if not exists slettede_saksflytnr_org_idx
  on slettede_saksflytnr (organization_id, slettet_tid desc);

comment on table slettede_saksflytnr is
  'Saksflytnummer som har tilhørt et slettet dokument. Nummeret gjenbrukes aldri.';

alter table slettede_saksflytnr enable row level security;

drop policy if exists slettede_saksflytnr_les on slettede_saksflytnr;
create policy slettede_saksflytnr_les on slettede_saksflytnr
  for select using (er_medlem_av(organization_id));
-- Bevisst: ingen INSERT/UPDATE/DELETE-policy. Bare triggeren skriver.

create or replace function husk_slettet_saksflytnr()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.saksflytnr is not null then
    insert into slettede_saksflytnr
      (saksflytnr, organization_id, document_id, tittel, filnavn, mappe, slettet_av)
    values
      (old.saksflytnr, old.organization_id, old.id, old.tittel, old.filnavn, old.mappe, auth.uid())
    on conflict (saksflytnr) do nothing;
  end if;
  return old;
end;
$$;

drop trigger if exists trg_husk_slettet_saksflytnr on documents;
create trigger trg_husk_slettet_saksflytnr before delete on documents
  for each row execute function husk_slettet_saksflytnr();

-- Generatoren hopper nå også over nummer som har tilhørt slettede dokumenter.
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

    exit when not exists (select 1 from documents where saksflytnr = kode)
          and not exists (select 1 from slettede_saksflytnr where saksflytnr = kode);

    if forsok >= 25 then
      raise exception 'Fant ikke et ledig saksflytnummer etter 25 forsøk.';
    end if;
  end loop;

  return kode;
end;
$$;

-- ---------------------------------------------------------------------
--  2. Revisjonslogg
-- ---------------------------------------------------------------------

drop trigger if exists trg_logg_documents on documents;
create trigger trg_logg_documents after delete on documents
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
--  3. Filene
--
--  Samme mønster som lese- og opplastingsreglene i OPPSETT.md: første
--  ledd i stien er organisasjonens id. Bare administratorer sletter,
--  og bare i bøtta «dokumenter» — bilag røres ikke.
-- ---------------------------------------------------------------------

drop policy if exists "admin sletter dokumentfiler" on storage.objects;
create policy "admin sletter dokumentfiler" on storage.objects for delete
  using (bucket_id = 'dokumenter'
         and kan_admin(((storage.foldername(name))[1])::uuid));

-- ---------------------------------------------------------------------
--  Kontroll etter kjøring
-- ---------------------------------------------------------------------
--  select policyname from pg_policies
--   where tablename in ('objects','slettede_saksflytnr');
--  select tgname from pg_trigger
--   where tgrelid = 'documents'::regclass and not tgisinternal;
