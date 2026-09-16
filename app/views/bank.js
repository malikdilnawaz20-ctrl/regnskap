// =====================================================================
//  Bank — avstemt kontosaldo og transaksjonshistorikk.
//  Bankbevegelser importeres som transaksjoner med fast bankkonto.
// =====================================================================

import {
  el, kpi, kort, pille, tabell, felt, velg, kr, dato, datoKort,
  eksporterExcel, visFeil, toast
} from "../lib.js";
import { S, velgFra, paaNytt } from "../store.js";

const BANKAAR = 2026;
const BANK_SISTE_DATO = "2026-09-16";
const PERIODER = [
  { verdi: "alle", tekst: "Hele 2026", fra: "2026-01-01", til: "2026-12-31" },
  { verdi: "jan-jul", tekst: "1. jan – 31. jul", fra: "2026-01-01", til: "2026-07-31" },
  { verdi: "aug", tekst: "August", fra: "2026-08-01", til: "2026-08-31" },
  { verdi: "sep", tekst: "1. sep – i dag", fra: "2026-09-01", til: "2026-12-31" }
];

async function hentBankkontoer() {
  const { data, error } = await velgFra("accounts", "id,navn,kontonummer,type,aapningssaldo_ore")
    .in("type", ["bank", "vipps"]).eq("aktiv", true).order("navn");
  if (error) throw error;
  return data || [];
}

async function hentBanktransaksjoner(accountId) {
  const { data, error } = await velgFra("transactions",
    "id,bilagsnummer,dato,type,beskrivelse,belop_ore,motpart,account_id")
    .eq("account_id", accountId)
    .gte("dato", `${BANKAAR}-01-01`)
    .lte("dato", `${BANKAAR}-12-31`)
    .order("dato", { ascending: false })
    .order("bilagsnummer", { ascending: false });
  if (error) throw error;
  return data || [];
}

function erSynlig(t, filter) {
  const periode = PERIODER.find(p => p.verdi === filter.periode) || PERIODER[0];
  if (t.dato < periode.fra || t.dato > periode.til) return false;
  if (filter.retning !== "alle" && t.type !== filter.retning) return false;
  if (filter.sok) {
    const sok = filter.sok.toLowerCase();
    const tekst = [t.beskrivelse, t.motpart, t.bilagsnummer].filter(Boolean).join(" ").toLowerCase();
    if (!tekst.includes(sok)) return false;
  }
  return true;
}

function bankRad(t) {
  const inn = t.type === "inntekt";
  return el("tr", {}, [
    el("td", { class: "mono" }, datoKort(t.dato)),
    el("td", {}, [el("b", {}, t.beskrivelse), t.motpart ? el("span", { class: "who" }, t.motpart) : null]),
    el("td", {}, t.bilagsnummer),
    el("td", {}, pille(inn ? "Penger inn" : "Penger ut", inn ? "green" : "red")),
    el("td", { class: "num" }, (inn ? "+ " : "− ") + kr(t.belop_ore) + " kr")
  ]);
}

