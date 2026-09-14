// =====================================================================
//  Innmelding — offentlig skjema for familiemedlemskap.
//  Ingen innlogging. Skriver ikke til tabeller direkte: alt går
//  gjennom RPC-en send_innmelding(), som validerer og krypterer
//  fødselsnummeret før noe lagres.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "../app/config.js";

const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false }
});

/* ---------------------------------------------------------------
   Små hjelpere — bevisst uten avhengighet til app/lib.js, siden
   den drar inn innlogging og delt tilstand denne siden ikke har.
   --------------------------------------------------------------- */

const $ = (s, r = document) => r.querySelector(s);

function el(tag, attr = {}, barn = []) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attr)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") n.className = v;
    else if (k === "html") n.innerHTML = v;
    else if (k.startsWith("on") && typeof v === "function") n.addEventListener(k.slice(2), v);
    else n.setAttribute(k, v === true ? "" : v);
  }
  for (const b of [].concat(barn)) {
    if (b === null || b === undefined || b === false) continue;
    n.append(b.nodeType ? b : document.createTextNode(String(b)));
  }
  return n;
}

const tom = (n) => { while (n.firstChild) n.removeChild(n.firstChild); return n; };

const antall = (n, ental, flertall) => `${n} ${n === 1 ? ental : flertall}`;

function felt(merkelapp, input, hint) {
  return el("label", { class: "field" }, [
    el("span", {}, merkelapp),
    input,
    hint && el("span", { class: "hint" }, hint)
  ]);
}

function tekst(verdi, attr = {}) {
  return el("input", { type: "text", value: verdi || "", ...attr });
}

function velg(valg, verdi, attr = {}) {
  const s = el("select", attr, valg.map(v =>
    el("option", { value: v.verdi ?? v }, v.tekst ?? v)
  ));
  s.value = verdi ?? "";
  return s;
}

function toast(melding, feil = false) {
  let t = $("#toast");
  if (!t) { t = el("div", { class: "toast", id: "toast" }); document.body.append(t); }
  tom(t);
  t.className = "toast show" + (feil ? " feil" : "");
  t.append(el("span", { class: "k" }, feil ? "Stopp" : "Klart"), document.createTextNode(melding));
  clearTimeout(toast._t);
  toast._t = setTimeout(() => t.classList.remove("show"), 5200);
}

/* ---------------------------------------------------------------
   Fødselsnummer — samme regler som i databasen, slik at foreldre
   får svar med én gang i stedet for en feilmelding etter innsending.
   --------------------------------------------------------------- */

const V1 = [3, 7, 6, 1, 8, 9, 4, 5, 2];
const V2 = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];

export function fodselsdatoAv(fnr) {
  const f = String(fnr || "").replace(/\s/g, "");
  if (!/^\d{11}$/.test(f)) return null;

  let dag = +f.slice(0, 2);
  const mnd = +f.slice(2, 4);
  const aar = +f.slice(4, 6);
  const ind = +f.slice(6, 9);

  if (dag >= 41 && dag <= 71) dag -= 40;              // D-nummer
  if (mnd >= 41 && mnd <= 52) return null;            // H-nummer
  if (dag < 1 || dag > 31 || mnd < 1 || mnd > 12) return null;

  let hundre;
  if (ind <= 499) hundre = 1900;
  else if (ind <= 749 && aar >= 54) hundre = 1800;
  else if (aar <= 39) hundre = 2000;
  else if (ind >= 900) hundre = 1900;
  else return null;

  const d = new Date(Date.UTC(hundre + aar, mnd - 1, dag));
  if (d.getUTCFullYear() !== hundre + aar || d.getUTCMonth() !== mnd - 1 || d.getUTCDate() !== dag) return null;
  if (d.getTime() > Date.now()) return null;
  return d.toISOString().slice(0, 10);
}

export function fnrGyldig(fnr) {
  const f = String(fnr || "").replace(/\s/g, "");
  if (!/^\d{11}$/.test(f)) return false;

  let s1 = 0, s2 = 0;
  for (let i = 0; i < 9; i++) s1 += V1[i] * +f[i];
  let k1 = 11 - (s1 % 11); if (k1 === 11) k1 = 0;
  if (k1 === 10 || k1 !== +f[9]) return false;

  for (let i = 0; i < 10; i++) s2 += V2[i] * +f[i];
  let k2 = 11 - (s2 % 11); if (k2 === 11) k2 = 0;
  if (k2 === 10 || k2 !== +f[10]) return false;

  return !!fodselsdatoAv(f);
}

