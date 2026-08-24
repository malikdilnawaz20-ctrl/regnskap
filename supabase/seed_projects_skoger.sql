-- =====================================================================
--  Prosjekter for Skoger og Fjell kampsportklubb
--  Oppdatert etter tilskuddsbrev lastet opp 2026-08-24.
-- =====================================================================

do $$
declare
  org uuid;
begin
  select id into org from organizations where orgnr = '912484335';
  if org is null then
    raise exception 'Fant ikke organisasjon 912484335';
  end if;

  insert into projects (
    organization_id, navn, beskrivelse, tilskuddsgiver, tilskudd_ore,
    start_dato, slutt_dato, rapportfrist, status
  ) values
    (
      org,
      'Åpen Hall 2025',
      'Tilskuddsprosjekt for Åpen hall i Aktive Lokalsamfunn. Beløp er hentet fra tildelingsbrev for 2025.',
      'Drammen idrettsråd - Aktive Lokalsamfunn',
      5000000,
      '2025-01-01',
      '2025-12-31',
      null,
      'aktiv'
    ),
    (
      org,
      'Åpen Hall 2026',
      'Videreføring av Åpen Hall med aktivitetstilbud og oppfølging i idrettslaget. Opprettet som eget prosjektspor for årets tilskudd.',
      'Tilskuddsgiver - Åpen Hall',
      6000000,
      '2026-01-01',
      '2026-12-31',
      '2027-03-31',
      'aktiv'
    ),
    (
      org,
      'Ungdommer i IL 2026',
      'Tilskuddsprosjekt for Ungdom i AL / ungdommer i idrettslaget. Beløp er hentet fra tilsagnsbrev Aktive Lokalsamfunn.',
      'Drammen idrettsråd - Aktive Lokalsamfunn',
      6000000,
      '2026-01-01',
      '2026-12-31',
      '2026-12-31',
      'aktiv'
    )
  on conflict (organization_id, navn) do update set
    beskrivelse = excluded.beskrivelse,
    tilskuddsgiver = excluded.tilskuddsgiver,
    tilskudd_ore = excluded.tilskudd_ore,
    start_dato = excluded.start_dato,
    slutt_dato = excluded.slutt_dato,
    rapportfrist = excluded.rapportfrist,
    status = excluded.status;
end $$;
