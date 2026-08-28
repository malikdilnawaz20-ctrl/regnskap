// =====================================================================
//  Faktura — regninger klubben sender ut.
//  Motstykket til Attestering, som er regningene klubben mottar.
//
//  Nummeret tildeles av databasen når fakturaen utstedes, ikke før, og
//  en utstedt faktura kan ikke endres. Det er ikke pyntet på i
//  grensesnittet — knappene forsvinner, og serveren avviser uansett.
// =====================================================================

import {
  el, svg, kort, kpi, merke, tabell, felt, tekstfelt, velg, skjemaModal, bekreft,
  toast, visFeil, knapp, kr, kr0, tilOre, dato, iDag, tomTilstand, skuff,
  verktoylinje, fanerad, eksporterExcel, db
} from "../lib.js";
import { S, kanOkonomi, velgFra, settInn, paaNytt, aarNaa } from "../store.js";
import { MALER, lagVisning, tegnFaktura } from "../faktura-maler.js";

const STATUS = {
  kladd:      ["Kladd", "neutral"],
  utstedt:    ["Sendt", "blue"],
  betalt:     ["Betalt", "green"],
  kreditert:  ["Kreditert", "red"]
};

const TYPER = [
  { verdi: "faktura",    tekst: "Faktura" },
  { verdi: "proforma",   tekst: "Proforma faktura" },
  { verdi: "kreditnota", tekst: "Kreditnota" }
];

const VALUTAER = ["NOK", "USD", "EUR", "GBP", "SEK", "DKK", "PKR"]
  .map(v => ({ verdi: v, tekst: v }));

const MVASATSER = [25, 15, 12, 6, 0].map(s => ({ verdi: String(s), tekst: s + " %" }));

const forfalt = (f) =>
  f.status === "utstedt" && f.forfall && f.forfall < iDag();

/* --- brukes av forsiden --- */
export async function hentFakturaTall() {
  const { data, error } = await velgFra("sales_invoices", "status,forfall,brutto_ore");
  if (error) throw error;
  const ute = data.filter(f => f.status === "utstedt");
  return {
    utestaende: ute.reduce((s, f) => s + (f.brutto_ore || 0), 0),
    antallUte: ute.length,
    forfalt: ute.filter(forfalt).length,
    kladder: data.filter(f => f.status === "kladd").length
  };
}

/* =====================================================================
   Avsenderoppsettet — klubbens egne opplysninger på fakturaen.
   ===================================================================== */

function avsenderFra(org) {
  return {
    navn: org?.navn || "",
    adresse: [org?.adresse, [org?.postnr, org?.poststed].filter(Boolean).join(" ")]
      .filter(Boolean).join("\n"),
    epost: org?.epost || "",
    telefon: org?.telefon || "",
    orgnr: org?.orgnr || "",
    mva: org?.orgnr ? "Org.nr " + org.orgnr : "",
    farge: "#0E9A6E",
    kontonummer: org?.faktura_kontonummer || org?.kontonummer || "",
    iban: org?.faktura_iban || "",
    swift: org?.faktura_swift || "",
    vilkar: org?.faktura_vilkar || "",
    eksport: {}
  };
}

/* =====================================================================
   Hovedvisning
   ===================================================================== */

export const fakturaView = {
  tittel: "Faktura",
  undertekst: "Regninger klubben sender ut. Nummeret tildeles når fakturaen utstedes.",
  async bygg() { return bygg(); }
};

let filter = "aapne";
let sok = "";

