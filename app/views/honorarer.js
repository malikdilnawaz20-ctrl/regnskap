// =====================================================================
//  Honorarer - avklaring, intern dokumentasjon og PDF-bilag.
// =====================================================================

import {
  el, kpi, kort, pille, tabell, velg, knapp, skjemaModal, bekreft,
  toast, visFeil, laster, kr, dato, iDag, db
} from "../lib.js";
import { S, kanOkonomi, velgFra, settInn, paaNytt } from "../store.js";

const HONORAR_NAVN = new Map([
  ["FIKEN-2025-0061", "Hizzar Ali"], ["FIKEN-2025-0062", "Aman Malik"],
  ["FIKEN-2025-0095", "Aneesa Malik"], ["FIKEN-2025-0106", "Hizzar Ali"],
  ["FIKEN-2025-0107", "Aneesa Malik"], ["FIKEN-2025-0112", "Aman Malik"],
  ["FIKEN-2025-0113", "Amir Malik"], ["FIKEN-2025-0115", "Aneesa Malik"],
  ["FIKEN-2025-0122", "Aneesa Malik"], ["FIKEN-2025-0123", "Amir Malik"],
  ["FIKEN-2025-0124", "Hizzar Ali"], ["FIKEN-2025-0125", "Aneesa Malik"],
  ["FIKEN-2025-0130", "Aman Malik"], ["FIKEN-2025-0134", "Aneesa Malik"],
  ["FIKEN-2025-0142", "Amir Malik"], ["FIKEN-2025-0143", "Aneesa Malik"],
  ["FIKEN-2025-0144", "Aman Malik"], ["FIKEN-2025-0145", "Hizzar Ali"],
  ["FIKEN-2025-0156", "Amir Malik"], ["FIKEN-2025-0161", "Amir Malik"],
  ["FIKEN-2025-0164", "Hizzar Ali"], ["FIKEN-2025-0165", "Aneesa Malik"],
  ["FIKEN-2025-0167", "Aman Malik"]
]);

const STORE_UTBETALINGER = new Map([
  ["FIKEN-2025-0135", { konto: "4111.15.93777", original: "Bedrterm oppgave Til: 4111.15.93777" }],
  ["FIKEN-2025-0138", { konto: "1204.62.69215", original: "Bedrterm oppgave Til: 1204.62.69215" }],
  ["FIKEN-2025-0141", { konto: "2220.35.54846", original: "Bedrterm oppgave Til: 2220.35.54846" }]
]);

const LEVERANDORPOSTER = new Set([
  "FIKEN-2025-0066", "FIKEN-2025-0091", "FIKEN-2025-0092", "FIKEN-2025-0109",
  "FIKEN-2025-0126", "FIKEN-2025-0127", "FIKEN-2025-0129", "FIKEN-2025-0153", "FIKEN-2025-0154"
]);

