-- =====================================================================
--  0003 — Utgående faktura
--  Klubben sender regning ut. Motstykket til supplier_invoices, som er
--  regningene klubben mottar.
--
--  To ting styres av databasen, ikke av grensesnittet:
--    1. Fakturanummer tildeles maskinelt i en sammenhengende serie,
--       først når fakturaen utstedes.
--    2. En utstedt faktura kan ikke endres. Feil rettes med kreditnota.
-- =====================================================================

create type sales_invoice_status as enum ('kladd','utstedt','betalt','kreditert');
create type sales_invoice_kind   as enum ('faktura','proforma','kreditnota');

-- ---------------------------------------------------------------------
-- Kunder. Et medlem kan være kunde, men de fleste kunder er ikke
-- medlemmer — sponsorer, kommunen, andre klubber.
-- ---------------------------------------------------------------------

create table customers (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  navn            text not null,
  att             text,                     -- "v/ Malik Dilnawaz"
  adresse         text,                     -- flere linjer, ett linjeskift mellom
  orgnr           text,
  epost           text,
  telefon         text,
  ehf_mottaker    text,                     -- Peppol-adresse, f.eks. 0192:912484335
  member_id       uuid references members(id) on delete set null,
  notat           text,
  aktiv           boolean not null default true,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now()
);
create index cu_org_idx on customers(organization_id, navn);

create trigger trg_endret_cu before update on customers
  for each row execute function sett_endret();

-- ---------------------------------------------------------------------
-- Avsenderoppsett per organisasjon. Én klubb, ett oppsett.
-- Malvalget er en av de tjue malene i app/faktura-maler.js.
-- ---------------------------------------------------------------------

alter table organizations
  add column if not exists faktura_prefiks     text,
  add column if not exists faktura_mal         int not null default 1,
  add column if not exists faktura_betalingsdager int not null default 14,
  add column if not exists faktura_vilkar      text,
  add column if not exists faktura_kontonummer text,
  add column if not exists faktura_iban        text,
  add column if not exists faktura_swift       text;

create table invoice_sequences (
  organization_id uuid not null references organizations(id) on delete cascade,
  aar             int not null,
  siste_nr        int not null default 0,
  primary key (organization_id, aar)
);

create or replace function neste_fakturanummer(p_org uuid, p_aar int)
returns text language plpgsql security definer set search_path = public as $$
declare n int; p text;
begin
  select coalesce(faktura_prefiks, '') into p from organizations where id = p_org;

  insert into invoice_sequences (organization_id, aar, siste_nr)
  values (p_org, p_aar, 1)
  on conflict (organization_id, aar)
    do update set siste_nr = invoice_sequences.siste_nr + 1
  returning invoice_sequences.siste_nr into n;

  return case when p = '' then '' else p || '-' end
       || p_aar::text || '-' || lpad(n::text, 4, '0');
end;
$$;

-- ---------------------------------------------------------------------
-- Fakturaen
-- ---------------------------------------------------------------------

create table sales_invoices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id     uuid references customers(id) on delete restrict,

  type            sales_invoice_kind not null default 'faktura',
  status          sales_invoice_status not null default 'kladd',
  nummer          text,                     -- tildeles ved utstedelse, ikke før

  -- Utstedelsesdato og leveringsdato er to forskjellige ting, og det er
  -- hele nøkkelen til etterslepshåndteringen. Se historisk under.
  fakturadato     date,
  levering_fra    date,
  levering_til    date,
  forfall         date,

  -- historisk = dokumentet ble faktisk utstedt den gang, og importeres nå.
  -- Da kommer nummeret utenfra og den maskinelle serien røres ikke.
  historisk       boolean not null default false,

  valuta          text not null default 'NOK',
  mal             int not null default 1,
  sprak           text not null default 'no',

  var_ref         text,
  deres_ref       text,
  bestillingsnr   text,
  notat           text,                     -- vises på fakturaen
  internt_notat   text,                     -- vises ikke

  -- Summer i øre, beregnet fra linjene. Lagres fordi en utstedt faktura
  -- skal kunne gjengis identisk om fem år.
  netto_ore       bigint not null default 0,
  mva_ore         bigint not null default 0,
  brutto_ore      bigint not null default 0,

  category_id     uuid references categories(id) on delete set null,
  project_id      uuid references projects(id) on delete set null,
  account_id      uuid references accounts(id) on delete set null,

  transaction_id  uuid references transactions(id) on delete set null,
  krediterer      uuid references sales_invoices(id),
  kreditert_av    uuid references sales_invoices(id),

  utstedt_av      uuid references profiles(id),
  utstedt_tid     timestamptz,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now(),

  unique (organization_id, nummer)
);
create index sinv_org_idx     on sales_invoices(organization_id, status);
create index sinv_forfall_idx on sales_invoices(organization_id, forfall);
create index sinv_kunde_idx   on sales_invoices(customer_id);

