-- =====================================================================
--  0017 — Elektronisk signatur på dokumenter i arkivet
--
--  Styreprotokoller og andre dokumenter kan signeres inne i Saksflyt.
--  To måter:
--
--    1. Fullmektig på vegne av styret. Styret har gitt en person
--       fullmakt ved vedtak (tabellen mandates). Vedkommende signerer
--       ut hele protokollen alene. Administrator kan alltid gjøre det
--       samme — det står ingenting om det i grensesnittet, men
--       revisjonsloggen viser hva som skjedde, akkurat som ved
--       attestering.
--
--    2. Hvert styremedlem selv. Dokumentet sendes til utvalgte
--       personer, og hver av dem signerer. Ferdig når alle har signert.
--
--  To datoer, alltid begge:
--    signaturdato      — datoen som står på dokumentet (møtedatoen).
--                        Velges av den som signerer. Aldri frem i tid.
--    signert_tidspunkt — når det faktisk skjedde. Settes av databasen.
--
--  Reglene håndheves her, ikke i grensesnittet. Signaturer kan aldri
--  endres eller slettes. Et ferdig signert dokument låses.
--
--  Kan kjøres flere ganger.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Dokumentet
-- ---------------------------------------------------------------------

alter table documents
  add column if not exists dokumentdato date,
  add column if not exists laast        boolean not null default false,
  add column if not exists signert_path text,
  add column if not exists signert_tid  timestamptz;

comment on column documents.dokumentdato is 'Møtedato eller datoen dokumentet gjelder. Nedre grense for signaturdato.';
comment on column documents.laast is 'Sann når dokumentet er ferdig signert. Kan ikke settes tilbake.';
comment on column documents.signert_path is 'Sti til den signerte PDF-en (originalen med signaturside) i bøtta dokumenter.';

-- ---------------------------------------------------------------------
--  2. Fullmakter — et vedtak med gyldighetsperiode, ikke en rolle
-- ---------------------------------------------------------------------

create table if not exists mandates (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id         uuid not null references profiles(id) on delete cascade,
  nummer          text,                      -- SFK-F-2026-01, settes av trigger
  vedtak          text not null,             -- «Styrevedtak sak 12/2026»
  vedtaksdato     date not null,
  vedtak_document_id uuid references documents(id) on delete set null,
  gyldig_fra      date not null default current_date,
  gyldig_til      date,                      -- NULL = inntil videre
  omfang          text not null default 'styreprotokoll'
                  check (omfang in ('styreprotokoll','aarsmoteprotokoll','alle_dokumenter')),
  trukket_tilbake timestamptz,
  trukket_av      uuid references profiles(id),
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  check (gyldig_til is null or gyldig_til >= gyldig_fra)
);
create index if not exists mandates_org_idx on mandates(organization_id, user_id);
create unique index if not exists mandates_nummer_unik on mandates(organization_id, nummer);

comment on table mandates is 'Fullmakt fra styret til én person om å signere dokumenter på styrets vegne.';

-- Fullmaktsnummer: F-<år>-<løpenummer> per organisasjon
create or replace function sett_fullmaktsnummer()
returns trigger language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not exists (select 1 from organization_users ou
                  where ou.organization_id = new.organization_id and ou.user_id = new.user_id and ou.aktiv) then
    raise exception 'Fullmektig må være en aktiv bruker i organisasjonen.';
  end if;
  if new.nummer is null then
    select coalesce(max(substring(nummer from '\d+$')::int), 0) + 1 into n
      from mandates
     where organization_id = new.organization_id
       and nummer like 'F-' || extract(year from new.vedtaksdato)::text || '-%';
    new.nummer := 'F-' || extract(year from new.vedtaksdato)::text || '-' || lpad(n::text, 2, '0');
  end if;
  new.opprettet_av := coalesce(new.opprettet_av, auth.uid());
  return new;
end;
$$;
drop trigger if exists trg_fullmaktsnummer on mandates;
create trigger trg_fullmaktsnummer before insert on mandates
  for each row execute function sett_fullmaktsnummer();

