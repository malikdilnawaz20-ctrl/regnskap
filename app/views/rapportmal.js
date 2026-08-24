// =====================================================================
//  Rapportdokumenter
//
//  Alle rapporter går gjennom det samme dokumentoppsettet. En rapport
//  fra Saksflyt skal kunne legges på bordet foran en revisor uten at
//  noen må forklare hvor tallene kommer fra: dokumentet oppgir selv
//  hvilken periode det dekker, hvor mange bilag som ligger bak, hva
//  som ikke er med, og hvilke kontroller som er kjørt.
//
//  Regelen for alt her inne: ingenting påstås som ikke kan utledes av
//  bilagene. Der grunnlaget mangler, står det at det mangler.
// =====================================================================

import { el, svg, kr, kr0, dato, tidspunkt, knapp, toast, visFeil, tabell,
         merke, fremdrift, tomTilstand, db } from "../lib.js";
import { S, velgFra } from "../store.js";

/* =====================================================================
   1. Dokumentrammen
   ===================================================================== */

const iDagLang = () =>
  new Date().toLocaleDateString("nb-NO", { day: "numeric", month: "long", year: "numeric" });

/**
 * Bygger ett ark. Alle rapporter bruker denne.
 *  tittel, ingress, type (vises i brevhodet), periode
 *  fakta:      [{merkelapp, verdi}]  — grunnlaget rapporten hviler på
 *  seksjoner:  DOM-noder
 *  signaturer: [{rolle, navn}] eller null
 */
export function ark({ type, periode, tittel, ingress, fakta = [], seksjoner = [], signaturer, sted }) {
  const org = S.org || {};
  const bunntekst = `${org.navn || "Organisasjon"} · ${tittel} · generert ${tidspunkt(new Date())}`;

  return el("article", { class: "ark" }, [
    el("header", { class: "ark-hode" }, [
      el("div", {}, [
        el("div", { class: "klubb" }, org.navn || "Organisasjon"),
        el("div", { class: "orgnr" }, org.orgnr ? "Organisasjonsnummer " + org.orgnr : "")
      ]),
      el("div", { class: "hoyre" }, [
        el("div", { class: "type" }, type),
        el("div", { class: "periode" }, periode)
      ])
    ]),

    el("h1", {}, tittel),
    ingress && el("p", { class: "ingress" }, ingress),

    fakta.length ? el("dl", { class: "dok-fakta" }, fakta.map(f =>
      el("div", {}, [el("dt", {}, f.merkelapp), el("dd", {}, f.verdi)]))) : null,

    ...seksjoner.filter(Boolean),

    signaturer ? signaturblokk(signaturer, sted) : null,

    el("footer", { class: "ark-bunn" }, [
      el("span", {}, bunntekst),
      el("span", {}, "Saksflyt")
    ])
  ]);
}

export function seksjon(tittel, innhold, forklaring) {
  return el("section", { class: "dok-seksjon" }, [
    tittel && el("h2", {}, tittel),
    forklaring && el("p", { class: "forklaring" }, forklaring),
    ...[].concat(innhold).filter(Boolean)
  ]);
}

function signaturblokk(signaturer, sted) {
  return el("div", { class: "signaturer" }, [
    el("div", { class: "sted" }, `${sted || S.org?.sted || "Sted"}, ${iDagLang()}`),
    el("div", { class: "rader" }, signaturer.map(s =>
      el("div", { class: "felt" }, [
        el("b", {}, s.navn || " "),
        el("span", {}, s.rolle)
      ])))
  ]);
}

/* =====================================================================
   2. Regnskapstabellen
   Rader: {type: 'gruppe'|'linje'|'mellomsum'|'sum'|'resultat', ...}
   ===================================================================== */

export function regnskapstabell(rader, { kolonner = ["Beløp"], visKonto = false } = {}) {
  const t = el("table", { class: "regnskap" });

  t.append(el("thead", {}, el("tr", {}, [
    visKonto ? el("th", { class: "konto" }, "Kto") : null,
    el("th", {}, ""),
    ...kolonner.map(k => el("th", { class: "num" }, k))
  ].filter(Boolean))));

  const kropp = el("tbody");
  for (const r of rader) {
    if (!r) continue;
    const tr = el("tr", { class: r.type === "linje" ? (r.tynn ? "tynn" : "") : r.type });
    if (visKonto) tr.append(el("td", { class: "konto" }, r.konto ? String(r.konto) : ""));
    tr.append(el("td", {}, r.tekst));
    for (const v of [].concat(r.verdier ?? [])) {
      if (v && typeof v === "object" && v.endring !== undefined) {
        tr.append(el("td", { class: "num" }, el("span", {
          class: "endring " + (v.endring > 0 ? "opp" : v.endring < 0 ? "ned" : "")
        }, v.tekst)));
      } else {
        tr.append(el("td", { class: "num" + (r.farge ? " " + r.farge : "") },
          v === null || v === undefined ? "—" : v));
      }
    }
    kropp.append(tr);
  }
  t.append(kropp);
  return t;
}

