// =====================================================================
//  Signering — elektronisk signatur på dokumenter i arkivet.
//
//  To måter: fullmektig signerer på vegne av styret (etter fullmakt
//  registrert under Innstillinger → Fullmakter), eller hvert styremedlem
//  signerer selv. Reglene ligger i databasen (0017); denne filen viser
//  bare det som er lov, og sier fra når det ikke er det.
// =====================================================================

import {
  el, svg, kort, merke, tabell, felt, skjemaModal, bekreft, toast, visFeil,
  knapp, dato, tidspunkt, iDag, tomTilstand, antall, db
} from "../lib.js";
import { S, VERV, erAdmin, kanSkrive, velgFra, settInn, paaNytt, gaTil } from "../store.js";
import { lagSignertPdf, hashAvFil } from "../signatur-pdf.js";

export const STATUS = {
  venter:   ["Venter på signering", "gold"],
  delvis:   ["Delvis signert", "blue"],
  fullfort: ["Signert", "green"],
  avvist:   ["Avvist", "red"],
  trukket:  ["Trukket tilbake", "neutral"]
};

export const OMFANG = {
  styreprotokoll: "Styreprotokoller (mappen Styremøter)",
  aarsmoteprotokoll: "Årsmøteprotokoller (Årsprotokoller og ekstraordinære)",
  alle_dokumenter: "Alle dokumenter i arkivet"
};

const SIGNERT_SOM = {
  styremedlem: "Styremedlem, innlogget",
  styremedlem_i_mote: "Enkel signatur i møtet",
  fullmektig_for_styret: "På vegne av styret",
  administrator: "På vegne av styret"
};

export const ANLEDNINGER = ["Årsmøte", "Ekstraordinær generalforsamling", "Styremøte", "Avtale", "Vedtekter"];
const anledningForMappe = (mappe) => ({
  "Årsprotokoller": "Årsmøte", "Ekstraordinære generalforsamlinger": "Ekstraordinær generalforsamling",
  "Styremøter": "Styremøte", "Avtaler": "Avtale", "Vedtekter": "Vedtekter"
})[mappe] || "Annet";

export const TYPE_TEKST = {
  mote: "Enkel signatur",
  styremedlemmer: "Innlogget signatur",
  fullmektig: "Fullmektig for styret"
};

const navnPaa = (p) => p ? (((p.fornavn || "") + " " + (p.etternavn || "")).trim() || p.epost || "Ukjent") : "—";
const VERIFISER_URL = new URL("../verifiser.html", location.href).href;

/* =====================================================================
   Henting
   ===================================================================== */

/** Alle forespørsler i organisasjonen, med mottakere og signaturer. */
export async function hentForesporsler() {
  mineFullmakter = null;
  const { data, error } = await db.from("signature_requests")
    .select("*, oppretter:opprettet_av(fornavn,etternavn,epost), " +
            "mottakere:signature_request_recipients(user_id, profiles(fornavn,etternavn,epost)), " +
            "styre:signature_request_board(id, board_member_id, navn, rolle, rekkefolge), " +
            "signaturer:signatures(id, user_id, signer_id, board_member_id, navn_tekst, rolle_tekst, signert_som, signaturdato, signert_tidspunkt, signatur_id, mandate_id, signaturbilde_path)")
    .eq("organization_id", S.orgId).order("opprettet", { ascending: false });
  if (error) throw error;
  return data || [];
}

/** Åpne forespørsler, nøklet på dokument-id. Brukes av arkivet. */
export async function hentApneForesporsler() {
  const alle = await hentForesporsler();
  const kart = {};
  for (const r of alle) if (r.status === "venter" || r.status === "delvis") kart[r.document_id] = r;
  return kart;
}

/** Mine fullmakter, hentet én gang per visning. Regelen speiler aktiv_fullmakt() i databasen. */
let mineFullmakter = null;
export function nullstillFullmakter() { mineFullmakter = null; }
async function minFullmakt(mappe) {
  if (!mineFullmakter) {
    const { data, error } = await velgFra("mandates", "id, omfang, gyldig_fra, gyldig_til, trukket_tilbake")
      .eq("user_id", S.bruker.id).is("trukket_tilbake", null);
    if (error) throw error;
    mineFullmakter = data || [];
  }
  const i = iDag();
  return mineFullmakter.find(m => m.gyldig_fra <= i && (!m.gyldig_til || m.gyldig_til >= i) && (
    m.omfang === "alle_dokumenter"
    || (m.omfang === "styreprotokoll" && mappe === "Styremøter")
    || (m.omfang === "aarsmoteprotokoll" && ["Årsprotokoller", "Ekstraordinære generalforsamlinger"].includes(mappe))
  ))?.id || null;
}

/** Kan jeg signere denne forespørselen nå? Returnerer signert_som eller null. */
export async function hvordanKanJegSignere(r, dok) {
  if (!r || !["venter", "delvis"].includes(r.status)) return null;
  const jeg = S.bruker.id;
  if (r.type !== "mote" && (r.signaturer || []).some(s => s.user_id === jeg)) return null;
  if (r.type === "styremedlemmer") {
    return (r.mottakere || []).some(m => m.user_id === jeg) ? "styremedlem" : null;
  }
  if (r.type === "mote") {
    // Enkel signatur: den som holder enheten registrerer styremedlemmenes signaturer
    return kanSkrive() && gjenstaarIMote(r).length ? "styremedlem_i_mote" : null;
  }
  const mappe = dok?.mappe ?? r.documents?.mappe;
  if (await minFullmakt(mappe)) return "fullmektig_for_styret";
  if (erAdmin()) return "administrator";
  return null;
}

/** Styremedlemmer som ikke har signert ennå (enkel signatur). */
function gjenstaarIMote(r) {
  const signert = new Set((r.signaturer || []).map(s => s.signer_id).filter(Boolean));
  return (r.styre || []).filter(b => !signert.has(b.id));
}

