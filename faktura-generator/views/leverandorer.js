// =====================================================================
//  Leverandører — de som står som avsender på fakturaene.
//
//  Navn og adresse er nok til å komme i gang. Resten er felter som bare
//  noen maler bruker: REX og HS-kode havner på eksportfakturaen, IBAN og
//  SWIFT i betalingsfeltet. Tomme felter vises ikke på dokumentet.
// =====================================================================

import {
  el, kort, merke, tabell, skjemaModal, toast, visFeil, knapp,
  tomTilstand, verktoylinje, eksporterExcel, db
} from "../../app/lib.js";
import { S, kanOkonomi, velgFra, settInn, paaNytt } from "../../app/store.js";
import { MALER } from "../../app/faktura-maler.js";

const VALUTAER = ["USD", "EUR", "GBP", "NOK", "PKR", "SEK", "DKK"];

export const leverandorerView = {
  tittel: "Leverandører",
  undertekst: "Hver leverandør har sitt eget oppsett, sin egen mal og sin egen nummerserie.",
  async bygg() { return bygg(); }
};

async function bygg() {
  const [{ data: leverandorer, error }, { data: fakturaer }] = await Promise.all([
    velgFra("vendors", "*").order("navn"),
    velgFra("vendor_invoices", "vendor_id,status")
  ]);
  if (error) throw error;

  const boks = el("div", { class: "stack" });
  const skriv = kanOkonomi();

  boks.append(verktoylinje({
    handling: skriv ? knapp("Ny leverandør", {
      klasse: "primary", ikon: "pluss", ved: () => rediger()
    }) : null
  }));

  if (!leverandorer.length) {
    boks.append(kort({
      innhold: tomTilstand({
        tittel: "Ingen leverandører ennå",
        tekst: "Legg inn den første, så kan du lage faktura i navnet deres. Navn og adresse holder — resten kan fylles ut når det trengs.",
        ikon: "bygg",
        handlinger: skriv ? [knapp("Ny leverandør", { klasse: "primary", ikon: "pluss", ved: () => rediger() })] : []
      })
    }));
    return boks;
  }

  const antallPer = {};
  (fakturaer || []).forEach(f => {
    if (f.status !== "kladd") antallPer[f.vendor_id] = (antallPer[f.vendor_id] || 0) + 1;
  });

  const rader = leverandorer.map(l => el("tr", {
    class: skriv ? "klikk" : null,
    onclick: skriv ? () => rediger(l) : null
  }, [
    el("td", {}, [
      el("b", {}, l.navn),
      !l.aktiv && el("span", { class: "sub" }, " · arkivert")
    ]),
    el("td", {}, l.land || "—"),
    el("td", {}, l.skattenr || "—"),
    el("td", {}, l.valuta),
    el("td", {}, merke(String(l.mal).padStart(2, "0") + " " + (MALER.find(m => m.id === l.mal)?.name || ""), "neutral")),
    el("td", { class: "num" }, String(antallPer[l.id] || 0))
  ]));

  boks.append(kort({
    innhold: tabell(
      [{ t: "Leverandør" }, { t: "Land" }, { t: "Skattenr." }, { t: "Valuta" },
       { t: "Mal" }, { t: "Sendt", num: true }],
      rader
    )
  }));

  boks.append(el("div", { class: "actions" }, [
    knapp("Last ned som Excel", { ikon: "last", ved: () => eksporterExcel("leverandorer.xlsx", [{
      navn: "Leverandører",
      rader: leverandorer.map(l => ({
        Navn: l.navn, Land: l.land || "", Adresse: (l.adresse || "").split("\n").join(", "),
        Skattenr: l.skattenr || "", REX: l.rex_nr || "", HSkode: l.hs_kode || "",
        Valuta: l.valuta, Mal: l.mal, Epost: l.epost || "", Telefon: l.telefon || ""
      }))
    }]) })
  ]));

  return boks;
}