/** Kontrollpunkt med tydelig ja/nei. Dette er det revisor ser etter. */
export function kontrollpunkt(tittel, punkter) {
  const avvik = punkter.some(p => p.ok === false);
  return el("div", { class: "kontroll" + (avvik ? " avvik" : "") }, [
    el("b", {}, tittel),
    el("ul", {}, punkter.map(p =>
      el("li", {}, `${p.ok === false ? "Avvik: " : p.ok === true ? "OK: " : ""}${p.tekst}`)))
  ]);
}

export function noter(liste) {
  return el("div", { class: "noter" }, liste.filter(Boolean).map(n =>
    el("div", { class: "note" }, [el("b", {}, n.tittel), el("p", {}, n.tekst)])));
}

/* =====================================================================
   3. Datagrunnlag
   Hentes én gang og deles av alle rapportene, slik at to rapporter
   for samme periode aldri kan vise ulike tall.
   ===================================================================== */

export async function hentGrunnlag(aar) {
  const [txn, kat, kontoer, prosj, vedl, aarslaas] = await Promise.all([
    velgFra("transactions", "id,bilagsnummer,dato,type,beskrivelse,belop_ore,motpart,category_id,konto_nummer,account_id,project_id,regnskapsaar,opprettet"),
    velgFra("categories", "id,navn,retning,konto_nummer"),
    velgFra("accounts", "id,navn,type,aapningssaldo_ore,kontonummer"),
    velgFra("projects", "id,navn,tilskuddsgiver,tilskudd_ore,rapportfrist,status,start_dato,slutt_dato"),
    velgFra("attachments", "id,transaction_id"),
    velgFra("fiscal_years", "aar,laast,laast_tid")
  ]);
  for (const r of [txn, kat, kontoer, prosj, vedl, aarslaas]) if (r.error) throw r.error;

  const alle = txn.data || [];
  const aaret = a => alle.filter(t => (t.regnskapsaar ?? Number(String(t.dato).slice(0, 4))) === a);
  const medVedlegg = new Set((vedl.data || []).map(v => v.transaction_id));

  return {
    aar,
    alle,
    iAar: aaret(aar),
    iFjor: aaret(aar - 1),
    kategorier: kat.data || [],
    kontoer: kontoer.data || [],
    prosjekter: prosj.data || [],
    medVedlegg,
    laast: (aarslaas.data || []).find(f => f.aar === aar) || null,
    aarstall: [...new Set(alle.map(t => t.regnskapsaar ?? Number(String(t.dato).slice(0, 4))))].sort((a, b) => b - a)
  };
}

const sum = (liste, type) => liste.filter(t => t.type === type).reduce((s, t) => s + t.belop_ore, 0);

function perKategori(txn, kategorier, retning) {
  const kart = new Map();
  for (const t of txn.filter(x => x.type === retning)) {
    const k = kategorier.find(c => c.id === t.category_id);
    const navn = k?.navn || "Uten kategori";
    const konto = k?.konto_nummer ?? t.konto_nummer ?? null;
    const noekkel = navn + "|" + (konto ?? "");
    const rad = kart.get(noekkel) || { navn, konto, ore: 0, antall: 0 };
    rad.ore += t.belop_ore; rad.antall++;
    kart.set(noekkel, rad);
  }
  return [...kart.values()].sort((a, b) =>
    (a.konto ?? 9999) - (b.konto ?? 9999) || b.ore - a.ore);
}

const endringsTekst = (naa, foer) => {
  if (!foer) return { tekst: "—", endring: 0 };
  const pst = Math.round(((naa - foer) / Math.abs(foer)) * 100);
  return { tekst: (pst > 0 ? "+" : "") + pst + " %", endring: pst };
};

/* =====================================================================
   4. Årsregnskap — hovedrapporten
   ===================================================================== */

export function arsregnskap(g) {
  const { aar, iAar, iFjor, kategorier } = g;
  const innN = sum(iAar, "inntekt"), utN = sum(iAar, "utgift");
  const innF = sum(iFjor, "inntekt"), utF = sum(iFjor, "utgift");
  const resN = innN - utN, resF = innF - utF;
  const harIFjor = iFjor.length > 0;
  const kol = harIFjor ? [String(aar), String(aar - 1), "Endring"] : [String(aar)];
  const v = (n, f) => harIFjor ? [kr(n), kr(f), endringsTekst(n, f)] : [kr(n)];

  const inntekter = perKategori(iAar, kategorier, "inntekt");
  const utgifter = perKategori(iAar, kategorier, "utgift");
  const iFjorKat = (navn, retning) => {
    const r = perKategori(iFjor, kategorier, retning).find(x => x.navn === navn);
    return r ? r.ore : 0;
  };

  const rader = [
    { type: "gruppe", tekst: "Driftsinntekter", verdier: kol.map(() => "") },
    ...inntekter.map(r => ({
      type: "linje", konto: r.konto, tekst: r.navn, verdier: v(r.ore, iFjorKat(r.navn, "inntekt"))
    })),
    { type: "sum", tekst: "Sum driftsinntekter", verdier: v(innN, innF) },

    { type: "gruppe", tekst: "Driftskostnader", verdier: kol.map(() => "") },
    ...utgifter.map(r => ({
      type: "linje", konto: r.konto, tekst: r.navn, verdier: v(r.ore, iFjorKat(r.navn, "utgift"))
    })),
    { type: "sum", tekst: "Sum driftskostnader", verdier: v(utN, utF) },

    {
      type: "resultat", tekst: aar + "-resultat",
      farge: resN >= 0 ? "pos" : "neg", verdier: v(resN, resF)
    }
  ];

  return seksjon(
    "Resultatregnskap",
    [
      regnskapstabell(rader, { kolonner: kol, visKonto: true }),
      kontrollpunkt("Kontroll av oppstillingen", [
        {
          ok: innN - utN === resN,
          tekst: `Sum inntekter minus sum kostnader gir oppgitt resultat (${kr(innN)} − ${kr(utN)} = ${kr(resN)}).`
        },
        {
          ok: iAar.every(t => t.category_id),
          tekst: iAar.every(t => t.category_id)
            ? "Alle bilag i perioden er kategorisert."
            : `${iAar.filter(t => !t.category_id).length} av ${iAar.length} bilag mangler kategori og står under «Uten kategori».`
        },
        { tekst: `Oppstillingen bygger på ${iAar.length} bilag ført i regnskapsåret ${aar}.` }
      ])
    ],
    harIFjor
      ? `Beløp i kroner. Sammenligningstallene er hentet fra ${iFjor.length} bilag ført i ${aar - 1}.`
      : "Beløp i kroner. Det finnes ingen bilag fra året før å sammenligne med."
  );
}

