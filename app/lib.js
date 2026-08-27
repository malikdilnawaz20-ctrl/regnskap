// =====================================================================
//  Felles verktøykasse: Supabase-klient, UI-byggeklosser, formatering.
//  Alle visninger bygger på denne filen.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { SUPABASE_URL, SUPABASE_ANON_KEY, ER_KONFIGURERT } from "./config.js";
import { S, erRevisor } from "./store.js";

export const db = ER_KONFIGURERT
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: true, autoRefreshToken: true } })
  : null;

export { ER_KONFIGURERT };

/* ---------------------------------------------------------------
   DOM
   --------------------------------------------------------------- */

export const $ = (s, rot = document) => rot.querySelector(s);
export const $$ = (s, rot = document) => [...rot.querySelectorAll(s)];

/** el("div", {class:"x", onclick:fn}, ["tekst", elementer]) */
export function el(tag, attr = {}, barn = []) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attr)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") n.className = v;
    else if (k === "html") n.innerHTML = v;
    else if (k === "dataset") Object.assign(n.dataset, v);
    else if (k.startsWith("on") && typeof v === "function") n.addEventListener(k.slice(2), v);
    else n.setAttribute(k, v === true ? "" : v);
  }
  for (const b of [].concat(barn)) {
    if (b === null || b === undefined || b === false) continue;
    n.append(b.nodeType ? b : document.createTextNode(String(b)));
  }
  return n;
}

export function tom(node) { while (node.firstChild) node.removeChild(node.firstChild); return node; }

/* ---------------------------------------------------------------
   Formatering — alt regnes i øre (heltall), aldri flyttall
   --------------------------------------------------------------- */

