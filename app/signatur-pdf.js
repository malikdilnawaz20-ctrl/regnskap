// =====================================================================
//  Signaturside — legges bakerst i PDF-en når et dokument er ferdig
//  signert. Er originalen ikke en PDF, lages et eget signeringsbevis.
//
//  Siden viser hvem som signerte, i hvilken rolle, på hvilken dato
//  (datoen som gjelder for dokumentet) og når det faktisk skjedde,
//  pluss signatur-ID og hash av dokumentet slik det var da det ble
//  sendt til signering. Alt kan kontrolleres på sakflyt.no/verifiser.
//
//  Samme bibliotek som stempel.js: pdf-lib, lastet ved behov.
// =====================================================================

const NAVY = [0.04, 0.17, 0.2];
const TEAL = [0.0, 0.42, 0.45];
const GRAA = [0.45, 0.47, 0.48];

const SIGNERT_SOM = {
  styremedlem: "Styremedlem — innlogget signatur",
  styremedlem_i_mote: "Styremedlem — enkel signatur",
  fullmektig_for_styret: "På vegne av styret, etter fullmakt",
  administrator: "På vegne av styret"
};

// Helvetica kan bare WinAnsi. Alt annet (emoji, →, ł …) byttes ut, så
// en pil i en tittel aldri stopper hele signeringen.
const trygg = (s) => String(s ?? "").replace(/[^\u0000-\u00ff\u0152\u0153\u0160\u0161\u0178\u017d\u017e\u0192\u02c6\u02dc\u2013\u2014\u2018-\u201e\u2020-\u2022\u2026\u2030\u2039\u203a\u20ac\u2122]/g, "?");