/* =====================================================================
   5. Beholdning og bankavstemming
   Systemet fører enkeltsidig. Vi setter derfor ikke opp en formell
   balanse, men en beholdningsoversikt som kan avstemmes mot bank.
   Det står det også i rapporten, med vilje.
   ===================================================================== */

export function beholdning(g, faktiskSaldoOre = null) {
  const { aar, alle, kontoer } = g;
  const tom = new Date(aar, 11, 31).toISOString().slice(0, 10);
  const tilOgMed = alle.filter(t => String(t.dato) <= tom);

  const aapning = kontoer.reduce((s, k) => s + (k.aapningssaldo_ore || 0), 0);
  const inn = sum(tilOgMed, "inntekt");
  const ut = sum(tilOgMed, "utgift");
  const beregnet = aapning + inn - ut;

  const rader = [
    { type: "linje", tekst: "Registrert åpningssaldo på klubbens kontoer", verdier: [kr(aapning)] },
    { type: "linje", tekst: `Innbetalinger til og med ${dato(tom)}`, verdier: [kr(inn)] },
    { type: "linje", tekst: `Utbetalinger til og med ${dato(tom)}`, verdier: ["−" + kr(ut)] },
    { type: "resultat", tekst: "Beregnet beholdning etter bokførte bilag", verdier: [kr(beregnet)] }
  ];

  const kontoRader = kontoer.length ? seksjon("Klubbens kontoer", regnskapstabell(
    kontoer.map(k => ({
      type: "linje",
      tekst: k.navn + (k.kontonummer ? " · " + k.kontonummer : ""),
      verdier: [kr(k.aapningssaldo_ore || 0)]
    })).concat([{ type: "sum", tekst: "Sum registrert åpningssaldo", verdier: [kr(aapning)] }]),
    { kolonner: ["Åpningssaldo"] }
  ), "Åpningssaldoen er den som er registrert på kontoen i systemet.") : null;

  const avvik = faktiskSaldoOre === null ? null : faktiskSaldoOre - beregnet;

  return [
    seksjon(
      "Beholdning",
      [
        regnskapstabell(rader, { kolonner: ["Beløp"] }),
        avvik === null
          ? kontrollpunkt("Avstemming mot bank", [{
            tekst: "Det er ikke registrert noen bekreftet banksaldo for perioden. Avstemmingen er derfor ikke fullført, og beholdningen over er utledet av bokførte bilag alene."
          }])
          : kontrollpunkt("Avstemming mot bank", [
            { tekst: `Beregnet beholdning etter bilag: ${kr(beregnet)} kr.` },
            { tekst: `Bekreftet saldo fra bank: ${kr(faktiskSaldoOre)} kr.` },
            {
              ok: avvik === 0,
              tekst: avvik === 0
                ? "Bokført beholdning stemmer med banken."
                : `Differanse på ${kr(Math.abs(avvik))} kr ${avvik > 0 ? "i bankens favør" : "i regnskapets favør"}. Differansen må forklares før regnskapet avlegges.`
            }
          ])
      ],
      "Systemet fører inntekter og utgifter enkeltsidig. Oppstillingen under er derfor en beholdningsoversikt, ikke en balanse etter regnskapslovens oppstillingsplan."
    ),
    kontoRader
  ];
}

/* =====================================================================
   6. Noter
   ===================================================================== */

