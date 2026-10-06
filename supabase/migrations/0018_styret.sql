-- =====================================================================
--  0018 — Styreregister
--
--  Hvem som sitter i styret, uavhengig av om de har brukerkonto i
--  Saksflyt. Når fullmektig signerer på vegne av styret, fryses
--  styresammensetningen på signaturen, slik at signatursiden og
--  verifiseringen viser hvem styret var den dagen.
--
--  Et styremedlem kan senere kobles til en bruker (user_id) hvis
--  vedkommende får innlogging og skal signere selv.
--
--  Kan kjøres flere ganger.
-- =====================================================================

create table if not exists board_members (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,
  verv            text not null default 'Styremedlem',
  user_id         uuid references profiles(id) on delete set null,
  fra             date,
  til             date,                       -- NULL = sitter fortsatt
  rekkefolge      int not null default 100,
  opprettet       timestamptz not null default now()
);
create index if not exists board_members_org_idx on board_members(organization_id, rekkefolge);
comment on table board_members is 'Styrets sammensetning. Trenger ikke brukerkonto.';

alter table board_members enable row level security;
drop policy if exists bm_les on board_members;
create policy bm_les on board_members for select using (er_medlem_av(organization_id));
drop policy if exists bm_skriv on board_members;
create policy bm_skriv on board_members for insert with check (kan_admin(organization_id));
drop policy if exists bm_endre on board_members;
create policy bm_endre on board_members for update using (kan_admin(organization_id)) with check (kan_admin(organization_id));
drop policy if exists bm_slett on board_members;
create policy bm_slett on board_members for delete using (kan_admin(organization_id));

drop trigger if exists trg_logg_board_members on board_members;
create trigger trg_logg_board_members after insert or update or delete on board_members
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
--  Signering i møte: iPaden går rundt bordet
--
--  Den som er innlogget (møteleder/sekretær) åpner dokumentet, og hvert
--  styremedlem trykker på sitt navn og signerer — gjerne med fingeren.
--  Styremedlemmet trenger ingen konto. Signaturen får board_member_id.
--  Hvem som holdt enheten vises ingen steder — ingen spør hvem som
--  holdt arket heller.
-- ---------------------------------------------------------------------

alter table signature_requests drop constraint if exists signature_requests_type_check;
alter table signature_requests add constraint signature_requests_type_check
  check (type in ('fullmektig','styremedlemmer','mote'));

-- Hva signeringen gjelder: «Årsmøte», «Styremøte», fritekst …
alter table signature_requests add column if not exists anledning text;
comment on column signature_requests.anledning is 'Hva signeringen gjelder, f.eks. Ekstraordinær generalforsamling. Vises på signatursiden og i verifiseringen.';

create table if not exists signature_request_board (
  request_id       uuid not null references signature_requests(id) on delete cascade,
  board_member_id  uuid not null references board_members(id) on delete cascade,
  primary key (request_id, board_member_id)
);
alter table signature_request_board enable row level security;
drop policy if exists srb_les on signature_request_board;
create policy srb_les on signature_request_board for select using (
  exists (select 1 from signature_requests r where r.id = request_id and er_medlem_av(r.organization_id)));
drop policy if exists srb_skriv on signature_request_board;
create policy srb_skriv on signature_request_board for insert with check (
  exists (select 1 from signature_requests r where r.id = request_id
            and er_medlem_av(r.organization_id) and r.status = 'venter'
            and (r.opprettet_av = auth.uid() or kan_admin(r.organization_id))));

alter table signatures drop constraint if exists signatures_signert_som_check;
alter table signatures add constraint signatures_signert_som_check
  check (signert_som in ('styremedlem','styremedlem_i_mote','fullmektig_for_styret','administrator'));
alter table signatures
  add column if not exists board_member_id    uuid references board_members(id),
  add column if not exists signaturbilde_path text;
comment on column signatures.signaturbilde_path is 'Håndtegnet signatur (PNG) i bøtta dokumenter, når den finnes.';

