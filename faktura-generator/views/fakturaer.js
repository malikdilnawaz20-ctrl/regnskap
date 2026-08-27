// =====================================================================
//  Fakturaer — lista og redigeringssiden i Faktura generator.
//
//  Lav terskel er kravet. Derfor:
//    · «Ny faktura» oppretter kladden og åpner den med én gang. Ingen
//      dialog å fylle ut først.
//    · Leverandøren bestemmer valuta, språk, mal og betalingsfrist, så
//      det er ingenting å velge for den som bare skal sende en regning.
//    · Linjene lagrer seg selv mens du skriver.
//    · «Lag lik» er den knappen som brukes mest — de fleste fakturaer er
//      forrige faktura med ny dato.
//
//  Redigeringen ligger på egen side, ikke i en skuff. Et fakturaskjema
//  med forhåndsvisning ved siden av trenger hele bredden.
// =====================================================================

import {
  el, svg, kort, kpi, merke, tabell, tekstfelt, velg, skjemaModal, bekreft,
  toast, visFeil, knapp, kr, tilOre, dato, iDag, tomTilstand,
  verktoylinje, fanerad, db
} from "../../app/lib.js";
import { S, kanOkonomi, velgFra, settInn, paaNytt } from "../../app/store.js";
import { MALER, lagVisning, tegnFaktura } from "../../app/faktura-maler.js";

const STATUS = {
  kladd:     ["Kladd", "neutral"],
  utstedt:   ["Sendt", "blue"],
  betalt:    ["Betalt", "green"],
  kreditert: ["Kreditert", "red"]
};

const TYPER = [
  { verdi: "faktura", tekst: "Faktura" },
  { verdi: "proforma", tekst: "Proforma faktura" }
];

const VALUTAER = ["USD", "EUR", "GBP", "NOK", "PKR", "SEK", "DKK"]
  .map(v => ({ verdi: v, tekst: v }));

const MVASATSER = [0, 25, 15, 12, 6].map(s => ({ verdi: String(s), tekst: s + " %" }));

/* Leverandøren blir avsender på dokumentet. */
function avsenderFra(v) {
  return {
    navn: v.navn || "",
    adresse: [v.adresse, v.land].filter(Boolean).join("\n"),
    epost: v.epost || "",
    telefon: v.telefon || "",
    orgnr: v.skattenr || "",
    mva: v.skattenr || "",
    farge: v.aksentfarge || "#087F7A",
    logo: v.logo || "",
    bank: v.bank || "",
    kontonummer: v.kontonummer || "",
    iban: v.iban || "",
    swift: v.swift || "",
    betalingsnotat: v.betalingsnotat || "",
    vilkar: v.vilkar || "",
    fotnote: v.fotnote || "",
    eksport: {
      rex: v.rex_nr || "",
      ntn: v.skattenr || "",
      hs: v.hs_kode || "",
      origin: v.opprinnelsesland || "",
      terms: v.leveringsvilkar || ""
    }
  };
}

function trygtLagret(nokkel, verdi) {
  try {
    if (verdi === undefined) return localStorage.getItem(nokkel);
    localStorage.setItem(nokkel, verdi);
  } catch (e) { /* privat vindu eller blokkert lagring — vi klarer oss uten */ }
  return null;
}

/* =====================================================================
   Lista
   ===================================================================== */

let filter = "alle";
let sok = "";
let valgtId = null;

export function apneFaktura(id) {
  valgtId = id;
  location.hash = "#/rediger";
}

export const fakturaerView = {
  tittel: "Fakturaer",
  undertekst: "Regning på vegne av leverandørene. Velg leverandør, fyll linjene, utsted.",
  async bygg() { return byggListe(); }
};

