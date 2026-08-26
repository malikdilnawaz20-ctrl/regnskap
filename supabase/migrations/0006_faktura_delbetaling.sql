-- =====================================================================
--  Delbetaling / forskudd på leverandørfaktura.
--
--  0005 ga en enkel betalt/ikke-betalt-bryter. Den dekker ikke forskudd
--  eller delbetaling, så den erstattes her av en betalingslogg: hver
--  innbetaling er en egen rad, og fakturaens betalt_ore og status
--  regnes ut av loggen — akkurat som netto_ore/mva_ore/brutto_ore
--  allerede regnes ut av linjene (etter_leverandorlinje/trg_summer_vil).
--
--  En betaling er en registrering av mottatte penger, ikke en endring
--  av selve salgsdokumentet — den rammes derfor ikke av
--  vern_utstedt_leverandorfaktura, som bare beskytter nummer, dato,
--  beløp, parter og type på selve fakturaen.
-- =====================================================================

alter table vendor_invoices
  add column betalt_ore bigint not null default 0;

create table vendor_invoice_payments (
  id            uuid primary key default gen_random_uuid(),
  invoice_id    uuid not null references vendor_invoices(id) on delete cascade,
  belop_ore     bigint not null check (belop_ore > 0),
  dato          date not null default current_date,
  notat         text,
  registrert_av uuid references profiles(id),
  registrert    timestamptz not null default now()
);
create index vip_inv_idx on vendor_invoice_payments(invoice_id, dato);

create or replace function summer_leverandorbetaling()
returns trigger language plpgsql security definer set search_path = public as $$
declare inv uuid; sum_ore bigint; f record; siste date;
begin
  inv := coalesce(new.invoice_id, old.invoice_id);
  select coalesce(sum(belop_ore), 0) into sum_ore
    from vendor_invoice_payments where invoice_id = inv;
  select * into f from vendor_invoices where id = inv;

  if f.status = 'utstedt' and sum_ore >= f.brutto_ore and f.brutto_ore > 0 then
    select max(dato) into siste from vendor_invoice_payments where invoice_id = inv;
    update vendor_invoices
       set betalt_ore = sum_ore, status = 'betalt',
           betalt_dato = coalesce(siste, current_date),
           betalt_av = auth.uid(), betalt_tid = now()
     where id = inv;
  elsif f.status = 'betalt' and (sum_ore < f.brutto_ore or f.brutto_ore = 0) then
    update vendor_invoices
       set betalt_ore = sum_ore, status = 'utstedt',
           betalt_dato = null, betalt_av = null, betalt_tid = null
     where id = inv;
  else
    update vendor_invoices set betalt_ore = sum_ore where id = inv;
  end if;

  return coalesce(new, old);
end;
$$;
create trigger trg_summer_vip after insert or update or delete on vendor_invoice_payments
  for each row execute function summer_leverandorbetaling();

create or replace function vern_leverandorbetaling()
returns trigger language plpgsql security definer set search_path = public as $$
declare st vendor_invoice_status;
begin
  select status into st from vendor_invoices where id = new.invoice_id;
  if st is null or st not in ('utstedt', 'betalt') then
    raise exception 'Fakturaen må være utstedt før en betaling kan registreres.';
  end if;
  return new;
end;
$$;
create trigger trg_vern_vip before insert on vendor_invoice_payments
  for each row execute function vern_leverandorbetaling();

alter table vendor_invoice_payments enable row level security;

create policy vip_les on vendor_invoice_payments for select using (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and er_medlem_av(f.organization_id)));
create policy vip_ny on vendor_invoice_payments for insert with check (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)));
create policy vip_slett on vendor_invoice_payments for delete using (
  exists (select 1 from vendor_invoices f where f.id = invoice_id and kan_okonomi(f.organization_id)));

-- 0005 sin enkle av/på-bryter er erstattet av betalingsloggen over.
drop function if exists merk_leverandorfaktura_betalt(uuid, date);
drop function if exists angre_leverandorfaktura_betalt(uuid);