/** Brukes av forsiden. */
export async function hentSigneringTall() {
  const [alle, { data: doks }] = await Promise.all([hentForesporsler(), velgFra("documents", "id, mappe")]);
  const mapper = Object.fromEntries((doks || []).map(d => [d.id, d]));
  const apne = alle.filter(r => r.status === "venter" || r.status === "delvis");
  let tilMeg = 0;
  for (const r of apne) if (await hvordanKanJegSignere(r, mapper[r.document_id])) tilMeg++;
  return { apne: apne.length, tilMeg };
}

/* =====================================================================
   Celle i arkivtabellen: status + knapper
   ===================================================================== */

export function signeringCelle(dok, apne, tegn) {
  const r = apne[dok.id];
  const deler = [];
  if (dok.laast) {
    deler.push(merke("Signert", "green"));
    if (dok.signert_tid) deler.push(el("span", { class: "who" }, tidspunkt(dok.signert_tid)));
  } else if (r) {
    const [tekst, farge] = STATUS[r.status] || [r.status, "neutral"];
    deler.push(merke(tekst, farge));
    if (r.type === "styremedlemmer") {
      deler.push(el("span", { class: "who" }, `Innlogget signatur · ${(r.signaturer || []).length} av ${(r.mottakere || []).length} har signert`));
    } else if (r.type === "mote") {
      deler.push(el("span", { class: "who" }, `Enkel signatur · ${(r.signaturer || []).length} av ${(r.styre || []).length} har signert`));
    } else {
      deler.push(el("span", { class: "who" }, "Fullmektig på vegne av styret"));
    }
  } else {
    deler.push(el("span", { class: "dim" }, "—"));
  }
  return deler;
}

export function signeringKnapper(dok, apne, tegn) {
  const r = apne[dok.id];
  const knapper = [];
  if (dok.signert_path) knapper.push(knapp("Åpne signert", {
    klasse: "stille sm", ikon: "ok",
    ved: async () => {
      const { data: url, error } = await db.storage.from("dokumenter").createSignedUrl(dok.signert_path, 60);
      if (error) return visFeil(error, "Åpning");
      window.open(url.signedUrl, "_blank", "noopener");
    }
  }));
  if (dok.laast && !dok.signert_path && kanSkrive()) knapper.push(knapp("Lag signert PDF", {
    klasse: "stille sm", tittel: "Signaturene er registrert, men filen ble ikke laget. Prøv igjen.",
    ved: async () => { try { await ferdigstillSignertFil(dok); toast("Ferdig", "Den signerte PDF-en ligger i arkivet."); tegn(); } catch (e) { visFeil(e, "Signert PDF"); } }
  }));
  if (!dok.laast && !r && kanSkrive()) knapper.push(knapp("Send til signering", {
    klasse: "stille sm",
    ved: async () => { if (await sendTilSignering(dok)) tegn(); }
  }));
  if (r) knapper.push(knapp("Signering", {
    klasse: "primary sm",
    ved: () => gaTil("signering")
  }));
  return knapper;
}

/* =====================================================================
   Sende til signering
   ===================================================================== */