async function bygg() {
  const [{ data: fakturaer, error }, { data: kunder }, { data: kategorier }, { data: prosjekter }] =
    await Promise.all([
      db.from("sales_invoices")
        .select("*, kunde:customer_id(id,navn,att,adresse,orgnr,epost)")
        .eq("organization_id", S.orgId)
        .order("fakturadato", { ascending: false, nullsFirst: true })
        .order("opprettet", { ascending: false }),
      velgFra("customers", "id,navn,att,adresse,orgnr,epost").eq("aktiv", true).order("navn"),
      velgFra("categories", "id,navn,retning").eq("retning", "inntekt"),
      velgFra("projects", "id,navn")
    ]);
  if (error) throw error;

  const boks = el("div", { class: "stack" });
  const skriv = kanOkonomi();

  /* --- nøkkeltall --- */
  const ute = fakturaer.filter(f => f.status === "utstedt");
  const iAar = fakturaer.filter(f =>
    f.status !== "kladd" && f.fakturadato && Number(f.fakturadato.slice(0, 4)) === aarNaa());
  const sum = a => a.reduce((s, f) => s + (f.brutto_ore || 0), 0);
  const antForfalt = ute.filter(forfalt).length;

  boks.append(el("div", { class: "grid g4" }, [
    kpi({ nokkel: "Utestående", verdi: kr0(sum(ute)) + " kr", ikon: "okonomi",
          under: ute.length + (ute.length === 1 ? " faktura" : " fakturaer") }),
    kpi({ nokkel: "Forfalt", verdi: String(antForfalt), ikon: "varsel",
          farge: antForfalt ? "neg" : null,
          under: antForfalt ? "purring bør sendes" : "ingenting over forfall" }),
    kpi({ nokkel: "Fakturert i år", verdi: kr0(sum(iAar)) + " kr", ikon: "rapport",
          under: aarNaa() + ", eks. kladder" }),
    kpi({ nokkel: "Kladder", verdi: String(fakturaer.filter(f => f.status === "kladd").length),
          ikon: "dokument", under: "ikke utstedt ennå" })
  ]));

  /* --- ingen kunder ennå --- */
  if (!kunder.length) {
    boks.append(kort({
      tittel: "Legg inn den første kunden",
      innhold: tomTilstand({
        tittel: "Ingen kunder ennå",
        tekst: "En faktura må ha en mottaker. Kunder er ofte kommunen, en sponsor eller en annen klubb — de trenger ikke være medlemmer.",
        ikon: "medlemmer",
        handlinger: skriv ? [knapp("Ny kunde", { klasse: "primary", ikon: "pluss", ved: () => nyKunde() })] : []
      })
    }));
    return boks;
  }

  /* --- verktøylinje --- */
  const faner = fanerad([
    { id: "aapne", tekst: "Åpne" }, { id: "kladd", tekst: "Kladder" },
    { id: "forfalt", tekst: "Forfalt" }, { id: "betalt", tekst: "Betalt" },
    { id: "alle", tekst: "Alle" }
  ], filter, id => { filter = id; paaNytt(); });

  boks.append(faner);
  boks.append(verktoylinje({
    sok: { plassholder: "Søk på nummer eller kunde …", verdi: sok, ved: v => { sok = v; tegnTabell(); } },
    handling: skriv ? el("div", { class: "actions" }, [
      knapp("Ny kunde", { ikon: "medlemmer", ved: () => nyKunde() }),
      knapp("Ny faktura", { klasse: "primary", ikon: "pluss", ved: () => nyFaktura(kunder, kategorier, prosjekter) })
    ]) : null
  }));

  /* --- tabell --- */
  const tabellboks = el("div", {});
  boks.append(kort({ innhold: tabellboks }));

  function synlige() {
    const s = sok.toLowerCase();
    return fakturaer.filter(f => {
      if (filter === "aapne" && f.status !== "utstedt" && f.status !== "kladd") return false;
      if (filter === "kladd" && f.status !== "kladd") return false;
      if (filter === "forfalt" && !forfalt(f)) return false;
      if (filter === "betalt" && f.status !== "betalt") return false;
      if (!s) return true;
      return (f.nummer || "").toLowerCase().includes(s) ||
             (f.kunde?.navn || "").toLowerCase().includes(s);
    });
  }

  function tegnTabell() {
    const rader = synlige().map(f => {
      const [tekst, farge] = STATUS[f.status] || ["—", "neutral"];
      return el("tr", { class: "klikk", onclick: () => aapne(f, kunder, kategorier, prosjekter) }, [
        el("td", {}, f.nummer || el("span", { class: "sub" }, "kladd")),
        el("td", {}, [
          el("b", {}, f.kunde?.navn || "—"),
          f.type !== "faktura" && el("span", { class: "sub" }, " · " + (TYPER.find(t => t.verdi === f.type)?.tekst || ""))
        ]),
        el("td", {}, f.fakturadato ? dato(f.fakturadato) : "—"),
        el("td", {}, f.forfall ? dato(f.forfall) : "—"),
        el("td", { class: "num" }, kr(f.brutto_ore) + (f.valuta !== "NOK" ? " " + f.valuta : "")),
        el("td", {}, forfalt(f) ? merke("Forfalt", "red") : merke(tekst, farge))
      ]);
    });
    tabellboks.replaceChildren(tabell(
      [{ t: "Nummer" }, { t: "Kunde" }, { t: "Dato" }, { t: "Forfall" }, { t: "Beløp", num: true }, { t: "Status" }],
      rader,
      "Ingen fakturaer i dette utvalget."
    ));
  }
  tegnTabell();

  return boks;
}