-- Én signatur per bruker per forespørsel gjelder ikke i møte: samme
-- innloggede bruker registrerer flere styremedlemmers signaturer.
alter table signatures drop constraint if exists signatures_request_id_user_id_key;
create unique index if not exists signatures_bruker_unik on signatures(request_id, user_id)
  where signert_som <> 'styremedlem_i_mote';
create unique index if not exists signatures_styremedlem_unik on signatures(request_id, board_member_id)
  where board_member_id is not null;

-- Styret slik det var da det ble signert på styrets vegne — fryses på signaturen
alter table signatures add column if not exists styret_tekst text;
comment on column signatures.styret_tekst is 'Styrets sammensetning på signeringsdagen, når det ble signert på vegne av styret.';

create or replace function styret_tekst(org uuid, dag date)
returns text language sql stable security definer set search_path = public as $$
  select string_agg(b.navn || ' (' || b.verv || ')', ', ' order by b.rekkefolge, b.navn)
    from board_members b
   where b.organization_id = org
     and (b.fra is null or b.fra <= dag)
     and (b.til is null or b.til >= dag);
$$;

-- vern_signatur() utvides: fryser styret ved signering på styrets vegne.
create or replace function vern_signatur()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r signature_requests%rowtype;
  d documents%rowtype;
  p profiles%rowtype;
  ou organization_users%rowtype;
  bm board_members%rowtype;
  fm uuid;
begin
  select * into r from signature_requests where id = new.request_id;
  if r.id is null then raise exception 'Fant ikke signeringsforespørselen.'; end if;
  if r.status not in ('venter','delvis') then
    raise exception 'Forespørselen er avsluttet. Dokumentet kan ikke signeres.';
  end if;
  select * into d from documents where id = r.document_id;
  if d.laast then raise exception 'Dokumentet er allerede låst.'; end if;

  new.user_id := auth.uid();
  if new.user_id is null then raise exception 'Du må være innlogget for å signere.'; end if;
  new.organization_id := r.organization_id;
  new.document_id := r.document_id;
  if not er_medlem_av(r.organization_id) then
    raise exception 'Du har ikke tilgang til denne organisasjonen.';
  end if;

  if new.signert_som = 'styremedlem_i_mote' then
    if r.type <> 'mote' then
      raise exception 'Dette dokumentet er ikke sendt til signering i møte.';
    end if;
    if har_rolle(r.organization_id, array['revisor']::user_role[]) then
      raise exception 'Revisor kan ikke registrere signaturer.';
    end if;
    if new.board_member_id is null then
      raise exception 'Velg hvilket styremedlem som signerer.';
    end if;
    if not exists (select 1 from signature_request_board b where b.request_id = r.id and b.board_member_id = new.board_member_id) then
      raise exception 'Dette styremedlemmet står ikke på listen for dokumentet.';
    end if;
    select * into bm from board_members where id = new.board_member_id and organization_id = r.organization_id;
    if bm.id is null then raise exception 'Fant ikke styremedlemmet.'; end if;
    new.mandate_id := null;
  elsif new.signert_som = 'styremedlem' then
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

  if new.signaturdato is null then new.signaturdato := (now() at time zone 'Europe/Oslo')::date; end if;
  if new.signaturdato > (now() at time zone 'Europe/Oslo')::date then
    raise exception 'Signaturdatoen kan ikke være frem i tid.';
  end if;
  if d.dokumentdato is not null and new.signaturdato < d.dokumentdato then
    raise exception 'Signaturdatoen kan ikke være før dokumentets dato (%).', to_char(d.dokumentdato, 'DD.MM.YYYY');
  end if;

  select * into p from profiles where id = new.user_id;
  select * into ou from organization_users where organization_id = r.organization_id and user_id = new.user_id and aktiv;
  if new.signert_som = 'styremedlem_i_mote' then
    new.navn_tekst := bm.navn;
    new.rolle_tekst := bm.verv;
  else
    new.board_member_id := null;
    new.signaturbilde_path := null;
    new.navn_tekst := coalesce(nullif(trim(coalesce(p.fornavn,'') || ' ' || coalesce(p.etternavn,'')), ''), p.epost::text, 'Ukjent');
    new.rolle_tekst := coalesce(nullif(ou.styreverv, ''), nullif(ou.tittel, ''), initcap(ou.rolle::text));
  end if;

  -- På vegne av styret: frys hvem styret var på signaturdatoen
  if new.signert_som in ('fullmektig_for_styret', 'administrator') then
    new.styret_tekst := styret_tekst(r.organization_id, new.signaturdato);
  else
    new.styret_tekst := null;
  end if;

  new.signert_tidspunkt := now();
  new.signatur_id := nytt_signaturnummer();
  new.dokument_hash := r.dokument_hash;
  new.nivaa := 'intern';
  return new;