export async function sendTilSignering(dok) {
  const [{ data: brukere, error }, { data: styret, error: sFeil }] = await Promise.all([
    db.from("organization_users").select("user_id, rolle, styreverv, profiles(fornavn,etternavn,epost)")
      .eq("organization_id", S.orgId).eq("aktiv", true).neq("rolle", "revisor"),
    db.from("board_members").select("id, navn, verv, fra, til").eq("organization_id", S.orgId).order("rekkefolge").order("navn")
  ]);
  if (error || sFeil) { visFeil(error || sFeil, "Henting"); return false; }
  const i = iDag();
  const sitter = (styret || []).filter(b => (!b.fra || b.fra <= i) && (!b.til || b.til >= i));

  /* --- måte: radioknapper --- */
  const MAATER = [
    ["mote", "Enkel signatur", "Enheten går rundt bordet. Hvert styremedlem trykker på navnet sitt og signerer — ingen innlogging."],
    ["styremedlemmer", "Innlogget signatur", "Hver person logger inn i Saksflyt selv og signerer med passord."],
    ["fullmektig", "Fullmektig for styret", "Én person med fullmakt signerer på vegne av hele styret."]
  ];
  let maate = sitter.length ? "mote" : "fullmektig";
  const radioer = {};
  const maateBoks = el("div", { class: "stack", style: "gap:8px" }, MAATER.map(([verdi, tittel, tekst]) => {
    const rb = el("input", { type: "radio", name: "maate", value: verdi, checked: verdi === maate });
    radioer[verdi] = rb;
    rb.addEventListener("change", () => { maate = verdi; visListe(); });
    return el("label", { style: "display:flex;gap:10px;align-items:flex-start;cursor:pointer" }, [
      rb, el("span", {}, [el("b", {}, tittel), el("span", { class: "hint", style: "display:block" }, tekst)])
    ]);
  }));

  /* --- hvem: styremedlemmer (enkel) eller brukere (innlogget) --- */
  const kryssStyre = {}, kryssBruker = {};
  const listeStyre = el("div", { class: "stack", style: "gap:6px" }, sitter.map(b => {
    const cb = el("input", { type: "checkbox", checked: true });
    kryssStyre[b.id] = cb;
    return el("label", { style: "display:flex;gap:8px;align-items:center;font-weight:500" }, [cb, b.navn, el("span", { class: "dim" }, b.verv)]);
  }));
  if (!sitter.length) listeStyre.append(el("span", { class: "hint" }, "Ingen styremedlemmer er registrert. Legg dem inn under Innstillinger → Styret og fullmakter."));
  // Inntil fire ekstra som skrives inn der og da — f.eks. de årsmøtet velger til å underskrive
  const ekstraRader = [1, 2, 3, 4].map(() => ({
    navn: el("input", { type: "text", placeholder: "Navn" }),
    rolle: el("input", { type: "text", placeholder: "Verv / valgt til", style: "max-width:45%" })
  }));
  listeStyre.append(
    el("span", { class: "hint", style: "margin-top:8px" }, "Andre som skal signere (valgfritt), f.eks. valgt på årsmøtet til å underskrive protokollen:"),
    ...ekstraRader.map(r => el("div", { style: "display:flex;gap:8px" }, [r.navn, r.rolle]))
  );
  const listeBruker = el("div", { class: "stack", style: "gap:6px" }, (brukere || []).map(b => {
    const cb = el("input", { type: "checkbox", checked: !!b.styreverv && !["Ingen verv", "Revisor", "Valgkomité"].includes(b.styreverv) });
    kryssBruker[b.user_id] = cb;
    return el("label", { style: "display:flex;gap:8px;align-items:center;font-weight:500" }, [cb, navnPaa(b.profiles), el("span", { class: "dim" }, b.styreverv || b.rolle)]);
  }));
  const hvemFelt = el("div", { class: "field", style: "margin-top:14px" }, [el("label", {}, "Hvem skal signere?"), listeStyre, listeBruker]);
  const visListe = () => {
    listeStyre.style.display = maate === "mote" ? "" : "none";
    listeBruker.style.display = maate === "styremedlemmer" ? "" : "none";
    hvemFelt.style.display = maate === "fullmektig" ? "none" : "";
  };
  visListe();

  /* --- hva gjelder signeringen --- */
  const anledningValg = el("select", {}, [...ANLEDNINGER, "Annet"].map(a => el("option", { value: a }, a)));
  anledningValg.value = anledningForMappe(dok.mappe);
  const anledningFri = el("input", { type: "text", placeholder: "Skriv hva det gjelder", style: "margin-top:6px" });
  const visFri = () => { anledningFri.style.display = anledningValg.value === "Annet" ? "" : "none"; };
  anledningValg.addEventListener("change", visFri); visFri();

  const svar = await skjemaModal({
    tittel: "Send til signering",
    beskrivelse: (dok.tittel || dok.filnavn) + (dok.saksflytnr ? " · " + dok.saksflytnr : ""),
    felter: [
      { navn: "dokumentdato", label: "Dokumentdato (møtedato)", type: "date", verdi: dok.dokumentdato || "", hint: "Signaturdatoen kan ikke settes tidligere enn denne." },
      { navn: "melding", label: "Melding", plassholder: "Valgfritt" }
    ],
    ekstra: el("div", {}, [
      el("div", { class: "field", style: "margin-top:14px" }, [el("label", {}, "Hva gjelder signeringen?"), anledningValg, anledningFri]),
      el("div", { class: "field", style: "margin-top:14px" }, [el("label", {}, "Hvordan skal det signeres?"), maateBoks]),
      hvemFelt
    ]),
    lagreTekst: "Send til signering",
    onLagre: async (d) => {
      const valgteStyre = Object.entries(kryssStyre).filter(([, cb]) => cb.checked).map(([id]) => id);
      const valgteBrukere = Object.entries(kryssBruker).filter(([, cb]) => cb.checked).map(([id]) => id);
      const ekstra = ekstraRader.map(r => ({ navn: r.navn.value.trim(), rolle: r.rolle.value.trim() || null })).filter(r => r.navn);
      if (maate === "mote" && !valgteStyre.length && !ekstra.length) { toast("Ingen valgt", "Velg minst én som skal signere.", true); return false; }
      if (maate === "styremedlemmer" && !valgteBrukere.length) { toast("Ingen valgt", "Velg minst én person.", true); return false; }
      const anledning = anledningValg.value === "Annet" ? anledningFri.value.trim() : anledningValg.value;
      if (!anledning) { toast("Mangler", "Skriv hva signeringen gjelder.", true); return false; }

      if (d.dokumentdato && d.dokumentdato !== (dok.dokumentdato || "")) {
        const { error } = await db.from("documents").update({ dokumentdato: d.dokumentdato }).eq("id", dok.id);
        if (error) throw error;
      }
      let hash = null;
      if (dok.storage_path) {
        const { data: blob, error: nedFeil } = await db.storage.from("dokumenter").download(dok.storage_path);
        if (nedFeil) throw nedFeil;
        hash = await hashAvFil(blob);
      }
      const { data: ny, error } = await settInn("signature_requests", {
        document_id: dok.id, type: maate, dokument_hash: hash, melding: d.melding || null, anledning
      }).select("id").single();
      if (error) throw error;
      if (maate === "styremedlemmer") {
        const { error: mFeil } = await db.from("signature_request_recipients")
          .insert(valgteBrukere.map(user_id => ({ request_id: ny.id, user_id })));
        if (mFeil) throw mFeil;
      } else if (maate === "mote") {
        const rader = [
          ...valgteStyre.map((id, i) => { const b = sitter.find(x => x.id === id); return { request_id: ny.id, board_member_id: id, navn: b.navn, rolle: b.verv, rekkefolge: i * 10 }; }),
          ...ekstra.map((e, i) => ({ request_id: ny.id, board_member_id: null, navn: e.navn, rolle: e.rolle, rekkefolge: 500 + i * 10 }))
        ];
        const { error: bFeil } = await db.from("signature_request_board").insert(rader);
        if (bFeil) throw bFeil;
      }
      return true;
    }
  });
  if (svar) toast("Klart", maate === "mote"
    ? "Gå til Signering og trykk «Start enkel signatur» når enheten skal rundt bordet."
    : maate === "fullmektig" ? "Dokumentet venter på at fullmektig signerer på vegne av styret."
    : "Dokumentet venter på at hver person logger inn og signerer.");
  return !!svar;
}

/* =====================================================================
   Signere
   ===================================================================== */

