// =====================================================================
//  Attestering — to personer må godkjenne en regning før den betales.
//  Hvem de to er, settes under Innstillinger → Selskapsinformasjon.
// =====================================================================

import {
  el, svg, kort, kpi, merke, tabell, felt, skjemaModal, bekreft, toast, visFeil,
  knapp, kr, kr0, tilOre, dato, tidspunkt, iDag, tomTilstand, skuff, nedtrekk,
  eksporterExcel, db
} from "../lib.js";
import { S, kanOkonomi, erAdmin, velgFra, settInn, paaNytt } from "../store.js";

const STATUS = {
  mottatt: ["Venter på godkjenning", "gold"],
  delvis_godkjent: ["Én godkjenning", "blue"],
  godkjent: ["Klar for betaling", "teal"],
  betalt: ["Betalt", "green"],
  avvist: ["Avvist", "red"]
};

const navnPaa = (p) => p ? (((p.fornavn || "") + " " + (p.etternavn || "")).trim() || p.epost) : "—";

/* --- brukes av forsiden --- */
export async function hentAttesteringTall() {
  const { data, error } = await velgFra("supplier_invoices", "status");
  if (error) throw error;
  return {
    tilAttestering: data.filter(f => f.status === "mottatt" || f.status === "delvis_godkjent").length,
    klarForBetaling: data.filter(f => f.status === "godkjent").length
  };
}

export const attesteringView = {
  tittel: "Attestering",
  undertekst: "Regninger klubben har mottatt. To personer godkjenner før pengene går ut.",
  async bygg() { return bygg(); }
};

let filter = "aapne";