export function alderAv(isoDato) {
  if (!isoDato) return null;
  const f = new Date(isoDato), n = new Date();
  let a = n.getFullYear() - f.getFullYear();
  const m = n.getMonth() - f.getMonth();
  if (m < 0 || (m === 0 && n.getDate() < f.getDate())) a--;
  return a;
}

const norskDato = (iso) =>
  iso ? new Date(iso).toLocaleDateString("nb-NO", { day: "numeric", month: "long", year: "numeric" }) : "";

/* ---------------------------------------------------------------
   Tilstand
   --------------------------------------------------------------- */

const DRAKTSTORRELSER = [
  "", "110 (4–5 år)", "120 (6–7 år)", "130 (8–9 år)", "140 (10–11 år)",
  "150 (12–13 år)", "160 (14–15 år)", "170 (S)", "180 (M)", "190 (L)", "Vet ikke"
];

let skjema = null;              // fra innmelding_skjema()
let sender = false;

const familie = {
  etternavn: "", adresse: "", postnr: "", sted: "",
  kontakt_navn: "", kontakt_epost: "", kontakt_telefon: "", notat: ""
};

let personer = [];
let nesteNokkel = 1;

function nyPerson(rolle) {
  return {
    nokkel: nesteNokkel++,
    rolle,
    fornavn: "",
    etternavn: familie.etternavn || "",
    fodselsnummer: "",
    epost: "",
    telefon: "",
    draktstorrelse: "",
    gren: "",
    samtykke_bilder: false
  };
}

/* ---------------------------------------------------------------
   Oppstart
   --------------------------------------------------------------- */

const slug = (new URLSearchParams(location.search).get("klubb") || "skoger-og-fjell")
  .toLowerCase().trim();

start();

async function start() {
  const rot = $("#rot");
  try {
    const { data, error } = await db.rpc("innmelding_skjema", { p_slug: slug });
    if (error) throw error;
    skjema = data;
  } catch (e) {
    console.error(e);
    return tom(rot).append(beskjed(
      "Fikk ikke kontakt",
      "Vi klarte ikke å hente skjemaet akkurat nå. Prøv igjen om et øyeblikk, eller ta kontakt med klubben."
    ));
  }

  if (!skjema?.funnet) {
    return tom(rot).append(beskjed(
      "Fant ikke skjemaet",
      "Lenken ser ut til å være feil eller utgått. Be klubben om en ny lenke."
    ));
  }
  if (!skjema.aapen) {
    return tom(rot).append(beskjed(
      "Innmeldingen er stengt",
      `${skjema.klubb} tar ikke imot nye innmeldinger gjennom dette skjemaet nå. Ta kontakt med klubben direkte.`
    ));
  }

  personer = [nyPerson("voksen"), nyPerson("barn")];
  tegn();
}

function beskjed(tittel, tekstInnhold) {
  return el("div", { class: "inn-wrap" }, [
    el("div", { class: "card", style: "margin-top:40px" }, [
      el("div", { class: "inn-kvittering" }, [
        el("h1", {}, tittel),
        el("p", {}, tekstInnhold)
      ])
    ])
  ]);
}

/* ---------------------------------------------------------------
   Tegning
   --------------------------------------------------------------- */

function tegn() {
  const rot = tom($("#rot"));
  rot.append(topp(), el("main", { class: "inn-wrap" }, [
    seksjonFamilie(),
    seksjonPersoner(),
    seksjonSamtykke(),
    bunntekst()
  ]), sendelinje());
  oppdaterSendelinje();
}

function topp() {
  return el("header", { class: "inn-topp" }, [
    el("div", { class: "inn-wrap" }, [
      el("div", { class: "inn-klubb" }, [
        el("span", { class: "inn-merke" }, (skjema.klubb || "K").slice(0, 1)),
        skjema.klubb
      ]),
      el("h1", {}, skjema.tittel),
      skjema.ingress && el("p", {}, skjema.ingress),
      skjema.gratis_drakt && el("span", { class: "inn-gratis" }, "Gratis medlemskap · gratis drakt til barna")
    ])
  ]);
}

