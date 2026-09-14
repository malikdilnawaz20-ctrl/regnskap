-- =====================================================================
--  0011 — Nummerformat på leverandørfaktura
--
--  IFKK bruker ikke serien 2026-0001. Nummeret deres er satt sammen av
--  utstederens initialer, tosifret år, landet fakturaen gjelder og fem
--  tilfeldige siffer:
--
--      MD 26 NO 12345
--      │  │  │  └── fem siffer, trukket tilfeldig, 00000–99999
--      │  │  └───── landet fakturaen gjelder, ISO 3166-1 alpha-2
--      │  └──────── tosifret år, fra fakturadato
--      └─────────── utstederens initialer
--
--  Det er et identifikasjonsnummer, ikke en sekvens — IFKK bruker det
--  som referanse når de bokfører internt.
--
--  Formatet velges per leverandør. Alle andre leverandører beholder
--  neste_leverandornummer() og serien sin uendret, og sales_invoices
--  (klubbmodulen) røres ikke i det hele tatt.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Felter
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'leverandor_nummerformat') then
    create type leverandor_nummerformat as enum ('serie', 'ifkk_tilfeldig');
  end if;
end $$;

alter table vendors
  add column if not exists nummerformat      leverandor_nummerformat not null default 'serie',
  add column if not exists initialer         text,
  add column if not exists standard_landkode char(2);

alter table vendors drop constraint if exists vendors_initialer_format;
alter table vendors add  constraint vendors_initialer_format
  check (initialer is null or initialer ~ '^[A-Z]{2,4}$');

alter table vendors drop constraint if exists vendors_ifkk_krever_initialer;
alter table vendors add  constraint vendors_ifkk_krever_initialer
  check (nummerformat <> 'ifkk_tilfeldig' or initialer is not null);

comment on column vendors.nummerformat is
  'serie = prefiks/2026-0001 (standard). ifkk_tilfeldig = MD26NO12345.';
comment on column vendors.initialer is
  'Initialene i nummeret, 2–4 store bokstaver. Kreves av ifkk_tilfeldig.';
comment on column vendors.standard_landkode is
  'Landkode å falle tilbake på når kunden ikke har et land systemet kjenner igjen.';

alter table vendor_invoices
  add column if not exists nummer_landkode    char(2),
  add column if not exists nummer_opprinnelig text;

alter table vendor_invoices drop constraint if exists vendor_invoices_landkode_format;
alter table vendor_invoices add  constraint vendor_invoices_landkode_format
  check (nummer_landkode is null or nummer_landkode ~ '^[A-Z]{2}$');

comment on column vendor_invoices.nummer_landkode is
  'Landet fakturaen gjelder, ISO 3166-1 alpha-2. Inngår i nummeret ved ifkk_tilfeldig.';
comment on column vendor_invoices.nummer_opprinnelig is
  'Nummeret fakturaen hadde før omleggingen i 0011. NULL i normal drift.';

-- unique (vendor_id, nummer) finnes allerede fra 0004 og er det som
-- faktisk garanterer at to tilfeldige trekk aldri kolliderer.

-- ---------------------------------------------------------------------
--  2. Landnavn → landkode
--
--  vendors.land og vendor_customers.land er fritekst («Pakistan»,
--  «Norge»). Her oversettes de landene som faktisk er i bruk. Er
--  teksten allerede to bokstaver, brukes den som den er.
-- ---------------------------------------------------------------------