-- En fullmakt endres ikke etter at den er gitt. Den kan bare trekkes
-- tilbake, og det kan bare skje én gang.
create or replace function vern_fullmakt()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.trukket_tilbake is not null then
    raise exception 'Fullmakten er trukket tilbake og kan ikke endres.';
  end if;
  if new.trukket_tilbake is null then
    raise exception 'En fullmakt kan ikke redigeres. Trekk den tilbake og registrer en ny.';
  end if;
  -- Bare tilbaketrekkingen får endres
  new.user_id := old.user_id;           new.nummer := old.nummer;
  new.vedtak := old.vedtak;             new.vedtaksdato := old.vedtaksdato;
  new.gyldig_fra := old.gyldig_fra;     new.gyldig_til := old.gyldig_til;
  new.omfang := old.omfang;             new.opprettet_av := old.opprettet_av;
  new.opprettet := old.opprettet;       new.organization_id := old.organization_id;
  new.vedtak_document_id := old.vedtak_document_id;
  new.trukket_tilbake := now();
  new.trukket_av := auth.uid();
  return new;
end;
$$;
drop trigger if exists trg_vern_fullmakt on mandates;
create trigger trg_vern_fullmakt before update on mandates
  for each row execute function vern_fullmakt();

-- Hvilken aktiv fullmakt har den innloggede for et dokument i en gitt mappe?
create or replace function aktiv_fullmakt(org uuid, mappe text)
returns uuid language sql stable security definer set search_path = public as $$
  select m.id from mandates m
   where m.organization_id = org
     and m.user_id = auth.uid()
     and m.trukket_tilbake is null
     and m.gyldig_fra <= (now() at time zone 'Europe/Oslo')::date
     and (m.gyldig_til is null or m.gyldig_til >= (now() at time zone 'Europe/Oslo')::date)
     and (
       m.omfang = 'alle_dokumenter'
       or (m.omfang = 'styreprotokoll' and mappe = 'Styremøter')
       or (m.omfang = 'aarsmoteprotokoll' and mappe in ('Årsprotokoller','Ekstraordinære generalforsamlinger'))
     )
   order by m.gyldig_fra desc
   limit 1;
$$;

-- ---------------------------------------------------------------------
--  3. Signeringsforespørsel — én per dokument som sendes til signering
-- ---------------------------------------------------------------------

create table if not exists signature_requests (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  document_id     uuid not null references documents(id) on delete cascade,
  type            text not null check (type in ('fullmektig','styremedlemmer')),
  status          text not null default 'venter'
                  check (status in ('venter','delvis','fullfort','avvist','trukket')),
  dokument_hash   text,                      -- SHA-256 av filen da den ble sendt
  melding         text,
  avvist_av       uuid references profiles(id),
  avvist_arsak    text,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  fullfort        timestamptz
);
create index if not exists sr_org_idx on signature_requests(organization_id, status);
create index if not exists sr_doc_idx on signature_requests(document_id);

-- Hvem skal signere når type = styremedlemmer
create table if not exists signature_request_recipients (
  request_id      uuid not null references signature_requests(id) on delete cascade,
  user_id         uuid not null references profiles(id) on delete cascade,
  primary key (request_id, user_id)
);

create or replace function vern_ny_signeringsforesporsel()
returns trigger language plpgsql security definer set search_path = public as $$
declare d documents%rowtype;
begin
  select * into d from documents where id = new.document_id;
  if d.id is null or d.organization_id <> new.organization_id then
    raise exception 'Dokumentet finnes ikke i denne organisasjonen.';
  end if;
  if d.laast then
    raise exception 'Dokumentet er allerede signert og låst.';
  end if;
  if exists (select 1 from signature_requests r
              where r.document_id = new.document_id and r.status in ('venter','delvis')) then
    raise exception 'Dokumentet er allerede sendt til signering.';
  end if;
  new.opprettet_av := auth.uid();
  new.status := 'venter';
  new.fullfort := null;
  return new;