function seksjon(nr, tittel, undertekst, innhold) {
  return el("section", { class: "inn-seksjon" }, [
    el("div", { class: "card" }, [
      el("div", { class: "inn-hode" }, [
        el("h2", {}, [el("span", { class: "inn-nr" }, String(nr)), tittel]),
        undertekst && el("p", {}, undertekst)
      ]),
      el("div", { class: "inn-kropp" }, innhold)
    ])
  ]);
}

function seksjonFamilie() {
  const bind = (n) => (e) => { familie[n] = e.target.value; };

  const etternavn = tekst(familie.etternavn, {
    placeholder: "Malik", autocomplete: "family-name",
    oninput: (e) => {
      const gammelt = familie.etternavn;
      familie.etternavn = e.target.value;
      // Etternavnet er som regel felles. Fyll bare der forelderen ikke
      // har overstyrt det selv.
      for (const p of personer) if (!p.etternavn || p.etternavn === gammelt) p.etternavn = e.target.value;
      tegnPersoner();
    }
  });

  return seksjon(1, "Familien", "Adressen fylles ut én gang og gjelder alle i familien.", [
    felt("Familiens etternavn", etternavn, "Blir til «Familien " + (familie.etternavn || "…") + "» i medlemsregisteret."),
    felt("Gateadresse", tekst(familie.adresse, {
      placeholder: "Storgata 12 B", autocomplete: "street-address", oninput: bind("adresse")
    })),
    el("div", { class: "inn-rad postnr" }, [
      felt("Postnr.", tekst(familie.postnr, {
        placeholder: "3050", inputmode: "numeric", maxlength: "4",
        autocomplete: "postal-code", oninput: bind("postnr")
      })),
      felt("Poststed", tekst(familie.sted, {
        placeholder: "Mjøndalen", autocomplete: "address-level2", oninput: bind("sted")
      }))
    ])
  ]);
}

function seksjonKontakt() {
  const bind = (n) => (e) => { familie[n] = e.target.value; };
  return [
    felt("Navn på foresatt", tekst(familie.kontakt_navn, {
      placeholder: "Fornavn Etternavn", autocomplete: "name", oninput: bind("kontakt_navn")
    })),
    el("div", { class: "inn-rad to" }, [
      felt("Mobil", tekst(familie.kontakt_telefon, {
        placeholder: "912 34 567", inputmode: "tel", autocomplete: "tel", oninput: bind("kontakt_telefon")
      })),
      felt("E-post", el("input", {
        type: "email", value: familie.kontakt_epost, placeholder: "navn@epost.no",
        autocomplete: "email", oninput: bind("kontakt_epost")
      }))
    ])
  ];
}

function seksjonPersoner() {
  // Personlisten tegnes på nytt når noen legges til eller fjernes.
  // Kontaktfeltene ligger utenfor, slik at de aldri mister fokus.
  const boks = el("div", { class: "inn-kropp", id: "personer" });

  const seksjonsEl = el("section", { class: "inn-seksjon" }, [
    el("div", { class: "card" }, [
      el("div", { class: "inn-hode" }, [
        el("h2", {}, [el("span", { class: "inn-nr" }, "2"), "Hvem skal meldes inn"]),
        el("p", {}, "Legg til alle i familien — voksne og barn. Alle bor på adressen over.")
      ]),
      boks,
      el("div", { class: "inn-kropp", style: "padding-top:0" }, seksjonKontakt())
    ])
  ]);

  tegnPersoner(boks);
  return seksjonsEl;
}

function tegnPersoner(boks = $("#personer"), fokusNokkel = null) {
  if (!boks) return;
  tom(boks);

  const voksne = personer.filter(p => p.rolle === "voksen");
  const barn = personer.filter(p => p.rolle === "barn");

  boks.append(...personer.map(personKort));

  boks.append(el("div", { class: "inn-legg-til" }, [
    el("button", {
      type: "button", class: "btn",
      onclick: () => { const n = nyPerson("voksen"); personer.push(n); tegnPersoner(); oppdaterSendelinje(); rullTil(n.nokkel); }
    }, "+ Legg til voksen"),
    el("button", {
      type: "button", class: "btn primary",
      onclick: () => { const n = nyPerson("barn"); personer.push(n); tegnPersoner(); oppdaterSendelinje(); rullTil(n.nokkel); }
    }, "+ Legg til barn")
  ]));

  boks.append(el("div", { class: "note info" }, [
    el("div", {}, [
      el("b", {}, `${antall(voksne.length, "voksen", "voksne")} og ${antall(barn.length, "barn", "barn")}. `),
      skjema.gratis_drakt
        ? "Alle barn i familiemedlemskapet får drakt uten kostnad — oppgi størrelse så ligger den klar."
        : "Familiemedlemskapet dekker alle som står på samme adresse."
    ])
  ]));

  // Et kort som tegnes på nytt midt i utfyllingen skal ikke stjele
  // tastaturet fra forelderen. Sett markøren tilbake der den var.
  if (fokusNokkel !== null) {
    const kort = boks.querySelector(`[data-nokkel="${fokusNokkel}"]`);
    const felt = kort?.querySelector("input[inputmode=numeric]");
    if (felt) { felt.focus(); felt.setSelectionRange(felt.value.length, felt.value.length); }
  }
}