export const kr = (ore = 0) =>
  (ore / 100).toLocaleString("nb-NO", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export const kr0 = (ore = 0) => Math.round(ore / 100).toLocaleString("nb-NO");

/** "1 234,50" eller "1234.5" → 123450 øre */
export function tilOre(tekst) {
  if (tekst === null || tekst === undefined || tekst === "") return 0;
  const rent = String(tekst).replace(/\s|kr/gi, "").replace(",", ".");
  const tall = parseFloat(rent);
  return Number.isFinite(tall) ? Math.round(tall * 100) : 0;
}

export const dato = (d) => d ? new Date(d).toLocaleDateString("nb-NO", { day: "2-digit", month: "short", year: "numeric" }) : "—";
export const datoKort = (d) => d ? new Date(d).toLocaleDateString("nb-NO", { day: "2-digit", month: "2-digit", year: "2-digit" }) : "—";
export const tidspunkt = (t) => t ? new Date(t).toLocaleString("nb-NO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }) : "—";
export const iDag = () => new Date().toISOString().slice(0, 10);

export function alder(fodselsdato) {
  if (!fodselsdato) return null;
  const f = new Date(fodselsdato), n = new Date();
  let a = n.getFullYear() - f.getFullYear();
  const m = n.getMonth() - f.getMonth();
  if (m < 0 || (m === 0 && n.getDate() < f.getDate())) a--;
  return a;
}

export const initialer = (fornavn = "", etternavn = "") =>
  ((fornavn[0] || "") + (etternavn[0] || "")).toUpperCase() || "?";

/* ---------------------------------------------------------------
   Tilbakemelding
   --------------------------------------------------------------- */

export function toast(kicker, melding, feil = false) {
  let t = $("#toast");
  if (!t) { t = el("div", { class: "toast", id: "toast" }); document.body.append(t); }
  tom(t);
  t.className = "toast show" + (feil ? " feil" : "");
  t.append(el("span", { class: "k" }, kicker), document.createTextNode(melding));
  clearTimeout(toast._t);
  toast._t = setTimeout(() => t.classList.remove("show"), 4200);
}

/** Oversett databasefeil til noe et menneske forstår. */
export function visFeil(e, hva = "Handlingen") {
  const m = String(e?.message || e || "");
  let tekst = m;
  if (/row-level security/i.test(m)) tekst = "Du har ikke tilgang til å gjøre dette. Sjekk rollen din under Brukere.";
  else if (/duplicate key|already exists|unique/i.test(m)) tekst = "Dette finnes allerede fra før.";
  else if (/violates foreign key/i.test(m)) tekst = "Noe det vises til finnes ikke lenger.";
  else if (/JWT|not authenticated|session/i.test(m)) tekst = "Innloggingen har utløpt. Logg inn på nytt.";
  else if (/Failed to fetch|NetworkError/i.test(m)) tekst = "Fikk ikke kontakt med serveren. Sjekk nettforbindelsen.";
  else if (/låst/i.test(m)) tekst = m;
  console.error(e);
  toast(hva + " gikk ikke", tekst, true);
}

export function laster(tekst = "Henter …") {
  return el("div", { class: "laster" }, [el("div", { class: "spinner" }), tekst]);
}

/* ---------------------------------------------------------------
   UI-byggeklosser
   --------------------------------------------------------------- */

export function kort({ eyebrow, tittel, beskrivelse, innhold, hoyre, klasse = "" }) {
  return el("section", { class: "card " + klasse }, [
    (eyebrow || tittel || beskrivelse || hoyre) && el("div", { class: "card-head" }, [
      el("div", { class: "between" }, [
        el("div", {}, [
          eyebrow && el("div", { class: "eyebrow" }, eyebrow),
          tittel && el("h2", {}, tittel),
          beskrivelse && el("p", {}, beskrivelse)
        ]),
        hoyre || null
      ])
    ]),
    el("div", { class: "card-body" }, innhold)
  ]);
}

export function stat({ nokkel, verdi, under, klikk, andel, farge }) {
  return el(klikk ? "button" : "div", {
    class: "stat" + (klikk ? " klikk" : ""), onclick: klikk || null
  }, [
    el("span", { class: "k" }, nokkel),
    el("span", { class: "v" + (farge ? " " + farge : "") }, verdi),
    under && el("span", { class: "m" }, under),
    andel !== undefined && el("span", { class: "bar" }, el("i", { style: `width:${Math.max(0, Math.min(100, andel))}%` }))
  ]);
}

export function pille(tekst, farge = "neutral") { return el("span", { class: "pill " + farge }, tekst); }

export function tabell(kolonner, rader, tomTekst = "Ingenting å vise ennå.") {
  if (!rader.length) return el("div", { class: "empty" }, tomTekst);
  const t = el("table", {}, [
    el("thead", {}, el("tr", {}, kolonner.map(k =>
      el("th", { class: k.num ? "num" : null }, k.t)))),
    el("tbody", {}, rader)
  ]);
  return el("div", { class: "tablewrap" }, t);
}

export function felt(label, input, hint) {
  return el("div", { class: "field" }, [el("label", {}, label), input, hint && el("span", { class: "hint" }, hint)]);
}

export function tekstfelt(navn, verdi = "", attr = {}) {
  return el("input", { type: "text", name: navn, value: verdi ?? "", ...attr });
}

export function velg(navn, valg, verdi, attr = {}) {
  const s = el("select", { name: navn, ...attr },
    valg.map(v => el("option", { value: v.verdi }, v.tekst)));
  s.value = verdi ?? (valg[0] && valg[0].verdi) ?? "";
  return s;
}

/** Modal med skjema. felter: [{navn,label,type,verdi,valg,hint,bredde}] */
export function skjemaModal({ tittel, beskrivelse, felter, lagreTekst = "Lagre", ekstra, onLagre, onSlett }) {
  return new Promise(resolve => {
    const inputs = {};
    const rad = el("div", { class: "grid g2" });

    for (const f of felter) {
      let inp;
      if (f.type === "select") inp = velg(f.navn, f.valg, f.verdi);
      else if (f.type === "textarea") inp = el("textarea", { name: f.navn, rows: f.rows || 3 }, f.verdi || "");
      else if (f.type === "checkbox") inp = el("input", { type: "checkbox", name: f.navn, checked: !!f.verdi });
      else inp = el("input", { type: f.type || "text", name: f.navn, value: f.verdi ?? "", placeholder: f.plassholder || "", step: f.step || null });
      inputs[f.navn] = inp;
      const boks = felt(f.label, inp, f.hint);
      if (f.bredde === "full") boks.style.gridColumn = "1 / -1";
      rad.append(boks);
    }

    const overlay = el("div", { class: "overlay" });
    const lukk = (v) => { overlay.remove(); document.removeEventListener("keydown", esc); resolve(v); };
    const esc = e => { if (e.key === "Escape") lukk(null); };
    document.addEventListener("keydown", esc);

    const knappLagre = el("button", { class: "btn primary" }, lagreTekst);
    knappLagre.addEventListener("click", async () => {
      const data = {};
      for (const [k, i] of Object.entries(inputs)) data[k] = i.type === "checkbox" ? i.checked : i.value.trim?.() ?? i.value;
      knappLagre.disabled = true; knappLagre.textContent = "Lagrer …";
      try {
        if (onLagre) { const ok = await onLagre(data); if (ok === false) { knappLagre.disabled = false; knappLagre.textContent = lagreTekst; return; } }
        lukk(data);
      } catch (e) { visFeil(e, "Lagring"); knappLagre.disabled = false; knappLagre.textContent = lagreTekst; }
    });

    const modal = el("div", { class: "modal" }, [
      el("div", { class: "modal-head" }, [el("h2", {}, tittel), beskrivelse && el("p", {}, beskrivelse)]),
      el("div", { class: "modal-body" }, [rad, ekstra || null]),
      el("div", { class: "modal-foot" }, [
        onSlett && el("button", {
          class: "btn danger",
          onclick: async () => { if (confirm("Er du sikker? Dette kan ikke angres.")) { try { await onSlett(); lukk("slettet"); } catch (e) { visFeil(e, "Sletting"); } } }
        }, "Slett"),
        el("button", { class: "btn", onclick: () => lukk(null) }, "Avbryt"),
        knappLagre
      ])
    ]);
    overlay.append(modal);
    overlay.addEventListener("click", e => { if (e.target === overlay) lukk(null); });
    document.body.append(overlay);
    setTimeout(() => modal.querySelector("input,select,textarea")?.focus(), 40);
  });
}

export function bekreft(tittel, tekst, knapp = "Ja, fortsett") {
  return new Promise(resolve => {
    const overlay = el("div", { class: "overlay" });
    const lukk = v => { overlay.remove(); resolve(v); };
    overlay.append(el("div", { class: "modal" }, [
      el("div", { class: "modal-head" }, [el("h2", {}, tittel), el("p", {}, tekst)]),
      el("div", { class: "modal-foot" }, [
        el("button", { class: "btn", onclick: () => lukk(false) }, "Avbryt"),
        el("button", { class: "btn primary", onclick: () => lukk(true) }, knapp)
      ])
    ]));
    overlay.addEventListener("click", e => { if (e.target === overlay) lukk(false); });
    document.body.append(overlay);
  });
}

/* ---------------------------------------------------------------
   Excel — inn og ut. Regneark er en førsteklasses funksjon,
   men aldri lagringsstedet.
   --------------------------------------------------------------- */

let XLSXlib = null;
export async function xlsx() {
  if (!XLSXlib) XLSXlib = await import("https://esm.sh/xlsx@0.18.5");
  return XLSXlib;
}

/** rader: liste med objekter. Kolonnenavn skal være lesbare for mennesker. */
export async function eksporterExcel(filnavn, ark) {
  if (erRevisor()) {
    toast("Ikke tilgjengelig", "Revisortilgang er skrivebeskyttet i visning \u2014 last ned er sl\u00e5tt av.", true);
    return;
  }
  const XLSX = await xlsx();
  const wb = XLSX.utils.book_new();
  for (const [navn, rader] of Object.entries(ark)) {
    const ws = XLSX.utils.json_to_sheet(rader.length ? rader : [{ "Ingen data": "" }]);
    const bredder = Object.keys(rader[0] || { "Ingen data": "" }).map(k => ({
      wch: Math.min(42, Math.max(k.length + 2, ...rader.slice(0, 200).map(r => String(r[k] ?? "").length + 2)))
    }));
    ws["!cols"] = bredder;
    XLSX.utils.book_append_sheet(wb, ws, navn.slice(0, 31));
  }
  XLSX.writeFile(wb, filnavn);
}

/** Leser første ark i en Excel/CSV-fil til liste med objekter. */
export async function lesExcel(fil) {
  const XLSX = await xlsx();
  const buf = await fil.arrayBuffer();
  const wb = XLSX.read(buf, { cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  return XLSX.utils.sheet_to_json(ws, { defval: "", raw: false });
}

/* ---------------------------------------------------------------
   Ikoner
   --------------------------------------------------------------- */

export const IKON = {
  oversikt:  '<rect x="3" y="3" width="7.5" height="8.5" rx="2"/><rect x="13.5" y="3" width="7.5" height="5.5" rx="2"/><rect x="3" y="15" width="7.5" height="6" rx="2"/><rect x="13.5" y="11.5" width="7.5" height="9.5" rx="2"/>',
  medlemmer: '<circle cx="9" cy="8" r="3.2"/><path d="M2.8 20c0-3.4 2.8-5.2 6.2-5.2s6.2 1.8 6.2 5.2"/><path d="M17.2 10.8a2.6 2.6 0 1 0 0-5.2M21.2 20c0-2.6-1.6-4.2-4.2-4.4"/>',
  aktivitet: '<path d="M3.5 18.5 9 8.5l3.2 5.2L15 10l5.5 8.5z"/><circle cx="6.5" cy="5" r="1.7"/>',
  betaling:  '<rect x="2.5" y="5.5" width="19" height="13" rx="2.5"/><path d="M2.5 10h19"/><path d="M6 14.5h3.5"/>',
  okonomi:   '<path d="M4 19.5V11M9.3 19.5V5.5M14.7 19.5v-6M20 19.5V8.5"/><path d="M2.5 21.5h19"/>',
  prosjekt:  '<path d="M3 7.5h5.5l2 2.2H21v9.3a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 19z"/><path d="M3 7.5v-2A1.5 1.5 0 0 1 4.5 4h4l2 2.2"/>',
  dokument:  '<path d="M6.5 2.8h7.2l4.8 4.9v13.5H6.5z"/><path d="M13.7 2.8v4.9h4.8"/><path d="M9.5 13h6M9.5 16.5h4"/>',
  rapport:   '<path d="M12 3.2a8.8 8.8 0 1 0 8.8 8.8H12z"/><path d="M14.5 2.2A7.5 7.5 0 0 1 21.8 9.5h-7.3z"/>',
  innstilling:'<circle cx="12" cy="12" r="3.1"/><path d="M19.3 14.6a1.6 1.6 0 0 0 .32 1.76l.06.06a1.94 1.94 0 1 1-2.74 2.74l-.06-.06a1.6 1.6 0 0 0-1.76-.32 1.6 1.6 0 0 0-.97 1.47v.17a1.94 1.94 0 1 1-3.88 0v-.09a1.6 1.6 0 0 0-1.05-1.47 1.6 1.6 0 0 0-1.76.32l-.06.06a1.94 1.94 0 1 1-2.74-2.74l.06-.06a1.6 1.6 0 0 0 .32-1.76 1.6 1.6 0 0 0-1.47-.97h-.17a1.94 1.94 0 1 1 0-3.88h.09a1.6 1.6 0 0 0 1.47-1.05 1.6 1.6 0 0 0-.32-1.76l-.06-.06a1.94 1.94 0 1 1 2.74-2.74l.06.06a1.6 1.6 0 0 0 1.76.32h.08a1.6 1.6 0 0 0 .97-1.47v-.17a1.94 1.94 0 1 1 3.88 0v.09a1.6 1.6 0 0 0 .97 1.47 1.6 1.6 0 0 0 1.76-.32l.06-.06a1.94 1.94 0 1 1 2.74 2.74l-.06.06a1.6 1.6 0 0 0-.32 1.76v.08a1.6 1.6 0 0 0 1.47.97h.17a1.94 1.94 0 1 1 0 3.88h-.09a1.6 1.6 0 0 0-1.47.97z"/>',
  hjelp:     '<circle cx="12" cy="12" r="9"/><path d="M9.4 9.3a2.7 2.7 0 0 1 5.25.9c0 1.8-2.7 2.7-2.7 2.7"/><path d="M12 17.2h.01"/>',
  bruker:    '<circle cx="12" cy="8" r="3.6"/><path d="M4.8 20.2c0-4 3.2-6.2 7.2-6.2s7.2 2.2 7.2 6.2"/>',
  logg:      '<path d="M12 2.8 5 5.8v6.4c0 4.4 2.9 7.4 7 8.9 4.1-1.5 7-4.5 7-8.9V5.8z"/><path d="M9.4 12.1l1.9 1.9 3.5-3.6"/>',
  pluss:     '<path d="M12 5v14M5 12h14"/>',
  sok:       '<circle cx="10.8" cy="10.8" r="6.6"/><path d="M20 20l-4.6-4.6"/>',
  pil:       '<path d="M9 5.5 15.5 12 9 18.5"/>',
  ned:       '<path d="M6 9.5 12 15.5 18 9.5"/>',
  varsel:    '<path d="M12 3.6 2.8 20h18.4z"/><path d="M12 10v4M12 17h.01"/>',
  info:      '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.8h.01"/>',
  ok:        '<circle cx="12" cy="12" r="9"/><path d="m8.2 12.3 2.6 2.6 5-5.4"/>',
  ut:        '<path d="M15 4.5h3.5A1.5 1.5 0 0 1 20 6v12a1.5 1.5 0 0 1-1.5 1.5H15"/><path d="M10 16.5 5.5 12 10 7.5M5.5 12H16"/>',
  opp:       '<path d="M12 19V6M6 11.5 12 5.5l6 6"/>',
  last:      '<path d="M12 15.5V4.5M7.5 9 12 4.5 16.5 9"/><path d="M4.5 15.5v3A1.5 1.5 0 0 0 6 20h12a1.5 1.5 0 0 0 1.5-1.5v-3"/>',
  kvittering:'<path d="M5.5 3.2h13v18l-2.2-1.6-2.2 1.6-2.2-1.6-2.2 1.6-2.2-1.6z"/><path d="M9 8h6M9 12h6"/>',
  kalender:  '<rect x="3.2" y="5" width="17.6" height="16" rx="2.4"/><path d="M3.2 10h17.6M8 3v4M16 3v4"/>',
  bygg:      '<path d="M3.5 21h17M5 21V7.5l7-4.5 7 4.5V21"/><path d="M10 21v-5h4v5"/>'
};

export const ikon = (navn) => el("span", { class: "ico", html: svg(navn) });
export const svg = (navn) => `<svg viewBox="0 0 24 24" aria-hidden="true">${IKON[navn] || IKON.oversikt}</svg>`;

/* ---------------------------------------------------------------
   Tema
   --------------------------------------------------------------- */

export function settOppTema() {
  const rot = document.documentElement;
  try { const t = localStorage.getItem("sf-tema"); if (t) rot.setAttribute("data-theme", t); } catch { }
  const knapp = el("button", {
    class: "themetoggle", title: "Bytt lys/mørk",
    html: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4.5"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    onclick: () => {
      const naa = rot.getAttribute("data-theme");
      const sysMork = matchMedia("(prefers-color-scheme: dark)").matches;
      const erMork = naa ? naa === "dark" : sysMork;
      const ny = erMork ? "light" : "dark";
      rot.setAttribute("data-theme", ny);
      try { localStorage.setItem("sf-tema", ny); } catch { }
    }
  });
  document.body.append(knapp);
}

/* ---------------------------------------------------------------
   Komponenter i designsystemet
   Én implementasjon per komponent. Ingen lokale varianter per side.
   --------------------------------------------------------------- */

/** Stort nøkkeltall. ikon er et navn fra IKON. */
export function kpi({ nokkel, verdi, under, ikon: ikonNavn, klikk, andel, farge }) {
  return el(klikk ? "button" : "div", { class: "kpi" + (klikk ? " klikk" : ""), onclick: klikk || null }, [
    el("div", { class: "topp" }, [
      ikonNavn && el("span", { html: svg(ikonNavn) }),
      el("span", { class: "k" }, nokkel)
    ]),
    el("div", { class: "v" + (farge ? " " + farge : "") }, verdi),
    under && el("div", { class: "m" }, under),
    andel !== undefined && el("div", { class: "bar" }, el("i", { style: `width:${Math.max(0, Math.min(100, andel))}%` }))
  ]);
}

export const merke = (tekst, farge = "neutral") => el("span", { class: "badge " + farge }, tekst);

/** Rad i «Trenger oppmerksomhet». Hver rad peker på neste handling. */
export function oppmRad({ tittel, undertekst, farge = "gold", ikon: ikonNavn = "varsel", klikk }) {
  return el("button", { class: "oppm-rad", onclick: klikk || null }, [
    el("span", { class: "merke " + farge, html: svg(ikonNavn) }),
    el("span", { class: "tekst" }, [el("b", {}, tittel), undertekst && el("span", {}, undertekst)]),
    el("span", { class: "pil", html: svg("pil") })
  ]);
}

export function oppmListe(rader) {
  if (!rader.length) {
    return el("div", { class: "empty" }, [
      el("div", { class: "sirkel", html: svg("ok") }),
      el("b", {}, "Alt er i orden"),
      el("p", {}, "Ingenting krever din oppmerksomhet akkurat nå.")
    ]);
  }
  return el("div", { class: "oppm" }, rader);
}

/** Verktøylinje over en tabell: søk + filtre + én primærhandling. */
export function verktoylinje({ sok, filtre = [], handling }) {
  const boks = el("div", { class: "tabellverktoy" });
  if (sok) {
    boks.append(el("div", { class: "sok" }, [
      el("span", { html: svg("sok") }),
      el("input", {
        type: "search", placeholder: sok.plassholder || "Søk …", value: sok.verdi || "",
        oninput: e => sok.ved(e.target.value)
      })
    ]));
  }
  filtre.forEach(f => boks.append(f));
  if (handling) boks.append(handling);
  return boks;
}

/** Vennlig tom tilstand med neste handling. */
export function tomTilstand({ tittel, tekst, ikon: ikonNavn = "info", handlinger = [] }) {
  return el("div", { class: "empty" }, [
    el("div", { class: "sirkel", html: svg(ikonNavn) }),
    el("b", {}, tittel),
    tekst && el("p", {}, tekst),
    handlinger.length ? el("div", { class: "actions" }, handlinger) : null
  ]);
}

/** Faner. faner: [{id, tekst}] */
export function fanerad(faner, aktiv, ved) {
  return el("div", { class: "faner" }, faner.map(f =>
    el("button", { class: f.id === aktiv ? "on" : "", onclick: () => ved(f.id) }, f.tekst)));
}

/** Sidepanel som glir inn fra høyre. Returnerer {lukk}. */
export function skuff({ tittel, undertittel, innhold, bunn }) {
  const overlay = el("div", { class: "overlay", style: "place-items:stretch;justify-items:end;padding:0" });
  const lukk = () => { overlay.remove(); document.removeEventListener("keydown", esc); };
  const esc = e => { if (e.key === "Escape") lukk(); };
  document.addEventListener("keydown", esc);

  overlay.append(el("aside", { class: "skuff" }, [
    el("div", { class: "skuff-head" }, [
      el("div", { class: "between" }, [
        el("div", {}, [el("h2", {}, tittel), undertittel && el("p", { class: "sub" }, undertittel)]),
        el("button", { class: "ikonknapp", onclick: lukk, title: "Lukk", html: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>' })
      ])
    ]),
    el("div", { class: "skuff-body" }, innhold),
    bunn && el("div", { class: "skuff-foot" }, bunn)
  ]));
  overlay.addEventListener("click", e => { if (e.target === overlay) lukk(); });
  document.body.append(overlay);
  return { lukk, overlay };
}

/** Nedtrekksmeny. valg: [{tekst, ikon, ved}] eller "skille". */
export function nedtrekk(knapp, valg) {
  const boks = el("div", { class: "meny" });
  let apen = null;
  const lukk = () => { apen?.remove(); apen = null; document.removeEventListener("click", utenfor, true); };
  const utenfor = e => { if (!boks.contains(e.target)) lukk(); };

  knapp.addEventListener("click", e => {
    e.stopPropagation();
    if (apen) return lukk();
    apen = el("div", { class: "meny-liste" }, valg.map(v =>
      v === "skille" ? el("hr") : el("button", {
        onclick: () => { lukk(); v.ved(); }
      }, [v.ikon && el("span", { html: svg(v.ikon) }), v.tekst])
    ));
    boks.append(apen);
    setTimeout(() => document.addEventListener("click", utenfor, true), 0);
  });
  boks.append(knapp);
  return boks;
}

/** Fremdriftslinje for prosjekter. */
export function fremdrift({ brukt, ramme, venstre, hoyre }) {
  const pst = ramme > 0 ? Math.min(100, Math.round((brukt / ramme) * 100)) : 0;
  const klasse = pst > 100 ? " over" : pst >= 85 ? " nesten" : "";
  return el("div", { class: "fremdrift" }, [
    el("div", { class: "spor" }, el("i", { class: klasse.trim(), style: `width:${pst}%` })),
    el("div", { class: "tall" }, [el("span", {}, venstre), el("span", {}, hoyre)])
  ]);
}

/** Laste-skjelett i stedet for tom skjerm. */
export function skjelett(type = "kpi", antall = 1) {
  const boks = el("div", { class: type === "kpi" ? "grid g4" : "stack" });
  for (let i = 0; i < antall; i++) boks.append(el("div", { class: "skjelett " + type }));
  return boks;
}

/** Knapp med ikon. */
export function knapp(tekst, { ikon: ikonNavn, klasse = "", ved, tittel } = {}) {
  return el("button", { class: "btn " + klasse, onclick: ved || null, title: tittel || null },
    [ikonNavn && el("span", { html: svg(ikonNavn) }), tekst]);
}

/** «1 medlem» / «8 medlemmer» — riktig entall og flertall. */
export const antall = (n, ental, flertall) => `${n} ${n === 1 ? ental : flertall}`;