end;
$$;

-- etter_signatur(): i møte er det ferdig når alle styremedlemmene på listen har signert
create or replace function etter_signatur()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r signature_requests%rowtype;
  antall_mottakere int; antall_signert int; ferdig boolean;
begin
  select * into r from signature_requests where id = new.request_id;
  if r.type = 'fullmektig' then
    ferdig := true;
  elsif r.type = 'mote' then
    select count(*) into antall_mottakere from signature_request_board where request_id = r.id;
    select count(*) into antall_signert from signatures where request_id = r.id;
    ferdig := antall_signert >= antall_mottakere;
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

-- Avvisning i møte: den som holder enheten kan avvise
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
            or old.type = 'mote'
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
  new.type := old.type; new.document_id := old.document_id; new.dokument_hash := old.dokument_hash;
  new.organization_id := old.organization_id; new.opprettet_av := old.opprettet_av; new.opprettet := old.opprettet;
  new.melding := old.melding; new.anledning := old.anledning;
  if new.status = 'trukket' then new.avvist_av := old.avvist_av; new.avvist_arsak := old.avvist_arsak; end if;
  return new;
end;
$$;

-- Verifiseringen viser også styret
drop function if exists verifiser_signatur(text);
create or replace function verifiser_signatur(kode text)
returns table (
  signatur_id text, organisasjon text, orgnr text,
  dokument text, saksflytnr text, mappe text, anledning text,
  navn text, rolle text, signert_som text, fullmakt text, styret text,
  signaturdato date, signert_tidspunkt timestamptz, dokument_hash text, nivaa text,
  antall_signaturer bigint, status text
) language sql stable security definer set search_path = public as $$
  select s.signatur_id, o.navn, o.orgnr,
         case when d.kun_styret then 'Dokument for styret' else d.tittel end, d.saksflytnr, d.mappe, r.anledning,
         s.navn_tekst, s.rolle_tekst, s.signert_som,
         case when m.id is not null then m.nummer || ' · ' || m.vedtak || ' (' || to_char(m.vedtaksdato, 'DD.MM.YYYY') || ')' end,
         s.styret_tekst,
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
--  Styret i Skoger og Fjell kampsportklubb (org.nr 912484335)
--  Legges inn én gang; finnes navnet fra før, røres det ikke.
--  Verv settes til «Styremedlem» og rettes under Innstillinger → Fullmakter.
-- ---------------------------------------------------------------------
do $$
declare org uuid; n text; i int := 0;
begin
  select id into org from organizations where orgnr = '912484335';
  if org is null then raise notice 'Fant ikke org 912484335 — hopper over styret.'; return; end if;
  foreach n in array array['Adriana Januzi','Ardita Dije','Afrim Bekhtesi','Amir Malik','Monica Granly'] loop
    i := i + 10;
    if not exists (select 1 from board_members b where b.organization_id = org and lower(b.navn) = lower(n)) then
      insert into board_members (organization_id, navn, verv, rekkefolge, user_id)
      values (org, n, 'Styremedlem', i,
        -- Afrim har allerede bruker: kobles
        case when n = 'Afrim Bekhtesi' then (select id from profiles where epost = 'afrim@kampsportlaget.com') end);
    end if;
  end loop;
end $$;