create or replace function landkode(p_tekst text)
returns char(2) language sql immutable as $$
  select case
    when p_tekst is null or btrim(p_tekst) = '' then null
    when btrim(p_tekst) ~ '^[A-Za-z]{2}$' then upper(btrim(p_tekst))::char(2)
    else (select k from (values
      ('norge','NO'),('noreg','NO'),('norway','NO'),
      ('sverige','SE'),('sweden','SE'),
      ('danmark','DK'),('denmark','DK'),
      ('finland','FI'),('suomi','FI'),
      ('island','IS'),('iceland','IS'),
      ('pakistan','PK'),
      ('india','IN'),
      ('kina','CN'),('china','CN'),
      ('japan','JP'),
      ('thailand','TH'),
      ('vietnam','VN'),
      ('tyrkia','TR'),('turkey','TR'),('türkiye','TR'),
      ('tyskland','DE'),('germany','DE'),
      ('nederland','NL'),('netherlands','NL'),('holland','NL'),
      ('belgia','BE'),('belgium','BE'),
      ('frankrike','FR'),('france','FR'),
      ('spania','ES'),('spain','ES'),
      ('portugal','PT'),
      ('italia','IT'),('italy','IT'),
      ('polen','PL'),('poland','PL'),
      ('estland','EE'),('latvia','LV'),('litauen','LT'),
      ('storbritannia','GB'),('england','GB'),('united kingdom','GB'),('uk','GB'),
      ('irland','IE'),('ireland','IE'),
      ('usa','US'),('united states','US'),('amerika','US'),
      ('canada','CA'),
      ('australia','AU'),
      ('brasil','BR'),('brazil','BR'),
      ('sør-afrika','ZA'),('south africa','ZA'),
      ('marokko','MA'),('morocco','MA'),
      ('egypt','EG'),
      ('emiratene','AE'),('uae','AE'),('united arab emirates','AE'),
      ('saudi-arabia','SA'),('saudi arabia','SA'),
      ('sveits','CH'),('switzerland','CH'),
      ('østerrike','AT'),('austria','AT'),
      ('tsjekkia','CZ'),('czechia','CZ'),
      ('ungarn','HU'),('hungary','HU'),
      ('hellas','GR'),('greece','GR')
    ) as t(n,k) where t.n = lower(btrim(p_tekst)))::char(2)
  end;
$$;

comment on function landkode(text) is
  'Landnavn på norsk eller engelsk til ISO 3166-1 alpha-2. NULL når landet ikke kjennes igjen.';

-- ---------------------------------------------------------------------
--  3. Generatoren
--
--  100 000 mulige numre per kombinasjon av initialer, år og land.
--  Ved 5 000 utstedte numre i samme rom trengs i praksis aldri mer enn
--  tre trekk. 25 forsøk er derfor romslig; går de tomme, skal
--  utstedelsen stoppe framfor å finne på et nummer utenfor mønsteret.
-- ---------------------------------------------------------------------

create or replace function generer_leverandornummer_tilfeldig(
  p_vendor   uuid,
  p_dato     date,
  p_landkode char(2)
) returns text language plpgsql security definer set search_path = public as $$
declare ini text; kand text; i int := 0;
begin
  select initialer into ini
    from vendors
   where id = p_vendor and nummerformat = 'ifkk_tilfeldig';

  if ini is null then
    raise exception 'Leverandøren bruker ikke IFKK-nummerformat, eller mangler initialer.';
  end if;
  if p_landkode is null or upper(p_landkode) !~ '^[A-Z]{2}$' then
    raise exception 'Fakturaen mangler landkode. Sett den på fakturaen, eller en standard landkode på leverandøren.';
  end if;

  loop
    i := i + 1;
    kand := ini
         || to_char(p_dato, 'YY')
         || upper(p_landkode)
         || lpad(floor(random() * 100000)::int::text, 5, '0');

    exit when not exists (
      select 1 from vendor_invoices where vendor_id = p_vendor and nummer = kand
    );

    if i >= 25 then
      raise exception 'Fant ikke et ledig nummer for %/%/% etter 25 forsøk.',
        ini, to_char(p_dato, 'YY'), upper(p_landkode);
    end if;
  end loop;

  return kand;
end;
$$;

-- ---------------------------------------------------------------------
--  4. Utstedelse
--
--  Bygger på 0004. Eneste endring er den nye grenen: ved ifkk_tilfeldig
--  trekkes nummeret, og datosperren faller bort — den fantes for å
--  hindre at en fortløpende serie sluttet å stige med datoen, og en
--  tilfeldig serie stiger ikke uansett.
-- ---------------------------------------------------------------------