create table sales_invoice_lines (
  id           uuid primary key default gen_random_uuid(),
  invoice_id   uuid not null references sales_invoices(id) on delete cascade,
  rekkefolge   int not null default 0,
  beskrivelse  text not null,
  antall       numeric(12,3) not null default 1,
  enhet        text,
  pris_ore     bigint not null default 0,   -- pris per enhet, eks. mva
  mva_sats     int not null default 25 check (mva_sats between 0 and 100),
  project_id   uuid references projects(id) on delete set null
);
create index sil_inv_idx on sales_invoice_lines(invoice_id, rekkefolge);

create trigger trg_endret_sinv before update on sales_invoices
  for each row execute function sett_endret();
create trigger trg_logg_sinv after insert or update or delete on sales_invoices
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
-- Summering. Grensesnittet regner også ut summene for visning, men det
-- er denne som gjelder.
-- ---------------------------------------------------------------------

create or replace function summer_faktura(p_faktura uuid)
returns void language plpgsql security definer set search_path = public as $$
declare n bigint; m bigint;
begin
  select coalesce(sum(round(antall * pris_ore)), 0),
         coalesce(sum(round(antall * pris_ore * mva_sats / 100.0)), 0)
    into n, m
    from sales_invoice_lines where invoice_id = p_faktura;

  update sales_invoices
     set netto_ore = n, mva_ore = m, brutto_ore = n + m
   where id = p_faktura;
end;
$$;

create or replace function etter_fakturalinje()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform summer_faktura(coalesce(new.invoice_id, old.invoice_id));
  return coalesce(new, old);
end;
$$;
create trigger trg_summer_sil after insert or update or delete on sales_invoice_lines
  for each row execute function etter_fakturalinje();

-- ---------------------------------------------------------------------
-- En utstedt faktura er låst. Linjene også.
-- ---------------------------------------------------------------------

create or replace function vern_utstedt_faktura()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status <> 'kladd' then
    -- Disse feltene får endres etter utstedelse, resten ikke.
    if new.nummer        is distinct from old.nummer
    or new.fakturadato   is distinct from old.fakturadato
    or new.forfall       is distinct from old.forfall
    or new.netto_ore     is distinct from old.netto_ore
    or new.mva_ore       is distinct from old.mva_ore
    or new.brutto_ore    is distinct from old.brutto_ore
    or new.customer_id   is distinct from old.customer_id
    or new.type          is distinct from old.type then
      raise exception 'Fakturaen er utstedt og kan ikke endres. Lag en kreditnota i stedet.';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_vern_sinv before update on sales_invoices
  for each row execute function vern_utstedt_faktura();

create or replace function vern_fakturalinje()
returns trigger language plpgsql security definer set search_path = public as $$
declare st sales_invoice_status;
begin
  select status into st from sales_invoices
   where id = coalesce(new.invoice_id, old.invoice_id);
  if st is not null and st <> 'kladd' then
    raise exception 'Fakturaen er utstedt. Linjene kan ikke endres.';
  end if;
  return coalesce(new, old);
end;
$$;
create trigger trg_vern_sil before insert or update or delete on sales_invoice_lines
  for each row execute function vern_fakturalinje();

-- ---------------------------------------------------------------------
-- Utstedelse. Nummeret tildeles her og bare her.
--
-- Modus A (historisk = true): dokumentet ble faktisk utstedt den gang.
-- Nummeret oppgis utenfra og den maskinelle serien røres ikke.
--
-- Modus B (historisk = false): fakturaen utstedes nå. Datoen kan ikke
-- ligge før forrige utstedte faktura, for da ville nummerserien ikke
-- lenger vært stigende i tid.
-- ---------------------------------------------------------------------

create or replace function utsted_faktura(p_faktura uuid, p_dato date default null)
returns text language plpgsql security definer set search_path = public as $$
declare f record; d date; sist date; nr text; dager int;
begin
  select * into f from sales_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å utstede fakturaer.';
  end if;
  if f.status <> 'kladd' then raise exception 'Fakturaen er allerede utstedt.'; end if;
  if not exists (select 1 from sales_invoice_lines where invoice_id = p_faktura) then
    raise exception 'Fakturaen har ingen linjer.';
  end if;
  if f.customer_id is null then raise exception 'Fakturaen mangler kunde.'; end if;

  d := coalesce(p_dato, f.fakturadato, current_date);

  if f.historisk then
    if f.nummer is null or f.nummer = '' then
      raise exception 'En historisk faktura må ha nummeret den faktisk hadde.';
    end if;
    nr := f.nummer;
  else
    select max(fakturadato) into sist from sales_invoices
     where organization_id = f.organization_id and status <> 'kladd' and not historisk;
    if sist is not null and d < sist then
      raise exception 'Fakturadato % ligger før forrige utstedte faktura (%). Fakturanummer må stige i takt med datoen. Gjelder dette et salg som aldri ble fakturert, utsted i dag og før leveringsperioden i stedet.', d, sist;
    end if;
    nr := neste_fakturanummer(f.organization_id, extract(year from d)::int);
  end if;

  select coalesce(faktura_betalingsdager, 14) into dager
    from organizations where id = f.organization_id;

  update sales_invoices
     set nummer = nr, fakturadato = d,
         forfall = coalesce(f.forfall, d + dager),
         status = 'utstedt', utstedt_av = auth.uid(), utstedt_tid = now()
   where id = p_faktura;

  return nr;
