-- =====================================================================
--  0004 — Faktura generator
--
--  Regnskapsførerfirmaet fakturerer PÅ VEGNE AV leverandører. Leverandøren
--  står som avsender på dokumentet, leverandørens egen kunde er mottaker.
--  Firmaet er bare den som lager fakturaen.
--
--  Derfor egne tabeller, ikke sales_invoices: der er organisasjonen selv
--  avsender. Her er avsenderen en rad i vendors, og det kan være mange
--  under samme organisasjon.
--
--  Beløp lagres i minste valutaenhet — øre for NOK, cent for USD.
-- =====================================================================

create type vendor_invoice_status as enum ('kladd','utstedt','betalt','kreditert');
create type vendor_invoice_kind   as enum ('faktura','proforma','kreditnota');

-- ---------------------------------------------------------------------
-- Leverandøren. Alt som skal stå som avsender på fakturaen, og det som
-- trengs for eksportdokumenter: skattenummer, REX, HS-kode, opprinnelse.
-- ---------------------------------------------------------------------

create table vendors (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,

  navn            text not null,
  adresse         text,                     -- flere linjer, ett linjeskift mellom
  land            text,
  epost           text,
  telefon         text,
  nettsted        text,

  -- Skatt og eksport
  skattenr        text,                     -- NTN, VAT, org.nr — det leverandøren har
  rex_nr          text,
  hs_kode         text,
  opprinnelsesland text,
  leveringsvilkar text,                     -- Incoterm: FOB, C&F, EXW …

  -- Betaling
  bank            text,
  kontonummer     text,
  iban            text,
  swift           text,
  betalingsnotat  text,

  -- Fakturaoppsett
  mal             int  not null default 4,  -- eksportmalen passer de fleste
  aksentfarge     text not null default '#087F7A',
  valuta          text not null default 'USD',
  sprak           text not null default 'en',
  betalingsdager  int  not null default 0,  -- 0 = forskuddsbetaling
  prefiks         text,
  vilkar          text,
  fotnote         text,

  aktiv           boolean not null default true,
  notat           text,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now()
);
create index ven_org_idx on vendors(organization_id, navn);

create trigger trg_endret_ven before update on vendors
  for each row execute function sett_endret();

-- ---------------------------------------------------------------------
-- Leverandørens egne kunder
-- ---------------------------------------------------------------------

create table vendor_customers (
  id           uuid primary key default gen_random_uuid(),
  vendor_id    uuid not null references vendors(id) on delete cascade,
  navn         text not null,
  att          text,
  adresse      text,
  land         text,
  orgnr        text,
  epost        text,
  telefon      text,
  aktiv        boolean not null default true,
  opprettet    timestamptz not null default now()
);
create index vcu_ven_idx on vendor_customers(vendor_id, navn);

-- ---------------------------------------------------------------------
-- Fakturaen
-- ---------------------------------------------------------------------

create table vendor_invoices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  vendor_id       uuid not null references vendors(id) on delete restrict,
  customer_id     uuid references vendor_customers(id) on delete restrict,

  type            vendor_invoice_kind not null default 'faktura',
  status          vendor_invoice_status not null default 'kladd',
  nummer          text,

  fakturadato     date,
  levering_fra    date,
  levering_til    date,
  forfall         date,
  historisk       boolean not null default false,

  valuta          text not null default 'USD',
  mal             int  not null default 4,
  sprak           text not null default 'en',

  var_ref         text,
  deres_ref       text,
  notat           text,
  internt_notat   text,

  -- Frakt og toll, for eksportfakturaene
  vekt_kg         numeric(10,2),
  kolli           int,
  leveringsvilkar text,
  transportmate   text,

  netto_ore       bigint not null default 0,
  mva_ore         bigint not null default 0,
  brutto_ore      bigint not null default 0,

  krediterer      uuid references vendor_invoices(id),
  kreditert_av    uuid references vendor_invoices(id),

  utstedt_av      uuid references profiles(id),
  utstedt_tid     timestamptz,
  opprettet_av    uuid references profiles(id),
  opprettet       timestamptz not null default now(),
  endret          timestamptz not null default now(),

  unique (vendor_id, nummer)
);
create index vinv_org_idx  on vendor_invoices(organization_id, status);
create index vinv_ven_idx  on vendor_invoices(vendor_id, fakturadato desc);

