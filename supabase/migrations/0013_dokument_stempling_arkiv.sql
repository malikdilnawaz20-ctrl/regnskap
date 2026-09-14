-- =====================================================================
--  0013 — Stempling av dokumenter som allerede lå i arkivet
--
--  0012 ga alle dokumenter et saksflytnummer, men stemplet bare filene
--  som ble lastet opp etterpå. Arkivet skal stemples det også.
--
--  Når en gammel fil stemples, lastes den stemplede versjonen opp på en
--  ny sti og blir dokumentets fil. Den opprinnelige filen blir liggende
--  urørt i lagringen, og stien til den tas vare på her. Det er billig,
--  og det gjør at en feilstempling kan rulles tilbake uten at noe er
--  tapt — filen er tross alt klubbens original.
-- =====================================================================

alter table documents
  add column if not exists original_path text,
  add column if not exists stemplet_tid  timestamptz;

comment on column documents.original_path is
  'Stien til filen slik den ble lastet opp, før stempling. NULL når filen aldri er stemplet i ettertid.';
comment on column documents.stemplet_tid is
  'Når nummeret ble trykket inn i filen.';

-- Stemplingen skal aldri kunne gå baklengs: er originalstien først
-- lagret, blir den stående, så en dobbeltstempling ikke overskriver
-- den med den allerede stemplede versjonen.
create or replace function vern_saksflytnummer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.saksflytnr is not null and new.saksflytnr is distinct from old.saksflytnr then
    raise exception 'Saksflytnummeret følger dokumentet og kan ikke endres.';
  end if;
  if old.original_path is not null and new.original_path is distinct from old.original_path then
    new.original_path := old.original_path;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
--  Kontroll
-- ---------------------------------------------------------------------
--  select saksflytnr, tittel, filnavn, stemplet, stemplet_tid,
--         original_path is not null as har_original
--    from documents order by opprettet;
--
--  select count(*) filter (where not stemplet and storage_path is not null) as gjenstaar
--    from documents;