/* =====================================================================
   Ny faktura — hodet først, linjene etterpå i skuffen.
   ===================================================================== */

async function nyFaktura(kunder, kategorier, prosjekter) {
  const org = S.org;
  const svar = await skjemaModal({
    tittel: "Ny faktura",
    beskrivelse: "Fakturaen opprettes som kladd. Nummeret tildeles først når du utsteder den.",
    felter: [
      { navn: "customer_id", label: "Kunde", type: "select",
        valg: kunder.map(k => ({ verdi: k.id, tekst: k.navn })) },
      { navn: "type", label: "Type", type: "select", valg: TYPER },
      { navn: "fakturadato", label: "Fakturadato", type: "date", verdi: iDag(),
        hint: "Kan settes bakover, men se advarselen før du utsteder." },
      { navn: "forfall", label: "Forfall", type: "date",
        verdi: new Date(Date.now() + (org?.faktura_betalingsdager ?? 14) * 864e5).toISOString().slice(0, 10) },
      { navn: "levering_fra", label: "Levert fra", type: "date",
        hint: "Når ytelsen faktisk ble levert. Skal med på fakturaen." },
      { navn: "levering_til", label: "Levert til", type: "date" },
      { navn: "valuta", label: "Valuta", type: "select", valg: VALUTAER },
      { navn: "mal", label: "Mal", type: "select",
        valg: MALER.map(m => ({ verdi: String(m.id), tekst: String(m.id).padStart(2, "0") + " — " + m.name })),
        verdi: String(org?.faktura_mal || 1) },
      { navn: "category_id", label: "Inntektskategori", type: "select",
        valg: [{ verdi: "", tekst: "— velg —" }].concat(kategorier.map(k => ({ verdi: k.id, tekst: k.navn }))) },
      { navn: "project_id", label: "Prosjekt", type: "select",
        valg: [{ verdi: "", tekst: "— ingen —" }].concat(prosjekter.map(p => ({ verdi: p.id, tekst: p.navn }))) },
      { navn: "deres_ref", label: "Deres referanse", bredde: "full",
        hint: "Kontaktperson eller bestillingsnummer hos kunden. Offentlige oppdragsgivere krever dette." }
    ],
    lagreTekst: "Opprett kladd"
  });
  if (!svar) return;

  try {
    const { data, error } = await settInn("sales_invoices", {
      organization_id: S.orgId,
      customer_id: svar.customer_id,
      type: svar.type,
      fakturadato: svar.fakturadato || null,
      forfall: svar.forfall || null,
      levering_fra: svar.levering_fra || null,
      levering_til: svar.levering_til || null,
      valuta: svar.valuta,
      mal: Number(svar.mal),
      category_id: svar.category_id || null,
      project_id: svar.project_id || null,
      deres_ref: svar.deres_ref || null,
      opprettet_av: S.bruker.id
    }).select("*, kunde:customer_id(id,navn,att,adresse,orgnr,epost)").single();
    if (error) throw error;
    toast("Opprettet", "Legg inn linjene, så kan du utstede.");
    aapne(data, kunder, kategorier, prosjekter);
  } catch (e) { visFeil(e, "Opprettelsen"); }
}