create table vendor_invoice_lines (
  id           uuid primary key default gen_random_uuid(),
  invoice_id   uuid not null references vendor_invoices(id) on delete cascade,
  rekkefolge   int not null default 0,
  beskrivelse  text not null,
  antall       numeric(12,3) not null default 1,
  enhet        text,
  pris_ore     bigint not null default 0,
  mva_sats     int not null default 0 check (mva_sats between 0 and 100),
  hs_kode      text,
  vekt_kg      numeric(10,3)
);
create index vil_inv_idx on vendor_invoice_lines(invoice_id, rekkefolge);

create trigger trg_endret_vinv before update on vendor_invoices
  for each row execute function sett_endret();
create trigger trg_logg_vinv after insert or update or delete on vendor_invoices
  for each row execute function logg_endring();

-- ---------------------------------------------------------------------
-- Nummerserie per leverandør. To leverandører deler aldri serie — de er
-- to forskjellige avsendere, og hver serie skal kunne kontrolleres for seg.
-- ---------------------------------------------------------------------

create table vendor_invoice_sequences (
  vendor_id uuid not null references vendors(id) on delete cascade,
  aar       int  not null,
  siste_nr  int  not null default 0,
  primary key (vendor_id, aar)
);

create or replace function neste_leverandornummer(p_vendor uuid, p_aar int)
returns text language plpgsql security definer set search_path = public as $$
declare n int; p text;
begin
  select coalesce(prefiks, '') into p from vendors where id = p_vendor;

  insert into vendor_invoice_sequences (vendor_id, aar, siste_nr)
  values (p_vendor, p_aar, 1)
  on conflict (vendor_id, aar)
    do update set siste_nr = vendor_invoice_sequences.siste_nr + 1
  returning vendor_invoice_sequences.siste_nr into n;

  return case when p = '' then '' else p || '/' end
       || p_aar::text || '-' || lpad(n::text, 4, '0');
end;
$$;

-- ---------------------------------------------------------------------
-- Summering
-- ---------------------------------------------------------------------

create or replace function summer_leverandorfaktura(p_faktura uuid)
returns void language plpgsql security definer set search_path = public as $$
declare n bigint; m bigint;
begin
  select coalesce(sum(round(antall * pris_ore)), 0),
         coalesce(sum(round(antall * pris_ore * mva_sats / 100.0)), 0)
    into n, m
    from vendor_invoice_lines where invoice_id = p_faktura;

  update vendor_invoices
     set netto_ore = n, mva_ore = m, brutto_ore = n + m
   where id = p_faktura;
end;
$$;

create or replace function etter_leverandorlinje()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform summer_leverandorfaktura(coalesce(new.invoice_id, old.invoice_id));
  return coalesce(new, old);
end;
$$;
create trigger trg_summer_vil after insert or update or delete on vendor_invoice_lines
  for each row execute function etter_leverandorlinje();

-- ---------------------------------------------------------------------
-- Utstedt faktura er låst, som i klubbmodulen
-- ---------------------------------------------------------------------

create or replace function vern_utstedt_leverandorfaktura()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status <> 'kladd' then
    if new.nummer      is distinct from old.nummer
    or new.fakturadato is distinct from old.fakturadato
    or new.netto_ore   is distinct from old.netto_ore
    or new.mva_ore     is distinct from old.mva_ore
    or new.brutto_ore  is distinct from old.brutto_ore
    or new.vendor_id   is distinct from old.vendor_id
    or new.customer_id is distinct from old.customer_id
    or new.type        is distinct from old.type then
      raise exception 'Fakturaen er utstedt og kan ikke endres. Lag en kreditnota i stedet.';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_vern_vinv before update on vendor_invoices
  for each row execute function vern_utstedt_leverandorfaktura();

