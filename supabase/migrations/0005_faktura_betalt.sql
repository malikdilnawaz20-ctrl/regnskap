-- =====================================================================
--  Betalt-status på leverandørfaktura.
--
--  vendor_invoice_status hadde allerede 'betalt' i enumet, men det
--  fantes ingen vei dit — ingen kolonne for når den ble betalt, og
--  ingen funksjon for å sette den. trg_vern_vinv (fakturaen er
--  utstedt og låst) sjekker ikke status eller de nye kolonnene, så
--  en betalt-markering går fint gjennom uten å røre den låsingen.
-- =====================================================================

alter table vendor_invoices
  add column betalt_dato date,
  add column betalt_av   uuid references profiles(id),
  add column betalt_tid  timestamptz;

create or replace function merk_leverandorfaktura_betalt(p_faktura uuid, p_dato date default null)
returns void language plpgsql security definer set search_path = public as $$
declare f record;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å markere fakturaer som betalt.';
  end if;
  if f.status <> 'utstedt' then
    raise exception 'Bare utstedte fakturaer kan markeres som betalt.';
  end if;

  update vendor_invoices
     set status = 'betalt',
         betalt_dato = coalesce(p_dato, current_date),
         betalt_av = auth.uid(),
         betalt_tid = now()
   where id = p_faktura;
end;
$$;

create or replace function angre_leverandorfaktura_betalt(p_faktura uuid)
returns void language plpgsql security definer set search_path = public as $$
declare f record;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å endre betalingsstatus.';
  end if;
  if f.status <> 'betalt' then
    raise exception 'Fakturaen er ikke markert som betalt.';
  end if;

  update vendor_invoices
     set status = 'utstedt',
         betalt_dato = null,
         betalt_av = null,
         betalt_tid = null
   where id = p_faktura;
end;
$$;