/* =====================================================================
   Kunder
   ===================================================================== */

async function nyKunde(kunde) {
  const svar = await skjemaModal({
    tittel: kunde ? "Rediger kunde" : "Ny kunde",
    felter: [
      { navn: "navn", label: "Navn", verdi: kunde?.navn || "", bredde: "full" },
      { navn: "att", label: "Att.", verdi: kunde?.att || "", plassholder: "v/ Kari Nordmann" },
      { navn: "orgnr", label: "Org.nr", verdi: kunde?.orgnr || "" },
      { navn: "adresse", label: "Adresse", type: "textarea", verdi: kunde?.adresse || "",
        bredde: "full", hint: "Én linje per rad, slik den skal stå på fakturaen." },
      { navn: "epost", label: "E-post", verdi: kunde?.epost || "" },
      { navn: "telefon", label: "Telefon", verdi: kunde?.telefon || "" }
    ],
    onLagre: async (d) => {
      if (!d.navn) { toast("Mangler navn", "Kunden må ha et navn.", true); return false; }
      const rad = { navn: d.navn, att: d.att || null, orgnr: d.orgnr || null,
                    adresse: d.adresse || null, epost: d.epost || null, telefon: d.telefon || null };
      if (kunde) {
        const { error } = await db.from("customers").update(rad).eq("id", kunde.id);
        if (error) throw error;
      } else {
        const { error } = await settInn("customers",
          { ...rad, organization_id: S.orgId, opprettet_av: S.bruker.id });
        if (error) throw error;
      }
    }
  });
  if (svar) { toast("Lagret", "Kunden er lagret."); paaNytt(); }
}

/* =====================================================================
   Fakturaen i detalj — linjer, forhåndsvisning og handlinger
   ===================================================================== */

