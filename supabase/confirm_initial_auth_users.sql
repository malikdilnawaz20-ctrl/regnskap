-- =====================================================================
--  Bekreft initielle Auth-brukere opprettet fra Supabase Dashboard
-- =====================================================================

update auth.users
   set email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at = now()
 where email in (
   'malik@kampsportlaget.com',
   'carlos@kampsportlaget.com',
   'denis@kampsportlaget.com',
   'dilara@kampsportlaget.com',
   'afrim@kampsportlaget.com'
 );