function rullTil(nokkel) {
  const kort = document.querySelector(`[data-nokkel="${nokkel}"]`);
  if (!kort) return;
  kort.scrollIntoView({ behavior: "smooth", block: "center" });
  kort.querySelector("input")?.focus({ preventScroll: true });
}

function personKort(p) {
  const iso = fodselsdatoAv(p.fodselsnummer);
  const gyldig = fnrGyldig(p.fodselsnummer);
  const alder = alderAv(iso);
  const rentFnr = p.fodselsnummer.replace(/\s/g, "");

  const svar = el("div", { class: "inn-fnr-svar tom" }, "11 siffer. Brukes til medlemsregistrering, ikke til noe annet.");
  if (rentFnr.length === 11) {
    if (gyldig) {
      svar.className = "inn-fnr-svar ok";
      svar.textContent = `Født ${norskDato(iso)} · ${alder} år`;
    } else {
      svar.className = "inn-fnr-svar feil";
      svar.textContent = "Dette er ikke et gyldig fødselsnummer. Sjekk sifrene.";
    }
  } else if (rentFnr.length > 0) {
    svar.className = "inn-fnr-svar tom";
    svar.textContent = `${rentFnr.length} av 11 siffer`;
  }

  const fnrInput = el("input", {
    type: "text", value: p.fodselsnummer, inputmode: "numeric", maxlength: "11",
    placeholder: "11 siffer", autocomplete: "off", spellcheck: "false",
    oninput: (e) => {
      e.target.value = e.target.value.replace(/\D/g, "").slice(0, 11);
      p.fodselsnummer = e.target.value;
      const nyIso = fodselsdatoAv(p.fodselsnummer);
      const nyAlder = alderAv(nyIso);
      const nyGyldig = fnrGyldig(p.fodselsnummer);

      if (p.fodselsnummer.length === 11 && nyGyldig) {
        svar.className = "inn-fnr-svar ok";
        svar.textContent = `Født ${norskDato(nyIso)} · ${nyAlder} år`;
        // Alderen avgjør om det er barn eller voksen — ikke forelderens gjetning.
        const skalVaere = nyAlder < 18 ? "barn" : "voksen";
        if (p.rolle !== skalVaere) { p.rolle = skalVaere; tegnPersoner($("#personer"), p.nokkel); }
      } else if (p.fodselsnummer.length === 11) {
        svar.className = "inn-fnr-svar feil";
        svar.textContent = "Dette er ikke et gyldig fødselsnummer. Sjekk sifrene.";
      } else {
        svar.className = "inn-fnr-svar tom";
        svar.textContent = p.fodselsnummer.length
          ? `${p.fodselsnummer.length} av 11 siffer`
          : "11 siffer. Brukes til medlemsregistrering, ikke til noe annet.";
      }
      oppdaterSendelinje();
    }
  });

  const erBarn = p.rolle === "barn";
  const kanSlettes = personer.length > 1;

  const innhold = [
    el("div", { class: "inn-person-hode" }, [
      el("div", { class: "inn-person-tittel" }, [
        el("span", { class: "badge " + (erBarn ? "teal" : "blue") }, erBarn ? "Barn" : "Voksen"),
        p.fornavn ? `${p.fornavn} ${p.etternavn}`.trim() : (erBarn ? "Nytt barn" : "Voksen i familien")
      ]),
      kanSlettes && el("button", {
        type: "button", class: "btn sm danger",
        onclick: () => {
          personer = personer.filter(x => x.nokkel !== p.nokkel);
          tegnPersoner(); oppdaterSendelinje();
        }
      }, "Fjern")
    ]),

    el("div", { class: "inn-rad to" }, [
      felt("Fornavn", tekst(p.fornavn, {
        placeholder: "Fornavn", autocomplete: "off",
        oninput: (e) => { p.fornavn = e.target.value; oppdaterSendelinje(); }
      })),
      felt("Etternavn", tekst(p.etternavn, {
        placeholder: "Etternavn", autocomplete: "off",
        oninput: (e) => { p.etternavn = e.target.value; oppdaterSendelinje(); }
      }))
    ]),

    el("div", { class: "field" }, [
      el("span", {}, "Fødselsnummer"),
      fnrInput,
      svar
    ])
  ];

  if (skjema.grener?.length) {
    innhold.push(felt("Gren", velg(
      [{ verdi: "", tekst: "Velg gren" }, ...skjema.grener.map(g => ({ verdi: g, tekst: g }))],
      p.gren,
      { onchange: (e) => { p.gren = e.target.value; } }
    )));
  }

  if (erBarn && skjema.gratis_drakt) {
    innhold.push(felt(
      "Draktstørrelse",
      velg(DRAKTSTORRELSER.map(s => ({ verdi: s, tekst: s || "Velg størrelse" })), p.draktstorrelse, {
        onchange: (e) => { p.draktstorrelse = e.target.value; }
      }),
      "Drakten er gratis for barn i familiemedlemskapet."
    ));
  }

  if (!erBarn) {
    innhold.push(el("div", { class: "inn-rad to" }, [
      felt("Mobil (valgfritt)", tekst(p.telefon, {
        inputmode: "tel", placeholder: "912 34 567",
        oninput: (e) => { p.telefon = e.target.value; }
      })),
      felt("E-post (valgfritt)", el("input", {
        type: "email", value: p.epost, placeholder: "navn@epost.no",
        oninput: (e) => { p.epost = e.target.value; }
      }))
    ]));
  }

  innhold.push(el("label", { class: "inn-samtykke" }, [
    el("input", {
      type: "checkbox", checked: p.samtykke_bilder,
      onchange: (e) => { p.samtykke_bilder = e.target.checked; }
    }),
    el("span", {}, `Klubben kan publisere bilder og video av ${p.fornavn || (erBarn ? "barnet" : "meg")} fra trening og stevner. Samtykket kan trekkes tilbake når som helst.`)
  ]));

  return el("div", { class: "inn-person " + p.rolle, "data-nokkel": String(p.nokkel) }, innhold);
}