end;
$$;
drop trigger if exists trg_vern_ny_sr on signature_requests;
create trigger trg_vern_ny_sr before insert on signature_requests
  for each row execute function vern_ny_signeringsforesporsel();

-- Oppdateringer utenfra: bare trekke tilbake (uten signaturer) eller avvise.
-- Statusendringer til delvis/fullført gjøres av signaturtriggeren, som
-- setter en sesjonsvariabel så denne vernet slipper den gjennom.
create or replace function vern_endring_signeringsforesporsel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('saksflyt.intern', true) = 'ja' then
    return new;
  end if;
  if old.status not in ('venter','delvis') then
    raise exception 'Forespørselen er avsluttet og kan ikke endres.';
  end if;
  if new.status = 'trukket' then
    if exists (select 1 from signatures s where s.request_id = old.id) then
      raise exception 'Forespørselen har allerede signaturer og kan ikke trekkes. Avvis den i stedet.';
    end if;
    if old.opprettet_av <> auth.uid() and not kan_admin(old.organization_id) then
      raise exception 'Bare den som sendte forespørselen, eller administrator, kan trekke den.';
    end if;
  elsif new.status = 'avvist' then
    if not (kan_admin(old.organization_id)
            or exists (select 1 from signature_request_recipients m where m.request_id = old.id and m.user_id = auth.uid())
            or (old.type = 'fullmektig' and aktiv_fullmakt(old.organization_id,
                  (select mappe from documents where id = old.document_id)) is not null)) then
      raise exception 'Du er ikke bedt om å signere dette dokumentet.';
    end if;
    new.avvist_av := auth.uid();
    if coalesce(new.avvist_arsak, '') = '' then
      raise exception 'Skriv hvorfor dokumentet avvises.';
    end if;
  else
    raise exception 'Forespørselen kan bare trekkes eller avvises.';
  end if;
  new.fullfort := now();
  -- alt annet står
  new.type := old.type; new.document_id := old.document_id; new.dokument_hash := old.dokument_hash;
  new.organization_id := old.organization_id; new.opprettet_av := old.opprettet_av; new.opprettet := old.opprettet;
  new.melding := old.melding;
  if new.status = 'trukket' then new.avvist_av := old.avvist_av; new.avvist_arsak := old.avvist_arsak; end if;
  return new;
end;
$$;
drop trigger if exists trg_vern_endring_sr on signature_requests;
create trigger trg_vern_endring_sr before update on signature_requests
  for each row execute function vern_endring_signeringsforesporsel();

-- ---------------------------------------------------------------------
--  4. Signaturer — én rad per person. Skrives én gang, aldri endret.
-- ---------------------------------------------------------------------

create table if not exists signatures (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references organizations(id) on delete cascade,
  request_id        uuid not null references signature_requests(id) on delete cascade,
  document_id       uuid not null references documents(id) on delete cascade,
  user_id           uuid not null references profiles(id),   -- bevisst uten on delete: en signatur overlever ikke uten personen, og personen kan da ikke slettes
  signert_som       text not null check (signert_som in ('styremedlem','fullmektig_for_styret','administrator')),
  navn_tekst        text not null,           -- fryses ved signering
  rolle_tekst       text,                    -- «Styreleder», «Daglig leder» — fryses
  mandate_id        uuid references mandates(id),
  signaturdato      date not null,           -- datoen som vises på dokumentet
  signert_tidspunkt timestamptz not null default now(),  -- faktisk tidspunkt, server
  signatur_id       text not null unique,    -- SIG-XXXX-XXXX
  dokument_hash     text,
  nivaa             text not null default 'intern' check (nivaa in ('intern','bankid')),
  user_agent        text,
  unique (request_id, user_id)
);
create index if not exists signatures_doc_idx on signatures(document_id);