async function byggListe() {
  const [{ data: fakturaer, error }, { data: leverandorer }] = await Promise.all([
    db.from("vendor_invoices")
      .select("*, leverandor:vendor_id(*), kunde:customer_id(*)")
      .eq("organization_id", S.orgId)
      .order("opprettet", { ascending: false })
      .limit(300),
    velgFra("vendors", "*").eq("aktiv", true).order("navn")
  ]);
  if (error) throw error;

  const boks = el("div", { class: "stack" });
  const skriv = kanOkonomi();

  if (!leverandorer.length) {
    boks.append(kort({
      innhold: tomTilstand({
        tittel: "Legg inn den første leverandøren",
        tekst: "Fakturaen sendes i leverandørens navn, så systemet må vite hvem det er før noe kan lages. Navn og adresse holder for å komme i gang.",
        ikon: "bygg",
        handlinger: skriv ? [knapp("Ny leverandør", {
          klasse: "primary", ikon: "pluss",
          ved: () => { location.hash = "#/leverandorer"; }
        })] : []
      })
    }));
    return boks;
  }

  const ute = fakturaer.filter(f => f.status === "utstedt");
  const iAar = fakturaer.filter(f =>
    f.status !== "kladd" && f.fakturadato &&
    f.fakturadato.slice(0, 4) === String(new Date().getFullYear()));
  const kladder = fakturaer.filter(f => f.status === "kladd");

  boks.append(el("div", { class: "grid g4" }, [
    kpi({ nokkel: "Leverandører", verdi: String(leverandorer.length), ikon: "bygg",
          under: "aktive i registeret" }),
    kpi({ nokkel: "Sendt i år", verdi: String(iAar.length), ikon: "kvittering",
          under: "utstedte dokumenter" }),
    kpi({ nokkel: "Utestående", verdi: String(ute.length), ikon: "okonomi",
          under: ute.length ? "venter på betaling" : "ingenting utestående" }),
    kpi({ nokkel: "Kladder", verdi: String(kladder.length), ikon: "dokument",
          under: kladder.length ? "ikke utstedt ennå" : "ingen påbegynte" })
  ]));

  boks.append(fanerad([
    { id: "alle", tekst: "Alle" }, { id: "kladd", tekst: "Kladder" },
    { id: "utstedt", tekst: "Sendt" }, { id: "betalt", tekst: "Betalt" }
  ], filter, id => { filter = id; paaNytt(); }));

  boks.append(verktoylinje({
    sok: { plassholder: "Søk på nummer, leverandør eller kunde …", verdi: sok,
           ved: v => { sok = v; tegnTabell(); } },
    handling: skriv ? knapp("Ny faktura", {
      klasse: "primary", ikon: "pluss", ved: () => nyFaktura(leverandorer)
    }) : null
  }));

  const tabellboks = el("div", {});
  boks.append(kort({ innhold: tabellboks }));

  function synlige() {
    const s = sok.toLowerCase();
    return fakturaer.filter(f => {
      if (filter !== "alle" && f.status !== filter) return false;
      if (!s) return true;
      return (f.nummer || "").toLowerCase().includes(s)
          || (f.leverandor?.navn || "").toLowerCase().includes(s)
          || (f.kunde?.navn || "").toLowerCase().includes(s);
    });
  }

  function tegnTabell() {
    const rader = synlige().map(f => {
      const [tekst, farge] = STATUS[f.status] || ["—", "neutral"];
      return el("tr", { class: "klikk", onclick: () => apneFaktura(f.id) }, [
        el("td", {}, f.nummer || el("span", { class: "sub" }, "kladd")),
        el("td", {}, el("b", {}, f.leverandor?.navn || "—")),
        el("td", {}, f.kunde?.navn || el("span", { class: "sub" }, "ingen kunde")),
        el("td", {}, f.fakturadato ? dato(f.fakturadato) : "—"),
        el("td", { class: "num" }, kr(f.brutto_ore) + " " + f.valuta),
        el("td", {}, merke(f.type === "proforma" ? "Proforma" : tekst,
                           f.type === "proforma" ? "gold" : farge)),
        el("td", {}, skriv ? knapp("Lag lik", {
          klasse: "sm", tittel: "Ny kladd med samme leverandør, kunde og linjer",
          ved: (e) => { e.stopPropagation(); lagLik(f); }
        }) : null)
      ]);
    });
    tabellboks.replaceChildren(tabell(
      [{ t: "Nummer" }, { t: "Leverandør" }, { t: "Kunde" }, { t: "Dato" },
       { t: "Beløp", num: true }, { t: "Status" }, { t: "" }],
      rader, "Ingen fakturaer i dette utvalget."
    ));
  }
  tegnTabell();

  return boks;
}