async function rediger(lev) {
  const svar = await skjemaModal({
    tittel: lev ? lev.navn : "Ny leverandør",
    beskrivelse: "Navn og adresse er nok til å komme i gang. Feltene under fylles ut når en mal trenger dem.",
    felter: [
      { navn: "navn", label: "Navn", verdi: lev?.navn || "", bredde: "full" },
      { navn: "adresse", label: "Adresse", type: "textarea", verdi: lev?.adresse || "", bredde: "full",
        hint: "Én linje per rad, slik den skal stå på fakturaen." },
      { navn: "land", label: "Land", verdi: lev?.land || "", plassholder: "Pakistan" },
      { navn: "skattenr", label: "Skattenummer", verdi: lev?.skattenr || "",
        hint: "NTN, VAT eller org.nr — det leverandøren faktisk har." },
      { navn: "epost", label: "E-post", verdi: lev?.epost || "" },
      { navn: "telefon", label: "Telefon", verdi: lev?.telefon || "" },

      { navn: "mal", label: "Fast mal", type: "select", verdi: String(lev?.mal ?? 4),
        valg: MALER.map(m => ({ verdi: String(m.id), tekst: String(m.id).padStart(2, "0") + " — " + m.name })) },
      { navn: "valuta", label: "Valuta", type: "select", verdi: lev?.valuta || "USD",
        valg: VALUTAER.map(v => ({ verdi: v, tekst: v })) },
      { navn: "sprak", label: "Språk på fakturaen", type: "select", verdi: lev?.sprak || "en",
        valg: [{ verdi: "en", tekst: "Engelsk" }, { verdi: "no", tekst: "Norsk" }] },
      { navn: "prefiks", label: "Nummerprefiks", verdi: lev?.prefiks || "",
        plassholder: "GKS", hint: "Blir GKS/2026-0001. Tomt gir 2026-0001." },
      { navn: "betalingsdager", label: "Betalingsfrist (dager)", type: "number",
        verdi: String(lev?.betalingsdager ?? 0), hint: "0 betyr forskuddsbetaling." },
      { navn: "aksentfarge", label: "Farge på malen", type: "color", verdi: lev?.aksentfarge || "#087F7A" },
      { navn: "logo", label: "Logo", type: "textarea", bredde: "full", verdi: lev?.logo || "",
        hint: "Lim inn en data-URI (data:image/...;base64,...) eller en lenke til bildet. Tomt betyr ingen logo på fakturaen." },

      { navn: "rex_nr", label: "REX-nummer", verdi: lev?.rex_nr || "" },
      { navn: "hs_kode", label: "H.S.-kode", verdi: lev?.hs_kode || "", plassholder: "6203.1910" },
      { navn: "opprinnelsesland", label: "Opprinnelsesland", verdi: lev?.opprinnelsesland || "" },
      { navn: "leveringsvilkar", label: "Leveringsvilkår", verdi: lev?.leveringsvilkar || "",
        plassholder: "C&F, FOB, EXW" },

      { navn: "bank", label: "Bank", verdi: lev?.bank || "" },
      { navn: "kontonummer", label: "Kontonummer", verdi: lev?.kontonummer || "" },
      { navn: "iban", label: "IBAN", verdi: lev?.iban || "" },
      { navn: "swift", label: "SWIFT / BIC", verdi: lev?.swift || "" },
      { navn: "betalingsnotat", label: "Betalingsinstruks", type: "textarea", bredde: "full",
        verdi: lev?.betalingsnotat || "",
        plassholder: "Payment in advance by bank transfer. All bank charges at sender's cost." },
      { navn: "vilkar", label: "Vilkår nederst på fakturaen", type: "textarea", bredde: "full",
        verdi: lev?.vilkar || "" }
    ],
    lagreTekst: lev ? "Lagre" : "Opprett leverandør",
    onSlett: lev ? async () => {
      const { error } = await db.from("vendors").update({ aktiv: false }).eq("id", lev.id);
      if (error) throw error;
      toast("Arkivert", "Leverandøren er tatt ut av lista. Fakturaene står igjen.");
      paaNytt();
    } : null,
    onLagre: async (d) => {
      if (!d.navn) { toast("Mangler navn", "Leverandøren må ha et navn.", true); return false; }
      const rad = {
        navn: d.navn, adresse: d.adresse || null, land: d.land || null,
        epost: d.epost || null, telefon: d.telefon || null, skattenr: d.skattenr || null,
        rex_nr: d.rex_nr || null, hs_kode: d.hs_kode || null,
        opprinnelsesland: d.opprinnelsesland || null, leveringsvilkar: d.leveringsvilkar || null,
        bank: d.bank || null, kontonummer: d.kontonummer || null,
        iban: d.iban || null, swift: d.swift || null,
        betalingsnotat: d.betalingsnotat || null, vilkar: d.vilkar || null,
        mal: Number(d.mal) || 4, valuta: d.valuta, sprak: d.sprak,
        prefiks: d.prefiks || null, betalingsdager: Number(d.betalingsdager) || 0,
        aksentfarge: d.aksentfarge || "#087F7A", logo: d.logo || null
      };
      if (lev) {
        const { error } = await db.from("vendors").update(rad).eq("id", lev.id);
        if (error) throw error;
      } else {
        const { error } = await settInn("vendors",
          { ...rad, organization_id: S.orgId, opprettet_av: S.bruker.id });
        if (error) throw error;
      }
    }
  });
  if (svar) { toast("Lagret", "Leverandøren er lagret."); paaNytt(); }
}