async function bygg() {
  const [{ data: fakturaer, error }, { data: kategorier }, { data: prosjekter }, { data: attestanter }] = await Promise.all([
    db.from("supplier_invoices")
      .select("*, a1:attest1_av(fornavn,etternavn,epost), a2:attest2_av(fornavn,etternavn,epost)")
      .eq("organization_id", S.orgId).order("forfall", { ascending: true }),
    velgFra("categories", "id,navn,retning").eq("retning", "utgift"),
    velgFra("projects", "id,navn"),
    db.from("organization_users").select("user_id, profiles(fornavn,etternavn,epost)")
      .eq("organization_id", S.orgId).eq("aktiv", true)
  ]);
  if (error) throw error;

  const boks = el("div", { class: "stack" });
  const o = S.org;
  const jeg = S.bruker.id;
  const erAttestant = jeg === o.attestant1 || jeg === o.attestant2;
  const kanGodkjenne = erAttestant || erAdmin();

  /* --- er attestering satt opp? --- */
  if (!o.attestant1 || !o.attestant2) {
    boks.append(el("div", { class: "note warn" }, [
      el("span", { html: svg("varsel") }),
      el("div", {}, [
        el("b", {}, "Attestering er ikke satt opp ennå. "),
        "Velg hvilke to personer som skal godkjenne regninger under Innstillinger → Selskapsinformasjon."
      ])
    ]));
  }

  /* --- nøkkeltall --- */
  const aapne = fakturaer.filter(f => ["mottatt", "delvis_godkjent"].includes(f.status));
  const klare = fakturaer.filter(f => f.status === "godkjent");
  const forfalt = fakturaer.filter(f => f.status !== "betalt" && f.status !== "avvist" && f.forfall < iDag());
  const sum = a => a.reduce((s, x) => s + x.belop_ore, 0);

  boks.append(el("div", { class: "grid g4" }, [
    kpi({ nokkel: "Venter på godkjenning", ikon: "ok", verdi: String(aapne.length), under: kr0(sum(aapne)) + " kr" }),
    kpi({ nokkel: "Klar for betaling", ikon: "betaling", verdi: String(klare.length), under: kr0(sum(klare)) + " kr" }),
    kpi({ nokkel: "Forfalt", ikon: "varsel", verdi: String(forfalt.length), farge: forfalt.length ? "neg" : null, under: forfalt.length ? kr0(sum(forfalt)) + " kr" : "Ingenting på overtid" }),
    kpi({ nokkel: "Ubetalt totalt", ikon: "okonomi", verdi: kr0(sum(fakturaer.filter(f => !["betalt", "avvist"].includes(f.status)))), under: "kroner" })
  ]));

  /* --- hvem godkjenner --- */
  if (o.attestant1 && o.attestant2) {
    const finn = id => attestanter?.find(a => a.user_id === id)?.profiles;
    boks.append(kort({
      tittel: "Hvem godkjenner",
      innhold: el("div", { class: "rowline", style: "gap:22px" }, [
        el("div", {}, [el("div", { class: "meta" }, "Attestant 1"), el("b", {}, navnPaa(finn(o.attestant1)))]),
        el("div", {}, [el("div", { class: "meta" }, "Attestant 2"), el("b", {}, navnPaa(finn(o.attestant2)))]),
        erAdmin() ? knapp("Endre", { klasse: "stille sm", ved: () => (location.hash = "#/selskap") }) : null
      ])
    }));
  }

  /* --- filter --- */
  const lag = (id, tekst) => el("button", {
    class: "btn sm" + (filter === id ? " primary" : ""), onclick: () => { filter = id; paaNytt(); }
  }, tekst);

  const synlige = fakturaer.filter(f =>
    filter === "alle" ? true :
      filter === "klare" ? f.status === "godkjent" :
        filter === "betalt" ? f.status === "betalt" :
          ["mottatt", "delvis_godkjent"].includes(f.status));

  boks.append(kort({
    tittel: "Regninger",
    hoyre: kanOkonomi() ? knapp("Ny regning", { klasse: "primary", ikon: "pluss", ved: () => nyRegning(kategorier, prosjekter) }) : null,
    innhold: el("div", {}, [
      el("div", { class: "tabellverktoy" }, [
        lag("aapne", "Venter på godkjenning"), lag("klare", "Klar for betaling"),
        lag("betalt", "Betalt"), lag("alle", "Alle"),
        el("div", { style: "flex:1" }),
        fakturaer.length ? knapp("Eksporter", { klasse: "stille sm", ikon: "last", ved: () => eksporter(fakturaer) }) : null
      ]),
      synlige.length ? tabell(
        [{ t: "Leverandør" }, { t: "Hva" }, { t: "Forfall" }, { t: "Beløp", num: true }, { t: "Godkjent av" }, { t: "Status" }, { t: "" }],
        synlige.map(f => rad(f, kanGodkjenne, kategorier, prosjekter))
      ) : tomTilstand({
        tittel: filter === "aapne" ? "Ingen regninger venter" : "Ingenting her",
        tekst: filter === "aapne"
          ? "Når klubben mottar en regning, legger kassereren den inn her. Da får de to attestantene den til godkjenning."
          : "Prøv et annet filter.",
        ikon: "ok",
        handlinger: kanOkonomi() && filter === "aapne"
          ? [knapp("Legg inn regning", { klasse: "primary", ikon: "pluss", ved: () => nyRegning(kategorier, prosjekter) })] : []
      })
    ])
  }));

  return boks;
}

function nesteHandling(f, kanGodkjenne) {
  const jeg = S.bruker.id;
  const alleredeMeg = f.attest1_av === jeg || f.attest2_av === jeg;
  const mangler = f.status === "mottatt" || f.status === "delvis_godkjent";
  // Administrator kan fullføre begge godkjenningene. Det står det ingenting om
  // her — knappen ser lik ut uansett hvem som trykker.
  if (kanGodkjenne && mangler && (!alleredeMeg || erAdmin())) return "godkjenn";
  if (f.status === "godkjent" && kanOkonomi()) return "betal";
  return null;
}