async function nyFaktura(leverandorer) {
  const sisteId = trygtLagret("fg.sisteLeverandor");
  const lev = leverandorer.find(l => l.id === sisteId) || leverandorer[0];
  try {
    const { data, error } = await settInn("vendor_invoices", {
      vendor_id: lev.id,
      type: "faktura",
      fakturadato: iDag(),
      valuta: lev.valuta || "USD",
      mal: lev.mal || 4,
      sprak: lev.sprak || "en",
      leveringsvilkar: lev.leveringsvilkar || null,
      opprettet_av: S.bruker.id
    }).select("id").single();
    if (error) throw error;
    apneFaktura(data.id);
  } catch (e) { visFeil(e, "Opprettelsen"); }
}

async function lagLik(faktura) {
  try {
    const { data, error } = await db.rpc("kopier_leverandorfaktura", { p_faktura: faktura.id });
    if (error) throw error;
    toast("Kopiert", "Ny kladd med samme linjer og dagens dato.");
    apneFaktura(data);
  } catch (e) { visFeil(e, "Kopieringen"); }
}

/* =====================================================================
   Redigeringssiden
   ===================================================================== */

export const redigerView = {
  tittel: "Faktura",
  undertekst: "Fyll ut, se hvordan den blir, og utsted.",
  skjult: true,
  async bygg() { return byggRediger(); }
};