async function aapne(faktura, kunder, kategorier, prosjekter) {
  const { data: linjer, error } = await db.from("sales_invoice_lines")
    .select("*").eq("invoice_id", faktura.id).order("rekkefolge");
  if (error) { visFeil(error, "Henting av linjer"); return; }

  const erKladd = faktura.status === "kladd";
  const skriv = kanOkonomi() && erKladd;
  let mal = faktura.mal || 1;
  let arbeid = linjer.map(l => ({ ...l }));
  if (!arbeid.length && erKladd) arbeid.push(tomLinje(0));

  const innhold = el("div", { class: "stack" });

  /* --- advarsel ved tilbakedatering --- */
  const varsel = el("div", {});
  innhold.append(varsel);
  function tegnVarsel() {
    varsel.replaceChildren();
    if (!erKladd || !faktura.fakturadato || faktura.historisk) return;
    const dager = Math.round((Date.now() - new Date(faktura.fakturadato)) / 864e5);
    if (dager < 45) return;
    varsel.append(el("div", { class: "note warn" }, [
      el("span", { html: svg("varsel") }),
      el("div", {}, [
        el("b", {}, "Fakturadatoen ligger " + dager + " dager tilbake. "),
        "Gjelder dette et salg som aldri ble fakturert, skal fakturaen utstedes i dag med leveringsperioden angitt — ikke dateres bakover. Er dette et dokument som faktisk ble utstedt den gang, hører det hjemme under historisk import."
      ])
    ]));
  }
  tegnVarsel();

  /* --- linjer --- */
  const linjeboks = el("div", {});
  innhold.append(kort({
    tittel: "Linjer",
    beskrivelse: erKladd ? "Beløp uten mva. Summen regnes ut under." : "Fakturaen er utstedt, og linjene er låst.",
    innhold: linjeboks
  }));

  function tomLinje(n) {
    return { beskrivelse: "", antall: 1, enhet: "", pris_ore: 0, mva_sats: 25, rekkefolge: n };
  }

  function summer() {
    // En utstedt faktura viser beløpene som ble lagret ved utstedelsen.
    // Kladden regner ut mens du skriver.
    if (!erKladd) {
      return { netto: faktura.netto_ore || 0, mva: faktura.mva_ore || 0, brutto: faktura.brutto_ore || 0 };
    }
    const netto = arbeid.reduce((s, l) => s + Math.round((Number(l.antall) || 0) * (l.pris_ore || 0)), 0);
    const mva = arbeid.reduce((s, l) =>
      s + Math.round((Number(l.antall) || 0) * (l.pris_ore || 0) * (l.mva_sats || 0) / 100), 0);
    return { netto, mva, brutto: netto + mva };
  }

  function tegnLinjer() {
    const rader = arbeid.map((l, i) => {
      if (!skriv) {
        return el("tr", {}, [
          el("td", {}, l.beskrivelse),
          el("td", { class: "num" }, String(l.antall) + (l.enhet ? " " + l.enhet : "")),
          el("td", { class: "num" }, kr(l.pris_ore)),
          el("td", { class: "num" }, l.mva_sats + " %"),
          el("td", { class: "num" }, kr(Math.round(l.antall * l.pris_ore)))
        ]);
      }
      const besk = tekstfelt("b" + i, l.beskrivelse, { placeholder: "Hva selges?" });
      besk.addEventListener("input", () => { l.beskrivelse = besk.value; oppdater(); });
      const ant = el("input", { type: "text", value: String(l.antall), inputmode: "decimal" });
      ant.addEventListener("input", () => {
        l.antall = Number(ant.value.replace(",", ".")) || 0; oppdater();
      });
      const enh = tekstfelt("e" + i, l.enhet || "", { placeholder: "stk" });
      enh.addEventListener("input", () => { l.enhet = enh.value; });
      const pris = el("input", { type: "text", value: l.pris_ore ? kr(l.pris_ore) : "", inputmode: "decimal" });
      pris.addEventListener("input", () => { l.pris_ore = tilOre(pris.value); oppdater(); });
      const mvaValg = velg("m" + i, MVASATSER, String(l.mva_sats));
      mvaValg.addEventListener("change", () => { l.mva_sats = Number(mvaValg.value); oppdater(); });

      return el("tr", {}, [
        el("td", {}, besk),
        el("td", {}, ant),
        el("td", {}, enh),
        el("td", {}, pris),
        el("td", {}, mvaValg),
        el("td", {}, el("button", {
          class: "ikonknapp", title: "Fjern linjen",
          html: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
          onclick: () => { arbeid.splice(i, 1); if (!arbeid.length) arbeid.push(tomLinje(0)); oppdater(); }
        }))
      ]);
    });

    const kolonner = skriv
      ? [{ t: "Beskrivelse" }, { t: "Antall" }, { t: "Enhet" }, { t: "Pris eks. mva" }, { t: "Mva" }, { t: "" }]
      : [{ t: "Beskrivelse" }, { t: "Antall", num: true }, { t: "Pris", num: true },
         { t: "Mva", num: true }, { t: "Beløp", num: true }];

    const s = summer();
    linjeboks.replaceChildren(...[
      tabell(kolonner, rader, "Ingen linjer ennå."),
      skriv ? el("div", { class: "actions" }, [
        knapp("Legg til linje", { ikon: "pluss", ved: () => { arbeid.push(tomLinje(arbeid.length)); oppdater(); } }),
        knapp("Lagre linjer", { klasse: "primary", ved: lagreLinjer })
      ]) : null,
      el("dl", { class: "kv" }, [
        el("dt", {}, "Sum eks. mva"), el("dd", {}, kr(s.netto) + " kr"),
        el("dt", {}, "Mva"),         el("dd", {}, kr(s.mva) + " kr"),
        el("dt", {}, "Å betale"),    el("dd", {}, kr(s.brutto) + " " + (faktura.valuta || "NOK"))
      ])
    ].filter(Boolean));
  }

  function oppdater() { tegnLinjer(); tegnForhaandsvisning(); }

  async function lagreLinjer() {
    const gyldige = arbeid.filter(l => (l.beskrivelse || "").trim() !== "");
    if (!gyldige.length) { toast("Ingen linjer", "Fyll inn minst én linje med beskrivelse.", true); return; }
    try {
      const { error: slettFeil } = await db.from("sales_invoice_lines")
        .delete().eq("invoice_id", faktura.id);
      if (slettFeil) throw slettFeil;
      const { error } = await db.from("sales_invoice_lines").insert(gyldige.map((l, i) => ({
        invoice_id: faktura.id, rekkefolge: i,
        beskrivelse: l.beskrivelse, antall: Number(l.antall) || 0,
        enhet: l.enhet || null, pris_ore: l.pris_ore || 0, mva_sats: l.mva_sats || 0
      })));
      if (error) throw error;
      toast("Lagret", "Linjene er lagret.");
    } catch (e) { visFeil(e, "Lagring av linjer"); }
  }

  /* --- forhåndsvisning --- */
  const malrad = el("div", { class: "malvelger" }, MALER.map(m =>
    el("button", {
      class: "malflis", "aria-pressed": m.id === mal ? "true" : "false",
      title: m.description,
      onclick: async () => {
        mal = m.id;
        malrad.querySelectorAll(".malflis").forEach((b, i) =>
          b.setAttribute("aria-pressed", MALER[i].id === mal ? "true" : "false"));
        tegnForhaandsvisning();
        if (kanOkonomi()) await db.from("sales_invoices").update({ mal }).eq("id", faktura.id);
      }
    }, [el("span", { class: "nr" }, String(m.id).padStart(2, "0")), m.name])));

  const flate = el("div", { class: "fakturaflate" });
  innhold.append(kort({
    tittel: "Slik ser den ut",
    beskrivelse: "Malen lagres på fakturaen, så dokumentet ser likt ut om fem år.",
    innhold: [malrad, flate]
  }));

  function visning() {
    return lagVisning({
      faktura: { ...faktura, mal },
      linjer: arbeid,
      kunde: faktura.kunde || kunder.find(k => k.id === faktura.customer_id),
      org: S.org,
      avsender: avsenderFra(S.org)
    });
  }

  function tegnForhaandsvisning() {
    // Malmotoren escaper hver eneste verdi med esc() før den settes inn,
    // og flaten er en ren visningsflate uten skjema. Dette er samme
    // unntak som html:-attributtet for ikoner — ikke en åpning for
    // udesinfisert data ellers i appen.
    flate.innerHTML = tegnFaktura(visning(), mal);
    const ark = flate.querySelector(".inv");
    if (ark) {
      const skala = Math.min(1, (flate.clientWidth - 32) / ark.offsetWidth);
      ark.style.transform = "scale(" + skala.toFixed(3) + ")";
      flate.style.height = (ark.offsetHeight * skala + 32) + "px";
    }
  }

  /* --- handlinger --- */
  const bunn = el("div", { class: "actions" });

  function skrivUt() {
    let ut = document.getElementById("fakturautskrift");
    if (!ut) { ut = el("div", { id: "fakturautskrift" }); document.body.append(ut); }
    ut.innerHTML = '<div class="side">' + tegnFaktura(visning(), mal) + "</div>";
    window.print();
  }

  bunn.append(knapp("Skriv ut", { ikon: "dokument", ved: skrivUt }));

  if (kanOkonomi() && erKladd) {
    bunn.append(knapp("Utsted faktura", { klasse: "primary", ikon: "ok", ved: async () => {
      await lagreLinjer();
      const ok = await bekreft("Utsted fakturaen?",
        "Fakturaen får nummer fra den maskinelle serien, og kan ikke endres etterpå. Feil rettes med kreditnota.",
        "Ja, utsted");
      if (!ok) return;
      try {
        const { data, error } = await db.rpc("utsted_faktura", {
          p_faktura: faktura.id, p_dato: faktura.fakturadato || iDag()
        });
        if (error) throw error;
        toast("Utstedt", "Fakturaen fikk nummer " + data + ".");
        lukk(); paaNytt();
      } catch (e) { visFeil(e, "Utstedelsen"); }
    } }));
  }

  if (kanOkonomi() && faktura.status === "utstedt") {
    bunn.append(knapp("Registrer betalt", { klasse: "primary", ikon: "betaling", ved: async () => {
      const ok = await bekreft("Registrer som betalt?",
        "Fakturaen bokføres som inntekt med dagens dato, og får et bilagsnummer.", "Ja, den er betalt");
      if (!ok) return;
      try {
        const { error } = await db.rpc("bokfor_fakturabetaling", { p_faktura: faktura.id, p_dato: iDag() });
        if (error) throw error;
        toast("Bokført", "Fakturaen er registrert som betalt.");
        lukk(); paaNytt();
      } catch (e) { visFeil(e, "Registreringen"); }
    } }));

    bunn.append(knapp("Kreditnota", { ikon: "kvittering", ved: async () => {
      const svar = await skjemaModal({
        tittel: "Lag kreditnota",
        beskrivelse: "Kreditnotaen speiler linjene med motsatt fortegn. Den opprinnelige fakturaen blir stående.",
        felter: [{ navn: "arsak", label: "Årsak", bredde: "full", plassholder: "Feil beløp, kansellert leveranse …" }],
        lagreTekst: "Lag kreditnota"
      });
      if (!svar) return;
      try {
        const { error } = await db.rpc("lag_kreditnota", { p_faktura: faktura.id, p_arsak: svar.arsak || "" });
        if (error) throw error;
        toast("Opprettet", "Kreditnotaen ligger som kladd.");
        lukk(); paaNytt();
      } catch (e) { visFeil(e, "Kreditnotaen"); }
    } }));
  }

  const [statustekst, statusfarge] = STATUS[faktura.status] || ["—", "neutral"];
  const { lukk } = skuff({
    tittel: faktura.nummer || "Kladd",
    undertittel: (faktura.kunde?.navn || "") + " · " + statustekst,
    innhold,
    bunn
  });

  tegnLinjer();
  tegnForhaandsvisning();
}

