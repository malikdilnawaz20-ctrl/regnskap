-- =====================================================================
--  0019 — Innsyn: «medlem» ser bare dokumenter og signering
--
--  Fra starten ga den generelle regelen alle i organisasjonen lese-
--  tilgang til det meste. Menyen skjulte det, men databasen svarte.
--  Styremedlemmer som bare skal signere protokoller, skal ikke kunne
--  hente ut regnskap, medlemsregister eller fakturaer.
--
--  Løsning: RESTRIKTIVE regler oppå de som finnes. Postgres krever at
--  både minst én vanlig regel OG alle restriktive regler er oppfylt.
--  Da trenger vi ikke skrive om 40 eksisterende regler — vi legger
--  en sperre over hver tabell som sier hvilke roller som kan se den.
--
--    Økonomi    administrator, styreleder, kasserer, revisor
--    Medlemmer  administrator, styreleder, kasserer, medlemsansvarlig, trener
--    Alle       dokumenter, signering, styret, fullmakter, egen profil
--
--  Administrator gir utvidet innsyn ved å endre rollen under
--  Innstillinger → Brukere og roller. Kan kjøres flere ganger.
-- =====================================================================

create or replace function kan_se_okonomi(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select har_rolle(org, array['administrator','styreleder','kasserer','revisor']::user_role[]);
$$;

create or replace function kan_se_medlemmer(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select har_rolle(org, array['administrator','styreleder','kasserer','medlemsansvarlig','trener']::user_role[]);
$$;

-- ---------------------------------------------------------------------
--  Tabeller med organization_id
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  -- Økonomi
  foreach t in array array[
    'accounting_accounts','accounts','attachments','budgets','categories','customers',
    'fees','fiscal_years','import_jobs','invoice_sequences','payment_claims','projects',
    'sales_invoices','supplier_invoices','transactions','vendor_invoices','vendors','voucher_sequences'
  ] loop
    if to_regclass(t) is null then continue; end if;
    execute format('drop policy if exists %1$s_innsyn on %1$s', t);
    execute format(
      'create policy %1$s_innsyn on %1$s as restrictive for all
         using (kan_se_okonomi(organization_id)) with check (kan_se_okonomi(organization_id))', t);
  end loop;

  -- Medlemmer
  foreach t in array array['members','families','activities','groups','innmelding_lenker'] loop
    if to_regclass(t) is null then continue; end if;
    execute format('drop policy if exists %1$s_innsyn on %1$s', t);
    execute format(
      'create policy %1$s_innsyn on %1$s as restrictive for all
         using (kan_se_medlemmer(organization_id)) with check (kan_se_medlemmer(organization_id))', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
--  Tabeller uten organization_id: arver fra forelderen
-- ---------------------------------------------------------------------
drop policy if exists sales_invoice_lines_innsyn on sales_invoice_lines;
create policy sales_invoice_lines_innsyn on sales_invoice_lines as restrictive for all
  using (exists (select 1 from sales_invoices i where i.id = invoice_id and kan_se_okonomi(i.organization_id)))
  with check (exists (select 1 from sales_invoices i where i.id = invoice_id and kan_se_okonomi(i.organization_id)));

drop policy if exists vendor_invoice_lines_innsyn on vendor_invoice_lines;
create policy vendor_invoice_lines_innsyn on vendor_invoice_lines as restrictive for all
  using (exists (select 1 from vendor_invoices i where i.id = invoice_id and kan_se_okonomi(i.organization_id)))
  with check (exists (select 1 from vendor_invoices i where i.id = invoice_id and kan_se_okonomi(i.organization_id)));

drop policy if exists vendor_customers_innsyn on vendor_customers;
create policy vendor_customers_innsyn on vendor_customers as restrictive for all
  using (exists (select 1 from vendors v where v.id = vendor_id and kan_se_okonomi(v.organization_id)))
  with check (exists (select 1 from vendors v where v.id = vendor_id and kan_se_okonomi(v.organization_id)));

drop policy if exists vendor_invoice_sequences_innsyn on vendor_invoice_sequences;
create policy vendor_invoice_sequences_innsyn on vendor_invoice_sequences as restrictive for all
  using (exists (select 1 from vendors v where v.id = vendor_id and kan_se_okonomi(v.organization_id)))
  with check (exists (select 1 from vendors v where v.id = vendor_id and kan_se_okonomi(v.organization_id)));

drop policy if exists member_activities_innsyn on member_activities;
create policy member_activities_innsyn on member_activities as restrictive for all
  using (exists (select 1 from members m where m.id = member_id and kan_se_medlemmer(m.organization_id)))
  with check (exists (select 1 from members m where m.id = member_id and kan_se_medlemmer(m.organization_id)));

drop policy if exists member_groups_innsyn on member_groups;
create policy member_groups_innsyn on member_groups as restrictive for all
  using (exists (select 1 from members m where m.id = member_id and kan_se_medlemmer(m.organization_id)))
  with check (exists (select 1 from members m where m.id = member_id and kan_se_medlemmer(m.organization_id)));

-- ---------------------------------------------------------------------
--  Filer: kvitteringer og bilag («bilag»-bøtta) bare for økonomirollene.
--  Dokumentbøtta er åpen for alle i organisasjonen som før.
-- ---------------------------------------------------------------------
drop policy if exists "bilag kun for okonomi" on storage.objects;
create policy "bilag kun for okonomi" on storage.objects as restrictive for select
  using (bucket_id <> 'bilag' or kan_se_okonomi(((storage.foldername(name))[1])::uuid));

-- ---------------------------------------------------------------------
--  Kontroll (kjør som en medlem-bruker i appen, eller sjekk reglene):
--    select tablename, policyname, permissive from pg_policies
--     where policyname like '%_innsyn' order by 1;
-- ---------------------------------------------------------------------