export function standardnoter(g) {
  const { aar, iAar, medVedlegg, laast, kategorier } = g;
  const utenVedlegg = iAar.filter(t => t.type === "utgift" && !medVedlegg.has(t.id));
  const utenKategori = iAar.filter(t => !t.category_id);
  const foerste = iAar.map(t => t.dato).sort()[0];
  const siste = iAar.map(t => t.dato).sort().slice(-1)[0];

  return seksjon("Noter", noter([
    {
      tittel: "Regnskapsprinsipper",
      tekst: `Regnskapet er ført etter kontantprinsippet: en inntekt eller kostnad er tatt med i det året den er inn- eller utbetalt. Klubben er en liten forening, og oppstillingen følger ikke regnskapslovens fullstendige oppstillingsplan. Beløp er oppgitt i hele kroner med to desimaler.`
    },
    {
      tittel: "Grunnlaget for tallene",
      tekst: iAar.length
        ? `Rapporten bygger på ${iAar.length} bilag ført i regnskapsåret ${aar}, med bilagsdato fra ${dato(foerste)} til ${dato(siste)}. Hvert tall i oppstillingen kan spores til enkeltbilag i bilagsjournalen.`
        : `Det er ikke ført bilag i regnskapsåret ${aar}.`
    },
    utenKategori.length ? {
      tittel: "Bilag uten kategori",
      tekst: `${utenKategori.length} bilag mangler kategori og er samlet under «Uten kategori» i oppstillingen. Disse bør kategoriseres før regnskapet avlegges, slik at postene havner på riktig linje.`
    } : {
      tittel: "Kategorisering",
      tekst: `Samtlige bilag i perioden er knyttet til en kategori, og hver kategori peker på en konto i klubbens kontoplan.`
    },
    {
      tittel: "Dokumentasjon av utgifter",
      tekst: utenVedlegg.length
        ? `${utenVedlegg.length} av ${iAar.filter(t => t.type === "utgift").length} utgiftsbilag mangler vedlagt kvittering eller faktura. Bokføringsloven krever dokumentasjon for hver utbetaling, og disse bør ettersendes.`
        : `Samtlige utgiftsbilag i perioden har vedlagt dokumentasjon.`
    },
    {
      tittel: "Merverdiavgift",
      tekst: `Klubben er ikke registrert i Merverdiavgiftsregisteret for denne perioden. Beløpene er derfor ført inklusive eventuell merverdiavgift, og det er ikke krevd fradrag for inngående avgift.`
    },
    {
      tittel: "Perioden",
      tekst: laast?.laast
        ? `Regnskapsåret ${aar} er låst i systemet${laast.laast_tid ? " " + tidspunkt(laast.laast_tid) : ""}. Bilag i perioden kan ikke lenger endres, kun korrigeres med nye bilag.`
        : `Regnskapsåret ${aar} er ikke låst. Bilag i perioden kan fortsatt endres, og tallene kan derfor bevege seg fram til året låses.`
    },
    {
      tittel: "Godkjenning av utbetalinger",
      tekst: `Regninger som registreres i systemet krever godkjenning fra to forskjellige personer før de kan utbetales, og godkjenningen logges på det enkelte bilaget. For bilag som er importert fra tidligere regnskapssystemer ligger godkjenningen i styrets protokoller og ikke i systemet. Rapporten viser derfor ikke godkjenner på disse enkeltbilagene; dokumentasjonen finnes i møtebøkene.`
    }
  ]));
}

/* =====================================================================
   7. Bilagsjournal — spesifikasjonen revisor faktisk leser
   ===================================================================== */

export function bilagsjournal(g, { begrensTil = null } = {}) {
  const { iAar, kategorier, medVedlegg, prosjekter } = g;
  const liste = (begrensTil ? iAar.filter(begrensTil) : iAar)
    .slice().sort((a, b) => String(a.dato).localeCompare(String(b.dato)));

  const navnKat = id => kategorier.find(k => k.id === id)?.navn || "Uten kategori";
  const navnPro = id => prosjekter.find(p => p.id === id)?.navn || "";

  const rader = liste.map(t => ({
    type: "linje",
    konto: t.bilagsnummer,
    tekst: `${dato(t.dato)}  ${t.beskrivelse}${t.motpart ? " — " + t.motpart : ""}`,
    verdier: [
      navnKat(t.category_id),
      navnPro(t.project_id) || "—",
      medVedlegg.has(t.id) ? "Ja" : "Nei",
      (t.type === "utgift" ? "−" : "") + kr(t.belop_ore)
    ]
  }));

  const innSum = sum(liste, "inntekt"), utSum = sum(liste, "utgift");
  rader.push({ type: "sum", tekst: "Sum inn", verdier: ["", "", "", kr(innSum)] });
  rader.push({ type: "sum", tekst: "Sum ut", verdier: ["", "", "", "−" + kr(utSum)] });
  rader.push({
    type: "resultat", tekst: "Netto", farge: innSum - utSum >= 0 ? "pos" : "neg",
    verdier: ["", "", "", kr(innSum - utSum)]
  });

  return seksjon(
    "Bilagsjournal",
    [
      regnskapstabell(rader, { kolonner: ["Kategori", "Prosjekt", "Bilag", "Beløp"], visKonto: true }),
      kontrollpunkt("Fullstendighet", [
        { tekst: `Journalen viser samtlige ${liste.length} bilag i perioden. Ingen bilag er utelatt eller filtrert bort.` },
        {
          ok: liste.every(t => medVedlegg.has(t.id) || t.type === "inntekt"),
          tekst: `${liste.filter(t => t.type === "utgift" && !medVedlegg.has(t.id)).length} utgiftsbilag mangler vedlegg.`
        }
      ])
    ],
    "Alle bilag i perioden, sortert på bilagsdato. Kolonnen «Bilag» viser om det ligger kvittering eller faktura vedlagt."
  );
}