export async function signer(r, dok) {
  const som = await hvordanKanJegSignere(r, dok);
  if (som === "styremedlem_i_mote") return enkelSignering(r, dok);
  if (!som) { toast("Kan ikke signere", "Du er ikke bedt om å signere dette dokumentet, eller du har allerede signert.", true); return false; }

  const rolleTekst = S.styreverv || S.rolle;
  const passord = el("input", { type: "password", autocomplete: "current-password", placeholder: "Passordet ditt" });

  const svar = await skjemaModal({
    tittel: "Signer dokumentet",
    beskrivelse: (dok.tittel || dok.filnavn) + (dok.saksflytnr ? " · " + dok.saksflytnr : ""),
    felter: [
      { navn: "signaturdato", label: "Dato på signaturen", type: "date", verdi: dok.dokumentdato || iDag(),
        hint: "Datoen dokumentet gjelder, f.eks. møtedatoen. Tidspunktet du faktisk signerer, logges uansett." }
    ],
    ekstra: el("div", { class: "stack", style: "margin-top:14px;gap:12px" }, [
      el("dl", { class: "kv" }, [
        el("dt", {}, "Du signerer som"), el("dd", {}, navnPaa(S.bruker) + (rolleTekst ? ", " + rolleTekst : "")),
        el("dt", {}, "På vegne av"), el("dd", {}, som === "styremedlem" ? "Deg selv, som styremedlem" : "Styret" + (som === "fullmektig_for_styret" ? " — etter fullmakt" : ""))
      ]),
      el("div", { class: "field" }, [
        el("label", {}, "Bekreft med passordet ditt"), passord,
        el("span", { class: "hint" }, "Signaturen er personlig. Passordet bekrefter at det er du som trykker.")
      ])
    ]),
    lagreTekst: "Signer",
    onLagre: async (d) => {
      if (!passord.value) { toast("Mangler passord", "Skriv inn passordet ditt for å signere.", true); return false; }
      const { error: authFeil } = await db.auth.signInWithPassword({ email: S.bruker.epost, password: passord.value });
      if (authFeil) { toast("Feil passord", "Passordet stemte ikke. Prøv igjen.", true); return false; }
      const { error } = await db.from("signatures").insert({
        request_id: r.id, signert_som: som, signaturdato: d.signaturdato || null,
        user_agent: navigator.userAgent.slice(0, 200)
      });
      if (error) throw error;
      return true;
    }
  });
  if (!svar) return false;

  // Er dokumentet ferdig signert? Da lages PDF-en med signaturside.
  const { data: oppd } = await db.from("documents").select("*").eq("id", dok.id).single();
  if (oppd?.laast) {
    try { await ferdigstillSignertFil(oppd); toast("Signert", "Dokumentet er ferdig signert og låst. Den signerte PDF-en ligger i arkivet."); }
    catch (e) { console.warn(e); toast("Signert", "Signaturen er registrert, men den signerte PDF-en kunne ikke lages nå. Bruk «Lag signert PDF» i arkivet.", true); }
  } else {
    toast("Signert", "Signaturen din er registrert. Dokumentet venter på de andre.");
  }
  return true;
}

/** Lager PDF med signaturside og lagrer stien på dokumentet. */
export async function ferdigstillSignertFil(dok) {
  if (dok.signert_path) return dok.signert_path;
  const { data: sign, error } = await db.from("signatures")
    .select("*, mandates(nummer, vedtak, vedtaksdato), signature_requests(dokument_hash, anledning)")
    .eq("document_id", dok.id).order("signert_tidspunkt");
  if (error) throw error;
  if (!sign?.length) throw new Error("Dokumentet har ingen signaturer.");

  let original = null;
  if (dok.storage_path) {
    const { data: blob, error: nedFeil } = await db.storage.from("dokumenter").download(dok.storage_path);
    if (nedFeil) throw nedFeil;
    original = new File([blob], dok.filnavn || "dokument", { type: blob.type || "" });
  }
  const fil = await lagSignertPdf(original, {
    orgNavn: S.org.navn, orgnr: S.org.orgnr, tittel: dok.tittel, saksflytnr: dok.saksflytnr,
    mappe: dok.mappe, dokumentdato: dok.dokumentdato, anledning: sign[0].signature_requests?.anledning || null, hash: sign[0].dokument_hash || sign[0].signature_requests?.dokument_hash,
    verifiserUrl: VERIFISER_URL,
    signaturer: await Promise.all(sign.map(async s => {
      let bilde = null;
      if (s.signaturbilde_path) {
        const { data: png } = await db.storage.from("dokumenter").download(s.signaturbilde_path);
        if (png) bilde = new Uint8Array(await png.arrayBuffer());
      }
      return {
        navn: s.navn_tekst, rolle: s.rolle_tekst, signert_som: s.signert_som,
        signaturdato: s.signaturdato, signert_tidspunkt: s.signert_tidspunkt,
        signatur_id: s.signatur_id, fullmakt: s.mandates || null, styret: s.styret_tekst || null,
        bilde
      };
    }))
  });
  const sti = `${S.orgId}/signert-${Date.now()}-${fil.name.replace(/[^\w.\-]/g, "_")}`;
  const { error: oppFeil } = await db.storage.from("dokumenter").upload(sti, fil);
  if (oppFeil) throw oppFeil;
  const { error: lagreFeil } = await db.from("documents").update({ signert_path: sti }).eq("id", dok.id);
  if (lagreFeil) throw lagreFeil;
  return sti;
}

/* =====================================================================
   Avvise / trekke
   ===================================================================== */

async function avvis(r) {
  const svar = await skjemaModal({
    tittel: "Avvis signering",
    beskrivelse: "Dokumentet går tilbake uten signatur. Skriv hvorfor, så de som sendte det vet hva som må rettes.",
    felter: [{ navn: "arsak", label: "Hvorfor?", type: "textarea", bredde: "full" }],
    lagreTekst: "Avvis",
    onLagre: async (d) => {
      if (!d.arsak) { toast("Mangler begrunnelse", "Skriv hvorfor dokumentet avvises.", true); return false; }
      const { error } = await db.from("signature_requests").update({ status: "avvist", avvist_arsak: d.arsak }).eq("id", r.id);
      if (error) throw error;
      return true;
    }
  });
  return !!svar;
}

async function trekk(r) {
  if (!await bekreft("Trekke forespørselen?", "Dokumentet kan sendes til signering på nytt etterpå.", "Ja, trekk")) return false;
  try {
    const { error } = await db.from("signature_requests").update({ status: "trukket" }).eq("id", r.id);
    if (error) throw error;
    toast("Trukket", "Forespørselen er trukket tilbake.");
    return true;
  } catch (e) { visFeil(e, "Trekking"); return false; }
}