const d8 = (d) => d ? new Date(d).toLocaleDateString("nb-NO", { day: "2-digit", month: "2-digit", year: "numeric" }) : "—";
const t8 = (t) => t ? new Date(t).toLocaleString("nb-NO", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";

/**
 * @param {Blob|null} original  Dokumentets fil. PDF får signatursiden bakerst;
 *                              alt annet (eller ingen fil) gir et eget bevis.
 * @param {object} info  { orgNavn, orgnr, tittel, saksflytnr, mappe, dokumentdato,
 *                         hash, verifiserUrl, signaturer: [{ navn, rolle, signert_som,
 *                         signaturdato, signert_tidspunkt, signatur_id, fullmakt }] }
 * @returns {Promise<File>}
 */
export async function lagSignertPdf(original, info) {
  const { PDFDocument, StandardFonts, rgb } = await import("https://esm.sh/pdf-lib@1.17.1");

  let pdf = null;
  const erPdf = original && ((original.type || "").toLowerCase() === "application/pdf"
    || (original.name || "").toLowerCase().endsWith(".pdf"));
  if (erPdf) {
    try { pdf = await PDFDocument.load(await original.arrayBuffer(), { ignoreEncryption: true }); }
    catch (e) { console.warn("Kunne ikke åpne originalen, lager eget bevis:", e); pdf = null; }
  }
  const egetBevis = !pdf;
  if (!pdf) pdf = await PDFDocument.create();

  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const fet = await pdf.embedFont(StandardFonts.HelveticaBold);
  const c = (a) => rgb(a[0], a[1], a[2]);

  let side = pdf.addPage([595.28, 841.89]);
  const { width, height } = side.getSize();
  const marg = 56;
  let y = height - marg;

  const tekst = (s, { x = marg, size = 10, f = font, farge = NAVY } = {}) => {
    side.drawText(trygg(s), { x, y, size, font: f, color: c(farge) });
  };
  // Ny side når det er for lite plass igjen — store styrer gir mange signaturer.
  const plass = (trenger) => {
    if (y - trenger > marg) return;
    side = pdf.addPage([595.28, 841.89]);
    side.drawRectangle({ x: 0, y: height - 36, width, height: 36, color: c(TEAL) });
    side.drawText(trygg("SAKSFLYT · ELEKTRONISK SIGNERT (forts.)"), { x: marg, y: height - 23, size: 9.5, font: fet, color: rgb(1, 1, 1) });
    y = height - 36 - 40;
  };
  const linje = (ned = 14) => { y -= ned; };
  const strek = (farge = [0.85, 0.87, 0.88]) => {
    side.drawLine({ start: { x: marg, y }, end: { x: width - marg, y }, thickness: 0.7, color: c(farge) });
  };
  const par = (label, verdi, { size = 10 } = {}) => {
    tekst(label, { size: 8.5, farge: GRAA });
    linje(12);
    brytTekst(verdi, size);
    linje(6);
  };
  const brytTekst = (s, size = 10, f = font) => {
    const maks = width - marg * 2;
    const ord = trygg(s || "—").split(/\s+/);
    let rad = "";
    for (const o of ord) {
      const forsok = rad ? rad + " " + o : o;
      if (f.widthOfTextAtSize(forsok, size) > maks && rad) {
        tekst(rad, { size, f }); linje(size + 3); rad = o;
      } else rad = forsok;
    }
    tekst(rad, { size, f }); linje(size + 3);
  };

  // Topp
  side.drawRectangle({ x: 0, y: height - 36, width, height: 36, color: c(TEAL) });
  side.drawText(trygg("SAKSFLYT · ELEKTRONISK SIGNERT"), { x: marg, y: height - 23, size: 9.5, font: fet, color: rgb(1, 1, 1) });
  if (info.saksflytnr) {
    const w = fet.widthOfTextAtSize(trygg(info.saksflytnr), 9.5);
    side.drawText(trygg(info.saksflytnr), { x: width - marg - w, y: height - 23, size: 9.5, font: fet, color: rgb(1, 1, 1) });
  }
  y = height - 36 - 40;

  tekst(egetBevis ? "Signeringsbevis" : "Signaturside", { size: 20, f: fet });
  linje(16);
  tekst(egetBevis
    ? "Dette beviset dokumenterer den elektroniske signeringen av filen beskrevet nedenfor."
    : "Denne siden er lagt til bakerst i dokumentet da det ble ferdig signert.", { size: 9.5, farge: GRAA });
  linje(26);

  par("Organisasjon", [info.orgNavn, info.orgnr ? "org.nr " + info.orgnr : null].filter(Boolean).join(" · "));
  par("Dokument", [info.tittel, info.mappe ? "(" + info.mappe + ")" : null].filter(Boolean).join(" "));
  if (info.anledning) par("Gjelder", info.anledning);
  if (info.dokumentdato) par("Dokumentdato", d8(info.dokumentdato));
  if (info.hash) par("Dokumentets fingeravtrykk (SHA-256, før signering)", info.hash, { size: 8 });

  linje(6); strek(); linje(22);
  tekst("Signaturer", { size: 13, f: fet });
  linje(20);

  for (const s of info.signaturer || []) {
    let png = null;
    if (s.bilde) { try { png = await pdf.embedPng(s.bilde); } catch (e) { console.warn("Signaturbilde kunne ikke legges inn:", e); } }
    const ekstra = (s.fullmakt ? 14 : 0) + (s.styret ? 14 * Math.ceil((s.styret.length + 24) / 95) : 0);
    plass(100 + ekstra);
    side.drawRectangle({ x: marg - 10, y: y - 86 - ekstra, width: width - marg * 2 + 20, height: 104 + ekstra, color: c([0.965, 0.975, 0.975]) });
    tekst(s.navn, { size: 12.5, f: fet });
    const idW = font.widthOfTextAtSize(trygg(s.signatur_id), 9);
    tekst(s.signatur_id, { x: width - marg - idW, size: 9, farge: TEAL });
    if (png) {
      // Håndtegnet signatur til høyre i blokken, under ID-en
      const h = 44, w = Math.min(170, png.width * (h / png.height));
      side.drawImage(png, { x: width - marg - w, y: y - 16 - h, width: w, height: h });
    }
    linje(15);
    tekst([s.rolle, SIGNERT_SOM[s.signert_som] || s.signert_som].filter(Boolean).join(" · "), { size: 9.5, farge: GRAA });
    linje(15);
    if (s.fullmakt) {
      brytTekst("Fullmakt " + s.fullmakt.nummer + " — " + s.fullmakt.vedtak + ", " + d8(s.fullmakt.vedtaksdato), 9);
    }
    if (s.styret) brytTekst("Styret på signaturdatoen: " + s.styret, 9);
    tekst("Dato på dokumentet: " + d8(s.signaturdato), { size: 10, f: fet });
    linje(14);
    tekst("Signert elektronisk " + t8(s.signert_tidspunkt) + " · nivå: intern e-signatur i Saksflyt", { size: 8.5, farge: GRAA });
    linje(32);
  }

  plass(80);
  linje(8); strek(); linje(18);
  brytTekst("Kontroller signaturen: " + (info.verifiserUrl || "sakflyt.no/verifiser.html") + " — skriv inn signatur-ID-en.", 9);
  brytTekst("Signaturdato er datoen dokumentet gjelder, valgt av den som signerte. Tidspunktet for signeringen er satt av systemet og kan ikke endres. Begge ligger i Saksflyts revisjonsspor.", 8.5);

  const bytes = await pdf.save();
  const navn = egetBevis
    ? "signeringsbevis-" + (info.saksflytnr || "dokument") + ".pdf"
    : (original.name || "dokument.pdf").replace(/\.pdf$/i, "") + "-signert.pdf";
  return new File([bytes], navn, { type: "application/pdf" });
}

/** SHA-256 av en fil, som heksadesimal streng. */
export async function hashAvFil(blob) {
  const buf = await crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
}