/* =====================================================================
   8. Prosjektregnskap — det tilskuddsgiver får
   ===================================================================== */

export function prosjektregnskap(g, prosjekt) {
  const bilag = g.alle.filter(t => t.project_id === prosjekt.id);
  const brukt = sum(bilag, "utgift");
  const mottatt = sum(bilag, "inntekt");
  const ramme = prosjekt.tilskudd_ore || 0;
  const igjen = ramme - brukt;

  const perKat = perKategori(bilag, g.kategorier, "utgift");
  const rader = [
    { type: "gruppe", tekst: "Tilskudd og andre inntekter", verdier: [""] },
    { type: "linje", tekst: `Innvilget tilskudd${prosjekt.tilskuddsgiver ? " fra " + prosjekt.tilskuddsgiver : ""}`, verdier: [kr(ramme)] },
    { type: "linje", tekst: "Herav mottatt og bokført", verdier: [kr(mottatt)], tynn: true },
    { type: "gruppe", tekst: "Kostnader i prosjektet", verdier: [""] },
    ...perKat.map(r => ({ type: "linje", konto: r.konto, tekst: `${r.navn} (${r.antall} bilag)`, verdier: [kr(r.ore)] })),
    { type: "sum", tekst: "Sum kostnader", verdier: [kr(brukt)] },
    { type: "resultat", tekst: "Ubrukt av tilsagnet", farge: igjen >= 0 ? "pos" : "neg", verdier: [kr(igjen)] }
  ];

  const pst = ramme ? Math.round((brukt / ramme) * 100) : 0;

  return [
    seksjon(
      "Prosjektregnskap",
      [
        regnskapstabell(rader, { kolonner: ["Beløp"], visKonto: true }),
        kontrollpunkt("Kontroll", [
          { tekst: `${pst} % av tilsagnet er brukt.` },
          {
            ok: igjen >= 0,
            tekst: igjen >= 0
              ? "Kostnadene holder seg innenfor tilsagnet."
              : `Kostnadene overstiger tilsagnet med ${kr(Math.abs(igjen))} kr. Overskytende er dekket av klubbens egne midler.`
          },
          {
            ok: bilag.every(t => g.medVedlegg.has(t.id) || t.type === "inntekt"),
            tekst: `${bilag.filter(t => t.type === "utgift" && !g.medVedlegg.has(t.id)).length} av ${bilag.filter(t => t.type === "utgift").length} kostnadsbilag mangler vedlagt dokumentasjon.`
          },
          { tekst: "Samtlige kostnader er ført direkte på prosjektet, ikke fordelt med nøkkel." }
        ])
      ],
      `Alle beløp gjelder utelukkende ${prosjekt.navn}. Kostnader klubben har hatt utenfor prosjektet inngår ikke.`
    ),

    seksjon("Noter", noter([
      {
        tittel: "Avgrensning",
        tekst: `Regnskapet omfatter kun bilag som er knyttet til prosjektet i klubbens regnskapssystem. Hvert beløp kan spores til et enkeltbilag med dato, beskrivelse og mottaker i spesifikasjonen bakerst.`
      },
      {
        tittel: "Perioden",
        tekst: prosjekt.start_dato || prosjekt.slutt_dato
          ? `Prosjektet løper fra ${prosjekt.start_dato ? dato(prosjekt.start_dato) : "ikke oppgitt"} til ${prosjekt.slutt_dato ? dato(prosjekt.slutt_dato) : "ikke oppgitt"}.`
          : `Det er ikke registrert start- og sluttdato for prosjektet.`
      },
      prosjekt.rapportfrist ? {
        tittel: "Rapporteringsfrist",
        tekst: `Tilskuddsgiver har satt rapporteringsfrist ${dato(prosjekt.rapportfrist)}.`
      } : null,
      {
        tittel: "Bekreftelse",
        tekst: `Styret bekrefter at midlene er brukt i tråd med tilsagnet, og at kostnadene er dokumentert med bilag som oppbevares i klubbens regnskap.`
      }
    ])),

    bilag.length ? seksjon(
      "Spesifikasjon av kostnadene",
      regnskapstabell(
        bilag.filter(t => t.type === "utgift")
          .sort((a, b) => String(a.dato).localeCompare(String(b.dato)))
          .map(t => ({
            type: "linje", konto: t.bilagsnummer,
            tekst: `${dato(t.dato)}  ${t.beskrivelse}${t.motpart ? " — " + t.motpart : ""}`,
            verdier: [g.medVedlegg.has(t.id) ? "Ja" : "Nei", kr(t.belop_ore)]
          }))
          .concat([{ type: "sum", tekst: "Sum kostnader", verdier: ["", kr(brukt)] }]),
        { kolonner: ["Bilag", "Beløp"], visKonto: true }
      )
    ) : null
  ];
}

/* =====================================================================
   9. Ferdige dokumenter
   ===================================================================== */

