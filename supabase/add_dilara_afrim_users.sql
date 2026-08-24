-- =====================================================================
--  Legg Dilara og Afrim til i Skoger og Fjell kampsportklubb
--  Kjøres etter at Auth-brukerne er opprettet i Supabase.
-- =====================================================================

do $$
declare
  org uuid;
  u_dilara uuid;
  u_afrim uuid;
begin
  select id into org from organizations where orgnr = '912484335';

  if org is null then
    raise exception 'Fant ikke Skoger og Fjell kampsportklubb med org.nr 912484335';
  end if;

  select id into u_dilara from auth.users where email = 'dilara@kampsportlaget.com';
  select id into u_afrim  from auth.users where email = 'afrim@kampsportlaget.com';

  if u_dilara is not null then
    insert into profiles (id, epost, fornavn, etternavn)
    values (u_dilara, 'dilara@kampsportlaget.com', 'Dilara', '')
    on conflict (id) do update
      set epost = excluded.epost, fornavn = excluded.fornavn, etternavn = excluded.etternavn;

    insert into organization_users (organization_id, user_id, rolle)
    values (org, u_dilara, 'medlem')
    on conflict (organization_id, user_id) do update
      set rolle = excluded.rolle, aktiv = true;
  else
    insert into invitations (organization_id, epost, fornavn, rolle)
    values (org, 'dilara@kampsportlaget.com', 'Dilara', 'medlem')
    on conflict (organization_id, epost) do nothing;
  end if;

  if u_afrim is not null then
    insert into profiles (id, epost, fornavn, etternavn)
    values (u_afrim, 'afrim@kampsportlaget.com', 'Afrim', '')
    on conflict (id) do update
      set epost = excluded.epost, fornavn = excluded.fornavn, etternavn = excluded.etternavn;

    insert into organization_users (organization_id, user_id, rolle)
    values (org, u_afrim, 'medlem')
    on conflict (organization_id, user_id) do update
      set rolle = excluded.rolle, aktiv = true;
  else
    insert into invitations (organization_id, epost, fornavn, rolle)
    values (org, 'afrim@kampsportlaget.com', 'Afrim', 'medlem')
    on conflict (organization_id, epost) do nothing;
  end if;

  raise notice 'Dilara og Afrim er koblet til organisasjonen som medlem-brukere.';
end $$;