/* =====================================================================
   Kunderegister som egen side
   ===================================================================== */

export const kunderView = {
  tittel: "Kunder",
  undertekst: "De som får regning fra klubben.",
  async bygg() {
    const { data: kunder, error } = await velgFra("customers", "*").order("navn");
    if (error) throw error;

    const boks = el("div", { class: "stack" });
    const skriv = kanOkonomi();

    boks.append(verktoylinje({
      handling: skriv ? knapp("Ny kunde", { klasse: "primary", ikon: "pluss", ved: () => nyKunde() }) : null
    }));

    const rader = kunder.map(k => el("tr", {
      class: skriv ? "klikk" : null,
      onclick: skriv ? () => nyKunde(k) : null
    }, [
      el("td", {}, el("b", {}, k.navn)),
      el("td", {}, k.att || "—"),
      el("td", {}, (k.adresse || "").split("\n").join(", ") || "—"),
      el("td", {}, k.orgnr || "—"),
      el("td", {}, k.epost || "—")
    ]));

    boks.append(kort({
      innhold: rader.length ? tabell(
        [{ t: "Navn" }, { t: "Att." }, { t: "Adresse" }, { t: "Org.nr" }, { t: "E-post" }], rader
      ) : tomTilstand({
        tittel: "Ingen kunder ennå",
        tekst: "Legg inn den første, så kan du sende faktura.",
        ikon: "medlemmer",
        handlinger: skriv ? [knapp("Ny kunde", { klasse: "primary", ikon: "pluss", ved: () => nyKunde() })] : []
      })
    }));

    if (kunder.length) {
      boks.append(el("div", { class: "actions" }, [
        knapp("Last ned som Excel", { ikon: "last", ved: () => eksporterExcel("kunder.xlsx", [{
          navn: "Kunder",
          rader: kunder.map(k => ({
            Navn: k.navn, Att: k.att || "", Adresse: (k.adresse || "").split("\n").join(", "),
            Orgnr: k.orgnr || "", Epost: k.epost || "", Telefon: k.telefon || ""
          }))
        }]) })
      ]));
    }

    return boks;
  }
};