create or replace function utsted_leverandorfaktura(p_faktura uuid, p_dato date default null)
returns text language plpgsql security definer set search_path = public as $$
declare f record; v record; d date; sist date; nr text; lk char(2);
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

  select * into v from vendors where id = f.vendor_id;
  d := coalesce(p_dato, f.fakturadato, current_date);

  if f.type = 'proforma' then
    nr := 'PRO-' || to_char(d, 'YYYYMMDD') || '-' || substr(replace(f.id::text,'-',''), 1, 4);

  elsif f.historisk then
    if f.nummer is null or f.nummer = '' then
      raise exception 'En historisk faktura må ha nummeret den faktisk hadde.';
    end if;
    nr := f.nummer;

  elsif v.nummerformat = 'ifkk_tilfeldig' then
    select coalesce(f.nummer_landkode, landkode(c.land), v.standard_landkode)
      into lk
      from vendor_customers c where c.id = f.customer_id;

    if lk is null then
      raise exception 'Fakturaen mangler landkode. Sett landet på kunden, eller en standard landkode på leverandøren.';
    end if;
    nr := generer_leverandornummer_tilfeldig(f.vendor_id, d, lk);

  else
    select max(fakturadato) into sist from vendor_invoices
     where vendor_id = f.vendor_id and status <> 'kladd'
       and type <> 'proforma' and not historisk;
    if sist is not null and d < sist then
      raise exception 'Fakturadato % ligger før forrige utstedte faktura for denne leverandøren (%). Nummerserien må stige i takt med datoen.', d, sist;
    end if;
    nr := neste_leverandornummer(f.vendor_id, extract(year from d)::int);
  end if;

  update vendor_invoices
     set nummer = nr, fakturadato = d,
         nummer_landkode = coalesce(lk, nummer_landkode),
         forfall = coalesce(f.forfall, d + coalesce(v.betalingsdager, 0)),
         status = 'utstedt', utstedt_av = auth.uid(), utstedt_tid = now()
   where id = p_faktura;

  return nr;
end;
$$;

-- ---------------------------------------------------------------------
--  5. Vernet slipper omnummerering gjennom, men bare i en migrasjon
--
--  Bygger på 0007. Nytt: er app.tillat_omnummerering satt lokalt i
--  transaksjonen, kan selve nummeret byttes — alt annet på en utstedt
--  faktura er fortsatt låst. Flagget settes ikke av appen noe sted, og
--  forsvinner når transaksjonen er ferdig. Endringen logges som før i
--  audit_logs via trg_logg_vinv.
-- ---------------------------------------------------------------------

create or replace function vern_utstedt_leverandorfaktura()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'kladd' then
    return new;
  end if;
  if old.status <> 'kladd' then
    if coalesce(current_setting('app.tillat_omnummerering', true), 'av') = 'på'
      and new.fakturadato is not distinct from old.fakturadato
      and new.netto_ore   is not distinct from old.netto_ore
      and new.mva_ore     is not distinct from old.mva_ore
      and new.brutto_ore  is not distinct from old.brutto_ore
      and new.vendor_id   is not distinct from old.vendor_id
      and new.customer_id is not distinct from old.customer_id
      and new.type        is not distinct from old.type then
      return new;
    end if;
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

-- ---------------------------------------------------------------------
--  6. IFKK settes opp
--
--  Treffer leverandøren på navn, så migrasjonen kan kjøres uten å slå
--  opp en uuid først. Gjør ingenting hvis leverandøren ikke finnes.
-- ---------------------------------------------------------------------

update vendors
   set nummerformat      = 'ifkk_tilfeldig',
       initialer         = 'MD',
       standard_landkode = coalesce(standard_landkode, 'NO')
 where navn ilike '%IFKK%'
    or navn ilike '%International Federation of Karate%';

-- ---------------------------------------------------------------------
--  7. Fakturaene som allerede er utstedt legges om
--
--  Proforma står urørt — den har sitt eget PRO-nummer og hører ikke til
--  i serien. Kladd har ikke nummer ennå og får det ved utstedelse.
--  Det gamle nummeret blir stående i nummer_opprinnelig, så en faktura
--  som allerede er sendt kan spores fra gammelt til nytt nummer.
-- ---------------------------------------------------------------------

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
      raise notice '  hopper over % — vet ikke hvilket land den gjelder. Sett land paa kunden, eller standard landkode paa leverandoeren.', r.nummer;
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

  raise notice 'La om % leverandørfaktura(er) til IFKK-format. Hoppet over %.', ant, hoppet;
end $$;

-- ---------------------------------------------------------------------
--  Kontroll etter kjøring
-- ---------------------------------------------------------------------
--  select v.navn, i.nummer, i.nummer_opprinnelig, i.nummer_landkode,
--         i.fakturadato, i.status
--    from vendor_invoices i
--    join vendors v on v.id = i.vendor_id
--   where v.nummerformat = 'ifkk_tilfeldig'
--   order by i.fakturadato;
--
--  Forventet: alle nummer matcher ^[A-Z]{2,4}[0-9]{2}[A-Z]{2}[0-9]{5}$,
--  årssifrene stemmer med fakturadato, og hver omlagt rad har det gamle
--  nummeret i nummer_opprinnelig.