function erHonorarPdf(fil) { return /^honorar(bilag|oppgave)-/.test(fil.filnavn || ""); }
function mottaker(t) { return HONORAR_NAVN.get(t.bilagsnummer) || t.motpart || ""; }
function slug(tekst) { return tekst.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
async function hentData(aar) {
  const [{ data: txn, error }, { data: vedlegg, error: vedleggFeil }, { data: kategorier, error: kategoriFeil }] = await Promise.all([
    velgFra("transactions", "id,bilagsnummer,dato,type,beskrivelse,belop_ore,motpart,category_id,konto_nummer,regnskapsaar,categories(navn)")
      .eq("regnskapsaar", aar).eq("type", "utgift").order("dato", { ascending: true }),
    velgFra("attachments", "id,transaction_id,filnavn,storage_path,mime,storrelse,opprettet"),
    velgFra("categories", "id,navn,retning").eq("retning", "utgift")
  ]);
  if (error) throw error;
  if (vedleggFeil) throw vedleggFeil;
  if (kategoriFeil) throw kategoriFeil;
  const vedleggMap = new Map();
  for (const fil of vedlegg || []) {
    const liste = vedleggMap.get(fil.transaction_id) || [];
    liste.push(fil); vedleggMap.set(fil.transaction_id, liste);
  }
  const alle = txn || [];
  const sikre = alle.filter(t => HONORAR_NAVN.has(t.bilagsnummer));
  const uklare = alle.filter(t => STORE_UTBETALINGER.has(t.bilagsnummer)
    || (!LEVERANDORPOSTER.has(t.bilagsnummer) && /honorar/i.test(t.categories?.navn || "") && !HONORAR_NAVN.has(t.bilagsnummer)));
  return { sikre, uklare, vedleggMap, kategorier: kategorier || [] };
}

async function apnePdf(fil) {
  try {
    const { data, error } = await db.storage.from("bilag").createSignedUrl(fil.storage_path, 90);
    if (error) throw error;
    window.open(data.signedUrl, "_blank", "noopener");
  } catch (e) { visFeil(e, "Åpning av PDF"); }
}

async function pdfVerktoy() {
  return import("https://esm.sh/pdf-lib@1.17.1");
}

function skrivLinjer(page, font, tekst, x, y, bredde, storrelse = 10, linje = 15) {
  const ord = String(tekst || "").split(/\s+/); let rad = ""; let yy = y;
  for (const ordet of ord) {
    const neste = rad ? `${rad} ${ordet}` : ordet;
    if (font.widthOfTextAtSize(neste, storrelse) > bredde && rad) {
      page.drawText(rad, { x, y: yy, size: storrelse, font }); yy -= linje; rad = ordet;
    } else rad = neste;
  }
  if (rad) { page.drawText(rad, { x, y: yy, size: storrelse, font }); yy -= linje; }
  return yy;
}

async function byggHonorarPdf(t) {
  const { PDFDocument, StandardFonts, rgb } = await pdfVerktoy();
  const pdf = await PDFDocument.create();
  const page = pdf.addPage([419.53, 595.28]);
  const normal = await pdf.embedFont(StandardFonts.Helvetica);
  const fet = await pdf.embedFont(StandardFonts.HelveticaBold);
  const navy = rgb(0.04, 0.17, 0.2), teal = rgb(0.03, 0.5, 0.47), graa = rgb(0.42, 0.46, 0.49);
  const navn = mottaker(t), org = S.org || {};
  page.drawRectangle({ x: 0, y: 521, width: 419.53, height: 74, color: navy });
  page.drawText("HONORAROPPGAVE", { x: 28, y: 555, size: 19, font: fet, color: rgb(1, 1, 1) });
  page.drawText(org.navn || "Organisasjon", { x: 28, y: 537, size: 9, font: normal, color: rgb(0.82, 0.9, 0.9) });
  page.drawText(`Org.nr. ${org.orgnr || "-"}`, { x: 300, y: 537, size: 8, font: normal, color: rgb(0.82, 0.9, 0.9) });

  const detalj = (etikett, verdi, x, y) => {
    page.drawText(etikett.toUpperCase(), { x, y, size: 7.5, font: fet, color: graa });
    page.drawText(String(verdi || "-"), { x, y: y - 17, size: 10, font: normal, color: navy });
  };
  detalj("Bilagsnummer", `HB-${t.bilagsnummer}`, 28, 486);
  detalj("Bilagsdato", dato(t.dato), 235, 486);

  page.drawRectangle({ x: 28, y: 392, width: 363.53, height: 58, color: rgb(0.96, 0.97, 0.97) });
  page.drawText("MOTTAKER", { x: 42, y: 430, size: 7.5, font: fet, color: graa });
  page.drawText(navn, { x: 42, y: 409, size: 13, font: fet, color: navy });

  page.drawText("UTBETALING", { x: 28, y: 352, size: 8, font: fet, color: graa });
  const rad = (tekst, belop, y, fetRad = false) => {
    page.drawText(tekst, { x: 28, y, size: fetRad ? 10 : 9.5, font: fetRad ? fet : normal, color: navy });
    page.drawText(belop, { x: 315, y, size: fetRad ? 10 : 9.5, font: fetRad ? fet : normal, color: navy });
    page.drawLine({ start: { x: 28, y: y - 12 }, end: { x: 391.53, y: y - 12 }, thickness: 0.5, color: rgb(0.85, 0.88, 0.89) });
  };
  rad("Honorar", `${kr(t.belop_ore)} kr`, 325);
  rad("Forskuddstrekk", "0,00 kr", 286);
  page.drawRectangle({ x: 28, y: 208, width: 363.53, height: 48, color: rgb(0.92, 0.97, 0.96) });
  page.drawText("NETTO UTBETALT", { x: 42, y: 226, size: 10, font: fet, color: teal });
  page.drawText(`${kr(t.belop_ore)} kr`, { x: 286, y: 222, size: 15, font: fet, color: navy });

  detalj("Grunnlag", `Honorar - ${navn}`, 28, 167);
  detalj("Kildebilag", t.bilagsnummer, 235, 167);
  page.drawLine({ start: { x: 28, y: 58 }, end: { x: 391.53, y: 58 }, thickness: 0.5, color: rgb(0.85, 0.88, 0.89) });
  page.drawText(`Dokumentasjon for honorarutbetaling ${dato(t.dato)}`, { x: 28, y: 40, size: 8, font: normal, color: graa });
  return pdf.save();
}

async function lagreHonorarPdf(t, lastNed = false) {
  const navn = mottaker(t);
  if (!navn) throw new Error("Mottaker må avklares før honorarbilaget kan lages.");
  const bytes = await byggHonorarPdf(t);
  const filnavn = `honoraroppgave-${t.bilagsnummer}-${slug(navn)}.pdf`;
  const path = `${S.orgId}/${t.id}/${filnavn}`;
  const { error: lastFeil } = await db.storage.from("bilag").upload(path, new Blob([bytes], { type: "application/pdf" }), { upsert: false, contentType: "application/pdf" });
  if (lastFeil) throw lastFeil;
  const { data: eksisterende, error: finnFeil } = await velgFra("attachments", "id,filnavn").eq("transaction_id", t.id).or("filnavn.like.honorarbilag-%,filnavn.like.honoraroppgave-%").limit(1).maybeSingle();
  if (finnFeil) throw finnFeil;
  if (eksisterende) {
    const { error } = await db.from("attachments").update({ filnavn, storage_path: path, mime: "application/pdf", storrelse: bytes.length }).eq("organization_id", S.orgId).eq("id", eksisterende.id);
    if (error) throw error;
  } else {
    const { error } = await settInn("attachments", { transaction_id: t.id, filnavn, storage_path: path, mime: "application/pdf", storrelse: bytes.length, lastet_opp_av: S.bruker?.id });
    if (error) throw error;
  }
  if (lastNed) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([bytes], { type: "application/pdf" })); a.download = filnavn; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }
}