function rad(f, kanGodkjenne, kategorier, prosjekter) {
  const [tekst, farge] = STATUS[f.status] || [f.status, "neutral"];
  const forfalt = f.status !== "betalt" && f.status !== "avvist" && f.forfall < iDag();
  const godkjentAv = [f.a1 && navnPaa(f.a1), f.a2 && navnPaa(f.a2)].filter(Boolean);
  const handling = nesteHandling(f, kanGodkjenne);

  const meny = kanOkonomi() ? nedtrekk(
    el("button", { class: "mermeny", title: "Flere valg", onclick: e => e.stopPropagation() }, "\u22EF"),
    [
      { tekst: "Se detaljer", ikon: "info", ved: () => detaljer(f, kanGodkjenne, kategorier, prosjekter) },
      f.status !== "betalt" ? { tekst: "Endre regningen", ikon: "dokument", ved: () => nyRegning(kategorier, prosjekter, f) } : null,
      f.status !== "betalt" && f.status !== "avvist" ? { tekst: "Avvis regningen", ikon: "varsel", ved: () => avvis(f) } : null
    ].filter(Boolean)
  ) : null;

  return el("tr", {
    class: "klikk",
    onclick: () => detaljer(f, kanGodkjenne, kategorier, prosjekter)
  }, [
    el("td", { class: "strong" }, [f.leverandor, f.referanse && el("span", { class: "who" }, "Faktura " + f.referanse)]),
    el("td", {}, f.beskrivelse),
    el("td", { class: "mono" }, [
      dato(f.forfall),
      forfalt && el("span", { class: "who", style: "color:var(--red)" }, "forfalt")
    ]),
    el("td", { class: "num strong" }, kr(f.belop_ore)),
    el("td", { class: "tiny dim" }, godkjentAv.length ? godkjentAv.join(" + ") : "—"),
    el("td", {}, merke(tekst, farge)),
    el("td", { class: "num" }, el("div", { class: "actions", style: "justify-content:flex-end;flex-wrap:nowrap" }, [
      handling === "godkjenn" ? el("button", { class: "btn primary sm", onclick: e => { e.stopPropagation(); godkjenn(f); } }, "Godkjenn") : null,
      handling === "betal" ? el("button", { class: "btn primary sm", onclick: e => { e.stopPropagation(); betal(f); } }, "Registrer betaling") : null,
      meny
    ]))
  ]);
}

/* --- detaljer i sidepanel --- */

function detaljer(f, kanGodkjenne, kategorier, prosjekter) {
  const [tekst, farge] = STATUS[f.status] || [f.status, "neutral"];
  const handling = nesteHandling(f, kanGodkjenne);

  const steg = (nr, hvem, tid) => el("div", { class: "oppm-rad", style: "cursor:default" }, [
    el("span", { class: "merke " + (hvem ? "green" : "gold"), html: svg(hvem ? "ok" : "varsel") }),
    el("span", { class: "tekst" }, [
      el("b", {}, hvem ? "Godkjent av " + navnPaa(hvem) : "Godkjenning " + nr + " mangler"),
      el("span", {}, hvem ? tidspunkt(tid) : "Venter på en av de to attestantene")
    ])
  ]);

  const panel = skuff({
    tittel: f.leverandor,
    undertittel: f.beskrivelse,
    innhold: el("div", { class: "stack" }, [
      el("div", { class: "rowline" }, [merke(tekst, farge), f.referanse && merke("Faktura " + f.referanse, "neutral")]),
      el("dl", { class: "kv" }, [
        el("dt", {}, "Beløp"), el("dd", { style: "font-size:1.15rem" }, kr(f.belop_ore) + " kr"),
        el("dt", {}, "Herav mva"), el("dd", {}, f.mva_ore ? kr(f.mva_ore) + " kr" : "—"),
        el("dt", {}, "Mottatt"), el("dd", {}, dato(f.mottatt)),
        el("dt", {}, "Forfall"), el("dd", {}, dato(f.forfall)),
        el("dt", {}, "Kontonummer"), el("dd", {}, f.kontonummer || "—"),
        el("dt", {}, "KID eller melding"), el("dd", {}, f.kid || "—")
      ]),
      el("div", {}, [
        el("h3", { style: "margin-bottom:6px" }, "Godkjenning"),
        el("div", { class: "oppm" }, [steg(1, f.a1, f.attest1_tid), steg(2, f.a2, f.attest2_tid)])
      ]),
      f.status === "betalt" ? el("div", { class: "note ok" }, [
        el("span", { html: svg("ok") }),
        el("div", {}, "Regningen er bokført som utgift i regnskapet.")
      ]) : null,
      f.status === "avvist" ? el("div", { class: "note bad" }, [
        el("span", { html: svg("varsel") }),
        el("div", {}, [el("b", {}, "Avvist. "), f.avvist_arsak || ""])
      ]) : null
    ]),
    bunn: [
      kanOkonomi() && f.status !== "betalt"
        ? knapp("Endre", { klasse: "stille", ved: () => { panel.lukk(); nyRegning(kategorier, prosjekter, f); } }) : null,
      handling === "godkjenn" ? knapp("Godkjenn", { klasse: "primary", ved: () => { panel.lukk(); godkjenn(f); } }) : null,
      handling === "betal" ? knapp("Registrer betaling", { klasse: "primary", ved: () => { panel.lukk(); betal(f); } }) : null
    ].filter(Boolean)
  });
}