export function dokumentArsregnskap(g, { faktiskSaldoOre = null } = {}) {
  const inn = sum(g.iAar, "inntekt"), ut = sum(g.iAar, "utgift");
  return [
    ark({
      type: "Årsregnskap",
      periode: `1. januar – 31. desember ${g.aar}`,
      tittel: `Årsregnskap ${g.aar}`,
      ingress: `Oppstilling av klubbens inntekter, kostnader og beholdning for regnskapsåret ${g.aar}, med noter og kontrollpunkter.`,
      fakta: [
        { merkelapp: "Regnskapsår", verdi: String(g.aar) },
        { merkelapp: "Bilag i perioden", verdi: String(g.iAar.length) },
        { merkelapp: "Resultat", verdi: kr(inn - ut) + " kr" },
        { merkelapp: "Status", verdi: g.laast?.laast ? "Året er låst" : "Året er åpent" }
      ],
      seksjoner: [
        arsregnskap(g),
        ...beholdning(g, faktiskSaldoOre),
        standardnoter(g)
      ],
      signaturer: [
        { rolle: "Styreleder", navn: "" },
        { rolle: "Kasserer", navn: "" },
        { rolle: "Revisor / kontrollutvalg", navn: "" }
      ]
    }),
    ark({
      type: "Vedlegg",
      periode: `Regnskapsåret ${g.aar}`,
      tittel: `Bilagsjournal ${g.aar}`,
      ingress: "Spesifikasjon av samtlige bilag som ligger til grunn for årsregnskapet.",
      seksjoner: [bilagsjournal(g)]
    })
  ];
}

export function dokumentProsjekt(g, prosjekt) {
  const bilag = g.alle.filter(t => t.project_id === prosjekt.id);
  return [ark({
    type: "Prosjektregnskap",
    periode: prosjekt.tilskuddsgiver || "Tilskuddsmidler",
    tittel: prosjekt.navn,
    ingress: `Regnskap for bruken av tilskuddsmidlene, med spesifikasjon av hver enkelt kostnad.`,
    fakta: [
      { merkelapp: "Tilskuddsgiver", verdi: prosjekt.tilskuddsgiver || "Ikke oppgitt" },
      { merkelapp: "Innvilget", verdi: kr0(prosjekt.tilskudd_ore || 0) + " kr" },
      { merkelapp: "Brukt", verdi: kr0(sum(bilag, "utgift")) + " kr" },
      { merkelapp: "Bilag", verdi: String(bilag.length) }
    ],
    seksjoner: prosjektregnskap(g, prosjekt),
    signaturer: [
      { rolle: "Styreleder", navn: "" },
      { rolle: "Kasserer", navn: "" },
      { rolle: "Revisor / kontrollutvalg", navn: "" }
    ]
  })];
}

export function dokumentRevisor(g) {
  const utgifter = g.iAar.filter(t => t.type === "utgift");
  const utenVedlegg = utgifter.filter(t => !g.medVedlegg.has(t.id));
  const utenKategori = g.iAar.filter(t => !t.category_id);
  const store = [...utgifter].sort((a, b) => b.belop_ore - a.belop_ore).slice(0, 10);

  return [ark({
    type: "Revisjonsgrunnlag",
    periode: `Regnskapsåret ${g.aar}`,
    tittel: `Grunnlag for revisjon ${g.aar}`,
    ingress: "Samlet oversikt over det revisor trenger for å kontrollere regnskapet: hva som er ført, hva som mangler dokumentasjon, og hvor de største beløpene ligger.",
    fakta: [
      { merkelapp: "Bilag totalt", verdi: String(g.iAar.length) },
      { merkelapp: "Uten vedlegg", verdi: String(utenVedlegg.length) },
      { merkelapp: "Uten kategori", verdi: String(utenKategori.length) },
      { merkelapp: "Året er", verdi: g.laast?.laast ? "låst" : "åpent" }
    ],
    seksjoner: [
      seksjon("Sammendrag", regnskapstabell([
        { type: "linje", tekst: "Antall bilag i perioden", verdier: [String(g.iAar.length)] },
        { type: "linje", tekst: "Herav inntektsbilag", verdier: [String(g.iAar.filter(t => t.type === "inntekt").length)] },
        { type: "linje", tekst: "Herav utgiftsbilag", verdier: [String(utgifter.length)] },
        { type: "linje", tekst: "Utgiftsbilag uten vedlagt dokumentasjon", verdier: [String(utenVedlegg.length)], farge: utenVedlegg.length ? "neg" : "pos" },
        { type: "linje", tekst: "Bilag uten kategori", verdier: [String(utenKategori.length)], farge: utenKategori.length ? "neg" : "pos" },
        { type: "sum", tekst: "Sum utbetalt i perioden", verdier: [kr(sum(g.iAar, "utgift"))] }
      ], { kolonner: ["Antall / beløp"] })),

      utenVedlegg.length ? seksjon(
        "Bilag som mangler dokumentasjon",
        regnskapstabell(utenVedlegg
          .sort((a, b) => b.belop_ore - a.belop_ore)
          .map(t => ({
            type: "linje", konto: t.bilagsnummer,
            tekst: `${dato(t.dato)}  ${t.beskrivelse}${t.motpart ? " — " + t.motpart : ""}`,
            verdier: [kr(t.belop_ore)]
          }))
          .concat([{ type: "sum", tekst: "Sum uten dokumentasjon", verdier: [kr(utenVedlegg.reduce((s, t) => s + t.belop_ore, 0))] }]),
          { kolonner: ["Beløp"], visKonto: true }),
        "Bokføringsloven krever dokumentasjon for hver utbetaling. Disse bilagene mangler kvittering eller faktura i systemet."
      ) : seksjon("Dokumentasjon", kontrollpunkt("Kontroll", [
        { ok: true, tekst: "Samtlige utgiftsbilag i perioden har vedlagt dokumentasjon." }
      ])),

      seksjon(
        "De ti største utbetalingene",
        regnskapstabell(store.map(t => ({
          type: "linje", konto: t.bilagsnummer,
          tekst: `${dato(t.dato)}  ${t.beskrivelse}${t.motpart ? " — " + t.motpart : ""}`,
          verdier: [g.medVedlegg.has(t.id) ? "Ja" : "Nei", kr(t.belop_ore)]
        })), { kolonner: ["Bilag", "Beløp"], visKonto: true }),
        "Sortert på beløp. Et naturlig utgangspunkt for stikkprøver."
      ),

      standardnoter(g)
    ],
    signaturer: [
      { rolle: "Kasserer", navn: "" },
      { rolle: "Revisor / kontrollutvalg", navn: "" },
      { rolle: "Dato for gjennomgang", navn: "" }
    ]
  })];
}