function seksjonSamtykke() {
  return seksjon(3, "Før du sender", null, [
    felt("Noe klubben bør vite? (valgfritt)", el("textarea", {
      rows: "3", placeholder: "For eksempel hvilken treningsgruppe barna hører til fra før.",
      oninput: (e) => { familie.notat = e.target.value; }
    })),
    el("div", { class: "note info" }, [
      el("div", {}, [
        el("b", {}, "Om fødselsnummeret. "),
        `${skjema.klubb} trenger fødselsnummer for å registrere medlemskapet i idrettens registre. `,
        "Det lagres kryptert, er bare synlig for medlemsansvarlig, hvert oppslag blir logget, og det slettes så snart medlemmet er opprettet. ",
        "Selve medlemsregisteret lagrer bare fødselsdato."
      ])
    ])
  ]);
}

function bunntekst() {
  return el("div", { class: "inn-bunn" }, [
    `${skjema.klubb}${skjema.orgnr ? " · org.nr " + skjema.orgnr : ""}`,
    el("br"),
    "Behandlingsansvarlig for opplysningene i dette skjemaet."
  ]);
}

/* ---------------------------------------------------------------
   Validering og innsending
   --------------------------------------------------------------- */

function mangler() {
  const m = [];
  if (!familie.etternavn.trim()) m.push("familiens etternavn");
  if (!familie.adresse.trim()) m.push("adresse");
  if (!/^\d{4}$/.test(familie.postnr.trim())) m.push("postnummer");
  if (!familie.sted.trim()) m.push("poststed");
  if (!familie.kontakt_navn.trim()) m.push("navn på foresatt");
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(familie.kontakt_epost.trim())) m.push("e-post");
  if (!/^\d{8,15}$/.test(familie.kontakt_telefon.replace(/\D/g, ""))) m.push("mobilnummer");
  if (!personer.length) m.push("minst én person");

  personer.forEach((p, i) => {
    const navn = p.fornavn.trim() || `person ${i + 1}`;
    if (!p.fornavn.trim() || !p.etternavn.trim()) m.push(`navn på ${navn}`);
    if (skjema.krev_fodselsnummer && !fnrGyldig(p.fodselsnummer)) m.push(`gyldig fødselsnummer for ${navn}`);
  });

  return [...new Set(m)];
}

