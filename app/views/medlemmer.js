// =====================================================================
//  Medlemmer, aktiviteter og familier — Saksflyt Medlem.
//  Ett medlem er én rad i members-tabellen, aldri duplisert per
//  aktivitet. Kobling til aktiviteter/grupper skjer via
//  member_activities / member_groups.
// =====================================================================

import {
  el, svg, kpi, kort, stat, pille, tabell, felt, skjemaModal, bekreft, toast, visFeil,
  laster, kr, kr0, tilOre, dato, alder, initialer, eksporterExcel, lesExcel,
  velg, iDag, tom, db
} from "../lib.js";
import { S, kanMedlem, kanSkrive, velgFra, settInn, paaNytt, gaTil } from "../store.js";

/* ---------------------------------------------------------------
   Faste verdier
   --------------------------------------------------------------- */

const STATUS_VALG = [
  { verdi: "aktiv", tekst: "Aktiv" },
  { verdi: "inaktiv", tekst: "Inaktiv" },
  { verdi: "utmeldt", tekst: "Utmeldt" },
  { verdi: "venteliste", tekst: "Venteliste" }
];

const KJONN_VALG = [
  { verdi: "", tekst: "– Ikke oppgitt –" },
  { verdi: "kvinne", tekst: "Kvinne" },
  { verdi: "mann", tekst: "Mann" },
  { verdi: "annet", tekst: "Annet" }
];

// Målfelt for Excel-importen, i den rekkefølgen de vises i veiviseren.
const MAALFELT = [
  { navn: "fornavn", label: "Fornavn", nokler: ["fornavn", "first name", "firstname", "fname"] },
  { navn: "etternavn", label: "Etternavn", nokler: ["etternavn", "last name", "lastname", "surname"] },
  { navn: "fodselsdato", label: "Fødselsdato", nokler: ["fødselsdato", "fodselsdato", "birth date", "birthdate", "dob", "født", "fodt"] },
  { navn: "epost", label: "E-post", nokler: ["e-post", "epost", "email", "e-mail", "mail"] },
  { navn: "telefon", label: "Telefon", nokler: ["telefon", "tlf", "phone", "mobil", "mobile"] },
  { navn: "adresse", label: "Adresse", nokler: ["adresse", "address"] },
  { navn: "postnr", label: "Postnummer", nokler: ["postnr", "postnummer", "zip", "postcode", "postal code"] },
  { navn: "sted", label: "Poststed", nokler: ["sted", "poststed", "by", "city"] },
  { navn: "aktivitet", label: "Aktivitet", nokler: ["aktivitet", "activity", "gruppe", "idrett", "sport"] },
  { navn: "foresatt_navn", label: "Foresatt – navn", nokler: ["foresatt", "guardian", "parent"] },
  { navn: "foresatt_epost", label: "Foresatt – e-post", nokler: ["foresatt e-post", "foresatt epost", "guardian email", "parent email"] },
  { navn: "foresatt_telefon", label: "Foresatt – telefon", nokler: ["foresatt telefon", "foresatt tlf", "guardian phone", "parent phone"] }
];

// Rekkefølgen kolonne-gjetningen kjøres i — mest spesifikke først,
// slik at f.eks. "Foresatt e-post" ikke stjeles av det generiske "epost".
const GJETT_REKKEFOLGE = [
  "fornavn", "etternavn", "fodselsdato",
  "foresatt_epost", "foresatt_telefon", "foresatt_navn",
  "epost", "telefon", "adresse", "postnr", "sted", "aktivitet"
];

/* ---------------------------------------------------------------
   Delte hjelpere
   --------------------------------------------------------------- */

function normaliserTekst(s) {
  return String(s || "").toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "").trim();
}

function pad2(n) { return String(n).padStart(2, "0"); }

/** Godtar iso, dd.mm.åååå, dd/mm/åååå og det Date() klarer å tolke. */
function normaliserDato(v) {
  if (!v) return "";
  const s = String(v).trim();
  if (!s) return "";
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return `${m[1]}-${pad2(m[2])}-${pad2(m[3])}`;
  m = s.match(/^(\d{1,2})[.\/](\d{1,2})[.\/](\d{4})$/);
  if (m) return `${m[3]}-${pad2(m[1])}-${pad2(m[2])}`;
  const d = new Date(s);
  if (!isNaN(d.getTime())) return d.toISOString().slice(0, 10);
  return "";
}

function splitAktiviteter(tekst) {
  if (!tekst) return [];
  return [...new Set(String(tekst).split(/[,;/]/).map(s => s.trim()).filter(Boolean))];
}

/** Under 18 år, eller fødselsdato mangler → vis foresatt-felt. */
function skalViseForesatt(m) {
  if (!m || !m.fodselsdato) return true;
  const a = alder(m.fodselsdato);
  return a === null || a < 18;
}

function statusVisning(s) {
  switch (s) {
    case "aktiv": return { tekst: "Aktiv", farge: "green" };
    case "inaktiv": return { tekst: "Inaktiv", farge: "neutral" };
    case "utmeldt": return { tekst: "Utmeldt", farge: "red" };
    case "venteliste": return { tekst: "Venteliste", farge: "gold" };
    default: return { tekst: s || "—", farge: "neutral" };
  }
}

function betalingsstatus(claims) {
  if (!claims.length) return { tekst: "Ingen krav", farge: "neutral" };
  if (claims.some(c => c.status === "forfalt")) return { tekst: "Forfalt", farge: "red" };
  if (claims.some(c => c.status === "ikke_betalt")) return { tekst: "Ikke betalt", farge: "red" };
  if (claims.some(c => c.status === "delvis_betalt")) return { tekst: "Delvis betalt", farge: "gold" };
  return { tekst: "Betalt", farge: "green" };
}