async function avklar(t, kategorier) {
  if (!kanOkonomi()) return toast("Ikke tilgang", "Du trenger økonomitilgang for å avklare utbetalingen.", true);
  const resultat = await skjemaModal({
    tittel: "Avklar utbetaling",
    beskrivelse: `${dato(t.dato)} - ${kr(t.belop_ore)} kr - ${t.bilagsnummer}`,
    felter: [
      { navn: "mottaker", label: "Mottaker", verdi: mottaker(t), bredde: "full" },
      { navn: "type", label: "Hva gjelder betalingen?", type: "select", verdi: "refusjon", valg: [
        { verdi: "refusjon", tekst: "Refusjon av utlegg" },
        { verdi: "honorar", tekst: "Honorar" },
        { verdi: "annet", tekst: "Annen utgift" }
      ] },
      { navn: "beskrivelse", label: "Beskrivelse", verdi: t.beskrivelse, bredde: "full" }
    ],
    lagreTekst: "Lagre avklaring",
    onLagre: async d => {
      if (!d.mottaker) { toast("Mangler mottaker", "Skriv inn hvem som mottok betalingen.", true); return false; }
      const onsket = d.type === "honorar" ? ["Honorar og tjenester", "Trenerhonorar"]
        : d.type === "refusjon" ? ["Mellomregning"] : ["Andre utgifter"];
      const kategori = onsket.map(n => kategorier.find(k => k.navn === n)).find(Boolean);
      const beskrivelse = d.beskrivelse || (d.type === "honorar" ? `Honorar - ${d.mottaker}` : d.type === "refusjon" ? `Refusjon av dokumentert utlegg - ${d.mottaker}` : `Utbetaling - ${d.mottaker}`);
      const { error } = await db.from("transactions").update({ motpart: d.mottaker, beskrivelse, ...(kategori ? { category_id: kategori.id } : {}) }).eq("organization_id", S.orgId).eq("id", t.id);
      if (error) throw error;
    }
  });
  if (resultat) { toast("Avklart", "Utbetalingen er oppdatert. Lag honorar-PDF bare når betalingen faktisk er honorar."); paaNytt(); }
}

