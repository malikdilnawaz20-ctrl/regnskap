-- =====================================================================
--  Brukere for signering — Ardita, Adriana, Heidi, Robert og Truls
--
--  1. Opprett de fem i Supabase: Authentication → Users → Add user
--     (e-post + passord, «Auto Confirm User» på). E-postene under.
--  2. Kjør dette skriptet. Det bekrefter e-posten, lager profil,
--     gir medlem-rolle med styreverv i Skoger og Fjell, og kobler
--     Ardita og Adriana til styreregisteret så signaturene deres
--     henger sammen med styret.
--
--  Kan kjøres flere ganger. Finnes ikke auth-brukeren, legges det
--  i stedet en invitasjon som fanges opp ved første innlogging.
-- =====================================================================

do $$
declare
  org uuid;
  rad record;
  uid uuid;
begin
  select id into org from organizations where orgnr = '912484335';
  if org is null then raise exception 'Fant ikke Skoger og Fjell kampsportklubb (912484335)'; end if;

  for rad in select * from (values
      ('ardita@kampsportlaget.com',  'Ardita',  'Januzi', 'Styremedlem'),
      ('adriana@kampsportlaget.com', 'Adriana', 'Dije',   'Styremedlem'),
      ('heidi@kampsportlaget.com',   'Heidi',   '',       'Styremedlem'),
      ('robert@kampsportlaget.com',  'Robert',  '',       'Styremedlem'),
      ('truls@kampsportlaget.com',   'Truls',   '',       'Styremedlem')
    ) as t(epost, fornavn, etternavn, verv)
  loop
    select id into uid from auth.users where email = rad.epost;

    if uid is not null then
      update auth.users
         set email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
       where id = uid;

      insert into profiles (id, epost, fornavn, etternavn)
      values (uid, rad.epost, rad.fornavn, rad.etternavn)
      on conflict (id) do update
        set epost = excluded.epost,
            fornavn = excluded.fornavn,
            etternavn = case when excluded.etternavn <> '' then excluded.etternavn else profiles.etternavn end;

      insert into organization_users (organization_id, user_id, rolle, styreverv)
      values (org, uid, 'medlem', rad.verv)
      on conflict (organization_id, user_id) do update
        set aktiv = true, styreverv = coalesce(organization_users.styreverv, excluded.styreverv);

      -- Koble til styreregisteret der navnet finnes fra før (Ardita, Adriana)
      update board_members
         set user_id = uid
       where organization_id = org and user_id is null
         and lower(navn) = lower(trim(rad.fornavn || ' ' || rad.etternavn));

      raise notice '% er koblet til organisasjonen.', rad.epost;
    else
      insert into invitations (organization_id, epost, fornavn, rolle)
      values (org, rad.epost, rad.fornavn, 'medlem')
      on conflict (organization_id, epost) do nothing;
      raise notice '% finnes ikke i Auth ennå — invitasjon lagt inn.', rad.epost;
    end if;
  end loop;
end $$;

-- Kontroll
select p.epost, p.fornavn, p.etternavn, ou.rolle, ou.styreverv,
       (select navn from board_members b where b.user_id = p.id) as i_styret
  from profiles p
  join organization_users ou on ou.user_id = p.id
 where p.epost in ('ardita@kampsportlaget.com','adriana@kampsportlaget.com',
                   'heidi@kampsportlaget.com','robert@kampsportlaget.com','truls@kampsportlaget.com');