end;
$$;

-- ---------------------------------------------------------------------
-- Betalt faktura blir et bilag, på samme måte som bokfor_regning.
-- ---------------------------------------------------------------------

create or replace function bokfor_fakturabetaling(p_faktura uuid, p_dato date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare f record; k int; t_id uuid; d date; kunde text;
begin
  select * into f from sales_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å registrere betalinger.';
  end if;
  if f.status = 'betalt' then raise exception 'Fakturaen er allerede registrert som betalt.'; end if;
  if f.status <> 'utstedt' then raise exception 'Bare en utstedt faktura kan registreres som betalt.'; end if;
  if f.type = 'proforma' then raise exception 'En proforma faktura er ikke et salgsdokument og skal ikke bokføres.'; end if;

  d := coalesce(p_dato, current_date);
  select konto_nummer into k from categories where id = f.category_id;
  select navn into kunde from customers where id = f.customer_id;

  insert into transactions (organization_id, bilagsnummer, dato, type, beskrivelse, belop_ore,
                            motpart, category_id, konto_nummer, account_id, project_id,
                            regnskapsaar, opprettet_av)
  values (f.organization_id,
          neste_bilagsnummer(f.organization_id, extract(year from d)::int),
          d, 'inntekt',
          'Faktura ' || coalesce(f.nummer, '') || ' — ' || coalesce(kunde, 'kunde'),
          f.brutto_ore, kunde, f.category_id, k, f.account_id, f.project_id,
          extract(year from d)::int, auth.uid())
  returning id into t_id;

  update sales_invoices set status = 'betalt', transaction_id = t_id where id = p_faktura;
  return t_id;
end;
$$;

-- ---------------------------------------------------------------------
-- Kreditnota. Retting skjer ved ny transaksjon, aldri ved overskriving.
-- ---------------------------------------------------------------------

create or replace function lag_kreditnota(p_faktura uuid, p_arsak text)
returns uuid language plpgsql security definer set search_path = public as $$
declare f record; ny uuid;
begin
  select * into f from sales_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å lage kreditnota.';
  end if;
  if f.status = 'kladd' then raise exception 'En kladd slettes, den krediteres ikke.'; end if;
  if f.kreditert_av is not null then raise exception 'Fakturaen er allerede kreditert.'; end if;

  insert into sales_invoices (organization_id, customer_id, type, valuta, mal, sprak,
                              var_ref, deres_ref, notat, category_id, project_id, account_id,
                              krediterer, opprettet_av)
  values (f.organization_id, f.customer_id, 'kreditnota', f.valuta, f.mal, f.sprak,
          f.var_ref, f.deres_ref,
          'Kreditnota for faktura ' || coalesce(f.nummer, '') ||
            case when p_arsak is null or p_arsak = '' then '' else '. Årsak: ' || p_arsak end,
          f.category_id, f.project_id, f.account_id, p_faktura, auth.uid())
  returning id into ny;

  insert into sales_invoice_lines (invoice_id, rekkefolge, beskrivelse, antall, enhet, pris_ore, mva_sats, project_id)
  select ny, rekkefolge, beskrivelse, -antall, enhet, pris_ore, mva_sats, project_id
    from sales_invoice_lines where invoice_id = p_faktura;

  update sales_invoices set kreditert_av = ny where id = p_faktura;
  return ny;
end;
$$;

-- ---------------------------------------------------------------------
-- Tilgang
-- ---------------------------------------------------------------------

alter table customers            enable row level security;
alter table sales_invoices       enable row level security;
alter table sales_invoice_lines  enable row level security;
alter table invoice_sequences    enable row level security;

create policy cu_les    on customers for select using (er_medlem_av(organization_id));
create policy cu_ny     on customers for insert with check (kan_okonomi(organization_id));
create policy cu_endre  on customers for update using (kan_okonomi(organization_id))
                                          with check (kan_okonomi(organization_id));
create policy cu_slett  on customers for delete using (kan_admin(organization_id));

create policy sinv_les   on sales_invoices for select using (er_medlem_av(organization_id));
create policy sinv_ny    on sales_invoices for insert with check (kan_okonomi(organization_id));
create policy sinv_endre on sales_invoices for update using (kan_okonomi(organization_id))
                                              with check (kan_okonomi(organization_id));
-- Bare kladd kan slettes. En utstedt faktura krediteres.
create policy sinv_slett on sales_invoices for delete
  using (kan_okonomi(organization_id) and status = 'kladd');

create policy sil_les   on sales_invoice_lines for select using (
  exists (select 1 from sales_invoices f where f.id = invoice_id and er_medlem_av(f.organization_id)));
create policy sil_skriv on sales_invoice_lines for all using (
  exists (select 1 from sales_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)))
  with check (
  exists (select 1 from sales_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)));

create policy iseq_les on invoice_sequences for select using (er_medlem_av(organization_id));
