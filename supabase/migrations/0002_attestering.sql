-- =====================================================================
--  0002 — Regninger og attestering
--  To personer må godkjenne en regning før den kan betales.
--  Hvem de to er, settes under Innstillinger → Selskapsinformasjon.
-- =====================================================================

alter table organizations
  add column if not exists attestant1 uuid references profiles(id),
  add column if not exists attestant2 uuid references profiles(id),
  add column if not exists krev_to_attestanter boolean not null default true;

create type invoice_status as enum ('mottatt','delvis_godkjent','godkjent','betalt','avvist');

create table supplier_invoices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  referanse       text,                    -- fakturanummer fra leverandøren
  leverandor      text not null,
  orgnr           text,
  beskrivelse     text not null,
  belop_ore       bigint not null check (belop_ore > 0),
  mva_ore         bigint not null default 0 check (mva_ore >= 0),
  mottatt         date not null default current_date,
  forfall         date not null,
  kid             text,
  kontonummer     text,
  category_id     uuid references categories(id) on delete set null,
  project_id      uuid references projects(id) on delete set null,
  account_id      uuid references accounts(id) on delete set null,
  status          invoice_status not null default 'mottatt',

  -- Godkjenninger. To ulike personer, med mindre organisasjonen har
  -- slått av kravet under selskapsinformasjon.
  attest1_av      uuid references profiles(id),
  attest1_tid     timestamptz,
  attest2_av      uuid references profiles(id),
  attest2_tid     timestamptz,
  avvist_av       uuid references profiles(id),
  avvist_arsak    text,

  transaction_id  uuid references transactions(id) on delete set null,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now()
);
create index si_org_idx on supplier_invoices(organization_id, status);
create index si_forfall_idx on supplier_invoices(organization_id, forfall);

create trigger trg_endret_si before update on supplier_invoices
  for each row execute function sett_endret();
create trigger trg_logg_si after insert or update or delete on supplier_invoices
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
-- Regelen håndheves i databasen, ikke bare i grensesnittet.
-- ---------------------------------------------------------------------

create or replace function vern_attestering()
returns trigger language plpgsql security definer set search_path = public as $$
declare krev boolean;
begin
  select krev_to_attestanter into krev from organizations where id = new.organization_id;

  -- Samme person kan ikke fylle begge godkjenningene, med mindre
  -- vedkommende er administrator i organisasjonen.
  if new.attest1_av is not null and new.attest2_av is not null
     and new.attest1_av = new.attest2_av then
    if not exists (
      select 1 from organization_users ou
      where ou.organization_id = new.organization_id
        and ou.user_id = new.attest1_av
        and ou.rolle = 'administrator' and ou.aktiv
    ) then
      raise exception 'To forskjellige personer må godkjenne denne regningen.';
    end if;
  end if;

  -- Statusen følger av godkjenningene, den settes ikke fritt.
  if new.status <> 'avvist' then
    if new.attest1_av is not null and (new.attest2_av is not null or coalesce(krev, true) = false) then
      if new.status <> 'betalt' then new.status := 'godkjent'; end if;
    elsif new.attest1_av is not null then
      new.status := 'delvis_godkjent';
    else
      new.status := 'mottatt';
    end if;
  end if;

  return new;
end;
$$;
create trigger trg_vern_attestering before insert or update on supplier_invoices
  for each row execute function vern_attestering();

-- ---------------------------------------------------------------------
-- Tilgang
-- ---------------------------------------------------------------------

alter table supplier_invoices enable row level security;

create policy si_les on supplier_invoices for select using (er_medlem_av(organization_id));
create policy si_ny on supplier_invoices for insert with check (kan_okonomi(organization_id));
create policy si_endre on supplier_invoices for update
  using (
    kan_okonomi(organization_id)
    -- de to utpekte attestantene kan godkjenne selv om de ikke fører regnskap
    or exists (select 1 from organizations o where o.id = organization_id
               and auth.uid() in (o.attestant1, o.attestant2))
  )
  with check (
    kan_okonomi(organization_id)
    or exists (select 1 from organizations o where o.id = organization_id
               and auth.uid() in (o.attestant1, o.attestant2))
  );
create policy si_slett on supplier_invoices for delete
  using (kan_admin(organization_id) and status <> 'betalt');

-- ---------------------------------------------------------------------
-- Når en regning er betalt, blir den et bilag i regnskapet
-- ---------------------------------------------------------------------

create or replace function bokfor_regning(p_faktura uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare f record; t_id uuid; k int;
begin
  select * into f from supplier_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke regningen.'; end if;
  if f.status = 'betalt' then raise exception 'Denne regningen er allerede betalt og bokført.'; end if;
  if f.status <> 'godkjent' then raise exception 'Regningen må være godkjent av begge før den kan betales.'; end if;
  if not kan_okonomi(f.organization_id) then raise exception 'Du har ikke tilgang til å registrere betalinger.'; end if;

  select konto_nummer into k from categories where id = f.category_id;

  insert into transactions (organization_id, dato, type, beskrivelse, belop_ore, motpart,
                            category_id, konto_nummer, account_id, project_id,
                            regnskapsaar, opprettet_av)
  values (f.organization_id, current_date, 'utgift',
          f.beskrivelse, f.belop_ore, f.leverandor,
          f.category_id, k, f.account_id, f.project_id,
          extract(year from current_date)::int, auth.uid())
  returning id into t_id;

  update supplier_invoices set status = 'betalt', transaction_id = t_id where id = p_faktura;
  return t_id;
end;
$$;