/* =====================================================================
   10. Visningen
   ===================================================================== */

const RAPPORTER = [
  {
    id: "arsregnskap", navn: "Årsregnskap", ikon: "rapport",
    for: "Årsmøtet, revisor og kontrollutvalget",
    beskrivelse: "Resultatregnskap med sammenligning mot fjoråret, beholdning, noter og signaturfelt. Bilagsjournalen følger som vedlegg.",
    bygg: (g) => dokumentArsregnskap(g)
  },
  {
    id: "revisor", navn: "Grunnlag for revisjon", ikon: "logg",
    for: "Revisor og kontrollutvalg",
    beskrivelse: "Hva som er ført, hva som mangler dokumentasjon, og de ti største utbetalingene som utgangspunkt for stikkprøver.",
    bygg: (g) => dokumentRevisor(g)
  },
  {
    id: "journal", navn: "Bilagsjournal", ikon: "dokument",
    for: "Bokettersyn og egenkontroll",
    beskrivelse: "Samtlige bilag i perioden med dato, mottaker, kategori og om det ligger vedlegg.",
    bygg: (g) => [ark({
      type: "Bilagsjournal", periode: `Regnskapsåret ${g.aar}`,
      tittel: `Bilagsjournal ${g.aar}`,
      ingress: "Samtlige bilag ført i perioden, i datorekkefølge.",
      fakta: [
        { merkelapp: "Regnskapsår", verdi: String(g.aar) },
        { merkelapp: "Antall bilag", verdi: String(g.iAar.length) },
        { merkelapp: "Sum inn", verdi: kr0(sum(g.iAar, "inntekt")) + " kr" },
        { merkelapp: "Sum ut", verdi: kr0(sum(g.iAar, "utgift")) + " kr" }
      ],
      seksjoner: [bilagsjournal(g)]
    })]
  }
];

export const rapportmalView = {
  tittel: "Rapporter",
  undertekst: "Ferdige dokumenter til årsmøtet, revisor, kontrollutvalget og tilskuddsgivere.",
  async bygg() { return bygg(); }
};

let valgtAar = null;

/** Lar andre sider lenke rett til ett prosjektregnskap: #/rapporter/<prosjekt-id> */
export async function apneProsjektrapport(prosjektId) {
  const g = await hentGrunnlag(valgtAar || new Date().getFullYear());
  const p = g.prosjekter.find(x => x.id === prosjektId);
  if (!p) return toast("Fant ikke prosjektet", "Prosjektet finnes ikke lenger.", true);
  visDokument({ navn: p.navn, bygg: (gg, valg) => dokumentProsjekt(gg, valg) }, g, p);
}

function rapportkort({ tittel, merke: merkeTekst, beskrivelse, hoyre }) {
  return el("section", { class: "card" }, el("div", { class: "card-body" },
    el("div", { class: "between", style: "align-items:flex-start;gap:18px" }, [
      el("div", { style: "max-width:60ch" }, [
        el("div", { class: "rowline", style: "margin-bottom:5px" }, [
          el("h2", { style: "font-size:1.02rem" }, tittel),
          merkeTekst && el("span", { class: "badge neutral" }, merkeTekst)
        ]),
        el("p", { class: "meta", style: "margin:0" }, beskrivelse)
      ]),
      el("div", { class: "actions", style: "align-items:center" }, hoyre)
    ])));
}

