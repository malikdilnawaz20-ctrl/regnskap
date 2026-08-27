-- Bekreftede mottakere for honorarutbetalinger importert fra Fiken.
-- Andre honorarmerker og de tre store, uspesifiserte betalingene avklares i UI.

with org as (
  select id from organizations where orgnr = '912484335' limit 1
), navn(bilag, mottaker) as (
  values
    ('FIKEN-2025-0061', 'Hizzar Ali'), ('FIKEN-2025-0062', 'Aman Malik'),
    ('FIKEN-2025-0095', 'Aneesa Malik'), ('FIKEN-2025-0106', 'Hizzar Ali'),
    ('FIKEN-2025-0107', 'Aneesa Malik'), ('FIKEN-2025-0112', 'Aman Malik'),
    ('FIKEN-2025-0113', 'Amir Malik'), ('FIKEN-2025-0115', 'Aneesa Malik'),
    ('FIKEN-2025-0122', 'Aneesa Malik'), ('FIKEN-2025-0123', 'Amir Malik'),
    ('FIKEN-2025-0124', 'Hizzar Ali'), ('FIKEN-2025-0125', 'Aneesa Malik'),
    ('FIKEN-2025-0130', 'Aman Malik'), ('FIKEN-2025-0134', 'Aneesa Malik'),
    ('FIKEN-2025-0142', 'Amir Malik'), ('FIKEN-2025-0143', 'Aneesa Malik'),
    ('FIKEN-2025-0144', 'Aman Malik'), ('FIKEN-2025-0145', 'Hizzar Ali'),
    ('FIKEN-2025-0156', 'Amir Malik'), ('FIKEN-2025-0161', 'Amir Malik'),
    ('FIKEN-2025-0164', 'Hizzar Ali'), ('FIKEN-2025-0165', 'Aneesa Malik'),
    ('FIKEN-2025-0167', 'Aman Malik')
)
update transactions t
set motpart = navn.mottaker,
    beskrivelse = 'Honorar - ' || navn.mottaker,
    endret = now()
from org, navn
where t.organization_id = org.id
  and t.bilagsnummer = navn.bilag;

with org as (
  select id from organizations where orgnr = '912484335' limit 1
), uklare(bilag, konto) as (
  values
    ('FIKEN-2025-0135', '4111.15.93777'),
    ('FIKEN-2025-0138', '1204.62.69215'),
    ('FIKEN-2025-0141', '2220.35.54846')
)
update transactions t
set motpart = 'Konto ' || uklare.konto || ' (må avklares)',
    beskrivelse = 'Uspesifisert overføring - konto ' || uklare.konto,
    endret = now()
from org, uklare
where t.organization_id = org.id
  and t.bilagsnummer = uklare.bilag;