/** Erstatter medlemmets aktivitets- og gruppekoblinger med de valgte. */
async function lagreKoblinger(memberId, aktivitetIder, gruppeIder) {
  const { error: e1 } = await db.from("member_activities").delete().eq("member_id", memberId);
  if (e1) throw e1;
  if (aktivitetIder.length) {
    const { error } = await db.from("member_activities")
      .insert(aktivitetIder.map(id => ({ member_id: memberId, activity_id: id })));
    if (error) throw error;
  }
  const { error: e2 } = await db.from("member_groups").delete().eq("member_id", memberId);
  if (e2) throw e2;
  if (gruppeIder.length) {
    const { error } = await db.from("member_groups")
      .insert(gruppeIder.map(id => ({ member_id: memberId, group_id: id })));
    if (error) throw error;
  }
}

/* =====================================================================
   Medlemmer
   ===================================================================== */

export const medlemmerView = {
  tittel: "Medlemmer",
  undertekst: "Medlemsregister, søk og import fra regneark.",

  async bygg() {
    if (!S.orgId) return el("div", { class: "empty" }, "Velg en organisasjon for å se medlemmer.");

    let medlemmer = [], aktiviteter = [], grupper = [], claims = [], memberActs = [], memberGroups = [];
    try {
      const { data: mData, error: mErr } = await velgFra("members").order("etternavn").order("fornavn");
      if (mErr) throw mErr;
      medlemmer = mData || [];

      const { data: aData, error: aErr } = await velgFra("activities").order("navn");
      if (aErr) throw aErr;
      aktiviteter = aData || [];

      const { data: gData, error: gErr } = await velgFra("groups").order("navn");
      if (gErr) throw gErr;
      grupper = gData || [];

      const { data: cData, error: cErr } = await velgFra("payment_claims", "member_id, status");
      if (cErr) throw cErr;
      claims = cData || [];

      const aktIder = aktiviteter.map(a => a.id);
      if (aktIder.length) {
        const { data, error } = await db.from("member_activities").select("member_id, activity_id").in("activity_id", aktIder);
        if (error) throw error;
        memberActs = data || [];
      }

      const gruppeIder = grupper.map(g => g.id);
      if (gruppeIder.length) {
        const { data, error } = await db.from("member_groups").select("member_id, group_id").in("group_id", gruppeIder);
        if (error) throw error;
        memberGroups = data || [];
      }
    } catch (e) {
      visFeil(e, "Henting av medlemmer");
      return el("div", { class: "note bad" }, "Kunne ikke hente medlemmer. Prøv å laste siden på nytt.");
    }

    const aktivitetMap = new Map(aktiviteter.map(a => [a.id, a]));

    const memberActivityMap = new Map();
    for (const r of memberActs) {
      if (!memberActivityMap.has(r.member_id)) memberActivityMap.set(r.member_id, new Set());
      memberActivityMap.get(r.member_id).add(r.activity_id);
    }
    const memberGroupMap = new Map();
    for (const r of memberGroups) {
      if (!memberGroupMap.has(r.member_id)) memberGroupMap.set(r.member_id, new Set());
      memberGroupMap.get(r.member_id).add(r.group_id);
    }
    const claimMap = new Map();
    for (const c of claims) {
      if (!claimMap.has(c.member_id)) claimMap.set(c.member_id, []);
      claimMap.get(c.member_id).push(c);
    }

    const grense30 = new Date();
    grense30.setDate(grense30.getDate() - 30);
    const ubetalteIder = new Set(
      claims.filter(c => ["ikke_betalt", "delvis_betalt", "forfalt"].includes(c.status)).map(c => c.member_id)
    );

    /* ---- medlemskort: opprett/rediger ---- */

    async function apneMedlemskort(m) {
      const erNy = !m;
      const visForesatt = skalViseForesatt(m);

      const felter = [
        { navn: "fornavn", label: "Fornavn", verdi: m?.fornavn || "" },
        { navn: "etternavn", label: "Etternavn", verdi: m?.etternavn || "" },
        { navn: "fodselsdato", label: "Fødselsdato", type: "date", verdi: m?.fodselsdato || "" },
        { navn: "kjonn", label: "Kjønn", type: "select", valg: KJONN_VALG, verdi: m?.kjonn || "" },
        { navn: "epost", label: "E-post", type: "email", verdi: m?.epost || "" },
        { navn: "telefon", label: "Telefon", verdi: m?.telefon || "" },
        { navn: "adresse", label: "Adresse", verdi: m?.adresse || "" },
        { navn: "postnr", label: "Postnr", verdi: m?.postnr || "" },
        { navn: "sted", label: "Sted", verdi: m?.sted || "" },
        { navn: "innmeldt", label: "Innmeldt", type: "date", verdi: m?.innmeldt || iDag() },
        { navn: "status", label: "Status", type: "select", valg: STATUS_VALG, verdi: m?.status || "aktiv" },
        ...(visForesatt ? [
          { navn: "foresatt1_navn", label: "Foresatt 1 – navn", verdi: m?.foresatt1_navn || "" },
          { navn: "foresatt1_epost", label: "Foresatt 1 – e-post", type: "email", verdi: m?.foresatt1_epost || "" },
          { navn: "foresatt1_telefon", label: "Foresatt 1 – telefon", verdi: m?.foresatt1_telefon || "" },
          { navn: "foresatt2_navn", label: "Foresatt 2 – navn", verdi: m?.foresatt2_navn || "" },
          { navn: "foresatt2_epost", label: "Foresatt 2 – e-post", type: "email", verdi: m?.foresatt2_epost || "" },
          { navn: "foresatt2_telefon", label: "Foresatt 2 – telefon", verdi: m?.foresatt2_telefon || "" }
        ] : []),
        { navn: "notat", label: "Notat", type: "textarea", verdi: m?.notat || "", bredde: "full" }
      ];

      const eksisterendeAktIder = memberActivityMap.get(m?.id) || new Set();
      const eksisterendeGruppeIder = memberGroupMap.get(m?.id) || new Set();
      const aktivitetInputs = new Map();
      const gruppeInputs = new Map();

      const aktBoks = aktiviteter.length
        ? el("div", { class: "stack" }, aktiviteter.map(a => {
            const cb = el("input", { type: "checkbox", checked: eksisterendeAktIder.has(a.id) });
            aktivitetInputs.set(a.id, cb);
            return el("label", { class: "check" }, [cb, a.navn]);
          }))
        : el("div", { class: "empty" }, "Ingen aktiviteter opprettet ennå.");

      const gruppeBoks = grupper.length
        ? el("div", { class: "stack" }, grupper.map(g => {
            const cb = el("input", { type: "checkbox", checked: eksisterendeGruppeIder.has(g.id) });
            gruppeInputs.set(g.id, cb);
            const aktNavn = aktivitetMap.get(g.activity_id)?.navn || "";
            return el("label", { class: "check" }, [cb, aktNavn ? `${aktNavn} – ${g.navn}` : g.navn]);
          }))
        : el("div", { class: "empty" }, "Ingen grupper opprettet ennå.");

      const ekstra = el("div", { class: "grid g2" }, [
        el("div", {}, [el("div", { class: "eyebrow" }, "Aktiviteter"), aktBoks]),
        el("div", {}, [el("div", { class: "eyebrow" }, "Grupper"), gruppeBoks])
      ]);

      await skjemaModal({
        tittel: erNy ? "Nytt medlem" : `${m.fornavn} ${m.etternavn}`,
        beskrivelse: erNy ? "Registrer et nytt medlem." : "Rediger medlemsopplysninger.",
        felter,
        ekstra,
        lagreTekst: erNy ? "Legg til" : "Lagre",
        onLagre: async (data) => {
          if (!data.fornavn || !data.etternavn) {
            toast("Mangler informasjon", "Fornavn og etternavn må fylles ut.", true);
            return false;
          }
          const tomTilNull = (v) => (v === "" || v === undefined ? null : v);
          const payload = {
            fornavn: data.fornavn,
            etternavn: data.etternavn,
            fodselsdato: tomTilNull(data.fodselsdato),
            kjonn: tomTilNull(data.kjonn),
            epost: tomTilNull(data.epost),
            telefon: tomTilNull(data.telefon),
            adresse: tomTilNull(data.adresse),
            postnr: tomTilNull(data.postnr),
            sted: tomTilNull(data.sted),
            innmeldt: data.innmeldt || iDag(),
            status: data.status || "aktiv",
            notat: tomTilNull(data.notat)
          };
          if (visForesatt) {
            payload.foresatt1_navn = tomTilNull(data.foresatt1_navn);
            payload.foresatt1_epost = tomTilNull(data.foresatt1_epost);
            payload.foresatt1_telefon = tomTilNull(data.foresatt1_telefon);
            payload.foresatt2_navn = tomTilNull(data.foresatt2_navn);
            payload.foresatt2_epost = tomTilNull(data.foresatt2_epost);
            payload.foresatt2_telefon = tomTilNull(data.foresatt2_telefon);
          }

          let memberId = m?.id;
          if (erNy) {
            const { data: ny, error } = await settInn("members", payload).select("id").single();
            if (error) throw error;
            memberId = ny.id;
          } else {
            const { error } = await db.from("members").update(payload).eq("id", memberId);
            if (error) throw error;
          }

          const valgteAkt = [...aktivitetInputs].filter(([, cb]) => cb.checked).map(([id]) => id);
          const valgteGrupper = [...gruppeInputs].filter(([, cb]) => cb.checked).map(([id]) => id);
          await lagreKoblinger(memberId, valgteAkt, valgteGrupper);

          paaNytt();
          toast(erNy ? "Medlem lagt til" : "Medlem lagret", `${data.fornavn} ${data.etternavn} er lagret.`);
        },
        onSlett: (!erNy && kanMedlem()) ? async () => {
          const { error } = await db.from("members").delete().eq("id", m.id);
          if (error) throw error;
          paaNytt();
          toast("Medlem slettet", `${m.fornavn} ${m.etternavn} er slettet.`);
        } : undefined
      });
    }

    /* ---- Excel-eksport ---- */

    async function eksporterMedlemmer() {
      try {
        const medlemsRader = medlemmer.map(m => ({
          "Fornavn": m.fornavn,
          "Etternavn": m.etternavn,
          "Fødselsdato": m.fodselsdato || "",
          "Alder": m.fodselsdato ? alder(m.fodselsdato) : "",
          "Kjønn": m.kjonn || "",
          "E-post": m.epost || "",
          "Telefon": m.telefon || "",
          "Adresse": m.adresse || "",
          "Postnr": m.postnr || "",
          "Sted": m.sted || "",
          "Aktiviteter": [...(memberActivityMap.get(m.id) || [])].map(id => aktivitetMap.get(id)?.navn).filter(Boolean).join(", "),
          "Status": statusVisning(m.status).tekst,
          "Innmeldt": m.innmeldt || "",
          "Notat": m.notat || ""
        }));

        const antallPerAktivitet = new Map();
        for (const ider of memberActivityMap.values()) {
          for (const id of ider) antallPerAktivitet.set(id, (antallPerAktivitet.get(id) || 0) + 1);
        }
        const aktivitetRader = aktiviteter.map(a => ({
          "Aktivitet": a.navn,
          "Beskrivelse": a.beskrivelse || "",
          "Aktiv": a.aktiv ? "Ja" : "Nei",
          "Antall medlemmer": antallPerAktivitet.get(a.id) || 0
        }));

        await eksporterExcel("medlemmer.xlsx", { "Medlemmer": medlemsRader, "Aktiviteter": aktivitetRader });
        toast("Eksportert", "Filen ble lastet ned.");
      } catch (e) { visFeil(e, "Eksport"); }
    }

    /* ---- Excel-import: veiviser ---- */

    async function kjorImport(filnavn, rader, mapRad, beregnForhandsvisning) {
      const { mapped, gyldige } = beregnForhandsvisning();
      const trengerGjennomgang = mapped.length - gyldige.length;

      const normNavn = (s) => (s || "").trim().toLowerCase();
      const nokkel1 = (fornavn, etternavn, fodselsdato) => `${normNavn(fornavn)}|${normNavn(etternavn)}|${fodselsdato || ""}`;
      const nokkel2 = (epost, fodselsdato) => (epost && fodselsdato) ? `${epost.trim().toLowerCase()}|${fodselsdato}` : null;

      const settKey1 = new Set(medlemmer.map(m => nokkel1(m.fornavn, m.etternavn, m.fodselsdato)));
      const settKey2 = new Set(medlemmer.filter(m => m.epost && m.fodselsdato).map(m => nokkel2(m.epost, m.fodselsdato)));

      const nyeRader = [];
      let duplikater = 0;
      for (const r of gyldige) {
        const k1 = nokkel1(r.fornavn, r.etternavn, r.fodselsdato);
        const k2 = nokkel2(r.epost, r.fodselsdato);
        if (settKey1.has(k1) || (k2 && settKey2.has(k2))) { duplikater++; continue; }
        settKey1.add(k1);
        if (k2) settKey2.add(k2);
        nyeRader.push(r);
      }

      // Opprett aktiviteter som ikke finnes fra før.
      const aktivitetNavnTilId = new Map(aktiviteter.map(a => [a.navn.toLowerCase(), a.id]));
      const alleAktivitetNavn = new Set();
      for (const r of nyeRader) splitAktiviteter(r.aktivitet).forEach(n => alleAktivitetNavn.add(n));
      const manglerAktiviteter = [...alleAktivitetNavn].filter(n => !aktivitetNavnTilId.has(n.toLowerCase()));
      if (manglerAktiviteter.length) {
        const { data: nyeAkt, error } = await settInn("activities", manglerAktiviteter.map(navn => ({ navn }))).select("id, navn");
        if (error) throw error;
        for (const a of (nyeAkt || [])) {
          aktivitetNavnTilId.set(a.navn.toLowerCase(), a.id);
          aktiviteter.push({ id: a.id, navn: a.navn, aktiv: true });
        }
      }

      const KLUMPSTR = 200;
      let importerte = 0;
      const koblinger = [];
      for (let i = 0; i < nyeRader.length; i += KLUMPSTR) {
        const klump = nyeRader.slice(i, i + KLUMPSTR);
        const payload = klump.map(r => ({
          fornavn: r.fornavn,
          etternavn: r.etternavn,
          fodselsdato: r.fodselsdato || null,
          epost: r.epost || null,
          telefon: r.telefon || null,
          adresse: r.adresse || null,
          postnr: r.postnr || null,
          sted: r.sted || null,
          foresatt1_navn: r.foresatt_navn || null,
          foresatt1_epost: r.foresatt_epost || null,
          foresatt1_telefon: r.foresatt_telefon || null
        }));
        const { data: satt, error } = await settInn("members", payload).select("id");
        if (error) throw error;
        importerte += (satt || []).length;
        (satt || []).forEach((rad, idx) => {
          const kilde = klump[idx];
          for (const navn of splitAktiviteter(kilde.aktivitet)) {
            const activityId = aktivitetNavnTilId.get(navn.toLowerCase());
            if (activityId) koblinger.push({ member_id: rad.id, activity_id: activityId });
          }
        });
      }

      if (koblinger.length) {
        const { error } = await db.from("member_activities").insert(koblinger);
        if (error) throw error;
      }

      const avvist = trengerGjennomgang + duplikater;
      const { error: jobFeil } = await settInn("import_jobs", {
        type: "medlemmer",
        filnavn,
        antall_lest: mapped.length,
        antall_importert: importerte,
        antall_avvist: avvist,
        status: "fullfort"
      });
      if (jobFeil) throw jobFeil;

      paaNytt();
      toast("Import fullført", `${importerte} av ${mapped.length} medlemmer ble importert. ${avvist} ble ikke importert.`);
    }

    function visImportVeiviser(filnavn, rader) {
      return new Promise(resolve => {
        const kolonneNavn = Object.keys(rader[0] || {});
        const brukt = new Set();
        const finnKolonne = (nokler) => {
          for (const navn of kolonneNavn) {
            if (brukt.has(navn)) continue;
            const n = normaliserTekst(navn);
            if (nokler.some(k => n.includes(normaliserTekst(k)))) { brukt.add(navn); return navn; }
          }
          return "";
        };

        const gjetning = {};
        for (const navn of GJETT_REKKEFOLGE) {
          const felt2 = MAALFELT.find(f => f.navn === navn);
          gjetning[navn] = finnKolonne(felt2.nokler);
        }

        const kolonneValg = [{ verdi: "", tekst: "– Ikke i bruk –" }, ...kolonneNavn.map(n => ({ verdi: n, tekst: n }))];
        const mappingSelects = {};
        const mappingRad = el("div", { class: "grid g3" }, MAALFELT.map(f => {
          const s = velg(`map_${f.navn}`, kolonneValg, gjetning[f.navn] || "", { onchange: () => tegnForhandsvisning() });
          mappingSelects[f.navn] = s;
          return felt(f.label, s);
        }));

        function mapRad(rad) {
          const hent = (feltnavn) => {
            const kol = mappingSelects[feltnavn].value;
            return kol ? String(rad[kol] ?? "").trim() : "";
          };
          return {
            fornavn: hent("fornavn"),
            etternavn: hent("etternavn"),
            fodselsdato: normaliserDato(hent("fodselsdato")),
            epost: hent("epost"),
            telefon: hent("telefon"),
            adresse: hent("adresse"),
            postnr: hent("postnr"),
            sted: hent("sted"),
            aktivitet: hent("aktivitet"),
            foresatt_navn: hent("foresatt_navn"),
            foresatt_epost: hent("foresatt_epost"),
            foresatt_telefon: hent("foresatt_telefon")
          };
        }

        function beregnForhandsvisning() {
          const mapped = rader.map(mapRad);
          const gyldige = mapped.filter(r => r.fornavn && r.etternavn);
          return { mapped, gyldige, trengerGjennomgang: mapped.length - gyldige.length };
        }

        const forhandsvisningHost = el("div", { class: "stack" });
        function tegnForhandsvisning() {
          const { mapped, gyldige, trengerGjennomgang } = beregnForhandsvisning();
          tom(forhandsvisningHost);
          forhandsvisningHost.append(
            el("p", { class: "sub" }, `${mapped.length} rader lest — ${gyldige.length} kan importeres — ${trengerGjennomgang} trenger gjennomgang.`),
            tabell(
              [{ t: "Fornavn" }, { t: "Etternavn" }, { t: "Fødselsdato" }, { t: "E-post" }, { t: "Status" }],
              mapped.slice(0, 8).map(r => el("tr", {}, [
                el("td", {}, r.fornavn || "—"),
                el("td", {}, r.etternavn || "—"),
                el("td", {}, r.fodselsdato ? dato(r.fodselsdato) : "—"),
                el("td", {}, r.epost || "—"),
                el("td", {}, (r.fornavn && r.etternavn) ? pille("Klar", "green") : pille("Trenger gjennomgang", "gold"))
              ]))
            )
          );
        }

        const overlay = el("div", { class: "overlay" });
        const lukk = (v) => { overlay.remove(); resolve(v); };

        const knappImporter = el("button", { class: "btn primary" }, "Start import");
        knappImporter.addEventListener("click", async () => {
          const { gyldige } = beregnForhandsvisning();
          if (!gyldige.length) { toast("Import", "Ingen rader kan importeres med denne koblingen.", true); return; }
          knappImporter.disabled = true;
          knappImporter.textContent = "Importerer …";
          try {
            await kjorImport(filnavn, rader, mapRad, beregnForhandsvisning);
            lukk(true);
          } catch (e) {
            visFeil(e, "Import");
            knappImporter.disabled = false;
            knappImporter.textContent = "Start import";
          }
        });

        const modal = el("div", { class: "modal" }, [
          el("div", { class: "modal-head" }, [
            el("h2", {}, "Importer medlemmer fra fil"),
            el("p", {}, `Fil: ${filnavn}. Sjekk at kolonnene er koblet riktig før du importerer.`)
          ]),
          el("div", { class: "modal-body" }, [
            el("div", { class: "eyebrow" }, "Koble kolonner"),
            mappingRad,
            el("div", { class: "eyebrow" }, "Forhåndsvisning"),
            forhandsvisningHost
          ]),
          el("div", { class: "modal-foot" }, [
            el("button", { class: "btn", onclick: () => lukk(false) }, "Avbryt"),
            knappImporter
          ])
        ]);

        overlay.append(modal);
        overlay.addEventListener("click", e => { if (e.target === overlay) lukk(false); });
        document.body.append(overlay);
        tegnForhandsvisning();
      });
    }

    function startImportVeiviser() {
      const filInput = el("input", { type: "file", accept: ".xlsx,.xls,.csv", style: "display:none" });
      document.body.append(filInput);
      filInput.addEventListener("change", async () => {
        const fil = filInput.files[0];
        filInput.remove();
        if (!fil) return;
        try {
          const rader = await lesExcel(fil);
          if (!rader.length) { toast("Import", "Fant ingen rader i filen.", true); return; }
          await visImportVeiviser(fil.name, rader);
        } catch (e) { visFeil(e, "Lesing av fil"); }
      });
      filInput.click();
    }

    /* ---- tabell med søk og filter (i minnet) ---- */

    const filter = { sok: "", aktivitet: "", status: "", nye30: false, kunUbetalt: false };

    function filtrerte() {
      return medlemmer.filter(m => {
        if (filter.sok) {
          const hay = `${m.fornavn} ${m.etternavn} ${m.epost || ""} ${m.telefon || ""}`.toLowerCase();
          if (!hay.includes(filter.sok)) return false;
        }
        if (filter.aktivitet) {
          const ider = memberActivityMap.get(m.id) || new Set();
          if (!ider.has(filter.aktivitet)) return false;
        }
        if (filter.status && m.status !== filter.status) return false;
        if (filter.nye30 && !(m.opprettet && new Date(m.opprettet) >= grense30)) return false;
        if (filter.kunUbetalt && !ubetalteIder.has(m.id)) return false;
        return true;
      });
    }

    function radFor(m) {
      const aktIder = memberActivityMap.get(m.id) || new Set();
      const aktNavn = [...aktIder].map(id => aktivitetMap.get(id)?.navn).filter(Boolean);
      const alderTxt = m.fodselsdato ? `${alder(m.fodselsdato)} år` : "Alder ukjent";
      const bet = betalingsstatus(claimMap.get(m.id) || []);
      const st = statusVisning(m.status);
      return el("tr", { class: "klikk", onclick: () => apneMedlemskort(m) }, [
        el("td", {}, [el("div", {}, `${m.fornavn} ${m.etternavn}`), el("span", { class: "who" }, alderTxt)]),
        el("td", {}, dato(m.fodselsdato)),
        el("td", {}, aktNavn.length ? aktNavn.map(n => pille(n, "teal")) : el("span", { class: "dim" }, "Ingen")),
        el("td", {}, [el("div", {}, m.epost || "—"), el("span", { class: "who" }, m.telefon || "")]),
        el("td", {}, pille(st.tekst, st.farge)),
        el("td", {}, pille(bet.tekst, bet.farge))
      ]);
    }

    const kolonner = [
      { t: "Navn" }, { t: "Fødselsdato" }, { t: "Aktiviteter" }, { t: "Kontakt" }, { t: "Status" }, { t: "Betaling" }
    ];
    const tabellHost = el("div");
    function tegnTabell() {
      tom(tabellHost);
      tabellHost.append(tabell(kolonner, filtrerte().map(radFor), "Ingen medlemmer funnet."));
    }
    tegnTabell();

    const sokInput = el("input", {
      type: "search", placeholder: "Søk på navn, e-post eller telefon …",
      oninput: () => { filter.sok = sokInput.value.trim().toLowerCase(); tegnTabell(); }
    });
    const aktivitetSelect = velg(
      "filter_aktivitet",
      [{ verdi: "", tekst: "Alle aktiviteter" }, ...aktiviteter.map(a => ({ verdi: a.id, tekst: a.navn }))],
      "",
      { onchange: () => { filter.aktivitet = aktivitetSelect.value; tegnTabell(); } }
    );
    const statusSelect = velg(
      "filter_status",
      [{ verdi: "", tekst: "Alle statuser" }, ...STATUS_VALG],
      "",
      { onchange: () => { filter.status = statusSelect.value; tegnTabell(); } }
    );
    aktivitetSelect.style.width = "auto";
    statusSelect.style.width = "auto";
    const filterRad = el("div", { class: "tabellverktoy" }, [
      el("div", { class: "sok" }, [
        el("span", { html: svg("sok") }),
        sokInput
      ]),
      aktivitetSelect, statusSelect
    ]);

    /* ---- nøkkeltall ---- */

    const statsRow = el("div", { class: "grid g4" }, [
      kpi({
        ikon: "medlemmer",
        nokkel: "Aktive medlemmer",
        verdi: String(medlemmer.filter(m => m.status === "aktiv").length),
        under: `av ${medlemmer.length} totalt`,
        klikk: () => { statusSelect.value = "aktiv"; filter.status = "aktiv"; tegnTabell(); }
      }),
      kpi({
        ikon: "opp",
        nokkel: "Nye siste 30 dager",
        verdi: String(medlemmer.filter(m => (m.innmeldt || m.opprettet) && new Date(m.innmeldt || m.opprettet) >= grense30).length),
        under: "siden " + dato(grense30),
        klikk: () => { filter.nye30 = !filter.nye30; tegnTabell(); }
      }),
      kpi({
        ikon: "betaling",
        nokkel: "Ubetalt krav",
        verdi: String(ubetalteIder.size),
        under: "medlemmer med krav som ikke er betalt",
        farge: ubetalteIder.size ? "neg" : null,
        klikk: () => { filter.kunUbetalt = !filter.kunUbetalt; tegnTabell(); }
      }),
      kpi({
        ikon: "aktivitet",
        nokkel: "Aktiviteter",
        verdi: String(aktiviteter.length),
        under: "tilbud i organisasjonen",
        klikk: () => gaTil("aktiviteter")
      })
    ]);

    /* ---- knapper og samlet oppsett ---- */

    const knappNytt = kanMedlem() ? el("button", { class: "btn primary", onclick: () => apneMedlemskort(null) }, "Nytt medlem") : null;
    const knappImport = kanMedlem() ? el("button", { class: "btn", onclick: startImportVeiviser }, "Importer fra Excel") : null;
    const knappEksport = el("button", { class: "btn", onclick: eksporterMedlemmer }, "Eksporter til Excel");
    const handlinger = el("div", { class: "actions" }, [knappNytt, knappImport, knappEksport]);

    const infoNote = !kanMedlem()
      ? el("div", { class: "note info" }, "Du har kun lesetilgang til medlemmer. Ta kontakt med en administrator eller medlemsansvarlig for å gjøre endringer.")
      : null;

    const registerKort = kort({
      eyebrow: "Medlemsregister",
      tittel: `${medlemmer.length} medlemmer`,
      hoyre: handlinger,
      innhold: [infoNote, filterRad, tabellHost]
    });

    return el("div", { class: "stack" }, [statsRow, registerKort]);
  }
};