-- Samme alfabet og samme kilde som saksflytnummeret (se 0012).
create or replace function nytt_signaturnummer()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  alfabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  tegn text; b bytea; i int; v int; kode text;
begin
  loop
    tegn := '';
    while length(tegn) < 8 loop
      b := gen_random_bytes(16);
      for i in 0..15 loop
        v := get_byte(b, i);
        if v < 240 and length(tegn) < 8 then
          tegn := tegn || substr(alfabet, (v % 30) + 1, 1);
        end if;
      end loop;
    end loop;
    kode := 'SIG-' || substr(tegn, 1, 4) || '-' || substr(tegn, 5, 4);
    exit when not exists (select 1 from signatures where signatur_id = kode);
  end loop;
  return kode;
end;
$$;

create or replace function vern_signatur()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r signature_requests%rowtype;
  d documents%rowtype;
  p profiles%rowtype;
  ou organization_users%rowtype;
  fm uuid;
begin
  select * into r from signature_requests where id = new.request_id;
  if r.id is null then raise exception 'Fant ikke signeringsforespørselen.'; end if;
  if r.status not in ('venter','delvis') then
    raise exception 'Forespørselen er avsluttet. Dokumentet kan ikke signeres.';
  end if;
  select * into d from documents where id = r.document_id;
  if d.laast then raise exception 'Dokumentet er allerede låst.'; end if;

  -- Hvem som signerer bestemmes av innloggingen, ikke av raden
  new.user_id := auth.uid();
  if new.user_id is null then raise exception 'Du må være innlogget for å signere.'; end if;
  new.organization_id := r.organization_id;
  new.document_id := r.document_id;
  if not er_medlem_av(r.organization_id) then
    raise exception 'Du har ikke tilgang til denne organisasjonen.';
  end if;

  -- Hva signerer de som?
  if new.signert_som = 'styremedlem' then
    if r.type <> 'styremedlemmer' then
      raise exception 'Dette dokumentet skal signeres av fullmektig på vegne av styret.';
    end if;
    if not exists (select 1 from signature_request_recipients m where m.request_id = r.id and m.user_id = new.user_id) then
      raise exception 'Du står ikke på listen over hvem som skal signere dette dokumentet.';
    end if;
    new.mandate_id := null;
  elsif new.signert_som = 'fullmektig_for_styret' then
    if r.type <> 'fullmektig' then
      raise exception 'Dette dokumentet skal signeres av hvert styremedlem.';
    end if;
    fm := aktiv_fullmakt(r.organization_id, d.mappe);
    if fm is null then
      raise exception 'Du har ingen gyldig fullmakt til å signere dokumenter i mappen «%».', d.mappe;
    end if;
    new.mandate_id := fm;
  elsif new.signert_som = 'administrator' then
    if r.type <> 'fullmektig' then
      raise exception 'Dette dokumentet skal signeres av hvert styremedlem.';
    end if;
    if not kan_admin(r.organization_id) then
      raise exception 'Bare administrator kan signere uten fullmakt.';
    end if;
    new.mandate_id := null;
  end if;

  -- Datoen på dokumentet: aldri frem i tid, aldri før dokumentets egen dato
  -- Norsk dato, ikke serverens UTC-dato: rett etter midnatt er «i dag» ellers i morgen.
  if new.signaturdato is null then new.signaturdato := (now() at time zone 'Europe/Oslo')::date; end if;
  if new.signaturdato > (now() at time zone 'Europe/Oslo')::date then
    raise exception 'Signaturdatoen kan ikke være frem i tid.';
  end if;
  if d.dokumentdato is not null and new.signaturdato < d.dokumentdato then
    raise exception 'Signaturdatoen kan ikke være før dokumentets dato (%).', to_char(d.dokumentdato, 'DD.MM.YYYY');
  end if;

  -- Frys navn og rolle slik de var i signeringsøyeblikket
  select * into p from profiles where id = new.user_id;
  select * into ou from organization_users where organization_id = r.organization_id and user_id = new.user_id and aktiv;
  new.navn_tekst := coalesce(nullif(trim(coalesce(p.fornavn,'') || ' ' || coalesce(p.etternavn,'')), ''), p.epost::text, 'Ukjent');
  new.rolle_tekst := coalesce(nullif(ou.styreverv, ''), nullif(ou.tittel, ''), initcap(ou.rolle::text));

  new.signert_tidspunkt := now();
  new.signatur_id := nytt_signaturnummer();
  new.dokument_hash := r.dokument_hash;
  new.nivaa := 'intern';
  return new;