async function byggAvklaringsrapport(rader) {
  const { PDFDocument, StandardFonts, rgb } = await pdfVerktoy();
  const pdf = await PDFDocument.create(), page = pdf.addPage([595.28, 841.89]);
  const normal = await pdf.embedFont(StandardFonts.Helvetica), fet = await pdf.embedFont(StandardFonts.HelveticaBold);
  page.drawText("RAPPORT - UTBETALINGER MA AVKLARES", { x: 42, y: 790, size: 17, font: fet, color: rgb(0.04, 0.17, 0.2) });
  page.drawText(`${S.org?.navn || "Organisasjon"} | laget ${dato(iDag())}`, { x: 42, y: 766, size: 9, font: normal });
  let y = 716;
  for (const t of rader) {
    const info = STORE_UTBETALINGER.get(t.bilagsnummer);
    page.drawText(`${dato(t.dato)}   ${kr(t.belop_ore)} kr   ${t.bilagsnummer}`, { x: 42, y, size: 11, font: fet }); y -= 19;
    y = skrivLinjer(page, normal, info?.original || t.beskrivelse, 42, y, 500, 9, 14);
    y = skrivLinjer(page, normal, `Mottaker i kilden: ikke oppgitt. Kontonummer: ${info?.konto || "ikke oppgitt"}.`, 42, y, 500, 9, 14) - 18;
  }
  skrivLinjer(page, normal, "Postene er ikke klassifisert som honorar. Bilag, kontoeier og formal ma avklares for de kobles mot utlegg eller annen dokumentasjon.", 42, y, 500, 9, 14);
  const bytes = await pdf.save();
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([bytes], { type: "application/pdf" }));
  a.download = `avklaringsrapport-utbetalinger-${iDag()}.pdf`; a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