/* =====================================================================
   Aktiviteter
   ===================================================================== */

export const aktiviteterView = {
  tittel: "Aktiviteter",
  undertekst: "Aktivitetene og gruppene medlemmene kan meldes på.",

  async bygg() {
    if (!S.orgId) return el("div", { class: "empty" }, "Velg en organisasjon for å se aktiviteter.");

    let aktiviteter = [], grupper = [], memberActs = [], memberGroups = [];
    try {
      const { data: aData, error: aErr } = await velgFra("activities").order("navn");
      if (aErr) throw aErr;
      aktiviteter = aData || [];

      const { data: gData, error: gErr } = await velgFra("groups").order("navn");
      if (gErr) throw gErr;
      grupper = gData || [];

      const aktIder = aktiviteter.map(a => a.id);
      if (aktIder.length) {
        const { data, error } = await db.from("member_activities").select("member_id, activity_id").in("activity_id", aktIder);
        if (error) throw error;
        memberActs = data || [];
      }

      const gruppeIder = grupper.map(g => g.id);
      if (gruppeIder.length) {
        const { data, error } = await db.from("member_groups").select("member_id, group_id").in("group_id", gruppeIder);
        if (error) throw error;
        memberGroups = data || [];
      }
    } catch (e) {
      visFeil(e, "Henting av aktiviteter");
      return el("div", { class: "note bad" }, "Kunne ikke hente aktiviteter. Prøv å laste siden på nytt.");
    }

    const antallPerAktivitet = new Map();
    for (const r of memberActs) antallPerAktivitet.set(r.activity_id, (antallPerAktivitet.get(r.activity_id) || 0) + 1);
    const antallPerGruppe = new Map();
    for (const r of memberGroups) antallPerGruppe.set(r.group_id, (antallPerGruppe.get(r.group_id) || 0) + 1);
    const grupperPerAktivitet = new Map();
    for (const g of grupper) {
      if (!grupperPerAktivitet.has(g.activity_id)) grupperPerAktivitet.set(g.activity_id, []);
      grupperPerAktivitet.get(g.activity_id).push(g);
    }

    async function visAktivitetsdetaljer(a) {
      const memberIder = memberActs.filter(r => r.activity_id === a.id).map(r => r.member_id);
      let medlemmerIAktivitet = [];
      try {
        if (memberIder.length) {
          const { data, error } = await velgFra("members", "id, fornavn, etternavn, fodselsdato, status").in("id", memberIder);
          if (error) throw error;
          medlemmerIAktivitet = data || [];
        }
      } catch (e) { visFeil(e, "Henting av medlemmer"); }

      const grupperListe = grupperPerAktivitet.get(a.id) || [];
      const overlay = el("div", { class: "overlay" });
      const lukk = () => overlay.remove();

      const modal = el("div", { class: "modal" }, [
        el("div", { class: "modal-head" }, [
          el("h2", {}, a.navn),
          a.beskrivelse ? el("p", {}, a.beskrivelse) : null
        ]),
        el("div", { class: "modal-body" }, [
          el("div", { class: "eyebrow" }, "Grupper"),
          grupperListe.length
            ? el("div", { class: "rowline" }, grupperListe.map(g => pille(
                `${g.navn}${(g.alder_fra || g.alder_til) ? ` (${g.alder_fra ?? "–"}–${g.alder_til ?? "–"} år)` : ""} · ${antallPerGruppe.get(g.id) || 0}`,
                "teal"
              )))
            : el("div", { class: "empty" }, "Ingen grupper i denne aktiviteten ennå."),
          el("div", { class: "eyebrow" }, "Medlemmer"),
          tabell(
            [{ t: "Navn" }, { t: "Alder" }, { t: "Status" }],
            medlemmerIAktivitet.map(m => {
              const st = statusVisning(m.status);
              return el("tr", {}, [
                el("td", {}, `${m.fornavn} ${m.etternavn}`),
                el("td", {}, m.fodselsdato ? `${alder(m.fodselsdato)} år` : "—"),
                el("td", {}, pille(st.tekst, st.farge))
              ]);
            }),
            "Ingen medlemmer i denne aktiviteten ennå."
          )
        ]),
        el("div", { class: "modal-foot" }, [el("button", { class: "btn primary", onclick: lukk }, "Lukk")])
      ]);
      overlay.append(modal);
      overlay.addEventListener("click", e => { if (e.target === overlay) lukk(); });
      document.body.append(overlay);
    }

    async function nyAktivitet() {
      await skjemaModal({
        tittel: "Ny aktivitet",
        beskrivelse: "Aktiviteter er tilbudene medlemmene kan meldes på, som «Fotball» eller «Åpen hall».",
        felter: [
          { navn: "navn", label: "Navn", verdi: "" },
          { navn: "beskrivelse", label: "Beskrivelse", type: "textarea", verdi: "", bredde: "full" },
          { navn: "gren", label: "Idrettsgren (valgfritt)", verdi: "" }
        ],
        onLagre: async (data) => {
          if (!data.navn) { toast("Mangler navn", "Aktiviteten må ha et navn.", true); return false; }
          const { error } = await settInn("activities", {
            navn: data.navn,
            beskrivelse: data.beskrivelse || null,
            gren: data.gren || null
          });
          if (error) throw error;
          paaNytt();
          toast("Aktivitet opprettet", `${data.navn} er lagt til.`);
        }
      });
    }

    async function nyGruppe() {
      if (!aktiviteter.length) { toast("Ingen aktiviteter ennå", "Opprett en aktivitet før du lager en gruppe.", true); return; }
      await skjemaModal({
        tittel: "Ny gruppe",
        felter: [
          { navn: "navn", label: "Navn", verdi: "" },
          { navn: "alder_fra", label: "Alder fra", type: "number", verdi: "" },
          { navn: "alder_til", label: "Alder til", type: "number", verdi: "" },
          { navn: "activity_id", label: "Aktivitet", type: "select", valg: aktiviteter.map(a => ({ verdi: a.id, tekst: a.navn })), verdi: aktiviteter[0]?.id }
        ],
        onLagre: async (data) => {
          if (!data.navn) { toast("Mangler navn", "Gruppen må ha et navn.", true); return false; }
          const { error } = await settInn("groups", {
            navn: data.navn,
            activity_id: data.activity_id,
            alder_fra: data.alder_fra ? Number(data.alder_fra) : null,
            alder_til: data.alder_til ? Number(data.alder_til) : null
          });
          if (error) throw error;
          paaNytt();
          toast("Gruppe opprettet", `${data.navn} er lagt til.`);
        }
      });
    }

    function kortForAktivitet(a) {
      const antallMedlemmer = antallPerAktivitet.get(a.id) || 0;
      const grupperListe = grupperPerAktivitet.get(a.id) || [];
      return el("button", { class: "btn big", onclick: () => visAktivitetsdetaljer(a) }, [
        el("span", {}, a.navn + (a.aktiv ? "" : " (inaktiv)")),
        el("small", {}, `${antallMedlemmer} medlemmer · ${grupperListe.length} grupper`)
      ]);
    }

    const handlinger = el("div", { class: "actions" }, [
      kanMedlem() ? el("button", { class: "btn primary", onclick: nyAktivitet }, "Ny aktivitet") : null,
      kanMedlem() ? el("button", { class: "btn", onclick: nyGruppe }, "Ny gruppe") : null
    ]);
    const infoNote = !kanMedlem()
      ? el("div", { class: "note info" }, "Du har kun lesetilgang til aktiviteter. Ta kontakt med en administrator eller medlemsansvarlig for å gjøre endringer.")
      : null;

    const innhold = [
      infoNote,
      aktiviteter.length
        ? el("div", { class: "grid g3" }, aktiviteter.map(kortForAktivitet))
        : el("div", { class: "empty" }, "Ingen aktiviteter opprettet ennå.")
    ];

    const kortWrap = kort({
      eyebrow: "Aktiviteter",
      tittel: `${aktiviteter.length} aktiviteter`,
      hoyre: handlinger,
      innhold
    });

    return el("div", { class: "stack" }, [kortWrap]);
  }
};