create or replace function vern_leverandorlinje()
returns trigger language plpgsql security definer set search_path = public as $$
declare st vendor_invoice_status;
begin
  select status into st from vendor_invoices
   where id = coalesce(new.invoice_id, old.invoice_id);
  if st is not null and st <> 'kladd' then
    raise exception 'Fakturaen er utstedt. Linjene kan ikke endres.';
  end if;
  return coalesce(new, old);
end;
$$;
create trigger trg_vern_vil before insert or update or delete on vendor_invoice_lines
  for each row execute function vern_leverandorlinje();

-- ---------------------------------------------------------------------
-- Utstedelse
--
-- Proforma får ikke nummer fra den ordinære serien. En proforma er ikke
-- et salgsdokument, og skal ikke spise av nummerrekken til de ekte
-- fakturaene — den får sitt eget PRO-nummer.
-- ---------------------------------------------------------------------

create or replace function utsted_leverandorfaktura(p_faktura uuid, p_dato date default null)
returns text language plpgsql security definer set search_path = public as $$
declare f record; d date; sist date; nr text; dager int;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å utstede fakturaer.';
  end if;
  if f.status <> 'kladd' then raise exception 'Fakturaen er allerede utstedt.'; end if;
  if f.customer_id is null then raise exception 'Fakturaen mangler kunde.'; end if;
  if not exists (select 1 from vendor_invoice_lines where invoice_id = p_faktura) then
    raise exception 'Fakturaen har ingen linjer.';
  end if;

  d := coalesce(p_dato, f.fakturadato, current_date);

  if f.type = 'proforma' then
    nr := 'PRO-' || to_char(d, 'YYYYMMDD') || '-' || substr(replace(f.id::text,'-',''), 1, 4);
  elsif f.historisk then
    if f.nummer is null or f.nummer = '' then
      raise exception 'En historisk faktura må ha nummeret den faktisk hadde.';
    end if;
    nr := f.nummer;
  else
    select max(fakturadato) into sist from vendor_invoices
     where vendor_id = f.vendor_id and status <> 'kladd'
       and type <> 'proforma' and not historisk;
    if sist is not null and d < sist then
      raise exception 'Fakturadato % ligger før forrige utstedte faktura for denne leverandøren (%). Nummerserien må stige i takt med datoen.', d, sist;
    end if;
    nr := neste_leverandornummer(f.vendor_id, extract(year from d)::int);
  end if;

  select coalesce(betalingsdager, 0) into dager from vendors where id = f.vendor_id;

  update vendor_invoices
     set nummer = nr, fakturadato = d,
         forfall = coalesce(f.forfall, d + dager),
         status = 'utstedt', utstedt_av = auth.uid(), utstedt_tid = now()
   where id = p_faktura;

  return nr;
end;
$$;

-- ---------------------------------------------------------------------
-- Kreditnota
-- ---------------------------------------------------------------------

create or replace function lag_leverandor_kreditnota(p_faktura uuid, p_arsak text)
returns uuid language plpgsql security definer set search_path = public as $$
declare f record; ny uuid;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å lage kreditnota.';
  end if;
  if f.status = 'kladd' then raise exception 'En kladd slettes, den krediteres ikke.'; end if;
  if f.type = 'proforma' then raise exception 'En proforma krediteres ikke — den slettes eller erstattes.'; end if;
  if f.kreditert_av is not null then raise exception 'Fakturaen er allerede kreditert.'; end if;

  insert into vendor_invoices (organization_id, vendor_id, customer_id, type, valuta, mal, sprak,
                               var_ref, deres_ref, notat, leveringsvilkar, krediterer, opprettet_av)
  values (f.organization_id, f.vendor_id, f.customer_id, 'kreditnota', f.valuta, f.mal, f.sprak,
          f.var_ref, f.deres_ref,
          'Kreditnota for faktura ' || coalesce(f.nummer, '') ||
            case when p_arsak is null or p_arsak = '' then '' else '. Årsak: ' || p_arsak end,
          f.leveringsvilkar, p_faktura, auth.uid())
  returning id into ny;

  insert into vendor_invoice_lines (invoice_id, rekkefolge, beskrivelse, antall, enhet, pris_ore, mva_sats, hs_kode, vekt_kg)
  select ny, rekkefolge, beskrivelse, -antall, enhet, pris_ore, mva_sats, hs_kode, vekt_kg
    from vendor_invoice_lines where invoice_id = p_faktura;

  update vendor_invoices set kreditert_av = ny where id = p_faktura;
  return ny;
