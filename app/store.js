// =====================================================================
//  Delt tilstand: innlogget bruker, valgt organisasjon, rolle og modul.
//  Alle visninger leser herfra. Ingen visning snakker med auth selv.
// =====================================================================

import { db } from "./lib.js";

export const S = {
  bruker: null,          // { id, epost, fornavn, etternavn }
  organisasjoner: [],    // [{ organization_id, rolle, styreverv, org: {...} }]
  orgId: null,
  org: null,
  rolle: null,           // rollen min i valgt organisasjon
  styreverv: null,
  modul: "regnskap",     // regnskap | medlem | saksbehandling
  rute: "oversikt"
};

/* ---- roller -------------------------------------------------- */

export const erAdmin = () => ["administrator", "styreleder"].includes(S.rolle);
export const kanOkonomi = () => ["administrator", "styreleder", "kasserer"].includes(S.rolle);
export const kanMedlem = () => ["administrator", "styreleder", "medlemsansvarlig", "kasserer"].includes(S.rolle);
export const erRevisor = () => S.rolle === "revisor";
export const kanSkrive = () => !!S.rolle && S.rolle !== "revisor";

export const ROLLER = [
  { verdi: "administrator", tekst: "Administrator — full tilgang" },
  { verdi: "styreleder", tekst: "Styreleder — nesten full tilgang" },
  { verdi: "kasserer", tekst: "Kasserer — økonomi og rapporter" },
  { verdi: "medlemsansvarlig", tekst: "Medlemsansvarlig — medlemmer og aktiviteter" },
  { verdi: "trener", tekst: "Trener — egne grupper, begrenset medlemsinfo" },
  { verdi: "revisor", tekst: "Revisor — kun lesetilgang" },
  { verdi: "medlem", tekst: "Medlem — kun egen informasjon" }
];

export const VERV = [
  "Styreleder", "Nestleder", "Kasserer", "Sekretær", "Styremedlem",
  "Varamedlem", "Medlemsansvarlig", "Materialforvalter", "Sportslig leder",
  "Hovedtrener", "Trener", "Revisor", "Valgkomité", "Ingen verv"
];

/* ---- henting ------------------------------------------------- */

export async function hentBruker() {
  const { data: { user } } = await db.auth.getUser();
  if (!user) { S.bruker = null; return null; }
  const { data: profil } = await db.from("profiles").select("*").eq("id", user.id).maybeSingle();
  S.bruker = {
    id: user.id,
    epost: user.email,
    fornavn: profil?.fornavn || "",
    etternavn: profil?.etternavn || "",
    telefon: profil?.telefon || ""
  };
  return S.bruker;
}

export async function hentOrganisasjoner() {
  const { data, error } = await db
    .from("organization_users")
    .select("organization_id, rolle, styreverv, tittel, organizations(*)")
    .eq("user_id", S.bruker.id)
    .eq("aktiv", true);
  if (error) throw error;

  S.organisasjoner = (data || []).map(r => ({
    organization_id: r.organization_id,
    rolle: r.rolle,
    styreverv: r.styreverv,
    tittel: r.tittel,
    org: r.organizations
  })).filter(r => r.org);

  const lagret = lesValgtOrg();
  const treff = S.organisasjoner.find(o => o.organization_id === lagret) || S.organisasjoner[0];
  if (treff) settOrg(treff.organization_id);
  else { S.orgId = null; S.org = null; S.rolle = null; }
  return S.organisasjoner;
}

export function settOrg(id) {
  const t = S.organisasjoner.find(o => o.organization_id === id);
  if (!t) return false;
  S.orgId = t.organization_id;
  S.org = t.org;
  S.rolle = t.rolle;
  S.styreverv = t.styreverv;
  try { localStorage.setItem("sf-org", id); } catch { }
  return true;
}

function lesValgtOrg() { try { return localStorage.getItem("sf-org"); } catch { return null; } }

/* ---- spørringer alltid scopet til valgt organisasjon ---------- */

/** Bruk denne i stedet for db.from(...) for organisasjonsdata. */
export const q = (tabell) => db.from(tabell).eq ? db.from(tabell) : db.from(tabell);

/** Hjelper: select med organisasjonsfilter. */
export function velgFra(tabell, kolonner = "*") {
  return db.from(tabell).select(kolonner).eq("organization_id", S.orgId);
}

/** Hjelper: sett inn rad med organisasjonsfilter påført. */
export function settInn(tabell, rad) {
  const data = Array.isArray(rad)
    ? rad.map(r => ({ ...r, organization_id: S.orgId }))
    : { ...rad, organization_id: S.orgId };
  return db.from(tabell).insert(data);
}

export const aarNaa = () => new Date().getFullYear();

/* ---- enkel hendelsesbuss så visninger kan be om ny tegning ----
   Unngår sirkulær import mellom app.js og visningsfilene.        */

export function paaNytt() { window.dispatchEvent(new CustomEvent("sf:tegn")); }
export function gaTil(rute) { location.hash = "#/" + S.modul + "/" + rute; }