/* =====================================================================
   Familier
   ===================================================================== */

export const familierView = {
  tittel: "Familier",
  undertekst: "Familier og hvilke medlemmer som hører sammen.",

  async bygg() {
    if (!S.orgId) return el("div", { class: "empty" }, "Velg en organisasjon for å se familier.");

    let familier = [], medlemmer = [];
    try {
      const { data: fData, error: fErr } = await velgFra("families").order("navn");
      if (fErr) throw fErr;
      familier = fData || [];

      const { data: mData, error: mErr } = await velgFra("members", "id, fornavn, etternavn, fodselsdato, family_id").order("etternavn");
      if (mErr) throw mErr;
      medlemmer = mData || [];
    } catch (e) {
      visFeil(e, "Henting av familier");
      return el("div", { class: "note bad" }, "Kunne ikke hente familier. Prøv å laste siden på nytt.");
    }

    const medlemmerPerFamilie = new Map();
    for (const m of medlemmer) {
      if (!m.family_id) continue;
      if (!medlemmerPerFamilie.has(m.family_id)) medlemmerPerFamilie.set(m.family_id, []);
      medlemmerPerFamilie.get(m.family_id).push(m);
    }

    async function visFamiliedetaljer(f) {
      const barn = medlemmerPerFamilie.get(f.id) || [];

      const overlay = el("div", { class: "overlay" });
      const lukk = () => overlay.remove();

      const barnHost = el("div", { class: "stack" });
      function tegnBarn() {
        tom(barnHost);
        if (!barn.length) {
          barnHost.append(el("div", { class: "empty" }, "Ingen medlemmer knyttet til denne familien ennå."));
          return;
        }
        barnHost.append(...barn.map(m => el("div", { class: "rowline between" }, [
          el("span", {}, `${m.fornavn} ${m.etternavn}`),
          kanMedlem() ? el("button", {
            class: "btn sm",
            onclick: async () => {
              try {
                const { error } = await db.from("members").update({ family_id: null }).eq("id", m.id);
                if (error) throw error;
                m.family_id = null;
                barn.splice(barn.indexOf(m), 1);
                tegnBarn();
                paaNytt();
                toast("Fjernet", `${m.fornavn} er ikke lenger knyttet til ${f.navn}.`);
              } catch (e) { visFeil(e, "Endring"); }
            }
          }, "Fjern") : null
        ])));
      }
      tegnBarn();

      const ledigeMedlemmer = medlemmer.filter(m => m.family_id !== f.id);
      const leggTilSelect = velg(
        "legg_til_medlem",
        [{ verdi: "", tekst: "Velg medlem …" }, ...ledigeMedlemmer.map(m => ({ verdi: m.id, tekst: `${m.fornavn} ${m.etternavn}` }))],
        ""
      );
      const leggTilKnapp = el("button", {
        class: "btn primary sm",
        onclick: async () => {
          const id = leggTilSelect.value;
          if (!id) return;
          try {
            const { error } = await db.from("members").update({ family_id: f.id }).eq("id", id);
            if (error) throw error;
            const m = medlemmer.find(x => x.id === id);
            m.family_id = f.id;
            barn.push(m);
            const i = ledigeMedlemmer.indexOf(m);
            if (i >= 0) ledigeMedlemmer.splice(i, 1);
            leggTilSelect.querySelector(`option[value="${id}"]`)?.remove();
            leggTilSelect.value = "";
            tegnBarn();
            paaNytt();
            toast("Lagt til", `${m.fornavn} er knyttet til ${f.navn}.`);
          } catch (e) { visFeil(e, "Endring"); }
        }
      }, "Legg til");

      const modal = el("div", { class: "modal" }, [
        el("div", { class: "modal-head" }, [el("h2", {}, f.navn), el("p", {}, `${barn.length} medlemmer i familien`)]),
        el("div", { class: "modal-body" }, [
          el("div", { class: "eyebrow" }, "Medlemmer"),
          barnHost,
          kanMedlem() ? el("div", { class: "rowline" }, [leggTilSelect, leggTilKnapp]) : null
        ]),
        el("div", { class: "modal-foot" }, [el("button", { class: "btn primary", onclick: lukk }, "Lukk")])
      ]);
      overlay.append(modal);
      overlay.addEventListener("click", e => { if (e.target === overlay) lukk(); });
      document.body.append(overlay);
    }

    async function nyFamilie() {
      await skjemaModal({
        tittel: "Ny familie",
        felter: [
          { navn: "navn", label: "Familienavn", verdi: "" },
          { navn: "hovedkontakt_epost", label: "Hovedkontakt e-post", type: "email", verdi: "" },
          { navn: "hovedkontakt_telefon", label: "Hovedkontakt telefon", verdi: "" }
        ],
        onLagre: async (data) => {
          if (!data.navn) { toast("Mangler navn", "Familien må ha et navn.", true); return false; }
          const { error } = await settInn("families", {
            navn: data.navn,
            hovedkontakt_epost: data.hovedkontakt_epost || null,
            hovedkontakt_telefon: data.hovedkontakt_telefon || null
          });
          if (error) throw error;
          paaNytt();
          toast("Familie opprettet", `${data.navn} er lagt til.`);
        }
      });
    }

    function radForFamilie(f) {
      const barn = medlemmerPerFamilie.get(f.id) || [];
      return el("tr", { class: "klikk", onclick: () => visFamiliedetaljer(f) }, [
        el("td", {}, f.navn),
        el("td", { class: "num" }, String(barn.length)),
        el("td", {}, [el("div", {}, f.hovedkontakt_epost || "—"), el("span", { class: "who" }, f.hovedkontakt_telefon || "")])
      ]);
    }

    const kolonner = [{ t: "Familie" }, { t: "Antall medlemmer", num: true }, { t: "Hovedkontakt" }];
    const tabellNode = tabell(kolonner, familier.map(radForFamilie), "Ingen familier registrert ennå.");

    const handlinger = el("div", { class: "actions" }, [
      kanMedlem() ? el("button", { class: "btn primary", onclick: nyFamilie }, "Ny familie") : null
    ]);
    const infoNote = !kanMedlem()
      ? el("div", { class: "note info" }, "Du har kun lesetilgang til familier. Ta kontakt med en administrator eller medlemsansvarlig for å gjøre endringer.")
      : null;

    const kortWrap = kort({
      eyebrow: "Familier",
      tittel: `${familier.length} familier`,
      hoyre: handlinger,
      innhold: [infoNote, tabellNode]
    });

    return el("div", { class: "stack" }, [kortWrap]);
  }
};
