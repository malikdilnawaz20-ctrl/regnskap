-- =====================================================================
--  0008 — Batch og kolleksjon for eksport/produksjonsfaktura
--
--  Tekstilleverandører (som Awan Fabrication) opererer med batch-nummer
--  og kolleksjonsnavn på sine proforma- og handelsfakturaer, i tillegg
--  til leveringsdato og bestemmelsesland som allerede fantes. To nye,
--  valgfrie felt — ingenting endres for leverandører som ikke bruker dem.
-- =====================================================================

alter table vendor_invoices
  add column if not exists batch_nr    text,
  add column if not exists kolleksjon  text;

comment on column vendor_invoices.batch_nr   is 'Produksjonens batch-/lot-nummer, typisk for tekstil- og produksjonsfakturaer.';
comment on column vendor_invoices.kolleksjon is 'Kolleksjon/sesong varene tilhører, f.eks. "Uniform" eller "SS26".';