async function byggRediger() {
  if (!valgtId) {
    return tomTilstand({
      tittel: "Ingen faktura valgt",
      tekst: "Gå tilbake til lista og velg en faktura, eller lag en ny.",
      ikon: "kvittering",
      handlinger: [knapp("Til fakturaene", { klasse: "primary", ved: () => { location.hash = "#/fakturaer"; } })]
    });
  }

  const [{ data: faktura, error }, { data: leverandorer }] = await Promise.all([
    db.from("vendor_invoices").select("*").eq("id", valgtId).single(),
    velgFra("vendors", "*").eq("aktiv", true).order("navn")
  ]);
  if (error) throw error;

  const [{ data: linjer }, { data: kunder }, { data: betalingerData }] = await Promise.all([
    db.from("vendor_invoice_lines").select("*").eq("invoice_id", faktura.id).order("rekkefolge"),
    db.from("vendor_customers").select("*").eq("vendor_id", faktura.vendor_id).eq("aktiv", true).order("navn"),
    db.from("vendor_invoice_payments").select("*").eq("invoice_id", faktura.id).order("dato")
  ]);
  const betalinger = betalingerData || [];

  const erKladd = faktura.status === "kladd";
  const skriv = kanOkonomi() && erKladd;

  let lev = leverandorer.find(l => l.id === faktura.vendor_id) || {};
  let kundeliste = kunder || [];
  let kunde = kundeliste.find(k => k.id === faktura.customer_id) || null;
  let mal = faktura.mal || lev.mal || 4;
  let arbeid = (linjer || []).map(l => ({ ...l }));
  if (!arbeid.length && erKladd) arbeid.push(tomLinje(0));

  trygtLagret("fg.sisteLeverandor", faktura.vendor_id);

  function tomLinje(n) {
    return { beskrivelse: "", antall: 1, enhet: "", pris_ore: 0, mva_sats: 0, rekkefolge: n };
  }

  const side = el("div", { class: "stack" });

  /* ---------- topplinje ---------- */
  const [statustekst, statusfarge] = STATUS[faktura.status] || ["—", "neutral"];
  const handlinger = el("div", { class: "actions" });

  side.append(el("div", { class: "tabellverktoy" }, [
    knapp("Tilbake", { ikon: "pil", ved: () => { location.hash = "#/fakturaer"; } }),
    el("div", {}, [
      el("b", {}, faktura.nummer || "Ny faktura"),
      el("span", { class: "sub" }, " · " + (lev.navn || "")),
      " ",
      merke(faktura.type === "proforma" ? "Proforma" : statustekst,
            faktura.type === "proforma" ? "gold" : statusfarge)
    ]),
    handlinger
  ]));

  /* ---------- varsel ---------- */
  const varsel = el("div", {});
  side.append(varsel);
  function tegnVarsel() {
    varsel.replaceChildren();
    if (!erKladd || !faktura.fakturadato || faktura.historisk) return;
    const dager = Math.round((Date.now() - new Date(faktura.fakturadato)) / 864e5);
    if (dager < 45) return;
    varsel.append(el("div", { class: "note warn" }, [
      el("span", { html: svg("varsel") }),
      el("div", {}, [
        el("b", {}, "Fakturadatoen ligger " + dager + " dager tilbake. "),
        "Leverandørens nummerserie må stige i takt med datoen, så utstedelse blir avvist hvis det finnes en nyere faktura fra før."
      ])
    ]));
  }

  /* ---------- to kolonner ---------- */
  const venstre = el("div", { class: "stack" });
  const hoyre = el("div", { class: "stack" });
  side.append(el("div", { class: "grid g2" }, [venstre, hoyre]));

  /* ---------- hvem til hvem ---------- */
  const toppboks = el("div", {});
  venstre.append(kort({ tittel: "Hvem sender til hvem", innhold: toppboks }));

  function merkeFelt(label, input, hint) {
    return el("div", { class: "field" }, [
      el("label", {}, label), input, hint && el("span", { class: "hint" }, hint)
    ]);
  }

  function tegnTopp() {
    const levValg = velg("lev", leverandorer.map(l => ({ verdi: l.id, tekst: l.navn })), faktura.vendor_id);
    levValg.disabled = !skriv;
    levValg.addEventListener("change", async () => {
      const ny = leverandorer.find(l => l.id === levValg.value);
      await lagre({
        vendor_id: ny.id, customer_id: null, valuta: ny.valuta,
        mal: ny.mal, sprak: ny.sprak, leveringsvilkar: ny.leveringsvilkar
      });
      Object.assign(faktura, { vendor_id: ny.id, customer_id: null, valuta: ny.valuta, sprak: ny.sprak });
      lev = ny; mal = ny.mal || 4; kunde = null;
      const { data } = await db.from("vendor_customers").select("*")
        .eq("vendor_id", ny.id).eq("aktiv", true).order("navn");
      kundeliste = data || [];
      trygtLagret("fg.sisteLeverandor", ny.id);
      tegnTopp(); tegnLinjer(); tegnForhaandsvisning();
    });

    const kundeValg = velg("kunde",
      [{ verdi: "", tekst: kundeliste.length ? "— velg kunde —" : "— ingen kunder ennå —" }]
        .concat(kundeliste.map(k => ({ verdi: k.id, tekst: k.navn }))),
      faktura.customer_id || "");
    kundeValg.disabled = !skriv;
    kundeValg.addEventListener("change", async () => {
      kunde = kundeliste.find(k => k.id === kundeValg.value) || null;
      faktura.customer_id = kunde?.id || null;
      await lagre({ customer_id: faktura.customer_id });
      tegnForhaandsvisning();
    });

    const datoFelt = el("input", { type: "date", value: faktura.fakturadato || iDag() });
    datoFelt.disabled = !skriv;
    datoFelt.addEventListener("change", async () => {
      faktura.fakturadato = datoFelt.value;
      await lagre({ fakturadato: datoFelt.value });
      tegnForhaandsvisning(); tegnVarsel();
    });

    const typeValg = velg("type", TYPER, faktura.type);
    typeValg.disabled = !skriv;
    typeValg.addEventListener("change", async () => {
      faktura.type = typeValg.value;
      await lagre({ type: typeValg.value });
      tegnForhaandsvisning();
    });

    const valutaValg = velg("valuta", VALUTAER, faktura.valuta);
    valutaValg.disabled = !skriv;
    valutaValg.addEventListener("change", async () => {
      faktura.valuta = valutaValg.value;
      await lagre({ valuta: valutaValg.value });
      tegnLinjer(); tegnForhaandsvisning();
    });

    const refFelt = tekstfelt("ref", faktura.deres_ref || "", { placeholder: "Bestilling, kontrakt, merking" });
    refFelt.disabled = !skriv;
    refFelt.addEventListener("change", async () => {
      faktura.deres_ref = refFelt.value;
      await lagre({ deres_ref: refFelt.value });
      tegnForhaandsvisning();
    });

    const batchFelt = tekstfelt("batch", faktura.batch_nr || "", { placeholder: "F.eks. produksjonens lot-nummer" });
    batchFelt.disabled = !skriv;
    batchFelt.addEventListener("change", async () => {
      faktura.batch_nr = batchFelt.value;
      await lagre({ batch_nr: batchFelt.value });
      tegnForhaandsvisning();
    });

    const kolleksjonFelt = tekstfelt("kolleksjon", faktura.kolleksjon || "", { placeholder: "F.eks. Uniform, SS26" });
    kolleksjonFelt.disabled = !skriv;
    kolleksjonFelt.addEventListener("change", async () => {
      faktura.kolleksjon = kolleksjonFelt.value;
      await lagre({ kolleksjon: kolleksjonFelt.value });
      tegnForhaandsvisning();
    });

    const leveringFelt = el("input", { type: "date", value: faktura.levering_til || "" });
    leveringFelt.disabled = !skriv;
    leveringFelt.addEventListener("change", async () => {
      faktura.levering_til = leveringFelt.value || null;
      await lagre({ levering_til: leveringFelt.value || null });
      tegnForhaandsvisning();
    });

    const kundeboks = el("div", {}, [
      merkeFelt("Kunde — mottaker", kundeValg),
      skriv ? el("div", { class: "actions" },
        knapp("Ny kunde", { klasse: "sm", ikon: "pluss", ved: () => nyKunde() })) : null
    ]);

    toppboks.replaceChildren(
      el("div", { class: "grid g2" }, [
        merkeFelt("Leverandør — avsender", levValg, lev.navn ? (lev.land || "") : null),
        kundeboks
      ]),
      el("div", { class: "grid g2" }, [
        merkeFelt("Fakturadato", datoFelt),
        merkeFelt("Type", typeValg)
      ]),
      el("div", { class: "grid g2" }, [
        merkeFelt("Valuta", valutaValg),
        merkeFelt("Referanse", refFelt)
      ]),
      el("div", { class: "grid g2" }, [
        merkeFelt("Batch / lot-nummer", batchFelt, "Vises på eksport- og produksjonsmalen"),
        merkeFelt("Kolleksjon", kolleksjonFelt)
      ]),
      el("div", { class: "grid g2" }, [
        merkeFelt("Leveringsdato", leveringFelt),
        null
      ])
    );
  }

  async function nyKunde() {
    const svar = await skjemaModal({
      tittel: "Ny kunde for " + (lev.navn || "leverandøren"),
      beskrivelse: "Dette er leverandørens kunde — den som mottar og betaler fakturaen.",
      felter: [
        { navn: "navn", label: "Navn", bredde: "full" },
        { navn: "att", label: "Att.", plassholder: "v/ Kari Nordmann" },
        { navn: "orgnr", label: "Org.nr" },
        { navn: "adresse", label: "Adresse", type: "textarea", bredde: "full",
          hint: "Én linje per rad, slik den skal stå på fakturaen." },
        { navn: "land", label: "Land" },
        { navn: "epost", label: "E-post" }
      ],
      lagreTekst: "Lagre kunde",
      onLagre: async (d) => {
        if (!d.navn) { toast("Mangler navn", "Kunden må ha et navn.", true); return false; }
        const { data, error } = await db.from("vendor_customers").insert({
          vendor_id: faktura.vendor_id, navn: d.navn, att: d.att || null,
          orgnr: d.orgnr || null, adresse: d.adresse || null,
          land: d.land || null, epost: d.epost || null
        }).select("*").single();
        if (error) throw error;
        kundeliste = kundeliste.concat([data]).sort((a, b) => a.navn.localeCompare(b.navn, "nb"));
        kunde = data;
        faktura.customer_id = data.id;
        await lagre({ customer_id: data.id });
      }
    });
    if (svar) { tegnTopp(); tegnForhaandsvisning(); toast("Lagret", "Kunden er valgt på fakturaen."); }
  }

  /* ---------- linjer ---------- */
  const linjeboks = el("div", {});
  const lagrestatus = el("div", { class: "hint" }, "");
  venstre.append(kort({
    tittel: "Hva selges",
    beskrivelse: erKladd ? "Priser uten avgift. Lagres mens du skriver." : "Fakturaen er utstedt, og linjene er låst.",
    innhold: linjeboks
  }));

  /* ---------- betalinger ---------- */
  if (faktura.status === "utstedt" || faktura.status === "betalt") {
    const betalingsboks = el("div", {});
    venstre.append(kort({
      tittel: "Betalinger",
      beskrivelse: "Delbetalinger og forskudd registreres her. Fakturaen markeres betalt automatisk når summen når totalen.",
      innhold: betalingsboks
    }));

    function resterende() {
      const total = faktura.brutto_ore || 0;
      const sum = betalinger.reduce((s, b) => s + b.belop_ore, 0);
      return Math.max(0, total - sum);
    }

    function tegnBetalinger() {
      const rader = betalinger.map(b => el("tr", {}, [
        el("td", {}, dato(b.dato)),
        el("td", { class: "num" }, kr(b.belop_ore) + " " + faktura.valuta),
        el("td", {}, b.notat || el("span", { class: "sub" }, "—")),
        el("td", { class: "num" }, !kanOkonomi() ? "" : el("button", {
          class: "ikonknapp", title: "Angre registreringen",
          html: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
          onclick: async () => {
            const ok = await bekreft("Angre denne betalingen?",
              "Beløpet trekkes fra det betalte totalt igjen. Fakturaen kan gå tilbake til status Sendt.", "Ja, angre");
            if (!ok) return;
            try {
              const { error } = await db.from("vendor_invoice_payments").delete().eq("id", b.id);
              if (error) throw error;
              toast("Angret", "Betalingen er fjernet.");
              paaNytt();
            } catch (e) { visFeil(e, "Angringen"); }
          }
        }))
      ]));

      betalingsboks.replaceChildren(
        tabell([{ t: "Dato" }, { t: "Beløp", num: true }, { t: "Notat" }, { t: "" }], rader, "Ingen betalinger registrert."),
        kanOkonomi() ? el("div", { class: "actions" }, [
          knapp("Registrer betaling", { ikon: "pluss", ved: registrerBetaling })
        ]) : null,
        el("dl", { class: "kv" }, [
          el("dt", {}, "Betalt"), el("dd", {}, kr(faktura.betalt_ore || 0) + " " + faktura.valuta),
          el("dt", {}, "Resterende"), el("dd", {}, kr(resterende()) + " " + faktura.valuta)
        ])
      );
    }

    async function registrerBetaling() {
      const svar = await skjemaModal({
        tittel: "Registrer betaling",
        beskrivelse: "Legg inn beløpet som er mottatt. Et delbeløp er greit — resten står som resterende til flere betalinger er registrert.",
        felter: [
          { navn: "belop", label: "Beløp (" + faktura.valuta + ")", plassholder: kr(resterende()) },
          { navn: "dato", label: "Dato", type: "date", verdi: iDag() },
          { navn: "notat", label: "Notat", bredde: "full", plassholder: "Forskudd, delbetaling …" }
        ],
        lagreTekst: "Registrer",
        onLagre: async (d) => {
          const belop_ore = tilOre(d.belop);
          if (!belop_ore || belop_ore <= 0) { toast("Mangler beløp", "Skriv inn et beløp større enn null.", true); return false; }
          const { error } = await db.from("vendor_invoice_payments")
            .insert({ invoice_id: faktura.id, belop_ore, dato: d.dato || iDag(), notat: d.notat || null });
          if (error) throw error;
        }
      });
      if (svar) { toast("Registrert", "Betalingen er lagt inn."); paaNytt(); }
    }

    tegnBetalinger();
  }

  function summer() {
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
      besk.addEventListener("input", () => { l.beskrivelse = besk.value; endret(); });

      const ant = el("input", { type: "text", value: String(l.antall), inputmode: "decimal" });
      ant.addEventListener("input", () => { l.antall = Number(ant.value.replace(",", ".")) || 0; endret(); });

      const enh = tekstfelt("e" + i, l.enhet || "", { placeholder: "stk" });
      enh.addEventListener("input", () => { l.enhet = enh.value; endret(); });

      const pris = el("input", { type: "text", value: l.pris_ore ? kr(l.pris_ore) : "", inputmode: "decimal" });
      pris.addEventListener("input", () => { l.pris_ore = tilOre(pris.value); endret(); });

      const mvaValg = velg("m" + i, MVASATSER, String(l.mva_sats));
      mvaValg.addEventListener("change", () => { l.mva_sats = Number(mvaValg.value); endret(); });

      [besk, ant, enh, pris, mvaValg].forEach(x => { x.style.width = "100%"; });
      ant.style.textAlign = "right"; pris.style.textAlign = "right";

      return el("tr", {}, [
        el("td", { style: "width:34%" }, besk),
        el("td", { style: "width:12%" }, ant),
        el("td", { style: "width:13%" }, enh),
        el("td", { style: "width:22%" }, pris),
        el("td", { style: "width:12%" }, mvaValg),
        el("td", { style: "width:6%" }, el("button", {
          class: "ikonknapp", title: "Fjern linjen",
          html: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
          onclick: () => {
            arbeid.splice(i, 1);
            if (!arbeid.length) arbeid.push(tomLinje(0));
            endret();
          }
        }))
      ]);
    });

    const kolonner = skriv
      ? [{ t: "Beskrivelse" }, { t: "Antall" }, { t: "Enhet" }, { t: "Pris" }, { t: "Avgift" }, { t: "" }]
      : [{ t: "Beskrivelse" }, { t: "Antall", num: true }, { t: "Pris", num: true },
         { t: "Avgift", num: true }, { t: "Beløp", num: true }];

    const s = summer();
    linjeboks.replaceChildren(...[
      tabell(kolonner, rader, "Ingen linjer ennå."),
      skriv ? el("div", { class: "actions" }, [
        knapp("Legg til linje", { ikon: "pluss", ved: () => { arbeid.push(tomLinje(arbeid.length)); endret(); } })
      ]) : null,
      el("dl", { class: "kv" }, [
        el("dt", {}, "Sum"),      el("dd", {}, kr(s.netto) + " " + faktura.valuta),
        el("dt", {}, "Avgift"),   el("dd", {}, kr(s.mva) + " " + faktura.valuta),
        el("dt", {}, "Å betale"), el("dd", {}, kr(s.brutto) + " " + faktura.valuta)
      ]),
      lagrestatus
    ].filter(Boolean));
  }

  /* ---------- lagring ---------- */
  let timer = null, lagrer = false;

  function endret() {
    tegnLinjer();
    tegnForhaandsvisning();
    lagrestatus.textContent = "Lagrer …";
    clearTimeout(timer);
    timer = setTimeout(lagreLinjer, 900);
  }

  async function lagre(felter) {
    try {
      const { error } = await db.from("vendor_invoices").update(felter).eq("id", faktura.id);
      if (error) throw error;
    } catch (e) { visFeil(e, "Lagring"); }
  }

  async function lagreLinjer() {
    if (!skriv || lagrer) return;
    lagrer = true;
    const gyldige = arbeid.filter(l => (l.beskrivelse || "").trim() !== "");
    try {
      const { error: slettFeil } = await db.from("vendor_invoice_lines")
        .delete().eq("invoice_id", faktura.id);
      if (slettFeil) throw slettFeil;
      if (gyldige.length) {
        const { error } = await db.from("vendor_invoice_lines").insert(gyldige.map((l, i) => ({
          invoice_id: faktura.id, rekkefolge: i,
          beskrivelse: l.beskrivelse, antall: Number(l.antall) || 0,
          enhet: l.enhet || null, pris_ore: l.pris_ore || 0, mva_sats: l.mva_sats || 0,
          hs_kode: l.hs_kode || null, vekt_kg: l.vekt_kg || null
        })));
        if (error) throw error;
      }
      lagrestatus.textContent = "Lagret";
    } catch (e) {
      lagrestatus.textContent = "";
      visFeil(e, "Lagring av linjer");
    } finally { lagrer = false; }
  }

  async function lagreNaa() { clearTimeout(timer); await lagreLinjer(); }

  /* ---------- forhåndsvisning ---------- */
  const malrad = el("div", { class: "malvelger" }, MALER.map(m =>
    el("button", {
      class: "malflis", "aria-pressed": m.id === mal ? "true" : "false", title: m.description,
      onclick: async () => {
        mal = m.id;
        malrad.querySelectorAll(".malflis").forEach((b, i) =>
          b.setAttribute("aria-pressed", MALER[i].id === mal ? "true" : "false"));
        tegnForhaandsvisning();
        if (kanOkonomi()) await lagre({ mal });
      }
    }, [el("span", { class: "nr" }, String(m.id).padStart(2, "0")), m.name])));

  const flate = el("div", { class: "fakturaflate" });
  hoyre.append(kort({
    tittel: "Slik ser den ut",
    beskrivelse: "Malen lagres på fakturaen, så dokumentet gjengis likt om fem år.",
    innhold: [malrad, flate]
  }));

  function visning() {
    return lagVisning({
      faktura: { ...faktura, mal },
      linjer: arbeid,
      kunde,
      org: S.org,
      avsender: avsenderFra(lev)
    });
  }

  function tegnForhaandsvisning() {
    // Malmotoren escaper hver verdi med esc() før den settes inn, og flaten
    // er en ren visningsflate uten skjema. Samme unntak som html:-ikoner.
    flate.innerHTML = tegnFaktura(visning(), mal);
    const ark = flate.querySelector(".inv");
    if (ark) {
      const skala = Math.min(1, (flate.clientWidth - 32) / ark.offsetWidth);
      ark.style.transform = "scale(" + skala.toFixed(3) + ")";
      flate.style.height = (ark.offsetHeight * skala + 32) + "px";
    }
  }

  /* ---------- handlinger ---------- */
  function skrivUt() {
    let ut = document.getElementById("fakturautskrift");
    if (!ut) { ut = el("div", { id: "fakturautskrift" }); document.body.append(ut); }
    ut.innerHTML = '<div class="side">' + tegnFaktura(visning(), mal) + "</div>";
    window.print();
  }

  handlinger.append(knapp("Skriv ut", { ikon: "dokument", ved: async () => { await lagreNaa(); skrivUt(); } }));

  if (kanOkonomi() && erKladd) {
    handlinger.append(knapp("Utsted", { klasse: "primary", ikon: "ok", ved: async () => {
      await lagreNaa();
      if (!faktura.customer_id) { toast("Mangler kunde", "Velg hvem fakturaen skal til.", true); return; }
      if (!arbeid.some(l => (l.beskrivelse || "").trim())) {
        toast("Ingen linjer", "Fyll inn minst én linje.", true); return;
      }
      const ok = await bekreft("Utsted fakturaen?",
        faktura.type === "proforma"
          ? "Proforma får sitt eget nummer og spiser ikke av den ordinære serien. Den kan ikke endres etterpå."
          : "Fakturaen får neste nummer i leverandørens serie og kan ikke endres etterpå. Feil rettes med kreditnota.",
        "Ja, utsted");
      if (!ok) return;
      try {
        const { data, error } = await db.rpc("utsted_leverandorfaktura", {
          p_faktura: faktura.id, p_dato: faktura.fakturadato || iDag()
        });
        if (error) throw error;
        toast("Utstedt", "Nummer " + data + ".");
        paaNytt();
      } catch (e) { visFeil(e, "Utstedelsen"); }
    } }));
  }

  if (kanOkonomi() && faktura.status === "utstedt" && faktura.type !== "proforma") {
    handlinger.append(knapp("Kreditnota", { ikon: "kvittering", ved: async () => {
      const svar = await skjemaModal({
        tittel: "Lag kreditnota",
        beskrivelse: "Kreditnotaen speiler linjene med motsatt fortegn. Den opprinnelige fakturaen blir stående.",
        felter: [{ navn: "arsak", label: "Årsak", bredde: "full",
                   plassholder: "Feil beløp, kansellert leveranse …" }],
        lagreTekst: "Lag kreditnota"
      });
      if (!svar) return;
      try {
        const { data, error } = await db.rpc("lag_leverandor_kreditnota",
          { p_faktura: faktura.id, p_arsak: svar.arsak || "" });
        if (error) throw error;
        toast("Opprettet", "Kreditnotaen ligger som kladd.");
        apneFaktura(data);
      } catch (e) { visFeil(e, "Kreditnotaen"); }
    } }));
  }

  if (kanOkonomi() && faktura.status === "utstedt") {
    handlinger.append(knapp("Lås opp", { ikon: "pluss", ved: async () => {
      const ok = await bekreft("Låse opp fakturaen for redigering?",
        "Den går tilbake til kladd. Nummeret nullstilles — blir den utstedt igjen, får den et nytt.",
        "Ja, lås opp");
      if (!ok) return;
      try {
        const { error } = await db.rpc("las_opp_leverandorfaktura", { p_faktura: faktura.id });
        if (error) throw error;
        toast("Låst opp", "Fakturaen er en kladd igjen.");
        paaNytt();
      } catch (e) { visFeil(e, "Opplåsingen"); }
    } }));
  }

  if (kanOkonomi() && !erKladd) {
    handlinger.append(knapp("Lag lik", { ikon: "pluss", ved: () => lagLik(faktura) }));
  }

  tegnTopp();
  tegnVarsel();
  tegnLinjer();
  setTimeout(tegnForhaandsvisning, 0);

  return side;
}