/* =====================================================================
   Visning: Signering
   ===================================================================== */

export const signeringView = {
  tittel: "Signering",
  undertekst: "Dokumenter som venter på signatur, og dokumenter som er ferdig signert.",
  async bygg() { return bygg(); }
};

async function bygg() {
  const [alle, { data: doks, error }] = await Promise.all([hentForesporsler(), velgFra("documents", "*")]);
  if (error) throw error;
  const dokMap = Object.fromEntries((doks || []).map(d => [d.id, d]));
  const boks = el("div", { class: "stack" });
  const tegn = () => paaNytt();

  const apne = alle.filter(r => r.status === "venter" || r.status === "delvis");
  const tilMeg = [];
  for (const r of apne) { const som = await hvordanKanJegSignere(r, dokMap[r.document_id]); if (som) tilMeg.push({ r, som }); }

  if (!alle.length) {
    boks.append(kort({
      innhold: tomTilstand({
        tittel: "Ingenting til signering",
        tekst: "Gå til Dokumenter, finn protokollen og trykk «Send til signering».",
        ikon: "ok",
        handlinger: [knapp("Til dokumentene", { klasse: "primary", ved: () => gaTil("dokumenter") })]
      })
    }));
    return boks;
  }

  /* --- venter på meg --- */
  if (tilMeg.length) {
    boks.append(kort({
      eyebrow: "Venter på deg",
      tittel: antall(tilMeg.length, "dokument venter på signaturen din", "dokumenter venter på signaturen din"),
      innhold: el("div", { class: "oppm" }, tilMeg.map(({ r, som }) => {
        const d = dokMap[r.document_id] || {};
        return el("div", { class: "oppm-rad", style: "cursor:default" }, [
          el("span", { class: "merke gold", html: svg("dokument") }),
          el("span", { class: "tekst" }, [
            el("b", {}, (d.tittel || d.filnavn || "Dokument") + (d.saksflytnr ? " · " + d.saksflytnr : "")),
            el("span", {}, [
              som === "styremedlem_i_mote" ? `Enkel signatur — ${gjenstaarIMote(r).length} av ${(r.styre || []).length} gjenstår`
                : som === "styremedlem" ? "Du signerer som styremedlem" : "Du signerer på vegne av styret",
              r.melding ? " — «" + r.melding + "»" : "",
              " · sendt av " + navnPaa(r.oppretter) + " " + tidspunkt(r.opprettet)
            ])
          ]),
          el("span", { class: "actions" }, [
            d.storage_path ? knapp("Les", { klasse: "stille sm", ved: () => apne_(d.storage_path) }) : null,
            knapp("Avvis", { klasse: "stille sm", ved: async () => { if (await avvis(r)) tegn(); } }),
            knapp(som === "styremedlem_i_mote" ? "Start enkel signatur" : "Signer", { klasse: "primary sm", ved: async () => { if (await signer(r, d)) tegn(); } })
          ])
        ]);
      }))
    }));
  }

  /* --- alle forespørsler --- */
  boks.append(kort({
    tittel: "Alle signeringer",
    beskrivelse: "Hver signatur har sin egen ID som kan kontrolleres på verifiseringssiden.",
    innhold: tabell(
      [{ t: "Dokument" }, { t: "Måte" }, { t: "Status" }, { t: "Signaturer" }, { t: "Sendt" }, { t: "" }],
      alle.map(r => {
        const d = dokMap[r.document_id] || {};
        const [tekst, farge] = STATUS[r.status] || [r.status, "neutral"];
        const sign = r.signaturer || [];
        const kanTrekke = ["venter", "delvis"].includes(r.status) && !sign.length && (r.opprettet_av === S.bruker.id || erAdmin());
        return el("tr", {}, [
          el("td", { class: "strong" }, [d.tittel || d.filnavn || "—", r.anledning && el("span", { class: "who" }, r.anledning), d.saksflytnr && el("span", { class: "who mono" }, d.saksflytnr)]),
          el("td", {}, TYPE_TEKST[r.type] + (r.type === "mote" ? ` (${(r.styre || []).length})` : r.type === "styremedlemmer" ? ` (${(r.mottakere || []).length})` : "")),
          el("td", {}, [merke(tekst, farge), r.status === "avvist" && r.avvist_arsak && el("span", { class: "who" }, r.avvist_arsak)]),
          el("td", {}, sign.length
            ? el("div", { class: "stack", style: "gap:2px" }, sign.map(s => el("span", { style: "font-size:.83rem" }, [
                el("b", {}, s.navn_tekst), ` · ${dato(s.signaturdato)} `, el("span", { class: "mono dim" }, s.signatur_id)
              ])))
            : el("span", { class: "dim" }, r.type === "styremedlemmer"
                ? "Venter: " + (r.mottakere || []).map(m => navnPaa(m.profiles)).join(", ")
                : r.type === "mote" ? "Venter: " + (r.styre || []).map(b => b.navn).join(", ")
                : "—")),
          el("td", { class: "dim" }, [tidspunkt(r.opprettet), el("span", { class: "who" }, navnPaa(r.oppretter))]),
          el("td", { class: "num" }, el("div", { class: "actions" }, [
            d.signert_path ? knapp("Åpne signert", { klasse: "stille sm", ved: () => apne_(d.signert_path) }) : null,
            kanTrekke ? knapp("Trekk", { klasse: "stille sm", ved: async () => { if (await trekk(r)) tegn(); } }) : null
          ]))
        ]);
      })
    )
  }));
  return boks;
}

async function apne_(sti) {
  const { data: url, error } = await db.storage.from("dokumenter").createSignedUrl(sti, 60);
  if (error) return visFeil(error, "Åpning");
  window.open(url.signedUrl, "_blank", "noopener");
}

/* =====================================================================
   Visning: Fullmakter (Innstillinger)
   ===================================================================== */

