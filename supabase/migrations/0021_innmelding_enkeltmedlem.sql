-- =====================================================================
--  0021 — Enkeltmedlemskap i innmeldingsskjemaet
--
--  Samme lenke som før. Øverst velger man familiemedlemskap eller
--  enkeltmedlemskap, og skjemaet retter seg etter valget.
--
--  To ting skiller enkeltmedlemskap fra familiemedlemskap:
--    - hvert medlem kan ha sin egen adresse (arvet fra den første,
--      men overstyrbar), i stedet for én felles familieadresse
--    - det opprettes ingen familie i registeret ved godkjenning
--
--  Fødselsnummer er nå valgfritt. Oppgir man det, utledes fødselsdato
--  av nummeret som før. Lar man det stå tomt, fyller man ut fødselsdato
--  i stedet, og skjemaet slipper deg videre. NIF trenger nummeret til
--  slutt, men innmeldingen skal ikke stoppe på det.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Kolonner
-- ---------------------------------------------------------------------

alter table innmeldinger
  add column if not exists medlemstype text not null default 'familie';

do $$ begin
  alter table innmeldinger add constraint innmeldinger_medlemstype_sjekk
    check (medlemstype in ('familie','enkelt'));
exception when duplicate_object then null; end $$;

-- Egen adresse per person. Står de tomme, gjelder adressen på innmeldingen.
alter table innmelding_personer
  add column if not exists adresse text,
  add column if not exists postnr  text,
  add column if not exists sted    text;

-- Hva lenken tilbyr, og hvordan enkeltmedlemskap presenteres
alter table innmelding_lenker
  add column if not exists tilbyr_familie boolean not null default true,
  add column if not exists tilbyr_enkelt  boolean not null default true,
  add column if not exists enkelt_ingress text;

-- Fødselsnummer valgfritt for klubben
update innmelding_lenker
   set krev_fodselsnummer = false,
       enkelt_ingress = coalesce(enkelt_ingress,
         'Ett medlemskap per person. Skal du melde inn flere, legger du dem til med plusstegnet.')
 where slug = 'skoger-og-fjell';

-- ---------------------------------------------------------------------
-- 2. Skjemaoppslag
-- ---------------------------------------------------------------------

create or replace function innmelding_skjema(p_slug text)
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare r record;
begin
  select l.*, o.navn as orgnavn, o.orgnr
    into r
    from innmelding_lenker l
    join organizations o on o.id = l.organization_id
   where l.slug = lower(trim(p_slug));

  if not found then
    return jsonb_build_object('funnet', false);
  end if;

  return jsonb_build_object(
    'funnet', true,
    'aapen', r.aapen,
    'klubb', r.orgnavn,
    'orgnr', r.orgnr,
    'tittel', coalesce(r.tittel, 'Innmelding'),
    'ingress', r.ingress,
    'enkelt_ingress', r.enkelt_ingress,
    'gratis_drakt', r.gratis_drakt,
    'krev_fodselsnummer', r.krev_fodselsnummer,
    'tilbyr_familie', r.tilbyr_familie,
    'tilbyr_enkelt', r.tilbyr_enkelt,
    'grener', to_jsonb(r.grener)
  );