end;
$$;
drop trigger if exists trg_vern_signatur on signatures;
create trigger trg_vern_signatur before insert on signatures
  for each row execute function vern_signatur();

-- Etter signering: oppdater forespørselen, lås dokumentet når alle har signert
create or replace function etter_signatur()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r signature_requests%rowtype;
  antall_mottakere int; antall_signert int; ferdig boolean;
begin
  select * into r from signature_requests where id = new.request_id;
  if r.type = 'fullmektig' then
    ferdig := true;
  else
    select count(*) into antall_mottakere from signature_request_recipients where request_id = r.id;
    select count(*) into antall_signert from signatures where request_id = r.id;
    ferdig := antall_signert >= antall_mottakere;
  end if;

  perform set_config('saksflyt.intern', 'ja', true);
  update signature_requests
     set status = case when ferdig then 'fullfort' else 'delvis' end,
         fullfort = case when ferdig then now() else null end
   where id = r.id;
  perform set_config('saksflyt.intern', 'nei', true);

  if ferdig then
    update documents set laast = true, signert_tid = now() where id = r.document_id;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_etter_signatur on signatures;
create trigger trg_etter_signatur after insert on signatures
  for each row execute function etter_signatur();

-- Signaturer kan aldri endres eller slettes — heller ikke av administrator.
create or replace function signatur_er_laast()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  raise exception 'En signatur kan ikke endres eller slettes.';
end;
$$;
drop trigger if exists trg_signatur_laast on signatures;
create trigger trg_signatur_laast before update or delete on signatures
  for each row execute function signatur_er_laast();

-- ---------------------------------------------------------------------
--  5. Låst dokument: innholdet står. Bare den signerte filen kan legges til.
-- ---------------------------------------------------------------------

create or replace function vern_laast_dokument()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.laast then
    if new.laast = false then
      raise exception 'Et signert dokument kan ikke låses opp. Last opp en ny versjon og signer den på nytt.';
    end if;
    if new.tittel is distinct from old.tittel or new.mappe is distinct from old.mappe
       or new.filnavn is distinct from old.filnavn or new.storage_path is distinct from old.storage_path
       or new.dokumentdato is distinct from old.dokumentdato or new.saksflytnr is distinct from old.saksflytnr then
      raise exception 'Dokumentet er signert og låst. Innholdet kan ikke endres.';
    end if;
    if old.signert_path is not null and new.signert_path is distinct from old.signert_path then
      raise exception 'Den signerte filen kan ikke byttes ut.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_vern_laast_dokument on documents;
create trigger trg_vern_laast_dokument before update on documents
  for each row execute function vern_laast_dokument();

-- ---------------------------------------------------------------------
--  6. Revisjonsspor
-- ---------------------------------------------------------------------

drop trigger if exists trg_logg_mandates on mandates;
create trigger trg_logg_mandates after insert or update or delete on mandates
  for each row execute function logg_endring();
drop trigger if exists trg_logg_sr on signature_requests;
create trigger trg_logg_sr after insert or update or delete on signature_requests
  for each row execute function logg_endring();
drop trigger if exists trg_logg_signatures on signatures;
create trigger trg_logg_signatures after insert on signatures
  for each row execute function logg_endring();
-- Dokumentlåsing skal også i loggen (0015 logger bare sletting)
drop trigger if exists trg_logg_documents_endring on documents;
create trigger trg_logg_documents_endring after update on documents
  for each row when (old.laast is distinct from new.laast or old.signert_path is distinct from new.signert_path)
  execute function logg_endring();

-- ---------------------------------------------------------------------
--  7. Tilgangsregler
-- ---------------------------------------------------------------------

alter table mandates enable row level security;
alter table signature_requests enable row level security;
alter table signature_request_recipients enable row level security;
alter table signatures enable row level security;