async function bygg() {
  const g0 = await hentGrunnlag(valgtAar || new Date().getFullYear());
  const aarstall = g0.aarstall.length ? g0.aarstall : [new Date().getFullYear()];
  if (!valgtAar || !aarstall.includes(valgtAar)) valgtAar = aarstall[0];
  const g = valgtAar === g0.aar ? g0 : await hentGrunnlag(valgtAar);

  const boks = el("div", { class: "stack" });

  const aarVelger = el("select", {
    style: "width:auto;min-width:120px",
    onchange: e => { valgtAar = Number(e.target.value); window.dispatchEvent(new CustomEvent("sf:tegn")); }
  }, aarstall.map(a => el("option", { value: a }, String(a))));
  aarVelger.value = String(valgtAar);

  boks.append(el("div", { class: "tabellverktoy" }, [
    el("div", { class: "field" }, [el("label", {}, "Regnskapsår"), aarVelger]),
    el("div", { style: "flex:1" }),
    el("span", { class: "meta" }, `${g.iAar.length} bilag ført i ${valgtAar}`)
  ]));

  /* --- faste rapporter --- */
  for (const r of RAPPORTER) {
    boks.append(rapportkort({
      tittel: r.navn, merke: r.for, beskrivelse: r.beskrivelse,
      hoyre: [knapp("Åpne", { klasse: "primary", ikon: "dokument", ved: () => visDokument(r, g) })]
    }));
  }

  /* --- ett prosjektregnskap per prosjekt --- */
  const prosjektKort = el("section", { class: "card" }, [
    el("div", { class: "card-head" }, el("div", { class: "between" }, [
      el("div", {}, [
        el("h2", {}, "Prosjektregnskap"),
        el("p", {}, "Ett ferdig dokument per prosjekt, klart til å sendes tilskuddsgiver.")
      ]),
      el("span", { class: "badge neutral" }, "Tilskuddsgiver")
    ])),
    el("div", { class: "card-body" }, g.prosjekter.length
      ? tabellAvProsjekter(g)
      : tomTilstand({
        tittel: "Ingen prosjekter ennå",
        tekst: "Når klubben får tilskudd, oppretter du et prosjekt. Da lager systemet regnskapet for det automatisk.",
        ikon: "prosjekt"
      }))
  ]);
  boks.append(prosjektKort);

  return boks;
}

function tabellAvProsjekter(g) {
  const rader = g.prosjekter
    .slice()
    .sort((a, b) => String(a.status).localeCompare(String(b.status)) || a.navn.localeCompare(b.navn, "nb"))
    .map(p => {
      const bilag = g.alle.filter(t => t.project_id === p.id);
      const brukt = sum(bilag, "utgift");
      const ramme = p.tilskudd_ore || 0;
      const pst = ramme ? Math.round((brukt / ramme) * 100) : 0;
      const dagerTil = p.rapportfrist
        ? Math.round((new Date(p.rapportfrist) - new Date()) / 864e5) : null;

      return el("tr", { class: "klikk", onclick: () => visDokument({ navn: p.navn, bygg: dokumentProsjekt }, g, p) }, [
        el("td", { class: "strong" }, [
          p.navn,
          el("span", { class: "who" }, p.tilskuddsgiver || "Uten oppgitt tilskuddsgiver")
        ]),
        el("td", { class: "num mono" }, ramme ? kr0(ramme) + " kr" : "—"),
        el("td", { class: "num mono" }, kr0(brukt) + " kr"),
        el("td", {}, el("div", { style: "min-width:110px" }, fremdrift({
          brukt, ramme, venstre: pst + " %", hoyre: ramme ? kr0(Math.max(0, ramme - brukt)) + " kr igjen" : ""
        }))),
        el("td", { class: "mono tiny" }, bilag.length + " bilag"),
        el("td", {}, p.rapportfrist
          ? merke(dato(p.rapportfrist), dagerTil !== null && dagerTil < 0 ? "red" : dagerTil !== null && dagerTil <= 30 ? "gold" : "neutral")
          : el("span", { class: "dim tiny" }, "Ingen frist")),
        el("td", { class: "num" }, el("button", {
          class: "btn primary sm",
          onclick: e => { e.stopPropagation(); visDokument({ navn: p.navn, bygg: dokumentProsjekt }, g, p); }
        }, "Åpne"))
      ]);
    });

  return tabell(
    [{ t: "Prosjekt" }, { t: "Tilsagn", num: true }, { t: "Brukt", num: true },
    { t: "Forbruk" }, { t: "Grunnlag" }, { t: "Rapportfrist" }, { t: "" }],
    rader
  );
}

/** Åpner dokumentet i fullskjerm med utskriftsknapp. */
function visDokument(rapport, g, valg) {
  let sider;
  try { sider = rapport.bygg(g, valg); }
  catch (e) { return visFeil(e, "Rapporten"); }

  const scene = el("div", { class: "dok-scene" });
  const lukk = () => { overlay.remove(); document.removeEventListener("keydown", esc); };
  const esc = e => { if (e.key === "Escape") lukk(); };
  document.addEventListener("keydown", esc);

  scene.append(el("div", { class: "dok-verktoy" }, [
    el("div", { class: "venstre" }, [
      knapp("Lukk", { klasse: "stille", ved: lukk }),
      el("span", { class: "meta" }, `${rapport.navn} · ${sider.length} side${sider.length === 1 ? "" : "r"}`)
    ]),
    el("div", { class: "actions" }, [
      knapp("Skriv ut eller lagre som PDF", { klasse: "primary", ikon: "last", ved: () => window.print() })
    ])
  ]));
  sider.forEach(s => scene.append(s));

  const overlay = el("div", {
    class: "overlay", style: "place-items:start center;overflow-y:auto;padding:0;background:var(--paper)"
  }, scene);
  document.body.append(overlay);
  window.scrollTo({ top: 0 });
}