function sendelinje() {
  return el("div", { class: "inn-send", id: "sendelinje" }, [
    el("div", { class: "inn-wrap" }, [
      el("div", { class: "inn-send-tekst", id: "sendetekst" }),
      el("button", { type: "button", class: "btn primary", id: "sendknapp", onclick: send }, "Send innmelding")
    ])
  ]);
}

function oppdaterSendelinje() {
  const t = $("#sendetekst"), k = $("#sendknapp");
  if (!t || !k) return;
  const m = mangler();
  tom(t);
  if (sender) {
    t.append("Sender …");
    k.setAttribute("disabled", "");
    return;
  }
  k.removeAttribute("disabled");
  if (!m.length) {
    const barn = personer.filter(p => p.rolle === "barn").length;
    const voksne = personer.length - barn;
    t.append(el("b", {}, "Klar til å sendes. "), `${voksne} voksne og ${barn} barn.`);
  } else {
    t.append(el("b", {}, "Mangler: "), m.slice(0, 3).join(", ") + (m.length > 3 ? ` og ${m.length - 3} til` : ""));
  }
}

async function send() {
  const m = mangler();
  if (m.length) {
    toast("Fyll ut " + m[0] + " før du sender.", true);
    oppdaterSendelinje();
    return;
  }

  sender = true;
  oppdaterSendelinje();

  try {
    const { data, error } = await db.rpc("send_innmelding", {
      p_slug: slug,
      p_familie: {
        etternavn: familie.etternavn.trim(),
        adresse: familie.adresse.trim(),
        postnr: familie.postnr.trim(),
        sted: familie.sted.trim(),
        kontakt_navn: familie.kontakt_navn.trim(),
        kontakt_epost: familie.kontakt_epost.trim(),
        kontakt_telefon: familie.kontakt_telefon.trim(),
        notat: familie.notat
      },
      p_personer: personer.map(p => ({
        rolle: p.rolle,
        fornavn: p.fornavn.trim(),
        etternavn: p.etternavn.trim(),
        fodselsnummer: p.fodselsnummer.replace(/\s/g, ""),
        epost: p.epost.trim(),
        telefon: p.telefon.trim(),
        draktstorrelse: p.draktstorrelse,
        gren: p.gren,
        samtykke_bilder: p.samtykke_bilder
      }))
    });
    if (error) throw error;
    visKvittering(data);
  } catch (e) {
    console.error(e);
    sender = false;
    oppdaterSendelinje();
    toast(e?.message?.replace(/^.*?:\s*/, "") || "Innsendingen gikk ikke. Prøv igjen.", true);
  }
}

function visKvittering(svar) {
  const barn = personer.filter(p => p.rolle === "barn").length;
  document.body.classList.remove("innmelding-side");
  tom($("#rot")).append(el("div", { class: "inn-wrap" }, [
    el("div", { class: "card", style: "margin-top:40px" }, [
      el("div", { class: "inn-kvittering" }, [
        el("div", { class: "inn-hake" }, [
          el("span", { html: '<svg viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>' })
        ]),
        el("h1", {}, "Innmeldingen er mottatt"),
        el("p", {}, `${skjema.klubb} har fått innmeldingen for ${familie.etternavn ? "familien " + familie.etternavn : "familien"}` +
          ` — ${personer.length} personer, hvorav ${barn} barn. Dere hører fra oss på ${familie.kontakt_epost} når medlemskapet er registrert.`),
        el("div", { class: "inn-referanse" }, svar?.referanse || "—"),
        el("p", { style: "margin-top:16px" },
          "Ta vare på referansen. Den gjør det raskt å finne igjen innmeldingen hvis dere lurer på noe." +
          (barn && skjema.gratis_drakt ? " Draktene deles ut på trening." : ""))
      ])
    ])
  ]));
  window.scrollTo(0, 0);
}