async function avvis(f) {
  const svar = await skjemaModal({
    tittel: "Avvise regningen?",
    beskrivelse: f.leverandor + " — " + kr(f.belop_ore) + " kr. Skriv hvorfor, så vet neste person hva som skjedde.",
    felter: [{ navn: "arsak", label: "Hvorfor avvises den?", type: "textarea", bredde: "full", plassholder: "Vi har ikke bestilt dette" }],
    lagreTekst: "Avvis",
    onLagre: async (d) => {
      const { error } = await db.from("supplier_invoices")
        .update({ status: "avvist", avvist_av: S.bruker.id, avvist_arsak: d.arsak || null }).eq("id", f.id);
      if (error) throw error;
      return true;
    }
  });
  if (svar) { toast("Avvist", "Regningen er markert som avvist."); paaNytt(); }
}

/* --- handlinger --- */

async function godkjenn(f) {
  const ok = await bekreft(
    "Godkjenne regningen?",
    `${f.leverandor} — ${kr(f.belop_ore)} kr, forfall ${dato(f.forfall)}. Du bekrefter at klubben faktisk har mottatt dette, og at beløpet stemmer.`,
    "Ja, godkjenn"
  );
  if (!ok) return;

  const jeg = S.bruker.id;
  const oppdatering = f.attest1_av
    ? { attest2_av: jeg, attest2_tid: new Date().toISOString() }
    : { attest1_av: jeg, attest1_tid: new Date().toISOString() };

  const { error } = await db.from("supplier_invoices").update(oppdatering).eq("id", f.id);
  if (error) return visFeil(error, "Godkjenning");

  toast("Godkjent", f.attest1_av
    ? "Regningen er godkjent av begge og klar for betaling."
    : "Regningen er godkjent. Én godkjenning til, så er den klar for betaling.");
  paaNytt();
}

async function betal(f) {
  const ok = await bekreft(
    "Registrere betaling?",
    `${f.leverandor} — ${kr(f.belop_ore)} kr. Regningen føres som utgift i regnskapet med eget bilagsnummer. Betalingen selv gjør du i nettbanken.`,
    "Registrer betaling"
  );
  if (!ok) return;
  const { data, error } = await db.rpc("bokfor_regning", { p_faktura: f.id });
  if (error) return visFeil(error, "Registrering");
  toast("Registrert", "Regningen er bokført som utgift. Husk å betale den i nettbanken.");
  paaNytt();
}