export const bankView = {
  tittel: "Bank",
  undertekst: "Se kontosaldoen og alle bankbevegelser samlet på ett sted.",
  async bygg() {
    if (!S.orgId) return el("div", { class: "empty" }, "Velg en organisasjon først.");

    try {
      const kontoer = await hentBankkontoer();
      if (!kontoer.length) return kort({
        tittel: "Ingen bankkontoer",
        beskrivelse: "Legg til en aktiv bankkonto under Innstillinger før du importerer kontoutskriften.",
        innhold: el("div", { class: "note info" }, "Det finnes ingen aktive bank- eller Vipps-kontoer for organisasjonen.")
      });

      let konto = kontoer[0];
      let transaksjoner = await hentBanktransaksjoner(konto.id);
      const filter = { periode: "alle", retning: "alle", sok: "" };

      const saldo = () => {
        const inn = transaksjoner.filter(t => t.type === "inntekt").reduce((s, t) => s + t.belop_ore, 0);
        const ut = transaksjoner.filter(t => t.type === "utgift").reduce((s, t) => s + t.belop_ore, 0);
        return { inn, ut, saldo: konto.aapningssaldo_ore + inn - ut };
      };

      const holder = el("div");
      const sok = el("input", { type: "search", placeholder: "Søk i beskrivelse, motpart eller referanse" });
      const periodeSel = velg("bank-periode", PERIODER.map(p => ({ verdi: p.verdi, tekst: p.tekst })), filter.periode);
      const retningSel = velg("bank-retning", [
        { verdi: "alle", tekst: "Alle bevegelser" },
        { verdi: "inntekt", tekst: "Penger inn" },
        { verdi: "utgift", tekst: "Penger ut" }
      ], filter.retning);
      const kontoSel = kontoer.length > 1
        ? velg("bank-konto", kontoer.map(k => ({ verdi: k.id, tekst: k.navn + (k.kontonummer ? " · " + k.kontonummer : "") })), konto.id)
        : null;

      const tegnTabell = () => {
        const rader = transaksjoner.filter(t => erSynlig(t, filter));
        holder.replaceChildren(tabell(
          [{ t: "Dato" }, { t: "Beskrivelse" }, { t: "Referanse" }, { t: "Retning" }, { t: "Beløp", num: true }],
          rader.map(bankRad),
          "Ingen bankbevegelser passer til filteret."
        ));
        return rader;
      };

      const kontokort = el("div", { class: "bank-account-hero" });
      const tegnKonto = () => {
        const s = saldo();
        const siste = transaksjoner[0]?.dato;
        kontokort.replaceChildren(
          el("div", {}, [el("div", { class: "eyebrow" }, "Tilgjengelige midler"), el("div", { class: "bank-saldo" }, kr(s.saldo) + " kr"), el("div", { class: "meta" }, konto.navn + (konto.kontonummer ? " · " + konto.kontonummer : ""))]),
          el("div", { class: "bank-avstemt" }, [pille("Avstemt", "green"), el("span", {}, "Saldo per " + dato(BANK_SISTE_DATO)), siste && el("span", { class: "tiny" }, "Siste bevegelse " + dato(siste))])
        );
      };
      tegnKonto();

      const stats = el("div", { class: "grid g3" });
      const tegnStats = (rader = transaksjoner) => {
        const inn = rader.filter(t => t.type === "inntekt").reduce((s, t) => s + t.belop_ore, 0);
        const ut = rader.filter(t => t.type === "utgift").reduce((s, t) => s + t.belop_ore, 0);
        stats.replaceChildren(
          kpi({ ikon: "opp", nokkel: "Penger inn", verdi: "+ " + kr(inn) + " kr", farge: "pos" }),
          kpi({ ikon: "ut", nokkel: "Penger ut", verdi: "− " + kr(ut) + " kr", farge: "neg" }),
          kpi({ ikon: "rapport", nokkel: "Netto i valgt periode", verdi: (inn - ut >= 0 ? "+ " : "− ") + kr(Math.abs(inn - ut)) + " kr", farge: inn - ut >= 0 ? "pos" : "neg" })
        );
      };
      tegnStats();

      const oppdater = () => { filter.periode = periodeSel.value; filter.retning = retningSel.value; filter.sok = sok.value.trim(); const r = tegnTabell(); tegnStats(r); };
      periodeSel.addEventListener("change", oppdater);
      retningSel.addEventListener("change", oppdater);
      sok.addEventListener("input", oppdater);
      kontoSel?.addEventListener("change", async () => {
        konto = kontoer.find(k => k.id === kontoSel.value) || kontoer[0];
        transaksjoner = await hentBanktransaksjoner(konto.id);
        tegnKonto(); tegnStats(); tegnTabell();
      });

      const eksport = el("button", { class: "btn", onclick: async () => {
        try {
          const rader = transaksjoner.filter(t => erSynlig(t, filter));
          await eksporterExcel("banktransaksjoner-2026.xlsx", { Transaksjoner: rader.map(t => ({
            Dato: datoKort(t.dato), Beskrivelse: t.beskrivelse, Motpart: t.motpart || "", Referanse: t.bilagsnummer,
            Retning: t.type === "inntekt" ? "Penger inn" : "Penger ut", "Beløp (kr)": (t.type === "utgift" ? -1 : 1) * Number((t.belop_ore / 100).toFixed(2))
          })) });
          toast("Eksportert", "Bankbevegelsene er lastet ned.");
        } catch (e) { visFeil(e, "Eksport av bankbevegelser"); }
      } }, "Eksporter til Excel");
      const oppdaterKnapp = el("button", { class: "btn stille", onclick: () => paaNytt() }, "Oppdater");

      tegnTabell();
      return el("div", { class: "stack" }, [
        el("div", { class: "bank-account-row" }, [kontokort, kontoSel ? felt("Konto", kontoSel) : null]),
        stats,
        kort({ tittel: "Transaksjonshistorikk", beskrivelse: "Bankbevegelser fra 1. januar til siste importerte dato i 2026.", hoyre: el("div", { class: "actions" }, [oppdaterKnapp, eksport]), innhold: [
          el("div", { class: "grid g3 bank-filter" }, [felt("Periode", periodeSel), felt("Retning", retningSel), felt("Søk", sok)]),
          holder
        ] })
      ]);
    } catch (e) {
      visFeil(e, "Henting av bankbevegelser");
      return el("div", { class: "empty" }, "Klarte ikke å hente bankbevegelsene.");
    }
  }
};