async function bygg() {
  let aar = 2025;
  const rot = el("div", { class: "stack" });
  const tegn = async () => {
    rot.replaceChildren(laster("Henter honorarer ..."));
    try {
      const { sikre, uklare, vedleggMap, kategorier } = await hentData(aar);
      const utenPdf = sikre.filter(t => !(vedleggMap.get(t.id) || []).some(erHonorarPdf));
      const total = sikre.reduce((sum, t) => sum + t.belop_ore, 0);
      const aarVelger = velg("aar", [{ verdi: "2025", tekst: "2025" }, { verdi: "2024", tekst: "2024" }], String(aar), { "aria-label": "Regnskapsår" });
      aarVelger.onchange = () => { aar = Number(aarVelger.value); tegn(); };
      const pdfKandidater = utenPdf.length ? utenPdf : sikre;
      const masseknapp = knapp(utenPdf.length ? "Lag manglende PDF-er" : "Oppdater alle PDF-er", { ikon: "dokument", klasse: "primary", ved: async e => {
        const handlingsknapp = e.currentTarget;
        if (!pdfKandidater.length) return toast("Ingen honorarer", "Det finnes ingen bekreftede honorarer i dette året.");
        if (!await bekreft(utenPdf.length ? "Lag honorarbilag" : "Oppdater honorarbilag", `${pdfKandidater.length} PDF-bilag ${utenPdf.length ? "lages og kobles" : "erstattes med ny utforming"}.`, utenPdf.length ? "Lag PDF-bilag" : "Oppdater PDF-bilag")) return;
        handlingsknapp.disabled = true;
        try {
          for (let i = 0; i < pdfKandidater.length; i++) { handlingsknapp.textContent = `Oppdaterer ${i + 1} av ${pdfKandidater.length} ...`; await lagreHonorarPdf(pdfKandidater[i]); }
          toast("PDF-bilag oppdatert", `${pdfKandidater.length} honorarbilag er koblet til riktige datoer.`); await tegn();
        } catch (feil) { visFeil(feil, "Oppretting av honorarbilag"); handlingsknapp.disabled = false; }
      } });
      if (!kanOkonomi()) masseknapp.disabled = true;
      const bekreftedeRader = sikre.map(t => {
        const pdf = (vedleggMap.get(t.id) || []).find(erHonorarPdf);
        return el("tr", {}, [
          el("td", {}, dato(t.dato)), el("td", { class: "mono" }, t.bilagsnummer), el("td", {}, mottaker(t)),
          el("td", {}, t.beskrivelse), el("td", { class: "num" }, `${kr(t.belop_ore)} kr`),
          el("td", {}, pdf ? pille("PDF vedlagt", "green") : pille("Mangler PDF", "gold")),
          el("td", {}, pdf
            ? knapp("Åpne", { ikon: "dokument", klasse: "sm stille", ved: () => apnePdf(pdf) })
            : knapp("Lag PDF", { ikon: "dokument", klasse: "sm", ved: async e => { const handlingsknapp = e.currentTarget; handlingsknapp.disabled = true; try { await lagreHonorarPdf(t, true); toast("PDF opprettet", `Bilaget er koblet til ${t.bilagsnummer}.`); await tegn(); } catch (feil) { visFeil(feil, "Oppretting av PDF"); handlingsknapp.disabled = false; } } }))
        ]);
      });
      const uklareRader = uklare.map(t => {
        const info = STORE_UTBETALINGER.get(t.bilagsnummer);
        return el("tr", {}, [
          el("td", {}, dato(t.dato)), el("td", { class: "mono" }, t.bilagsnummer),
          el("td", {}, [el("span", {}, info?.original || t.beskrivelse), info?.konto ? el("span", { class: "who" }, `Konto ${info.konto}`) : null]),
          el("td", { class: "num" }, `${kr(t.belop_ore)} kr`), el("td", {}, pille("Må avklares", "gold")),
          el("td", {}, knapp("Avklar", { ikon: "ok", klasse: "sm", ved: () => avklar(t, kategorier) }))
        ]);
      });
      const storeRader = uklare.filter(t => STORE_UTBETALINGER.has(t.bilagsnummer));
      rot.replaceChildren(
        el("div", { class: "between" }, [aarVelger, masseknapp]),
        el("div", { class: "grid g3" }, [
          kpi({ ikon: "betaling", nokkel: "Bekreftede honorarer", verdi: `${kr(total)} kr`, under: `${sikre.length} utbetalinger` }),
          kpi({ ikon: "dokument", nokkel: "Mangler honorarbilag", verdi: String(utenPdf.length), under: "PDF-er som skal kobles" }),
          kpi({ ikon: "varsel", nokkel: "Må avklares", verdi: String(uklare.length), under: "Ikke klassifisert som honorar" })
        ]),
        el("div", { class: "note info" }, "Honoraroppgaven dokumenterer mottaker, beløp og bilagsdato. Eventuell rapportering vurderes separat."),
        kort({ tittel: `Honorarer ${aar}`, beskrivelse: "Bare bekreftede mottakere vises her. PDF-en kobles direkte til transaksjonen.", innhold: tabell(
          [{ t: "Dato" }, { t: "Bilag" }, { t: "Mottaker" }, { t: "Grunnlag" }, { t: "Beløp", num: true }, { t: "Status" }, { t: "" }], bekreftedeRader, "Ingen bekreftede honorarer dette året.") }),
        kort({ tittel: "Utbetalinger som må avklares", beskrivelse: "Disse er ikke honorarer før mottaker og formål er bekreftet.", hoyre: storeRader.length ? knapp("Last ned rapport", { ikon: "dokument", ved: () => byggAvklaringsrapport(storeRader) }) : null, innhold: tabell(
          [{ t: "Dato" }, { t: "Bilag" }, { t: "Originaltekst" }, { t: "Beløp", num: true }, { t: "Status" }, { t: "" }], uklareRader, "Ingen uavklarte honorarrelaterte utbetalinger dette året.") })
      );
    } catch (e) { visFeil(e, "Henting av honorarer"); rot.replaceChildren(el("div", { class: "note bad" }, "Klarte ikke å hente honoraroversikten.")); }
  };
  await tegn(); return rot;
}

export const honorarerView = {
  tittel: "Honorarer",
  undertekst: "Honorarbilag, mottakere og utbetalinger som må avklares.",
  async bygg() { return bygg(); }
};
