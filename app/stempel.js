// =====================================================================
//  Saksflytnummer — stempel på dokumenter
//
//  Hvert dokument i arkivet får et nummer på formen SF-7K3M-92Q4.
//  Nummeret hentes fra databasen før filen lastes opp, slik at det kan
//  trykkes inn i selve filen. Da følger det dokumentet også når noen
//  laster det ned, skriver det ut eller sender det videre — ikke bare
//  når de ser på det inne i Saksflyt.
//
//  PDF stemples med pdf-lib, samme bibliotek som honoraroppgavene
//  bruker. Bilder stemples på et lerret. Alt annet lastes opp urørt,
//  og nummeret står bare i arkivet.
// =====================================================================

const NAVY = [0.04, 0.17, 0.2];

/**
 * Filtyper vi kan trykke nummeret inn i. Tar en File, eller hva som
 * helst med et navn — arkivraden vet bare filnavnet, ikke MIME-typen.
 */
export function kanStemples(fil) {
  if (!fil) return false;
  const t = (typeof fil === "string" ? "" : fil.type || "").toLowerCase();
  const n = (typeof fil === "string" ? fil : fil.name || "").toLowerCase();
  return t === "application/pdf" || n.endsWith(".pdf")
      || t === "image/png" || t === "image/jpeg" || t === "image/webp"
      || /\.(png|jpe?g|webp)$/.test(n);
}

/**
 * Trykker nummeret øverst til høyre. Returnerer en ny fil, eller den
 * opprinnelige hvis formatet ikke lar seg stemple. Feiler stemplingen,
 * kastes ikke feilen videre — et dokument uten stempel er bedre enn et
 * dokument som ikke ble lagret.
 */
export async function stemple(fil, nummer) {
  if (!fil || !nummer || !kanStemples(fil)) return { fil, stemplet: false };
  try {
    const erPdf = (fil.type || "").toLowerCase() === "application/pdf"
      || (fil.name || "").toLowerCase().endsWith(".pdf");
    if (!erPdf && !/^image\//.test(fil.type || "")) {
      // Nedlastede filer fra lagringen kan komme uten MIME-type. Da er
      // filnavnet det eneste vi har, og det har allerede sagt at dette
      // er et bilde.
      fil = new File([fil], fil.name, { type: gjettType(fil.name) });
    }
    const ut = erPdf ? await stemplePdf(fil, nummer) : await stempleBilde(fil, nummer);
    return { fil: ut, stemplet: true };
  } catch (e) {
    console.warn("Stempling feilet, laster opp filen urørt:", e);
    return { fil, stemplet: false };
  }
}

/* ---------------------------------------------------------------------
   PDF — nummeret øverst til høyre på hver side
   --------------------------------------------------------------------- */

async function stemplePdf(fil, nummer) {
  const { PDFDocument, StandardFonts, rgb } = await import("https://esm.sh/pdf-lib@1.17.1");
  const pdf = await PDFDocument.load(await fil.arrayBuffer(), { ignoreEncryption: true });
  const font = await pdf.embedFont(StandardFonts.Helvetica);

  const storrelse = 8.5;
  const bredde = font.widthOfTextAtSize(nummer, storrelse);
  const luft = 5;

  for (const side of pdf.getPages()) {
    // getSize() gir sidens synlige mål; på en rotert side er høyde og
    // bredde byttet om i forhold til mediaboksen, og det er de synlige
    // målene stempelet skal plasseres etter.
    const { width, height } = side.getSize();
    const margin = Math.min(28, width * 0.06);
    const x = width - margin - bredde;
    const y = height - margin - storrelse;

    side.drawRectangle({
      x: x - luft, y: y - luft * 0.6,
      width: bredde + luft * 2, height: storrelse + luft * 1.4,
      color: rgb(1, 1, 1), opacity: 0.82
    });
    side.drawText(nummer, {
      x, y, size: storrelse, font,
      color: rgb(NAVY[0], NAVY[1], NAVY[2])
    });
  }

  const bytes = await pdf.save();
  return new File([bytes], fil.name, { type: "application/pdf" });
}

/* ---------------------------------------------------------------------
   Bilde — samme plassering, skalert etter bildets bredde
   --------------------------------------------------------------------- */

async function stempleBilde(fil, nummer) {
  const bilde = await lesBilde(fil);
  const lerret = document.createElement("canvas");
  lerret.width = bilde.naturalWidth;
  lerret.height = bilde.naturalHeight;

  const c = lerret.getContext("2d");
  c.drawImage(bilde, 0, 0);

  const storrelse = Math.max(11, Math.round(lerret.width * 0.016));
  const margin = Math.round(lerret.width * 0.03);
  const luft = Math.round(storrelse * 0.5);

  c.font = `500 ${storrelse}px -apple-system, "Segoe UI", Roboto, sans-serif`;
  c.textBaseline = "top";
  const bredde = c.measureText(nummer).width;

  const x = lerret.width - margin - bredde;
  const y = margin;

  c.fillStyle = "rgba(255,255,255,0.85)";
  c.fillRect(x - luft, y - luft * 0.6, bredde + luft * 2, storrelse + luft * 1.4);
  c.fillStyle = "rgb(10,43,51)";
  c.fillText(nummer, x, y);

  const type = fil.type === "image/jpeg" ? "image/jpeg" : "image/png";
  const blob = await new Promise(ok => lerret.toBlob(ok, type, 0.92));
  if (!blob) throw new Error("Lerretet ga ingen fil.");

  const navn = type === fil.type ? fil.name
    : fil.name.replace(/\.\w+$/, "") + (type === "image/jpeg" ? ".jpg" : ".png");
  return new File([blob], navn, { type });
}

function lesBilde(fil) {
  return new Promise((ok, nei) => {
    const url = URL.createObjectURL(fil);
    const b = new Image();
    b.onload = () => { URL.revokeObjectURL(url); ok(b); };
    b.onerror = () => { URL.revokeObjectURL(url); nei(new Error("Klarte ikke lese bildet.")); };
    b.src = url;
  });
}

function gjettType(navn = "") {
  const n = navn.toLowerCase();
  if (n.endsWith(".png")) return "image/png";
  if (n.endsWith(".webp")) return "image/webp";
  if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "image/jpeg";
  return "application/octet-stream";
}
