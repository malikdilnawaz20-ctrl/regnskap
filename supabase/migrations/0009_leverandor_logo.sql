-- =====================================================================
--  0009 — Logo på leverandøren
--
--  Noen leverandører (som IFKK) har en egen logo som skal med på
--  fakturaen. Lagres som data-URI eller lenke i tekstfeltet — malene
--  som støtter logo viser den automatisk, resten ignorerer feltet.
-- =====================================================================

alter table vendors
  add column if not exists logo text;

comment on column vendors.logo is 'Logo som data-URI (data:image/...;base64,...) eller URL. Tomt felt = ingen logo på fakturaen.';
