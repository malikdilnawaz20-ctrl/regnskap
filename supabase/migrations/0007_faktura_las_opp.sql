-- =====================================================================
--  Lås opp utstedt faktura for redigering.
--
--  Setter fakturaen tilbake til kladd slik at linjer og felter kan
--  endres igjen. vern_utstedt_leverandorfaktura fikk et unntak: en
--  overgang til status 'kladd' er selve opplåsingen, og skal ikke
--  blokkeres av samme sjekk som ellers hindrer overskriving av en
--  utstedt faktura.
--
--  Nummeret nullstilles ved opplåsing. Blir fakturaen utstedt igjen,
--  tildeler utsted_leverandorfaktura() et nytt nummer som normalt —
--  det gamle gjenbrukes aldri (samme regel som før), det blir bare
--  stående ubrukt. Alt dette logges uansett i audit_logs via den
--  eksisterende trg_logg_vinv-triggeren, uavhengig av denne endringen.
-- =====================================================================

create or replace function vern_utstedt_leverandorfaktura()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'kladd' then
    return new;
  end if;
  if old.status <> 'kladd' then
    if new.nummer      is distinct from old.nummer
    or new.fakturadato is distinct from old.fakturadato
    or new.netto_ore   is distinct from old.netto_ore
    or new.mva_ore     is distinct from old.mva_ore
    or new.brutto_ore  is distinct from old.brutto_ore
    or new.vendor_id   is distinct from old.vendor_id
    or new.customer_id is distinct from old.customer_id
    or new.type        is distinct from old.type then
      raise exception 'Fakturaen er utstedt og kan ikke endres. Lag en kreditnota i stedet, eller lås den opp.';
    end if;
  end if;
  return new;
end;
$$;

create or replace function las_opp_leverandorfaktura(p_faktura uuid)
returns void language plpgsql security definer set search_path = public as $$
declare f record;
begin
  select * into f from vendor_invoices where id = p_faktura;
  if f is null then raise exception 'Fant ikke fakturaen.'; end if;
  if not kan_okonomi(f.organization_id) then
    raise exception 'Du har ikke tilgang til å låse opp fakturaer.';
  end if;
  if f.status <> 'utstedt' then
    raise exception 'Bare utstedte fakturaer kan låses opp på denne måten.';
  end if;
  if exists (select 1 from vendor_invoice_payments where invoice_id = p_faktura) then
    raise exception 'Fakturaen har registrerte betalinger. Fjern dem først (angre-ikonet under Betalinger), så kan den låses opp.';
  end if;

  update vendor_invoices
     set status = 'kladd', nummer = null, utstedt_av = null, utstedt_tid = null
   where id = p_faktura;
end;
$$;
