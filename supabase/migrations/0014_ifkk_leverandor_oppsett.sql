-- =====================================================================
--  0014 — IFKK-leverandøren settes opp med nummerformatet
--
--  Punkt 6 i 0011 lette etter en leverandør med «IFKK» i navnet. Den
--  heter «International Federation of Kyokushinkaikan Karate», så
--  søket traff ingenting og ingen fakturaer ble lagt om. Her treffes
--  den på det faktiske navnet, og omleggingen kjøres.
-- =====================================================================

update vendors
   set nummerformat      = 'ifkk_tilfeldig',
       initialer         = 'MD',
       standard_landkode = coalesce(standard_landkode, 'NO')
 where navn ilike '%Kyokushinkaikan%'
    or navn ilike '%IFKK%';

do $$
declare r record; nytt text; ant int := 0; hoppet int := 0;
begin
  perform set_config('app.tillat_omnummerering', 'på', true);

  for r in
    select i.id, i.nummer, i.vendor_id, i.fakturadato,
           coalesce(i.nummer_landkode, landkode(c.land), v.standard_landkode)::char(2) as lk
      from vendor_invoices i
      join vendors v               on v.id = i.vendor_id
      left join vendor_customers c on c.id = i.customer_id
     where v.nummerformat = 'ifkk_tilfeldig'
       and i.type <> 'proforma'
       and i.nummer is not null
       and i.nummer !~ '^[A-Z]{2,4}[0-9]{2}[A-Z]{2}[0-9]{5}$'
     order by i.fakturadato, i.nummer
  loop
    if r.lk is null then
      raise notice '  hopper over % — vet ikke hvilket land den gjelder', r.nummer;
      hoppet := hoppet + 1;
      continue;
    end if;

    nytt := generer_leverandornummer_tilfeldig(r.vendor_id, coalesce(r.fakturadato, current_date), r.lk);

    update vendor_invoices
       set nummer             = nytt,
           nummer_opprinnelig = coalesce(nummer_opprinnelig, r.nummer),
           nummer_landkode    = r.lk
     where id = r.id;

    ant := ant + 1;
    raise notice '  % → %', r.nummer, nytt;
  end loop;

  raise notice 'La om % leverandørfaktura(er). Hoppet over %.', ant, hoppet;
end $$;