export const fullmakterView = {
  tittel: "Styret og fullmakter",
  undertekst: "Hvem som sitter i styret, og hvem styret har gitt fullmakt til å signere på styrets vegne.",
  async bygg() { return byggFullmakter(); }
};

async function byggFullmakter() {
  const { data: styret, error: sFeil } = await db.from("board_members")
    .select("*, profiles:user_id(fornavn,etternavn,epost)")
    .eq("organization_id", S.orgId).order("rekkefolge").order("navn");
  if (sFeil) throw sFeil;
  const { data, error } = await db.from("mandates")
    .select("*, profiles:user_id(fornavn,etternavn,epost), trukket:trukket_av(fornavn,etternavn), vedtak_dok:vedtak_document_id(tittel,saksflytnr)")
    .eq("organization_id", S.orgId).order("opprettet", { ascending: false });
  if (error) throw error;
  const boks = el("div", { class: "stack" });
  const iDag_ = iDag();
  const erAktiv = (m) => !m.trukket_tilbake && m.gyldig_fra <= iDag_ && (!m.gyldig_til || m.gyldig_til >= iDag_);

  boks.append(kort({
    tittel: "Slik virker fullmakt",
    innhold: el("p", { class: "dim", style: "margin:0;font-size:.885rem;line-height:1.5" },
      "Styret fatter et vedtak om at én person — ofte daglig leder eller sekretær — kan signere protokoller på styrets vegne. " +
      "Administrator registrerer vedtaket her med gyldighetsperiode. Når fullmektig signerer, viser signaturen til vedtaket. " +
      "En fullmakt kan ikke redigeres; den trekkes tilbake og en ny registreres. Alt havner i revisjonssporet.")
  }));

  const sitter = (b) => (!b.fra || b.fra <= iDag_) && (!b.til || b.til >= iDag_);
  boks.append(kort({
    tittel: "Styret",
    beskrivelse: "Styremedlemmene trenger ikke egen innlogging. Når fullmektig signerer på vegne av styret, står disse navnene på signatursiden.",
    hoyre: erAdmin() ? knapp("Legg til styremedlem", { klasse: "stille", ikon: "pluss", ved: async () => { if (await redigerStyremedlem(null)) paaNytt(); } }) : null,
    innhold: tabell(
      [{ t: "Navn" }, { t: "Verv" }, { t: "Periode" }, { t: "Innlogging" }, { t: "" }],
      (styret || []).map(b => el("tr", {}, [
        el("td", { class: "strong" }, b.navn),
        el("td", {}, b.verv),
        el("td", { class: "dim" }, [(b.fra ? dato(b.fra) : "—") + " – " + (b.til ? dato(b.til) : "sitter"), !sitter(b) && el("span", { class: "who" }, "Ikke i styret nå")]),
        el("td", {}, b.user_id ? merke(navnPaa(b.profiles), "teal") : el("span", { class: "dim" }, "Ingen")),
        el("td", { class: "num" }, erAdmin() ? el("div", { class: "actions" }, [
          knapp("Rediger", { klasse: "stille sm", ved: async () => { if (await redigerStyremedlem(b)) paaNytt(); } })
        ]) : null)
      ])),
      "Ingen styremedlemmer er registrert ennå."
    )
  }));

  boks.append(kort({
    tittel: "Fullmakter",
    hoyre: erAdmin() ? knapp("Ny fullmakt", { klasse: "primary", ikon: "pluss", ved: async () => { if (await nyFullmakt()) paaNytt(); } }) : null,
    innhold: tabell(
      [{ t: "Nr" }, { t: "Fullmektig" }, { t: "Vedtak" }, { t: "Gjelder" }, { t: "Omfang" }, { t: "Status" }, { t: "" }],
      (data || []).map(m => el("tr", {}, [
        el("td", { class: "mono" }, m.nummer),
        el("td", { class: "strong" }, navnPaa(m.profiles)),
        el("td", {}, [m.vedtak, el("span", { class: "who" }, dato(m.vedtaksdato) + (m.vedtak_dok ? " · " + (m.vedtak_dok.saksflytnr || m.vedtak_dok.tittel) : ""))]),
        el("td", { class: "dim" }, dato(m.gyldig_fra) + " – " + (m.gyldig_til ? dato(m.gyldig_til) : "inntil videre")),
        el("td", {}, OMFANG[m.omfang] || m.omfang),
        el("td", {}, m.trukket_tilbake
          ? [merke("Trukket", "red"), el("span", { class: "who" }, tidspunkt(m.trukket_tilbake) + " av " + navnPaa(m.trukket))]
          : erAktiv(m) ? merke("Aktiv", "green")
          : (m.gyldig_fra > iDag_ ? merke("Ikke startet", "blue") : merke("Utløpt", "neutral"))),
        el("td", { class: "num" }, (erAdmin() && !m.trukket_tilbake) ? knapp("Trekk tilbake", {
          klasse: "danger sm",
          ved: async () => {
            if (!await bekreft("Trekke fullmakten tilbake?", navnPaa(m.profiles) + " kan ikke lenger signere på vegne av styret. Dette kan ikke angres.", "Trekk tilbake")) return;
            try {
              const { error } = await db.from("mandates").update({ trukket_tilbake: new Date().toISOString() }).eq("id", m.id);
              if (error) throw error;
              toast("Trukket", "Fullmakten er trukket tilbake."); paaNytt();
            } catch (e) { visFeil(e, "Tilbaketrekking"); }
          }
        }) : null)
      ])),
      "Ingen fullmakter er registrert. Uten fullmakt kan bare administrator signere på vegne av styret."
    )
  }));
  return boks;
}