end;
$$;
grant execute on function innmelding_skjema(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Innsending
-- ---------------------------------------------------------------------

create or replace function send_innmelding(
  p_slug     text,
  p_familie  jsonb,
  p_personer jsonb
) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  l        innmelding_lenker%rowtype;
  ny_id    uuid;
  ref      text;
  p        jsonb;
  i        int := 0;
  antall   int;
  fnr      text;
  fdato    date;
  nylige   int;
  krev_fnr boolean;
  mtype    text;
  f_adr    text; f_post text; f_sted text;
  p_adr    text; p_post text; p_sted text;
  tittel   text;
begin
  select * into l from innmelding_lenker where slug = lower(trim(p_slug));
  if not found then raise exception 'Fant ikke innmeldingsskjemaet.'; end if;
  if not l.aapen then raise exception 'Innmeldingen er stengt for øyeblikket.'; end if;
  krev_fnr := l.krev_fodselsnummer;

  mtype := coalesce(nullif(trim(p_familie->>'medlemstype'), ''), 'familie');
  if mtype not in ('familie','enkelt') then raise exception 'Ukjent medlemstype.'; end if;
  if mtype = 'familie' and not l.tilbyr_familie then raise exception 'Familiemedlemskap tilbys ikke her.'; end if;
  if mtype = 'enkelt'  and not l.tilbyr_enkelt  then raise exception 'Enkeltmedlemskap tilbys ikke her.'; end if;

  select count(*) into nylige
    from innmeldinger
   where organization_id = l.organization_id
     and innsendt > now() - interval '1 hour';
  if nylige >= 20 then
    raise exception 'For mange innmeldinger på kort tid. Prøv igjen om en stund.';
  end if;

  antall := jsonb_array_length(coalesce(p_personer, '[]'::jsonb));
  if antall < 1 then raise exception 'Legg inn minst én person.'; end if;
  if antall > 15 then raise exception 'Maks 15 personer i én innmelding.'; end if;

  -- Felles kontaktopplysninger kreves uansett type
  if coalesce(trim(p_familie->>'kontakt_navn'), '') = '' then raise exception 'Navn på kontaktperson mangler.'; end if;
  if coalesce(trim(p_familie->>'kontakt_epost'), '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-postadressen ser ikke riktig ut.'; end if;
  if coalesce(regexp_replace(p_familie->>'kontakt_telefon', '\D', '', 'g'), '') !~ '^\d{8,15}$' then raise exception 'Telefonnummeret ser ikke riktig ut.'; end if;

  -- Adresse: familie har én felles. Enkeltmedlemskap henter fra første
  -- person, slik at innmeldingen alltid har en adresse å vise.
  if mtype = 'familie' then
    if coalesce(trim(p_familie->>'etternavn'), '') = '' then raise exception 'Familienavn mangler.'; end if;
    f_adr  := trim(p_familie->>'adresse');
    f_post := trim(p_familie->>'postnr');
    f_sted := trim(p_familie->>'sted');
    tittel := 'Familien ' || trim(p_familie->>'etternavn');
  else
    f_adr  := trim(coalesce(p_personer->0->>'adresse', ''));
    f_post := trim(coalesce(p_personer->0->>'postnr', ''));
    f_sted := trim(coalesce(p_personer->0->>'sted', ''));
    tittel := trim(p_familie->>'kontakt_navn') ||
              case when antall > 1 then ' (+' || (antall-1) || ')' else '' end;
  end if;

  if f_adr = '' then raise exception 'Adresse mangler.'; end if;
  if f_post !~ '^\d{4}$' then raise exception 'Postnummer må være fire siffer.'; end if;
  if f_sted = '' then raise exception 'Poststed mangler.'; end if;

  ref := 'INN-' || to_char(now(), 'YYYY') || '-' ||
         upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));

  insert into innmeldinger (
    organization_id, referanse, medlemstype, familienavn, adresse, postnr, sted,
    kontakt_navn, kontakt_epost, kontakt_telefon, notat
  ) values (
    l.organization_id, ref, mtype, tittel, f_adr, f_post, f_sted,
    trim(p_familie->>'kontakt_navn'),
    lower(trim(p_familie->>'kontakt_epost')),
    trim(p_familie->>'kontakt_telefon'),
    nullif(trim(coalesce(p_familie->>'notat', '')), '')
  ) returning id into ny_id;

  for p in select * from jsonb_array_elements(p_personer) loop
    i := i + 1;

    if coalesce(trim(p->>'fornavn'), '') = '' or coalesce(trim(p->>'etternavn'), '') = '' then
      raise exception 'Person %: navn mangler.', i;
    end if;
    if coalesce(p->>'rolle', '') not in ('voksen','barn') then
      raise exception 'Person %: mangler om det er voksen eller barn.', i;
    end if;

    fnr := regexp_replace(coalesce(p->>'fodselsnummer', ''), '\s', '', 'g');

    if fnr = '' then
      -- Fødselsnummer er frivillig. Da må fødselsdato være med.
      if krev_fnr then
        raise exception 'Person %: fødselsnummer mangler.', i;
      end if;
      begin
        fdato := nullif(trim(coalesce(p->>'fodselsdato','')), '')::date;
      exception when others then
        raise exception 'Person %: fødselsdatoen ser ikke riktig ut.', i;
      end;
      if fdato is null then
        raise exception 'Person %: oppgi enten fødselsnummer eller fødselsdato.', i;
      end if;
    else
      if not fnr_gyldig(fnr) then
        raise exception 'Person %: fødselsnummeret er ikke gyldig. Sjekk sifrene, eller la feltet stå tomt og fyll ut fødselsdato i stedet.', i;
      end if;
      fdato := fnr_fodselsdato(fnr);
    end if;

    if fdato > current_date then raise exception 'Person %: fødselsdato er i fremtiden.', i; end if;
    if fdato < current_date - interval '120 years' then raise exception 'Person %: fødselsdatoen ser ikke riktig ut.', i; end if;

    if mtype = 'enkelt' then
      p_adr  := nullif(trim(coalesce(p->>'adresse','')), '');
      p_post := nullif(trim(coalesce(p->>'postnr','')), '');
      p_sted := nullif(trim(coalesce(p->>'sted','')), '');
      if p_post is not null and p_post !~ '^\d{4}$' then
        raise exception 'Person %: postnummer må være fire siffer.', i;
      end if;
    else
      p_adr := null; p_post := null; p_sted := null;
    end if;

    insert into innmelding_personer (
      innmelding_id, organization_id, sortering, rolle, fornavn, etternavn,
      fodselsdato, fnr_kryptert, fnr_maskert, epost, telefon,
      draktstorrelse, gren, samtykke_bilder, adresse, postnr, sted
    ) values (
      ny_id, l.organization_id, i,
      p->>'rolle', trim(p->>'fornavn'), trim(p->>'etternavn'),
      fdato,
      case when fnr = '' then null else krypter_fnr(fnr) end,
      case when fnr = '' then 'ikke oppgitt' else fnr_maskert(fnr) end,
      nullif(lower(trim(coalesce(p->>'epost', ''))), ''),
      nullif(trim(coalesce(p->>'telefon', '')), ''),
      nullif(trim(coalesce(p->>'draktstorrelse', '')), ''),
      nullif(trim(coalesce(p->>'gren', '')), ''),
      coalesce((p->>'samtykke_bilder')::boolean, false),
      p_adr, p_post, p_sted
    );
  end loop;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (l.organization_id, null, 'innmeldinger', ny_id::text, 'mottatt',
          jsonb_build_object('referanse', ref, 'medlemstype', mtype, 'antall_personer', antall));

  return jsonb_build_object('ok', true, 'referanse', ref, 'antall', antall, 'medlemstype', mtype);