async function nyRegning(kategorier, prosjekter, f = null) {
  const kategoriValg = [{ verdi: "", tekst: "Ikke valgt" }]
    .concat((kategorier || []).map(k => ({ verdi: k.id, tekst: k.navn })));
  const prosjektValg = [{ verdi: "", tekst: "Ingen" }]
    .concat((prosjekter || []).map(p => ({ verdi: p.id, tekst: p.navn })));

  const svar = await skjemaModal({
    tittel: f ? "Endre regning" : "Legg inn regning",
    beskrivelse: f ? null : "Legg inn det som står på fakturaen. Deretter går den til godkjenning.",
    felter: [
      { navn: "leverandor", label: "Hvem har sendt regningen?", verdi: f?.leverandor || "", plassholder: "Drammen kommune", bredde: "full" },
      { navn: "beskrivelse", label: "Hva gjelder den?", verdi: f?.beskrivelse || "", plassholder: "Halleie september", bredde: "full" },
      { navn: "belop", label: "Beløp", verdi: f ? (f.belop_ore / 100).toFixed(2).replace(".", ",") : "", plassholder: "0,00" },
      { navn: "forfall", label: "Forfallsdato", type: "date", verdi: f?.forfall || "" },
      { navn: "referanse", label: "Fakturanummer", verdi: f?.referanse || "" },
      { navn: "kid", label: "KID eller melding", verdi: f?.kid || "" },
      { navn: "kontonummer", label: "Kontonummer", verdi: f?.kontonummer || "", plassholder: "1503.44.11902" },
      { navn: "category_id", label: "Kategori", type: "select", valg: kategoriValg, verdi: f?.category_id || "" },
      { navn: "project_id", label: "Prosjekt", type: "select", valg: prosjektValg, verdi: f?.project_id || "", bredde: "full" }
    ],
    lagreTekst: f ? "Lagre" : "Legg inn",
    onLagre: async (d) => {
      const belop = tilOre(d.belop);
      if (!d.leverandor) { toast("Mangler avsender", "Skriv hvem regningen kommer fra.", true); return false; }
      if (!d.beskrivelse) { toast("Mangler beskrivelse", "Skriv kort hva regningen gjelder.", true); return false; }
      if (belop <= 0) { toast("Mangler beløp", "Beløpet må være større enn null.", true); return false; }
      if (!d.forfall) { toast("Mangler forfall", "Sett forfallsdato, ellers vet ingen når den må betales.", true); return false; }

      const rad = {
        leverandor: d.leverandor, beskrivelse: d.beskrivelse, belop_ore: belop,
        forfall: d.forfall, referanse: d.referanse || null, kid: d.kid || null,
        kontonummer: d.kontonummer || null,
        category_id: d.category_id || null, project_id: d.project_id || null
      };
      if (f) {
        const { error } = await db.from("supplier_invoices").update(rad).eq("id", f.id);
        if (error) throw error;
      } else {
        const { error } = await settInn("supplier_invoices", { ...rad, opprettet_av: S.bruker.id });
        if (error) throw error;
      }
      return true;
    },
    onSlett: f && erAdmin() && f.status !== "betalt" ? async () => {
      const { error } = await db.from("supplier_invoices").delete().eq("id", f.id);
      if (error) throw error;
    } : null
  });

  if (svar) { toast("Lagret", f ? "Regningen er oppdatert." : "Regningen er lagt inn og venter på godkjenning."); paaNytt(); }
}

async function eksporter(fakturaer) {
  try {
    await eksporterExcel(`regninger-${S.org.navn.replace(/\s+/g, "-").toLowerCase()}.xlsx`, {
      "Regninger": fakturaer.map(f => ({
        Leverandør: f.leverandor,
        Fakturanummer: f.referanse || "",
        Beskrivelse: f.beskrivelse,
        Mottatt: f.mottatt,
        Forfall: f.forfall,
        "Beløp": f.belop_ore / 100,
        Status: (STATUS[f.status] || [f.status])[0],
        "Godkjent av 1": navnPaa(f.a1),
        "Godkjent av 2": navnPaa(f.a2),
        KID: f.kid || "",
        Kontonummer: f.kontonummer || ""
      }))
    });
    toast("Lastet ned", "Filen ligger i nedlastingsmappen din.");
  } catch (e) { visFeil(e, "Eksport"); }
}