end;
$$;

-- ---------------------------------------------------------------------
-- Kopier en faktura til ny kladd. Dette er hovedknappen i grensesnittet:
-- de fleste fakturaer er forrige faktura med ny dato.
-- ---------------------------------------------------------------------

create or replace function kopier_leverandorfaktura(p_faktura uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare f record; ny uuid;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å lage fakturaer.';
  end if;

  insert into vendor_invoices (organization_id, vendor_id, customer_id, type, valuta, mal, sprak,
                               fakturadato, var_ref, deres_ref, notat,
                               vekt_kg, kolli, leveringsvilkar, transportmate, opprettet_av)
  values (f.organization_id, f.vendor_id, f.customer_id,
          case when f.type = 'kreditnota' then 'faktura'::vendor_invoice_kind else f.type end,
          f.valuta, f.mal, f.sprak, current_date, f.var_ref, f.deres_ref, f.notat,
          f.vekt_kg, f.kolli, f.leveringsvilkar, f.transportmate, auth.uid())
  returning id into ny;

  insert into vendor_invoice_lines (invoice_id, rekkefolge, beskrivelse, antall, enhet, pris_ore, mva_sats, hs_kode, vekt_kg)
  select ny, rekkefolge, beskrivelse, abs(antall), enhet, pris_ore, mva_sats, hs_kode, vekt_kg
    from vendor_invoice_lines where invoice_id = p_faktura order by rekkefolge;

  return ny;
end;
$$;

-- ---------------------------------------------------------------------
-- Tilgang. Alt henger på organisasjonen, som resten av systemet.
-- ---------------------------------------------------------------------

alter table vendors                  enable row level security;
alter table vendor_customers         enable row level security;
alter table vendor_invoices          enable row level security;
alter table vendor_invoice_lines     enable row level security;
alter table vendor_invoice_sequences enable row level security;

create policy ven_les   on vendors for select using (er_medlem_av(organization_id));
create policy ven_ny    on vendors for insert with check (kan_okonomi(organization_id));
create policy ven_endre on vendors for update using (kan_okonomi(organization_id))
                                       with check (kan_okonomi(organization_id));
create policy ven_slett on vendors for delete using (kan_admin(organization_id));

create policy vcu_les   on vendor_customers for select using (
  exists (select 1 from vendors v where v.id = vendor_id and er_medlem_av(v.organization_id)));
create policy vcu_skriv on vendor_customers for all using (
  exists (select 1 from vendors v where v.id = vendor_id and kan_okonomi(v.organization_id)))
  with check (
  exists (select 1 from vendors v where v.id = vendor_id and kan_okonomi(v.organization_id)));

create policy vinv_les   on vendor_invoices for select using (er_medlem_av(organization_id));
create policy vinv_ny    on vendor_invoices for insert with check (kan_okonomi(organization_id));
create policy vinv_endre on vendor_invoices for update using (kan_okonomi(organization_id))
                                                with check (kan_okonomi(organization_id));
create policy vinv_slett on vendor_invoices for delete
  using (kan_okonomi(organization_id) and status = 'kladd');

create policy vil_les   on vendor_invoice_lines for select using (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and er_medlem_av(f.organization_id)));
create policy vil_skriv on vendor_invoice_lines for all using (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)))
  with check (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)));

create policy vseq_les on vendor_invoice_sequences for select using (
  exists (select 1 from vendors v where v.id = vendor_id and er_medlem_av(v.organization_id)));