async function nyFullmakt() {
  const [{ data: brukere, error }, { data: protokoller }] = await Promise.all([
    db.from("organization_users").select("user_id, rolle, styreverv, profiles(fornavn,etternavn,epost)")
      .eq("organization_id", S.orgId).eq("aktiv", true).neq("rolle", "revisor"),
    velgFra("documents", "id, tittel, saksflytnr, mappe").in("mappe", ["Styremøter", "Årsprotokoller"]).order("opprettet", { ascending: false }).limit(50)
  ]);
  if (error) { visFeil(error, "Henting"); return false; }

  const svar = await skjemaModal({
    tittel: "Ny fullmakt",
    beskrivelse: "Registrer styrevedtaket som gir én person rett til å signere på vegne av styret.",
    felter: [
      { navn: "user_id", label: "Fullmektig", type: "select", bredde: "full",
        valg: (brukere || []).map(b => ({ verdi: b.user_id, tekst: navnPaa(b.profiles) + (b.styreverv ? " — " + b.styreverv : "") })) },
      { navn: "vedtak", label: "Vedtak", plassholder: "Styrevedtak sak 12/2026", bredde: "full", hint: "Slik det skal stå i signaturblokken." },
      { navn: "vedtaksdato", label: "Vedtaksdato", type: "date", verdi: iDag() },
      { navn: "vedtak_document_id", label: "Protokollen vedtaket står i", type: "select",
        valg: [{ verdi: "", tekst: "Ikke lenket" }].concat((protokoller || []).map(p => ({ verdi: p.id, tekst: (p.saksflytnr ? p.saksflytnr + " · " : "") + p.tittel }))) },
      { navn: "gyldig_fra", label: "Gyldig fra", type: "date", verdi: iDag() },
      { navn: "gyldig_til", label: "Gyldig til", type: "date", hint: "Tom = inntil videre. Anbefalt: frem til neste årsmøte." },
      { navn: "omfang", label: "Omfang", type: "select", bredde: "full",
        valg: Object.entries(OMFANG).map(([verdi, tekst]) => ({ verdi, tekst })) }
    ],
    lagreTekst: "Registrer fullmakt",
    onLagre: async (d) => {
      if (!d.vedtak) { toast("Mangler vedtak", "Skriv hvilket vedtak fullmakten bygger på.", true); return false; }
      const { error } = await settInn("mandates", {
        user_id: d.user_id, vedtak: d.vedtak, vedtaksdato: d.vedtaksdato,
        vedtak_document_id: d.vedtak_document_id || null,
        gyldig_fra: d.gyldig_fra || iDag(), gyldig_til: d.gyldig_til || null, omfang: d.omfang
      });
      if (error) throw error;
      return true;
    }
  });
  if (svar) toast("Registrert", "Fullmakten er registrert og gjelder fra " + dato(svar.gyldig_fra || iDag()) + ".");
  return !!svar;
}

async function redigerStyremedlem(b) {
  const { data: brukere } = await db.from("organization_users").select("user_id, profiles(fornavn,etternavn,epost)")
    .eq("organization_id", S.orgId).eq("aktiv", true).neq("rolle", "revisor");
  const svar = await skjemaModal({
    tittel: b ? "Rediger styremedlem" : "Nytt styremedlem",
    felter: [
      { navn: "navn", label: "Navn", verdi: b?.navn || "", bredde: "full" },
      { navn: "verv", label: "Verv", type: "select", verdi: b?.verv || "Styremedlem",
        valg: VERV.filter(v => v !== "Ingen verv").map(v => ({ verdi: v, tekst: v })) },
      { navn: "user_id", label: "Knyttet til bruker", type: "select", verdi: b?.user_id || "",
        valg: [{ verdi: "", tekst: "Ingen innlogging" }].concat((brukere || []).map(u => ({ verdi: u.user_id, tekst: navnPaa(u.profiles) }))),
        hint: "Bare nødvendig hvis personen skal signere selv." },
      { navn: "fra", label: "Valgt fra", type: "date", verdi: b?.fra || "" },
      { navn: "til", label: "Gikk ut", type: "date", verdi: b?.til || "", hint: "Tom = sitter fortsatt." }
    ],
    lagreTekst: b ? "Lagre" : "Legg til",
    onLagre: async (d) => {
      if (!d.navn) { toast("Mangler navn", "Skriv navnet på styremedlemmet.", true); return false; }
      const rad = { navn: d.navn, verv: d.verv, user_id: d.user_id || null, fra: d.fra || null, til: d.til || null };
      const { error } = b
        ? await db.from("board_members").update(rad).eq("id", b.id)
        : await settInn("board_members", rad);
      if (error) throw error;
      return true;
    },
    onSlett: b ? async () => {
      const { error } = await db.from("board_members").delete().eq("id", b.id);
      if (error) throw error;
    } : undefined
  });
  return !!svar;
}

/* =====================================================================
   Enkel signatur — enheten går rundt bordet
   ===================================================================== */