end;
$$;
grant execute on function send_innmelding(text, jsonb, jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Godkjenning
--    Familiemedlemskap oppretter en familie. Enkeltmedlemskap gjør ikke
--    det — medlemmene står for seg selv, med sin egen adresse.
-- ---------------------------------------------------------------------

create or replace function godkjenn_innmelding(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  inm      innmeldinger%rowtype;
  fam_id   uuid;
  p        innmelding_personer%rowtype;
  ny_med   uuid;
  antall   int := 0;
begin
  select * into inm from innmeldinger where id = p_id;
  if not found then raise exception 'Fant ikke innmeldingen.'; end if;
  if not kan_medlem(inm.organization_id) then
    raise exception 'Du har ikke tilgang til å godkjenne innmeldinger.';
  end if;
  if inm.status = 'godkjent' then raise exception 'Innmeldingen er allerede godkjent.'; end if;

  if inm.medlemstype = 'familie' then
    insert into families (organization_id, navn, hovedkontakt_epost, hovedkontakt_telefon)
    values (inm.organization_id, inm.familienavn, inm.kontakt_epost, inm.kontakt_telefon)
    returning id into fam_id;
  else
    fam_id := null;
  end if;

  for p in select * from innmelding_personer where innmelding_id = p_id order by sortering loop
    insert into members (
      organization_id, fornavn, etternavn, fodselsdato,
      epost, telefon, adresse, postnr, sted,
      family_id, status,
      foresatt1_navn, foresatt1_epost, foresatt1_telefon,
      notat, opprettet_av
    ) values (
      inm.organization_id, p.fornavn, p.etternavn, p.fodselsdato,
      p.epost, p.telefon,
      coalesce(p.adresse, inm.adresse),
      coalesce(p.postnr,  inm.postnr),
      coalesce(p.sted,    inm.sted),
      fam_id, 'aktiv',
      case when p.rolle = 'barn' then inm.kontakt_navn end,
      case when p.rolle = 'barn' then inm.kontakt_epost end,
      case when p.rolle = 'barn' then inm.kontakt_telefon end,
      nullif(concat_ws(' · ',
        case when inm.medlemstype = 'enkelt' then 'Enkeltmedlemskap' else 'Familiemedlemskap' end
          || ', innmeldt via skjema ' || inm.referanse,
        nullif(p.gren, ''),
        case when p.draktstorrelse is not null then 'Draktstørrelse ' || p.draktstorrelse end,
        case when p.fnr_maskert = 'ikke oppgitt' then 'Fødselsnummer ikke oppgitt — må innhentes for NIF' end,
        case when p.samtykke_bilder then 'Samtykke bilder: ja' else 'Samtykke bilder: nei' end
      ), ''),
      auth.uid()
    ) returning id into ny_med;

    update innmelding_personer
       set member_id = ny_med,
           fnr_kryptert = null,
           fnr_maskert = case when fnr_maskert = 'ikke oppgitt'
                              then 'ikke oppgitt'
                              else 'slettet ved godkjenning' end
     where id = p.id;

    antall := antall + 1;
  end loop;

  update innmeldinger
     set status = 'godkjent', behandlet = now(), behandlet_av = auth.uid(), family_id = fam_id
   where id = p_id;

  insert into audit_logs (organization_id, user_id, tabell, rad_id, handling, til_verdi)
  values (inm.organization_id, auth.uid(), 'innmeldinger', p_id::text, 'godkjent',
          jsonb_build_object('referanse', inm.referanse, 'medlemstype', inm.medlemstype,
                             'family_id', fam_id, 'antall_medlemmer', antall));

  return jsonb_build_object('ok', true, 'family_id', fam_id, 'antall', antall);
end;
$$;
grant execute on function godkjenn_innmelding(uuid) to authenticated;
revoke execute on function godkjenn_innmelding(uuid) from public, anon;