drop policy if exists mandates_les on mandates;
create policy mandates_les on mandates for select using (er_medlem_av(organization_id));
drop policy if exists mandates_skriv on mandates;
create policy mandates_skriv on mandates for insert with check (kan_admin(organization_id));
drop policy if exists mandates_endre on mandates;
create policy mandates_endre on mandates for update using (kan_admin(organization_id)) with check (kan_admin(organization_id));
-- Ingen delete-policy: fullmakter trekkes tilbake, de forsvinner ikke.

drop policy if exists sr_les on signature_requests;
create policy sr_les on signature_requests for select using (er_medlem_av(organization_id));
drop policy if exists sr_skriv on signature_requests;
create policy sr_skriv on signature_requests for insert
  with check (er_medlem_av(organization_id) and not har_rolle(organization_id, array['revisor']::user_role[]));
drop policy if exists sr_endre on signature_requests;
create policy sr_endre on signature_requests for update
  using (er_medlem_av(organization_id)) with check (er_medlem_av(organization_id));
-- Ingen delete-policy.

drop policy if exists srr_les on signature_request_recipients;
create policy srr_les on signature_request_recipients for select using (
  exists (select 1 from signature_requests r where r.id = request_id and er_medlem_av(r.organization_id)));
drop policy if exists srr_skriv on signature_request_recipients;
create policy srr_skriv on signature_request_recipients for insert with check (
  exists (select 1 from signature_requests r where r.id = request_id
            and er_medlem_av(r.organization_id) and r.status = 'venter'
            and (r.opprettet_av = auth.uid() or kan_admin(r.organization_id))));

drop policy if exists signatures_les on signatures;
create policy signatures_les on signatures for select using (er_medlem_av(organization_id));
drop policy if exists signatures_skriv on signatures;
create policy signatures_skriv on signatures for insert with check (
  exists (select 1 from signature_requests r where r.id = request_id and er_medlem_av(r.organization_id)));
-- Ingen update/delete-policy, og triggeren avviser uansett.

-- ---------------------------------------------------------------------
--  8. Offentlig verifisering — sakflyt.no/verifiser.html?id=SIG-XXXX-XXXX
--     Viser hvem som signerte hva og når, uten å vise dokumentet.
-- ---------------------------------------------------------------------

create or replace function verifiser_signatur(kode text)
returns table (
  signatur_id text, organisasjon text, orgnr text,
  dokument text, saksflytnr text, mappe text,
  navn text, rolle text, signert_som text, fullmakt text,
  signaturdato date, signert_tidspunkt timestamptz, dokument_hash text, nivaa text,
  antall_signaturer bigint, status text
) language sql stable security definer set search_path = public as $$
  select s.signatur_id, o.navn, o.orgnr,
         -- Dokumenter merket «kun styret» viser bare nummeret utad
         case when d.kun_styret then 'Dokument for styret' else d.tittel end, d.saksflytnr, d.mappe,
         s.navn_tekst, s.rolle_tekst, s.signert_som,
         case when m.id is not null then m.nummer || ' · ' || m.vedtak || ' (' || to_char(m.vedtaksdato, 'DD.MM.YYYY') || ')' end,
         s.signaturdato, s.signert_tidspunkt, s.dokument_hash, s.nivaa,
         (select count(*) from signatures x where x.request_id = s.request_id),
         r.status
    from signatures s
    join documents d on d.id = s.document_id
    join organizations o on o.id = s.organization_id
    join signature_requests r on r.id = s.request_id
    left join mandates m on m.id = s.mandate_id
   where upper(trim(kode)) = s.signatur_id;
$$;
revoke all on function verifiser_signatur(text) from public;
grant execute on function verifiser_signatur(text) to anon, authenticated;

-- ---------------------------------------------------------------------
--  Kontroll
-- ---------------------------------------------------------------------
--  select nummer, vedtak, gyldig_fra, gyldig_til, trukket_tilbake from mandates;
--  select r.status, d.tittel, count(s.*) from signature_requests r
--    join documents d on d.id = r.document_id left join signatures s on s.request_id = r.id
--   group by 1,2;
--  select * from verifiser_signatur('SIG-XXXX-XXXX');