async function enkelSignering(r, dok) {
  let gjort = false;
  await new Promise(resolve => {
    const overlay = el("div", { class: "overlay" });
    const lukk = () => { overlay.remove(); resolve(); };
    const liste = el("div", { class: "oppm" });
    const datoFelt = el("input", { type: "date", value: dok.dokumentdato || iDag(), max: iDag() });

    const tegnListe = async () => {
      const { data: sign } = await db.from("signatures").select("signer_id, navn_tekst, signaturdato, signatur_id")
        .eq("request_id", r.id);
      const signert = Object.fromEntries((sign || []).filter(x => x.signer_id).map(x => [x.signer_id, x]));
      liste.replaceChildren(...(r.styre || [])
        .slice().sort((a, b) => (a.rekkefolge ?? 100) - (b.rekkefolge ?? 100))
        .map(b => {
          const s = signert[b.id];
          return el("div", { class: "oppm-rad", style: "cursor:default" }, [
            el("span", { class: "merke " + (s ? "green" : "gold"), html: svg(s ? "ok" : "bruker") }),
            el("span", { class: "tekst" }, [
              el("b", {}, b.navn || "—"),
              el("span", {}, s ? `Signert ${dato(s.signaturdato)} · ${s.signatur_id}` : (b.rolle || ""))
            ]),
            s ? merke("Signert", "green") : knapp("Signer", {
              klasse: "primary", ved: async () => {
                if (await signerStyremedlem(r, dok, b, datoFelt.value)) { gjort = true; await tegnListe(); }
              }
            })
          ]);
        }));
      const alle = (r.styre || []).length && Object.keys(signert).length >= (r.styre || []).length;
      ferdigKnapp.textContent = alle ? "Alle har signert — lukk" : "Lukk";
    };

    const ferdigKnapp = el("button", { class: "btn primary", onclick: lukk }, "Lukk");
    overlay.append(el("div", { class: "modal", style: "max-width:640px" }, [
      el("div", { class: "modal-head" }, [
        el("h2", {}, "Enkel signatur"),
        el("p", {}, (dok.tittel || dok.filnavn) + (dok.saksflytnr ? " · " + dok.saksflytnr : "") + ". Gi enheten til hvert styremedlem etter tur.")
      ]),
      el("div", { class: "modal-body" }, [
        el("div", { class: "field", style: "margin-bottom:12px" }, [
          el("label", {}, "Dato på signaturene"), datoFelt,
          el("span", { class: "hint" }, "Møtedatoen. Tidspunktet hver signatur faktisk gjøres, logges uansett.")
        ]),
        liste
      ]),
      el("div", { class: "modal-foot" }, [ferdigKnapp])
    ]));
    document.body.append(overlay);
    tegnListe();
  });

  if (gjort) {
    const { data: oppd } = await db.from("documents").select("*").eq("id", dok.id).single();
    if (oppd?.laast) {
      try { await ferdigstillSignertFil(oppd); toast("Ferdig signert", "Alle har signert. Den signerte PDF-en ligger i arkivet."); }
      catch (e) { console.warn(e); toast("Signert", "Signaturene er registrert, men PDF-en kunne ikke lages nå. Bruk «Lag signert PDF» i arkivet.", true); }
    }
  }
  return gjort;
}

async function signerStyremedlem(r, dok, b, signaturdato) {
  const navn = b.navn || "Signatar";
  const flate = tegneflate();
  const bekreftet = el("input", { type: "checkbox" });

  return new Promise(resolve => {
    const overlay = el("div", { class: "overlay" });
    const lukk = (v) => { overlay.remove(); resolve(v); };
    const signerKnapp = el("button", { class: "btn primary" }, "Signer");
    signerKnapp.addEventListener("click", async () => {
      if (!bekreftet.checked) { toast("Bekreft", "Kryss av for at det er du som signerer.", true); return; }
      signerKnapp.disabled = true; signerKnapp.textContent = "Signerer …";
      try {
        let sti = null;
        if (!flate.erTom()) {
          const png = await flate.blob();
          sti = `${S.orgId}/signatur-${Date.now()}-${b.id.slice(0, 8)}.png`;
          const { error: oppFeil } = await db.storage.from("dokumenter").upload(sti, png, { contentType: "image/png" });
          if (oppFeil) { console.warn(oppFeil); sti = null; toast("Håndtegning", "Tegningen kunne ikke lagres, signaturen registreres uten.", true); }
        }
        const { error } = await db.from("signatures").insert({
          request_id: r.id, signert_som: "styremedlem_i_mote", signer_id: b.id,
          signaturdato: signaturdato || null, signaturbilde_path: sti,
          user_agent: navigator.userAgent.slice(0, 200)
        });
        if (error) throw error;
        toast("Signert", navn + " har signert.");
        lukk(true);
      } catch (e) { visFeil(e, "Signering"); signerKnapp.disabled = false; signerKnapp.textContent = "Signer"; }
    });

    overlay.append(el("div", { class: "modal", style: "max-width:640px" }, [
      el("div", { class: "modal-head" }, [
        el("h2", {}, navn),
        el("p", {}, (b.rolle ? b.rolle + " · " : "") + "signerer " + (dok.tittel || dok.filnavn))
      ]),
      el("div", { class: "modal-body" }, [
        el("div", { class: "field" }, [
          el("label", {}, "Signer med fingeren eller pennen (valgfritt)"),
          flate.el,
          el("div", { class: "actions" }, [knapp("Tøm", { klasse: "stille sm", ved: flate.tom })])
        ]),
        el("label", { style: "display:flex;gap:10px;align-items:center;margin-top:14px;font-weight:500" }, [
          bekreftet, "Jeg er " + navn + " og signerer dette dokumentet."
        ])
      ]),
      el("div", { class: "modal-foot" }, [
        el("button", { class: "btn", onclick: () => lukk(false) }, "Avbryt"),
        signerKnapp
      ])
    ]));
    document.body.append(overlay);
  });
}

/** Tegneflate for håndsignatur. Returnerer { el, tom(), erTom(), blob() }. */
function tegneflate() {
  const lerret = el("canvas", { style: "width:100%;height:180px;border:1px dashed var(--line);border-radius:10px;background:#fff;touch-action:none;display:block" });
  const dpr = Math.max(1, window.devicePixelRatio || 1);
  let c, tegnet = false, nede = false, sist = null;
  const klargjor = () => {
    const w = lerret.clientWidth || 560, h = 180;
    lerret.width = Math.round(w * dpr); lerret.height = Math.round(h * dpr);
    c = lerret.getContext("2d"); c.scale(dpr, dpr);
    c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round"; c.strokeStyle = "#0b2b33";
    tegnet = false;
  };
  const pos = (e) => { const r = lerret.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
  lerret.addEventListener("pointerdown", e => { e.preventDefault(); lerret.setPointerCapture(e.pointerId); nede = true; sist = pos(e); });
  lerret.addEventListener("pointermove", e => {
    if (!nede) return; e.preventDefault();
    const p = pos(e); c.beginPath(); c.moveTo(sist.x, sist.y); c.lineTo(p.x, p.y); c.stroke(); sist = p; tegnet = true;
  });
  const slipp = () => { nede = false; sist = null; };
  lerret.addEventListener("pointerup", slipp); lerret.addEventListener("pointercancel", slipp); lerret.addEventListener("pointerleave", slipp);
  setTimeout(klargjor, 0);
  return {
    el: lerret,
    tom: () => { klargjor(); },
    erTom: () => !tegnet,
    blob: () => new Promise(ok => lerret.toBlob(ok, "image/png"))
  };
}
