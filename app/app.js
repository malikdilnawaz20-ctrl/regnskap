// =====================================================================
//  Saksflyt — skall, navigasjon, innlogging og forside.
//  Denne filen eier designsystemets ramme. Visningene eier innholdet.
// =====================================================================

import {
  el, tom, $, svg, kort, kpi, merke, tabell, felt, skjemaModal, bekreft, toast, visFeil, antall,
  laster, skjelett, kr, kr0, dato, tidspunkt, initialer, nedtrekk, knapp,
  oppmRad, oppmListe, tomTilstand, fremdrift, verktoylinje, fanerad, skuff,
  settOppTema, db, ER_KONFIGURERT, eksporterExcel
} from "./lib.js";

import {
  S, ROLLER, VERV, erAdmin, kanOkonomi, kanMedlem, kanSkrive, erRevisor,
  hentBruker, hentOrganisasjoner, settOrg, velgFra, settInn, paaNytt, aarNaa
} from "./store.js";

import { medlemmerView, aktiviteterView, familierView } from "./views/medlemmer.js";
import { okonomiView, prosjekterView, rapporterView, kontingentView, hentOkonomiTall, registrerModal } from "./views/okonomi.js?v=20260827-1705";
import { honorarerView } from "./views/honorarer.js?v=20260827-2350";
import { attesteringView, hentAttesteringTall } from "./views/attestering.js";
import { fakturaView, kunderView, hentFakturaTall } from "./views/faktura.js";
import { rapportmalView } from "./views/rapportmal.js?v=20260827-1705";
import { MERKE } from "./config.js";

/* =====================================================================
   Navigasjon — organisert etter hva brukeren vil gjøre,
   ikke etter regnskapstekniske prosesser.
   ===================================================================== */

const RUTER = {
  oversikt:    { tittel: "Oversikt", ikon: "oversikt" },
  medlemmer:   { tittel: "Medlemmer", ikon: "medlemmer", view: () => medlemmerView },
  aktiviteter: { tittel: "Aktiviteter", ikon: "aktivitet", view: () => aktiviteterView },
  familier:    { tittel: "Familier", ikon: "medlemmer", view: () => familierView, skjult: true },
  betalinger:  { tittel: "Betalinger", ikon: "betaling", view: () => kontingentView },
  okonomi:     { tittel: "Økonomi", ikon: "okonomi", view: () => okonomiView },
  honorarer:   { tittel: "Honorarer", ikon: "betaling", view: () => honorarerView },
  attestering: { tittel: "Attestering", ikon: "ok", view: () => attesteringView, under: "okonomi" },
  faktura:     { tittel: "Faktura", ikon: "kvittering", view: () => fakturaView },
  kunder:      { tittel: "Kunder", ikon: "medlemmer", view: () => kunderView, under: "faktura" },
  regnskapsrapporter: { tittel: "Regnskapsrapporter", ikon: "rapport", view: () => rapporterView, under: "okonomi" },
  prosjekter:  { tittel: "Prosjekter", ikon: "prosjekt", view: () => prosjekterView },
  dokumenter:  { tittel: "Dokumenter", ikon: "dokument" },
  rapporter:   { tittel: "Rapporter", ikon: "rapport", view: () => rapportmalView },
  innstillinger: { tittel: "Innstillinger", ikon: "innstilling" },
  brukere:     { tittel: "Brukere", ikon: "bruker", under: "innstillinger" },
  selskap:     { tittel: "Selskapsinformasjon", ikon: "bygg", under: "innstillinger" },
  revisjonsspor: { tittel: "Revisjonsspor", ikon: "logg", under: "innstillinger" },
  hjelp:       { tittel: "Hjelp", ikon: "hjelp" },
  profil:      { tittel: "Min profil", ikon: "bruker", skjult: true }
};

const HOVEDNAV = [
  { gruppe: null, punkter: ["oversikt"] },
  { gruppe: "Klubben", punkter: ["medlemmer", "aktiviteter", "betalinger"] },
  { gruppe: "Penger", punkter: ["okonomi", "honorarer", "faktura", "prosjekter", "rapporter"] },
  { gruppe: "Arkiv", punkter: ["dokumenter"] }
];

const OKONOMI_UNDER = ["attestering", "regnskapsrapporter"];
const INNST_UNDER = ["selskap", "brukere", "revisjonsspor"];

/** Revisor har kun lesetilgang til tall og bilag \u2014 ingen medlemsdata, ingen innstillinger, ingen eksport. */
const REVISOR_RUTER = ["oversikt", "okonomi", "regnskapsrapporter", "rapporter", "hjelp", "profil"];

let ruteNaa = "oversikt";
let okonomiApen = false;
let innstApen = false;

/* =====================================================================
   Oppstart
   ===================================================================== */

const rot = document.getElementById("rot");

settOppTema();
window.Saksflyt?.settOppArbeider();
window.addEventListener("saksflyt:kan-installeres", () => tegn());
window.addEventListener("sf:tegn", () => tegn());
window.addEventListener("hashchange", () => { lesRute(); tegn(); });

start();

async function start() {
  if (!ER_KONFIGURERT) return visIkkeKonfigurert();
  tom(rot).append(laster("Starter Saksflyt …"));
  try {
    const bruker = await hentBruker();
    if (!bruker) return visInnlogging();
    await hentOrganisasjoner();
    db.auth.onAuthStateChange((hendelse) => {
      if (hendelse === "SIGNED_OUT") location.reload();
    });
    lesRute();
    tegn();
  } catch (e) {
    visFeil(e, "Oppstart");
    tom(rot).append(el("div", { class: "auth" },
      el("div", { class: "auth-card" }, [
        el("h1", {}, "Kom ikke i gang"),
        el("p", { class: "sub" }, "Klarte ikke å hente dataene dine. Sjekk nettforbindelsen og prøv igjen."),
        knapp("Prøv på nytt", { klasse: "primary", ved: () => location.reload() })
      ])));
  }
}

function lesRute() {
  const del = location.hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  const kandidat = del[del.length - 1];
  if (kandidat && RUTER[kandidat]) ruteNaa = kandidat;
  else if (!RUTER[ruteNaa]) ruteNaa = "oversikt";
  if (erRevisor() && !REVISOR_RUTER.includes(ruteNaa)) ruteNaa = "oversikt";
  if (OKONOMI_UNDER.includes(ruteNaa)) okonomiApen = true;
  if (INNST_UNDER.includes(ruteNaa)) innstApen = true;
}

function gaTil(rute) {
  if (erRevisor() && !REVISOR_RUTER.includes(rute)) rute = "oversikt";
  ruteNaa = rute;
  location.hash = "#/" + rute;
  tegn();
  window.scrollTo({ top: 0, behavior: "instant" });
}

/* =====================================================================
   Oppsett mangler
   ===================================================================== */

function visIkkeKonfigurert() {
  tom(rot).append(el("div", { class: "auth" },
    el("div", { class: "auth-card" }, [
      el("div", { class: "sb-logo" }, "S"),
      el("h1", {}, "Nesten klar"),
      el("p", { class: "sub" }, "Legg inn Supabase-adressen og anon-nøkkelen i app/config.js, så starter systemet."),
      el("div", { class: "note info" }, el("div", {}, [
        el("b", {}, "Slik gjør du det: "),
        "Åpne Supabase → Project Settings → API. Kopier «Project URL» og «anon public» inn i filen app/config.js, og last siden på nytt."
      ]))
    ])));
}

/* =====================================================================
   Innlogging
   ===================================================================== */

function visInnlogging() {
  let modus = "logg-inn";

  const tegnAuth = () => {
    const epost = el("input", { type: "email", autocomplete: "email", placeholder: "navn@klubben.no" });
    const passord = el("input", { type: "password", autocomplete: modus === "logg-inn" ? "current-password" : "new-password", placeholder: "Passord" });
    const fornavn = el("input", { type: "text", placeholder: "Fornavn" });
    const etternavn = el("input", { type: "text", placeholder: "Etternavn" });
    const knappen = el("button", { class: "btn primary blokk" }, modus === "logg-inn" ? "Logg inn" : "Opprett konto");
    const beskjed = el("div", {});

    async function send() {
      const e = epost.value.trim(), p = passord.value;
      if (!e || !p) { beskjed.replaceChildren(el("div", { class: "note bad" }, "Fyll inn både e-post og passord.")); return; }
      knappen.disabled = true; knappen.textContent = "Et øyeblikk …";
      try {
        if (modus === "logg-inn") {
          const { error } = await db.auth.signInWithPassword({ email: e, password: p });
          if (error) throw error;
          location.reload();
        } else {
          const { error } = await db.auth.signUp({
            email: e, password: p,
            options: { data: { fornavn: fornavn.value.trim(), etternavn: etternavn.value.trim() } }
          });
          if (error) throw error;
          beskjed.replaceChildren(el("div", { class: "note ok" },
            el("div", {}, [el("b", {}, "Kontoen er opprettet. "), "Sjekk e-posten din hvis vi ber om bekreftelse, og logg deretter inn."])));
          modus = "logg-inn"; tegnAuth();
        }
      } catch (err) {
        const m = String(err.message || err);
        const norsk = /Invalid login/i.test(m) ? "Feil e-post eller passord."
          : /already registered/i.test(m) ? "Det finnes allerede en konto på denne e-posten. Logg inn i stedet."
            : /Password should be/i.test(m) ? "Passordet må ha minst 6 tegn."
              : /Email not confirmed/i.test(m) ? "E-posten er ikke bekreftet ennå. Sjekk innboksen din."
                : m;
        beskjed.replaceChildren(el("div", { class: "note bad" }, norsk));
        knappen.disabled = false; knappen.textContent = modus === "logg-inn" ? "Logg inn" : "Opprett konto";
      }
    }

    knappen.addEventListener("click", send);
    [epost, passord].forEach(i => i.addEventListener("keydown", ev => { if (ev.key === "Enter") send(); }));

    tom(rot).append(el("div", { class: "auth" },
      el("div", { class: "auth-card" }, [
        el("div", { class: "sb-logo" }, "S"),
        el("h1", {}, MERKE.navn),
        el("p", { class: "sub" }, "Medlemmer, økonomi og prosjekter for foreninger og idrettslag."),
        el("div", { class: "tabs" }, [
          el("button", { class: modus === "logg-inn" ? "on" : "", onclick: () => { modus = "logg-inn"; tegnAuth(); } }, "Logg inn"),
          el("button", { class: modus === "ny" ? "on" : "", onclick: () => { modus = "ny"; tegnAuth(); } }, "Ny bruker")
        ]),
        el("div", { class: "stack", style: "gap:13px" }, [
          modus === "ny" && el("div", { class: "grid g2", style: "gap:13px" }, [
            felt("Fornavn", fornavn), felt("Etternavn", etternavn)
          ]),
          felt("E-post", epost),
          felt("Passord", passord, modus === "ny" ? "Minst 6 tegn." : null),
          beskjed,
          knappen,
          modus === "logg-inn" && el("button", {
            class: "btn stille blokk", onclick: async () => {
              const e = epost.value.trim();
              if (!e) return toast("Skriv e-posten din", "Fyll inn e-postadressen først, så sender vi en lenke.", true);
              try {
                const { error } = await db.auth.resetPasswordForEmail(e, { redirectTo: location.href });
                if (error) throw error;
                toast("Sendt", "Vi har sendt en lenke for nytt passord til " + e + ".");
              } catch (err) { visFeil(err, "Sending"); }
            }
          }, "Glemt passord?")
        ])
      ])));
  };
  tegnAuth();
}

/* =====================================================================
   Ingen organisasjon ennå — enkel oppstart
   ===================================================================== */

function visOnboarding() {
  tom(rot).append(el("div", { class: "auth" },
    el("div", { class: "auth-card", style: "width:min(560px,100%)" }, [
      el("div", { class: "sb-logo" }, "S"),
      el("h1", {}, "Velkommen, " + (S.bruker.fornavn || "").trim()),
      el("p", { class: "sub" }, "Du er ikke koblet til noen organisasjon ennå. Opprett din egen, eller be en administrator invitere deg med e-postadressen " + S.bruker.epost + "."),
      el("div", { class: "actions", style: "margin-top:20px" }, [
        knapp("Opprett organisasjon", { klasse: "primary", ikon: "pluss", ved: nyOrganisasjon }),
        knapp("Logg ut", { klasse: "stille", ved: () => db.auth.signOut() })
      ])
    ])));
}

async function nyOrganisasjon() {
  const svar = await skjemaModal({
    tittel: "Opprett organisasjon",
    beskrivelse: "Du kan endre alt dette senere under Innstillinger.",
    felter: [
      { navn: "navn", label: "Hva heter organisasjonen?", plassholder: "Skoger og Fjell kampsportklubb", bredde: "full" },
      { navn: "orgnr", label: "Organisasjonsnummer", plassholder: "912484335" },
      {
        navn: "type", label: "Hva slags organisasjon?", type: "select", valg: [
          { verdi: "idrettslag", tekst: "Idrettslag" },
          { verdi: "forening", tekst: "Forening" },
          { verdi: "kulturorganisasjon", tekst: "Kulturorganisasjon" },
          { verdi: "velforening", tekst: "Velforening" },
          { verdi: "annet", tekst: "Annet" }
        ]
      }
    ],
    lagreTekst: "Opprett",
    onLagre: async (d) => {
      if (!d.navn) { toast("Mangler navn", "Skriv inn navnet på organisasjonen.", true); return false; }
      const { data, error } = await db.from("organizations")
        .insert({ navn: d.navn, orgnr: d.orgnr || null, type: d.type }).select().single();
      if (error) throw error;
      const { error: e2 } = await db.from("organization_users")
        .insert({ organization_id: data.id, user_id: S.bruker.id, rolle: "administrator", styreverv: "Styreleder" });
      if (e2) throw e2;
      return true;
    }
  });
  if (svar) { await hentOrganisasjoner(); toast("Opprettet", "Organisasjonen er klar. Kontoplan og kategorier er lagt inn automatisk."); tegn(); }
}

/* =====================================================================
   Skallet
   ===================================================================== */

function tegn() {
  if (!S.bruker) return visInnlogging();
  if (!S.orgId) return visOnboarding();

  tom(rot);
  const innhold = el("div", { id: "innhold" });
  rot.append(el("div", { class: "app" }, [byggSidepanel(), el("main", { class: "main" }, [byggTopp(), innhold])]));
  rot.append(byggMobilnav());
  tegnInnhold(innhold);
}

function byggSidepanel() {
  const orgvelger = el("select", {
    class: "orgpick", "aria-label": "Velg organisasjon",
    onchange: e => { settOrg(e.target.value); ruteNaa = "oversikt"; tegn(); }
  }, S.organisasjoner.map(o => el("option", { value: o.organization_id }, o.org.navn)));
  orgvelger.value = S.orgId;

  const punkt = (id, ekstraKlasse = "") => {
    const r = RUTER[id];
    return el("button", {
      class: "sb-item" + (ruteNaa === id ? " on" : "") + ekstraKlasse,
      onclick: () => gaTil(id)
    }, [el("span", { html: svg(r.ikon) }), r.tittel]);
  };

  const nav = el("nav", { class: "sidebar" });
  nav.append(
    el("div", { class: "sb-brand" }, [
      el("div", { class: "sb-logo" }, "S"),
      el("div", {}, [el("b", {}, MERKE.navn), el("span", {}, modulNavn())])
    ]),
    orgvelger
  );

  const revisorTilgang = erRevisor();
  const okonomiUnderSynlig = revisorTilgang ? OKONOMI_UNDER.filter(u => REVISOR_RUTER.includes(u)) : OKONOMI_UNDER;

  for (const g of HOVEDNAV) {
    const punkterSynlig = revisorTilgang ? g.punkter.filter(id => REVISOR_RUTER.includes(id)) : g.punkter;
    if (!punkterSynlig.length) continue;
    const boks = el("div", { class: "sb-group" });
    if (g.gruppe) boks.append(el("h4", {}, g.gruppe));
    for (const id of punkterSynlig) {
      boks.append(punkt(id));
      if (id === "okonomi" && okonomiUnderSynlig.length) {
        boks.append(el("button", {
          class: "sb-item", style: "padding-top:4px;padding-bottom:4px;font-size:.8rem",
          onclick: () => { okonomiApen = !okonomiApen; tegn(); }
        }, [el("span", { html: svg("ned"), style: okonomiApen ? "" : "transform:rotate(-90deg);display:inline-flex" }), okonomiApen ? "Skjul detaljer" : "Mer i økonomi"]));
        if (okonomiApen) {
          boks.append(el("div", { class: "sb-sub" }, okonomiUnderSynlig.map(u => punkt(u))));
        }
      }
    }
    nav.append(boks);
  }

  if (S.bruker?.epost === "malik@kampsportlaget.com") {
    const eierBoks = el("div", { class: "sb-group" });
    eierBoks.append(el("h4", {}, "Dine verktøy"));
    eierBoks.append(el("button", {
      class: "sb-item", onclick: () => { location.href = "../atlas/"; }
    }, [el("span", { html: svg("prosjekt") }), "Atlas — Prosjekter"]));
    eierBoks.append(el("button", {
      class: "sb-item", onclick: () => { location.href = "../faktura-generator/"; }
    }, [el("span", { html: svg("kvittering") }), "Faktura generator"]));
    nav.append(eierBoks);
  }

  const bunn = el("div", { class: "sb-bunn" });
  if (!revisorTilgang) {
    bunn.append(el("button", {
      class: "sb-item" + (["innstillinger", ...INNST_UNDER].includes(ruteNaa) ? " on" : ""),
      onclick: () => { innstApen = !innstApen; gaTil("innstillinger"); }
    }, [el("span", { html: svg("innstilling") }), "Innstillinger"]));
    if (innstApen) bunn.append(el("div", { class: "sb-sub" }, INNST_UNDER.map(u => punkt(u))));
  }
  bunn.append(punkt("hjelp"));
  const appPunkt = installerPunkt();
  if (appPunkt) bunn.append(appPunkt);
  bunn.append(el("button", { class: "sb-profil", onclick: () => gaTil("profil") }, [
    el("span", { class: "avatar" }, initialer(S.bruker.fornavn, S.bruker.etternavn) || S.bruker.epost[0].toUpperCase()),
    el("span", {}, [
      el("b", {}, ((S.bruker.fornavn || "") + " " + (S.bruker.etternavn || "")).trim() || S.bruker.epost),
      el("span", {}, S.styreverv || rolleNavn(S.rolle))
    ])
  ]));
  nav.append(bunn);
  return nav;
}

/** Vises bare når appen faktisk kan legges på hjem-skjermen. */
function installerPunkt() {
  const S2 = window.Saksflyt;
  if (!S2) return null;
  const t = S2.tilstand();
  if (t === "installert" || t === "ikke-mulig") return null;
  return el("button", {
    class: "sb-item",
    onclick: () => t === "kan-spørre" ? installerNaa() : visIosSteg()
  }, [el("span", { html: svg("last") }), "Legg til som app"]);
}

async function installerNaa() {
  const ja = await window.Saksflyt.installer();
  if (ja) { toast("Lagt til", "Saksflyt ligger nå på hjem-skjermen din."); tegn(); }
}

function visIosSteg() {
  const S2 = window.Saksflyt;
  skuff({
    tittel: "Legg Saksflyt på hjem-skjermen",
    undertittel: "På iPhone og iPad gjør du det selv. Det tar tre trykk.",
    innhold: el("div", { class: "stack" }, [
      el("div", { class: "oppm" }, S2.IOS_STEG.map((linje, i) =>
        el("div", { class: "oppm-rad", style: "cursor:default" }, [
          el("span", { class: "merke blue" }, String(i + 1)),
          el("span", { class: "tekst" }, el("b", {}, linje))
        ]))),
      el("div", { class: "note info" }, [
        el("span", { html: svg("info") }),
        el("div", {}, "Etterpå åpner Saksflyt seg uten adressefelt, med eget ikon — som en vanlig app.")
      ])
    ])
  });
}

function byggMobilnav() {
  const p = (id, tekst) => el("button", {
    class: ruteNaa === id ? "on" : "", onclick: () => gaTil(id)
  }, [el("span", { html: svg(RUTER[id].ikon) }), tekst]);
  if (erRevisor()) {
    return el("nav", { class: "mobilnav" }, [
      p("oversikt", "Oversikt"), p("okonomi", "Bilag"),
      p("regnskapsrapporter", "Regnskap"), p("rapporter", "Rapporter"), p("hjelp", "Hjelp")
    ]);
  }
  return el("nav", { class: "mobilnav" }, [
    p("oversikt", "Oversikt"), p("medlemmer", "Medlemmer"),
    p("okonomi", "Økonomi"), p("betalinger", "Betaling"), p("innstillinger", "Mer")
  ]);
}

function modulNavn() {
  return S.org?.produktnavn && S.org.produktnavn !== "Foreningssystem" ? S.org.produktnavn : "Klubbsystem";
}

const rolleNavn = r => (ROLLER.find(x => x.verdi === r)?.tekst || r || "").split("—")[0].trim();

/* ---- topplinje: én dominerende primærhandling ---- */

function byggTopp() {
  const r = RUTER[ruteNaa];
  const erForside = ruteNaa === "oversikt";
  const time = new Date().getHours();
  const hilsen = time < 10 ? "God morgen" : time < 18 ? "God dag" : "God kveld";

  const tittel = erForside
    ? `${hilsen}, ${(S.bruker.fornavn || S.bruker.epost.split("@")[0])}`
    : r.tittel;
  const under = erForside
    ? `Her er status for ${S.org.navn}.`
    : undertekstFor(ruteNaa);

  return el("div", { class: "topbar" }, [
    el("div", {}, [el("h1", {}, tittel), under && el("p", { class: "sub" }, under)]),
    el("div", { class: "top-hoyre" }, [kanSkrive() ? nyMeny() : null])
  ]);
}

function undertekstFor(rute) {
  const v = RUTER[rute]?.view?.();
  return v?.undertekst || {
    dokumenter: "Vedtekter, avtaler, årsmøtepapirer og annet klubben må ta vare på.",
    innstillinger: "Organisasjon, brukere og sporbarhet.",
    brukere: "Hvem som har tilgang, hvilken rolle de har og hvilket verv de sitter i.",
    selskap: "Grunnopplysninger om organisasjonen og hvem som attesterer regninger.",
    revisjonsspor: "Alle endringer i systemet, i den rekkefølgen de skjedde.",
    hjelp: "Korte svar på det folk lurer på.",
    profil: "Navnet ditt, kontaktopplysninger og passord."
  }[rute] || "";
}

function nyMeny() {
  const knappen = el("button", { class: "btn primary" }, [el("span", { html: svg("pluss") }), "Ny"]);
  const valg = [];
  if (kanMedlem()) valg.push({ tekst: "Nytt medlem", ikon: "medlemmer", ved: () => gaTil("medlemmer") });
  if (kanOkonomi()) valg.push(
    { tekst: "Registrer inntekt", ikon: "opp", ved: async () => { if (await registrerModal("inntekt")) tegn(); } },
    { tekst: "Registrer utgift", ikon: "betaling", ved: async () => { if (await registrerModal("utgift")) tegn(); } },
    { tekst: "Last opp kvittering", ikon: "kvittering", ved: () => gaTil("okonomi") },
    { tekst: "Opprett betalingskrav", ikon: "kalender", ved: () => gaTil("betalinger") }
  );
  if (kanSkrive()) valg.push("skille", { tekst: "Nytt prosjekt", ikon: "prosjekt", ved: () => gaTil("prosjekter") });
  if (!valg.length) return null;
  return nedtrekk(knappen, valg.filter(v => v));
}

/* =====================================================================
   Innhold
   ===================================================================== */

async function tegnInnhold(boks) {
  const r = RUTER[ruteNaa];
  tom(boks).append(ruteNaa === "oversikt" ? skjelett("kpi", 4) : laster());
  try {
    let node;
    if (r.view) node = await r.view().bygg();
    else node = await ({
      oversikt: forside, dokumenter: dokumenter, innstillinger: innstillinger,
      brukere: brukere, selskap: selskap, revisjonsspor: revisjonsspor,
      hjelp: hjelp, profil: profil
    }[ruteNaa] || (() => el("div", { class: "empty" }, "Ukjent side")))();
    tom(boks).append(node);
  } catch (e) {
    visFeil(e, "Henting");
    tom(boks).append(tomTilstand({
      tittel: "Fikk ikke hentet innholdet",
      tekst: "Noe gikk galt underveis. Prøv igjen, eller gå til Oversikt.",
      ikon: "varsel",
      handlinger: [knapp("Prøv igjen", { klasse: "primary", ved: () => tegn() })]
    }));
  }
}

/* =====================================================================
   Forsiden — referansesiden for designsystemet
   ===================================================================== */

async function forside() {
  const boks = el("div", { class: "stack" });

  const [okonomi, medlemsTall, prosjekter, attest] = await Promise.all([
    hentOkonomiTall().catch(() => ({})),
    hentMedlemsTall().catch(() => ({})),
    velgFra("v_prosjekt_status", "*").then(r => r.data || []).catch(() => []),
    hentAttesteringTall().catch(() => ({ tilAttestering: 0, tilAnvisning: 0 }))
  ]);

  /* --- fire nøkkeltall --- */
  boks.append(el("div", { class: "grid g4" }, [
    kpi({
      nokkel: "Aktive medlemmer", ikon: "medlemmer",
      verdi: String(medlemsTall.aktive ?? 0),
      under: medlemsTall.nye ? `+${medlemsTall.nye} nye siste 30 dager` : "Ingen nye siste 30 dager",
      klikk: () => gaTil("medlemmer")
    }),
    kpi({
      nokkel: "Tilgjengelige midler", ikon: "okonomi",
      verdi: kr0(okonomi.saldo_ore || 0) + " kr",
      under: "På klubbens kontoer", klikk: () => gaTil("okonomi")
    }),
    kpi({
      nokkel: "Resultat i år", ikon: "opp",
      verdi: (okonomi.resultat_ore >= 0 ? "+" : "−") + kr0(Math.abs(okonomi.resultat_ore || 0)) + " kr",
      farge: (okonomi.resultat_ore || 0) >= 0 ? "pos" : "neg",
      under: `Inn ${kr0(okonomi.inntekt_ore || 0)} · ut ${kr0(okonomi.utgift_ore || 0)}`,
      klikk: () => gaTil("okonomi")
    }),
    kpi({
      nokkel: "Ubetalte krav", ikon: "betaling",
      verdi: String(medlemsTall.ubetalte ?? 0),
      under: okonomi.ubetalt_ore ? kr0(okonomi.ubetalt_ore) + " kr utestående" : "Alt er betalt",
      klikk: () => gaTil("betalinger")
    })
  ]));

  /* --- trenger oppmerksomhet --- */
  const rader = [];
  if (medlemsTall.ubetalte) rader.push(oppmRad({
    tittel: antall(medlemsTall.ubetalte, "medlem har ikke betalt", "medlemmer har ikke betalt"),
    undertekst: "Se hvem det gjelder og send påminnelse",
    farge: "gold", ikon: "varsel", klikk: () => gaTil("betalinger")
  }));
  if (okonomi.manglerVedlegg) rader.push(oppmRad({
    tittel: antall(okonomi.manglerVedlegg, "bilag mangler kvittering", "bilag mangler kvittering"),
    undertekst: "Regnskapet bør ha dokumentasjon på hver utgift",
    farge: "gold", ikon: "kvittering", klikk: () => gaTil("okonomi")
  }));
  if (attest.tilAttestering) rader.push(oppmRad({
    tittel: antall(attest.tilAttestering, "regning venter på godkjenning", "regninger venter på godkjenning"),
    undertekst: "To personer må godkjenne før utbetaling",
    farge: "blue", ikon: "ok", klikk: () => gaTil("attestering")
  }));
  for (const p of prosjekter) {
    const frist = p.rapportfrist ? Math.round((new Date(p.rapportfrist) - new Date()) / 864e5) : null;
    if (frist !== null && frist <= 30) rader.push(oppmRad({
      tittel: `${p.navn} har rapporteringsfrist om ${antall(frist, "dag", "dager")}`,
      undertekst: "Tilskuddsgiver venter på regnskap for prosjektet",
      farge: frist <= 7 ? "red" : "blue", ikon: "kalender", klikk: () => gaTil("prosjekter")
    }));
  }
  if (medlemsTall.manglerInfo) rader.push(oppmRad({
    tittel: antall(medlemsTall.manglerInfo, "medlem mangler kontaktinformasjon", "medlemmer mangler kontaktinformasjon"),
    undertekst: "Uten e-post eller telefon når dere dem ikke",
    farge: "blue", ikon: "info", klikk: () => gaTil("medlemmer")
  }));

  boks.append(statusTavle({ okonomi, medlemsTall, prosjekter, attest, rader }));

  boks.append(el("div", { class: "split" }, [
    kort({
      tittel: "Trenger oppmerksomhet",
      beskrivelse: rader.length ? "Trykk på en linje for å gjøre noe med den." : null,
      innhold: oppmListe(rader)
    }),
    kort({
      tittel: "Prosjekter",
      hoyre: prosjekter.length ? knapp("Se alle", { klasse: "stille sm", ved: () => gaTil("prosjekter") }) : null,
      innhold: prosjekter.length
        ? el("div", { class: "stack", style: "gap:18px" }, prosjekter.slice(0, 3).map(p =>
          el("div", {}, [
            el("div", { class: "between", style: "margin-bottom:7px" }, [
              el("b", {}, p.navn),
              merke(p.tilskudd_ore ? Math.round((p.brukt_ore / p.tilskudd_ore) * 100) + " %" : "Uten ramme",
                p.tilskudd_ore && p.brukt_ore > p.tilskudd_ore ? "red" : "teal")
            ]),
            fremdrift({
              brukt: p.brukt_ore, ramme: p.tilskudd_ore || 0,
              venstre: `${kr0(p.brukt_ore)} kr brukt av ${kr0(p.tilskudd_ore)} kr`,
              hoyre: `${kr0(Math.max(0, p.gjenstaar_ore))} kr igjen`
            })
          ])))
        : tomTilstand({
          tittel: "Ingen prosjekter ennå",
          tekst: "Har klubben fått tilskudd? Opprett et prosjekt, så holder systemet regnskapet for det atskilt.",
          ikon: "prosjekt",
          handlinger: kanSkrive() ? [knapp("Nytt prosjekt", { klasse: "primary sm", ikon: "pluss", ved: () => gaTil("prosjekter") })] : []
        })
    })
  ]));

  if (S.bruker?.epost === "malik@kampsportlaget.com") {
    boks.append(kort({
      tittel: "Dine verktøy",
      beskrivelse: "Interne verktøy — kun synlig for deg, ikke en del av det organisasjoner ser.",
      innhold: el("div", { style: "display:flex;gap:10px;flex-wrap:wrap;" }, [
        knapp("Atlas — Prosjekter", { klasse: "stille sm", ikon: "prosjekt", ved: () => { location.href = "../atlas/"; } }),
        knapp("Faktura generator", { klasse: "stille sm", ikon: "kvittering", ved: () => { location.href = "../faktura-generator/"; } })
      ])
    }));
  }

  return boks;
}

function statusTavle({ okonomi, medlemsTall, prosjekter, attest, rader }) {
  const inntekt = Math.max(0, okonomi.inntekt_ore || 0);
  const utgift = Math.max(0, okonomi.utgift_ore || 0);
  const utestaaende = Math.max(0, okonomi.ubetalt_ore || 0);
  const total = Math.max(1, inntekt + utgift + utestaaende);
  const p1 = Math.round((inntekt / total) * 100);
  const p2 = Math.min(100, p1 + Math.round((utgift / total) * 100));
  const donut = `conic-gradient(var(--teal) 0 ${p1}%, var(--gold) ${p1}% ${p2}%, var(--blue-soft) ${p2}% 100%)`;
  const prosjektAktive = prosjekter.filter(p => p.status === "aktiv").length;
  const fristProsjekter = prosjekter.filter(p => {
    if (!p.rapportfrist) return false;
    const dager = Math.round((new Date(p.rapportfrist) - new Date()) / 864e5);
    return dager <= 30;
  }).length;
  const oppmerksomhet = rader.length;

  return el("section", { class: "status-board" }, [
    el("div", { class: "status-mini" }, [
      statusTile({ tittel: "Bilag uten vedlegg", verdi: okonomi.manglerVedlegg || 0, under: "Kontrollspor", ikon: "kvittering", farge: (okonomi.manglerVedlegg || 0) ? "gold" : "green", klikk: () => gaTil("okonomi") }),
      statusTile({ tittel: "Venter på godkjenning", verdi: attest.tilAttestering || 0, under: "Utbetaling", ikon: "ok", farge: (attest.tilAttestering || 0) ? "blue" : "green", klikk: () => gaTil("attestering") })
    ]),
    kort({
      klasse: "status-main",
      tittel: "Regnskapsoversikt",
      hoyre: knapp("Rapporter", { klasse: "stille sm", ikon: "rapport", ved: () => gaTil("rapporter") }),
      innhold: el("div", { class: "status-chart" }, [
        el("div", { class: "donut", style: `background:${donut}` }, el("span")),
        el("div", { class: "legend" }, [
          legend("Inntekter", kr0(inntekt) + " kr", "teal"),
          legend("Utgifter", kr0(utgift) + " kr", "gold"),
          legend("Utestående krav", kr0(utestaaende) + " kr", "blue"),
          el("div", { class: "sumline" }, [
            el("span", {}, "Resultat i år"),
            el("b", { class: (okonomi.resultat_ore || 0) >= 0 ? "pos" : "neg" },
              ((okonomi.resultat_ore || 0) >= 0 ? "+" : "-") + kr0(Math.abs(okonomi.resultat_ore || 0)) + " kr")
          ]),
          el("div", { class: "updated" }, [el("span", { html: svg("info") }), "Sist oppdatert " + tidspunkt(new Date())])
        ])
      ])
    }),
    kort({
      klasse: "status-side",
      tittel: "Frister og kontroll",
      hoyre: merke(String(oppmerksomhet), oppmerksomhet ? "gold" : "green"),
      innhold: el("div", { class: "deadline-list" }, [
        deadline("Årsregnskap 2025", "Mal og sammenligning fra 2025-regnskap", "blue", () => gaTil("rapporter")),
        deadline("Bankkontroll", "Saldo skal stemme med bank", "teal", () => gaTil("okonomi")),
        deadline("Prosjektfrister", fristProsjekter ? antall(fristProsjekter, "frist krever oppfølging", "frister krever oppfølging") : "Ingen frister neste 30 dager", fristProsjekter ? "gold" : "green", () => gaTil("prosjekter")),
        deadline("Medlemmer", `${medlemsTall.aktive || 0} aktive · ${medlemsTall.ubetalte || 0} ubetalte krav`, (medlemsTall.ubetalte || 0) ? "gold" : "green", () => gaTil("medlemmer")),
        deadline("Prosjekter", `${prosjektAktive} aktive prosjekt`, prosjektAktive ? "teal" : "neutral", () => gaTil("prosjekter"))
      ])
    })
  ]);
}

function statusTile({ tittel, verdi, under, ikon: ikonNavn, farge, klikk }) {
  return el("button", { class: "status-tile " + farge, onclick: klikk }, [
    el("span", { class: "tile-icon", html: svg(ikonNavn) }),
    el("span", { class: "tile-text" }, [
      el("b", {}, tittel),
      el("strong", {}, String(verdi)),
      el("small", {}, under)
    ])
  ]);
}

function legend(label, value, color) {
  return el("div", { class: "legend-row " + color }, [
    el("span", {}, label),
    el("b", {}, value)
  ]);
}

function deadline(tittel, under, farge, klikk) {
  return el("button", { class: "deadline " + farge, onclick: klikk }, [
    el("span", { class: "stripe" }),
    el("span", { class: "deadline-text" }, [
      el("b", {}, tittel),
      el("small", {}, under)
    ]),
    el("span", { class: "more", html: svg("pil") })
  ]);
}

async function hentMedlemsTall() {
  const { data, error } = await velgFra("members", "id,status,innmeldt,epost,telefon");
  if (error) throw error;
  const grense = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10);
  const { data: krav } = await velgFra("payment_claims", "id,status,member_id");
  const ubetalte = new Set((krav || []).filter(k => ["ikke_betalt", "delvis_betalt", "forfalt"].includes(k.status)).map(k => k.member_id));
  return {
    aktive: data.filter(m => m.status === "aktiv").length,
    nye: data.filter(m => m.innmeldt >= grense).length,
    ubetalte: ubetalte.size,
    manglerInfo: data.filter(m => m.status === "aktiv" && !m.epost && !m.telefon).length
  };
}

/* =====================================================================
   Brukere — brukerkort
   ===================================================================== */

async function brukere() {
  const boks = el("div", { class: "stack" });

  const [{ data: medlemskap, error: e1 }, { data: invitasjoner }] = await Promise.all([
    db.from("organization_users").select("*, profiles(*)").eq("organization_id", S.orgId),
    erAdmin() ? db.from("invitations").select("*").eq("organization_id", S.orgId).eq("status", "venter") : Promise.resolve({ data: [] })
  ]);
  if (e1) throw e1;

  if (!erAdmin()) {
    boks.append(el("div", { class: "note info" }, [
      el("span", { html: svg("info") }),
      el("div", {}, [el("b", {}, "Du kan se hvem som har tilgang, "), "men bare administrator og styreleder kan legge til eller endre brukere."])
    ]));
  }

  const kortFor = (m) => {
    const p = m.profiles || {};
    const navn = ((p.fornavn || "") + " " + (p.etternavn || "")).trim() || p.epost || "Ukjent";
    return el("div", { class: "kort" }, [
      el("div", { class: "topp" }, [
        el("span", { class: "avatar" }, initialer(p.fornavn, p.etternavn) || (p.epost || "?")[0].toUpperCase()),
        el("div", { style: "min-width:0" }, [
          el("div", { class: "navn" }, navn),
          el("div", { class: "epost" }, p.epost || "")
        ])
      ]),
      el("div", { class: "verv" }, [
        m.styreverv ? el("b", {}, m.styreverv) : el("span", { class: "dim" }, "Uten verv"),
        m.tittel ? " · " + m.tittel : ""
      ]),
      el("div", { class: "bunn" }, [
        merke(rolleNavn(m.rolle), m.rolle === "administrator" ? "teal" : m.rolle === "revisor" ? "neutral" : "blue"),
        !m.aktiv && merke("Deaktivert", "neutral"),
        erAdmin() && knapp("Rediger", {
          klasse: "stille sm", ved: () => redigerBruker(m, navn)
        })
      ])
    ]);
  };

  boks.append(kort({
    tittel: "Brukere med tilgang",
    beskrivelse: "Rollen bestemmer hva personen kan gjøre. Vervet er det som står i protokollen.",
    hoyre: erAdmin() ? knapp("Legg til bruker", { klasse: "primary", ikon: "pluss", ved: nyInvitasjon }) : null,
    innhold: medlemskap.length
      ? el("div", { class: "grid g3" }, medlemskap.map(kortFor))
      : tomTilstand({ tittel: "Ingen brukere ennå", tekst: "Legg til den første.", ikon: "bruker" })
  }));

  if (invitasjoner && invitasjoner.length) {
    boks.append(kort({
      tittel: "Venter på første innlogging",
      beskrivelse: "Disse er lagt inn, men har ikke opprettet passord ennå. De kobles på automatisk når de logger inn med e-postadressen sin.",
      innhold: tabell(
        [{ t: "Navn" }, { t: "E-post" }, { t: "Rolle" }, { t: "Verv" }, { t: "" }],
        invitasjoner.map(i => el("tr", {}, [
          el("td", { class: "strong" }, ((i.fornavn || "") + " " + (i.etternavn || "")).trim() || "—"),
          el("td", {}, i.epost),
          el("td", {}, merke(rolleNavn(i.rolle), "blue")),
          el("td", { class: "dim" }, i.styreverv || "—"),
          el("td", { class: "num" }, knapp("Trekk tilbake", {
            klasse: "danger sm", ved: async () => {
              if (!await bekreft("Trekke tilbake?", `${i.epost} vil ikke lenger få tilgang når de logger inn.`, "Trekk tilbake")) return;
              const { error } = await db.from("invitations").delete().eq("id", i.id);
              if (error) return visFeil(error, "Sletting");
              toast("Trukket tilbake", i.epost + " er fjernet fra listen."); tegn();
            }
          }))
        ]))
      )
    }));
  }

  return boks;
}

async function nyInvitasjon() {
  const svar = await skjemaModal({
    tittel: "Legg til bruker",
    beskrivelse: "Personen kobles automatisk til klubben første gang de logger inn med denne e-postadressen.",
    felter: [
      { navn: "fornavn", label: "Fornavn" },
      { navn: "etternavn", label: "Etternavn" },
      { navn: "epost", label: "E-post", type: "email", bredde: "full" },
      { navn: "telefon", label: "Telefon" },
      { navn: "rolle", label: "Rolle", type: "select", valg: ROLLER },
      { navn: "styreverv", label: "Styreverv", type: "select", valg: VERV.map(v => ({ verdi: v === "Ingen verv" ? "" : v, tekst: v })), bredde: "full" },
      { navn: "tittel", label: "Tittel (valgfri)", plassholder: "Hovedtrener karate", bredde: "full" }
    ],
    lagreTekst: "Legg til",
    onLagre: async (d) => {
      if (!d.epost) { toast("Mangler e-post", "E-postadressen er nøkkelen som kobler personen til klubben.", true); return false; }
      const { error } = await db.from("invitations").insert({
        organization_id: S.orgId, epost: d.epost.toLowerCase(), fornavn: d.fornavn, etternavn: d.etternavn,
        telefon: d.telefon || null, rolle: d.rolle, styreverv: d.styreverv || null, tittel: d.tittel || null,
        invitert_av: S.bruker.id
      });
      if (error) throw error;
      return true;
    }
  });
  if (svar) { toast("Lagt til", svar.epost + " får tilgang ved første innlogging."); tegn(); }
}

async function redigerBruker(m, navn) {
  const erMegSelv = m.user_id === S.bruker.id;
  const svar = await skjemaModal({
    tittel: navn,
    beskrivelse: erMegSelv ? "Dette er din egen bruker. Du kan ikke fjerne din egen tilgang." : "Endre rolle og verv for denne personen.",
    felter: [
      { navn: "rolle", label: "Rolle", type: "select", valg: ROLLER, verdi: m.rolle },
      { navn: "styreverv", label: "Styreverv", type: "select", valg: VERV.map(v => ({ verdi: v === "Ingen verv" ? "" : v, tekst: v })), verdi: m.styreverv || "" },
      { navn: "tittel", label: "Tittel (valgfri)", verdi: m.tittel || "", bredde: "full" },
      { navn: "aktiv", label: "Har tilgang", type: "checkbox", verdi: m.aktiv, hint: "Skru av for å stenge tilgangen uten å slette historikken." }
    ],
    onLagre: async (d) => {
      const { error } = await db.from("organization_users")
        .update({ rolle: d.rolle, styreverv: d.styreverv || null, tittel: d.tittel || null, aktiv: d.aktiv })
        .eq("id", m.id);
      if (error) throw error;
      return true;
    },
    onSlett: erMegSelv ? null : async () => {
      const { error } = await db.from("organization_users").delete().eq("id", m.id);
      if (error) throw error;
    }
  });
  if (svar) { toast("Lagret", "Endringene for " + navn + " er lagret."); tegn(); }
}

/* =====================================================================
   Selskapsinformasjon — inkludert hvem som attesterer
   ===================================================================== */

async function selskap() {
  const boks = el("div", { class: "stack" });
  const o = S.org;

  const { data: brukereIOrg } = await db.from("organization_users")
    .select("user_id, rolle, styreverv, profiles(fornavn, etternavn, epost)")
    .eq("organization_id", S.orgId).eq("aktiv", true);

  const personValg = [{ verdi: "", tekst: "Ikke valgt" }].concat((brukereIOrg || []).map(b => ({
    verdi: b.user_id,
    tekst: ((b.profiles?.fornavn || "") + " " + (b.profiles?.etternavn || "")).trim() || b.profiles?.epost || "Ukjent"
  })));

  boks.append(kort({
    tittel: "Om organisasjonen",
    hoyre: erAdmin() ? knapp("Rediger", { klasse: "stille", ved: () => redigerOrg() }) : null,
    innhold: el("dl", { class: "kv" }, [
      el("dt", {}, "Navn"), el("dd", {}, o.navn),
      el("dt", {}, "Organisasjonsnummer"), el("dd", {}, o.orgnr || "—"),
      el("dt", {}, "Type"), el("dd", {}, o.type),
      el("dt", {}, "E-post"), el("dd", {}, o.epost || "—"),
      el("dt", {}, "Telefon"), el("dd", {}, o.telefon || "—"),
      el("dt", {}, "Adresse"), el("dd", {}, [o.adresse, o.postnr, o.sted].filter(Boolean).join(", ") || "—"),
      el("dt", {}, "Regnskapsår starter"), el("dd", {}, dato(o.regnskapsaar_start))
    ])
  }));

  boks.append(kort({
    tittel: "Attestering av regninger",
    beskrivelse: "To personer må godkjenne en regning før den kan betales. Velg hvem som gjør det her.",
    hoyre: erAdmin() ? knapp("Endre", { klasse: "stille", ved: () => redigerAttestering(personValg) }) : null,
    innhold: el("div", { class: "stack" }, [
      el("dl", { class: "kv" }, [
        el("dt", {}, "Attestant 1"), el("dd", {}, navnFor(o.attestant1, personValg)),
        el("dt", {}, "Attestant 2"), el("dd", {}, navnFor(o.attestant2, personValg)),
        el("dt", {}, "Krever to godkjenninger"), el("dd", {}, o.krev_to_attestanter === false ? "Nei" : "Ja")
      ]),
      el("div", { class: "note info" }, [
        el("span", { html: svg("info") }),
        el("div", {}, [
          el("b", {}, "Hvorfor to? "),
          "Den som kontrollerer at varen er mottatt bør ikke være den samme som beslutter utbetalingen. Det er den enkleste sikringen en klubbkasse har."
        ])
      ])
    ])
  }));

  return boks;
}

function navnFor(id, valg) {
  if (!id) return "Ikke valgt";
  return valg.find(v => v.verdi === id)?.tekst || "Ukjent bruker";
}

async function redigerOrg() {
  const o = S.org;
  const svar = await skjemaModal({
    tittel: "Rediger organisasjon",
    felter: [
      { navn: "navn", label: "Navn", verdi: o.navn, bredde: "full" },
      { navn: "orgnr", label: "Organisasjonsnummer", verdi: o.orgnr || "" },
      { navn: "epost", label: "E-post", verdi: o.epost || "" },
      { navn: "telefon", label: "Telefon", verdi: o.telefon || "" },
      { navn: "adresse", label: "Adresse", verdi: o.adresse || "" },
      { navn: "postnr", label: "Postnummer", verdi: o.postnr || "" },
      { navn: "sted", label: "Sted", verdi: o.sted || "" }
    ],
    onLagre: async (d) => {
      const { data, error } = await db.from("organizations").update({
        navn: d.navn, orgnr: d.orgnr || null, epost: d.epost || null, telefon: d.telefon || null,
        adresse: d.adresse || null, postnr: d.postnr || null, sted: d.sted || null
      }).eq("id", S.orgId).select().single();
      if (error) throw error;
      S.org = data;
      const t = S.organisasjoner.find(x => x.organization_id === S.orgId); if (t) t.org = data;
      return true;
    }
  });
  if (svar) { toast("Lagret", "Opplysningene er oppdatert."); tegn(); }
}

async function redigerAttestering(personValg) {
  const o = S.org;
  const svar = await skjemaModal({
    tittel: "Hvem attesterer regninger?",
    beskrivelse: "Begge må godkjenne før en regning kan betales.",
    felter: [
      { navn: "attestant1", label: "Attestant 1", type: "select", valg: personValg, verdi: o.attestant1 || "", bredde: "full" },
      { navn: "attestant2", label: "Attestant 2", type: "select", valg: personValg, verdi: o.attestant2 || "", bredde: "full" },
      { navn: "krev_to_attestanter", label: "Krev to godkjenninger", type: "checkbox", verdi: o.krev_to_attestanter !== false, hint: "Skru av bare hvis klubben er så liten at det ikke lar seg gjøre." }
    ],
    onLagre: async (d) => {
      if (d.attestant1 && d.attestant1 === d.attestant2) {
        toast("Samme person", "Attestant 1 og 2 må være to forskjellige personer.", true); return false;
      }
      const { data, error } = await db.from("organizations").update({
        attestant1: d.attestant1 || null,
        attestant2: d.attestant2 || null,
        krev_to_attestanter: d.krev_to_attestanter
      }).eq("id", S.orgId).select().single();
      if (error) throw error;
      S.org = data;
      const t = S.organisasjoner.find(x => x.organization_id === S.orgId); if (t) t.org = data;
      return true;
    }
  });
  if (svar) { toast("Lagret", "Attestering er oppdatert."); tegn(); }
}

/* =====================================================================
   Innstillinger, dokumenter, revisjonsspor, hjelp, profil
   ===================================================================== */

async function innstillinger() {
  const rad = (rute, tekst, beskrivelse, ikonNavn) => el("button", { class: "oppm-rad", onclick: () => gaTil(rute) }, [
    el("span", { class: "merke blue", html: svg(ikonNavn) }),
    el("span", { class: "tekst" }, [el("b", {}, tekst), el("span", {}, beskrivelse)]),
    el("span", { class: "pil", html: svg("pil") })
  ]);
  return el("div", { class: "stack" }, [
    kort({
      tittel: "Innstillinger",
      innhold: el("div", { class: "oppm" }, [
        rad("selskap", "Selskapsinformasjon", "Navn, organisasjonsnummer og hvem som attesterer", "bygg"),
        rad("brukere", "Brukere og roller", "Hvem har tilgang, og hva får de lov til", "bruker"),
        rad("revisjonsspor", "Revisjonsspor", "Alle endringer, i rekkefølge", "logg"),
        rad("profil", "Min profil", "Navn, kontaktinfo og passord", "medlemmer")
      ])
    }),
    kort({
      tittel: "Dine data tilhører klubben",
      beskrivelse: "Du skal aldri føle deg låst inne. Last ned alt når som helst.",
      innhold: el("div", { class: "actions" }, [
        knapp("Last ned alle data som Excel", { klasse: "primary", ikon: "last", ved: lastNedAlt })
      ])
    })
  ]);
}

async function lastNedAlt() {
  try {
    toast("Henter", "Samler dataene dine …");
    const [medl, txn, prosj, krav, akt] = await Promise.all([
      velgFra("members", "*"), velgFra("transactions", "*"),
      velgFra("projects", "*"), velgFra("payment_claims", "*"), velgFra("activities", "*")
    ]);
    await eksporterExcel(`${S.org.navn.replace(/\s+/g, "-").toLowerCase()}-alle-data.xlsx`, {
      "Medlemmer": (medl.data || []).map(m => ({
        Fornavn: m.fornavn, Etternavn: m.etternavn, Fødselsdato: m.fodselsdato || "",
        "E-post": m.epost || "", Telefon: m.telefon || "", Adresse: m.adresse || "",
        Postnummer: m.postnr || "", Sted: m.sted || "", Innmeldt: m.innmeldt, Status: m.status
      })),
      "Transaksjoner": (txn.data || []).map(t => ({
        Bilagsnummer: t.bilagsnummer, Dato: t.dato, Type: t.type, Beskrivelse: t.beskrivelse,
        Motpart: t.motpart || "", "Beløp": (t.belop_ore / 100), "Regnskapsår": t.regnskapsaar
      })),
      "Prosjekter": (prosj.data || []).map(p => ({
        Navn: p.navn, Tilskuddsgiver: p.tilskuddsgiver || "", "Tilskudd": (p.tilskudd_ore / 100),
        Start: p.start_dato || "", Slutt: p.slutt_dato || "", Status: p.status
      })),
      "Betalingskrav": (krav.data || []).map(k => ({
        Beskrivelse: k.beskrivelse, "Beløp": (k.belop_ore / 100), "Betalt": (k.betalt_ore / 100),
        Forfall: k.forfall, Status: k.status
      })),
      "Aktiviteter": (akt.data || []).map(a => ({ Navn: a.navn, Beskrivelse: a.beskrivelse || "", Aktiv: a.aktiv ? "Ja" : "Nei" }))
    });
    toast("Lastet ned", "Filen ligger i nedlastingsmappen din.");
  } catch (e) { visFeil(e, "Nedlasting"); }
}

const MAPPER = [
  "Årsprotokoller",
  "Ekstraordinære generalforsamlinger",
  "Styremøter",
  "Årsberetninger",
  "Regnskap",
  "Tilskudd",
  "Avtaler",
  "Forsikring",
  "Vedtekter",
  "Andre dokumenter"
];

async function dokumenter() {
  const { data, error } = await velgFra("documents", "*").order("opprettet", { ascending: false });
  if (error) throw error;

  const boks = el("div", { class: "stack" });
  if (!data.length) {
    boks.append(kort({
      innhold: tomTilstand({
        tittel: "Ingen dokumenter ennå",
        tekst: "Legg inn vedtekter, årsmøteprotokoller og avtaler her, så finner styret dem igjen neste år.",
        ikon: "dokument",
        handlinger: kanSkrive() ? [knapp("Last opp dokument", { klasse: "primary", ikon: "last", ved: lastOppDokument })] : []
      })
    }));
    return boks;
  }

  const grupper = {};
  for (const d of data) (grupper[d.mappe] = grupper[d.mappe] || []).push(d);

  boks.append(el("div", { class: "between" }, [
    el("span", { class: "meta" }, `${data.length} dokumenter i ${Object.keys(grupper).length} mapper`),
    kanSkrive() ? knapp("Last opp dokument", { klasse: "primary", ikon: "last", ved: lastOppDokument }) : null
  ]));

  const mappeRekke = [...MAPPER, ...Object.keys(grupper).filter(m => !MAPPER.includes(m))];
  for (const mappe of mappeRekke) {
    const filer = grupper[mappe];
    if (!filer?.length) continue;
    boks.append(kort({
      tittel: mappe,
      beskrivelse: `${filer.length} dokument${filer.length === 1 ? "" : "er"}`,
      innhold: tabell([{ t: "Tittel" }, { t: "Lagt inn" }, { t: "Tilgang" }, { t: "" }],
        filer.map(f => el("tr", {}, [
          el("td", { class: "strong" }, [f.tittel, f.filnavn && el("span", { class: "who" }, f.filnavn)]),
          el("td", { class: "dim" }, tidspunkt(f.opprettet)),
          el("td", {}, f.kun_styret ? merke("Kun styret", "gold") : merke("Alle i klubben", "neutral")),
          el("td", { class: "num" }, f.storage_path ? knapp("Åpne", {
            klasse: "stille sm", ved: async () => {
              const { data: url, error } = await db.storage.from("dokumenter").createSignedUrl(f.storage_path, 60);
              if (error) return visFeil(error, "Åpning");
              window.open(url.signedUrl, "_blank", "noopener");
            }
          }) : null)
        ])))
    }));
  }
  return boks;
}

async function lastOppDokument() {
  const fil = el("input", { type: "file" });
  const svar = await skjemaModal({
    tittel: "Last opp dokument",
    felter: [
      { navn: "tittel", label: "Hva er dette?", plassholder: "Årsmøteprotokoll 2026", bredde: "full" },
      { navn: "mappe", label: "Mappe", type: "select", valg: MAPPER.map(m => ({ verdi: m, tekst: m })) },
      { navn: "kun_styret", label: "Kun for styret", type: "checkbox", verdi: false }
    ],
    ekstra: el("div", { class: "field", style: "margin-top:14px" }, [el("label", {}, "Fil"), fil]),
    lagreTekst: "Last opp",
    onLagre: async (d) => {
      if (!d.tittel) { toast("Mangler tittel", "Gi dokumentet et navn folk kjenner igjen.", true); return false; }
      const f = fil.files[0];
      let sti = null;
      if (f) {
        sti = `${S.orgId}/${Date.now()}-${f.name.replace(/[^\w.\-]/g, "_")}`;
        const { error } = await db.storage.from("dokumenter").upload(sti, f);
        if (error) { toast("Opplasting", "Filen ble ikke lastet opp: " + error.message + ". Dokumentet lagres uten fil.", true); sti = null; }
      }
      const { error } = await settInn("documents", {
        tittel: d.tittel, mappe: d.mappe, kun_styret: d.kun_styret,
        filnavn: f?.name || null, storage_path: sti, lastet_opp_av: S.bruker.id
      });
      if (error) throw error;
      return true;
    }
  });
  if (svar) { toast("Lagt inn", "Dokumentet er lagret."); tegn(); }
}

async function revisjonsspor() {
  const { data, error } = await db.from("audit_logs").select("*, profiles(fornavn, etternavn, epost)")
    .eq("organization_id", S.orgId).order("tidspunkt", { ascending: false }).limit(300);
  if (error) throw error;

  const HANDLING = { insert: ["Opprettet", "green"], update: ["Endret", "blue"], delete: ["Slettet", "red"] };
  const TABELL = {
    members: "medlem", transactions: "bilag", organization_users: "brukertilgang",
    payment_claims: "betalingskrav", supplier_invoices: "regning"
  };

  return kort({
    tittel: "Revisjonsspor",
    beskrivelse: "Loggen kan ikke endres eller slettes — heller ikke av administrator. Viser de 300 siste hendelsene.",
    innhold: tabell(
      [{ t: "Tidspunkt" }, { t: "Hendelse" }, { t: "Hva" }, { t: "Hvem" }],
      (data || []).map(a => {
        const [tekst, farge] = HANDLING[a.handling] || [a.handling, "neutral"];
        const p = a.profiles || {};
        return el("tr", {}, [
          el("td", { class: "dim mono" }, tidspunkt(a.tidspunkt)),
          el("td", {}, merke(tekst, farge)),
          el("td", { class: "strong" }, (TABELL[a.tabell] || a.tabell)),
          el("td", {}, ((p.fornavn || "") + " " + (p.etternavn || "")).trim() || p.epost || "System")
        ]);
      }),
      "Ingen hendelser logget ennå."
    )
  });
}

async function hjelp() {
  const sporsmaal = [
    ["Hvordan legger jeg inn medlemmer fra Excel?",
      "Gå til Medlemmer og velg «Importer fra Excel». Du velger selv hvilken kolonne i filen som er fornavn, etternavn og så videre, og du ser hvor mange rader som kan importeres før du bekrefter."],
    ["Hva er forskjellen på medlemskontingent og treningsavgift?",
      "Medlemskontingenten betaler man for å være medlem i klubben. Treningsavgiften betaler man for å delta i en bestemt aktivitet. Systemet holder dem atskilt fordi de rapporteres ulikt."],
    ["Hvorfor må to personer godkjenne en regning?",
      "Den som kontrollerer at varen er mottatt bør ikke være den samme som beslutter at pengene skal ut. Dere velger selv hvem de to er, under Innstillinger → Selskapsinformasjon."],
    ["Kan jeg slette et bilag?",
      "Nei, og det er med vilje. Regnskap skal kunne etterprøves. I stedet reverserer du bilaget, slik at både feilen og rettelsen står i historikken."],
    ["Hvem ser lønns- og persondata?",
      "Bare de rollene som trenger det. En trener ser gruppene sine, ikke klubbens økonomi. En revisor ser regnskapet, men kan ikke endre noe."],
    ["Hvordan får jeg dataene mine ut?",
      "Innstillinger → «Last ned alle data som Excel». Alt klubben har lagt inn, i lesbare regneark. Dere eier deres egne data."]
  ];
  let apen = null;
  const liste = el("div", { class: "oppm" });
  const tegnListe = () => {
    tom(liste);
    sporsmaal.forEach(([sp, sv], i) => {
      liste.append(el("button", {
        class: "oppm-rad", onclick: () => { apen = apen === i ? null : i; tegnListe(); }
      }, [
        el("span", { class: "merke blue", html: svg("hjelp") }),
        el("span", { class: "tekst" }, [el("b", {}, sp), apen === i && el("span", { style: "margin-top:5px;line-height:1.55" }, sv)]),
        el("span", { class: "pil", html: svg(apen === i ? "ned" : "pil") })
      ]));
    });
  };
  tegnListe();
  return el("div", { class: "stack" }, [
    kort({ tittel: "Vanlige spørsmål", innhold: liste }),
    kort({
      tittel: "Får du det ikke til?",
      innhold: el("p", { style: "margin:0;color:var(--muted)" },
        "Skriv til den som er administrator i klubben din. Står du fast i selve systemet, noter hva du gjorde rett før det stoppet — det er nesten alltid nok til å finne feilen.")
    })
  ]);
}

async function profil() {
  const b = S.bruker;
  return el("div", { class: "stack" }, [
    kort({
      tittel: "Min profil",
      hoyre: knapp("Rediger", {
        klasse: "stille", ved: async () => {
          const svar = await skjemaModal({
            tittel: "Rediger profil",
            felter: [
              { navn: "fornavn", label: "Fornavn", verdi: b.fornavn },
              { navn: "etternavn", label: "Etternavn", verdi: b.etternavn },
              { navn: "telefon", label: "Telefon", verdi: b.telefon, bredde: "full" }
            ],
            onLagre: async (d) => {
              const { error } = await db.from("profiles")
                .update({ fornavn: d.fornavn, etternavn: d.etternavn, telefon: d.telefon || null }).eq("id", b.id);
              if (error) throw error;
              Object.assign(S.bruker, d);
              return true;
            }
          });
          if (svar) { toast("Lagret", "Profilen er oppdatert."); tegn(); }
        }
      }),
      innhold: el("div", { class: "stack" }, [
        el("div", { class: "rowline", style: "gap:14px" }, [
          el("span", { class: "avatar stor" }, initialer(b.fornavn, b.etternavn) || b.epost[0].toUpperCase()),
          el("div", {}, [
            el("h2", {}, ((b.fornavn || "") + " " + (b.etternavn || "")).trim() || b.epost),
            el("div", { class: "meta" }, [S.styreverv, rolleNavn(S.rolle)].filter(Boolean).join(" · "))
          ])
        ]),
        el("dl", { class: "kv" }, [
          el("dt", {}, "E-post"), el("dd", {}, b.epost),
          el("dt", {}, "Telefon"), el("dd", {}, b.telefon || "—"),
          el("dt", {}, "Organisasjon"), el("dd", {}, S.org.navn),
          el("dt", {}, "Rolle"), el("dd", {}, rolleNavn(S.rolle))
        ])
      ])
    }),
    kort({
      tittel: "Passord",
      beskrivelse: "Bytt gjerne fra passordet du fikk utdelt til noe bare du kjenner.",
      innhold: el("div", { class: "actions" }, [
        knapp("Velg nytt passord", {
          klasse: "primary", ved: async () => {
            const svar = await skjemaModal({
              tittel: "Nytt passord",
              felter: [{ navn: "p1", label: "Nytt passord", type: "password", bredde: "full", hint: "Minst 8 tegn." },
              { navn: "p2", label: "Gjenta passordet", type: "password", bredde: "full" }],
              lagreTekst: "Bytt passord",
              onLagre: async (d) => {
                if (d.p1.length < 8) { toast("For kort", "Passordet må ha minst 8 tegn.", true); return false; }
                if (d.p1 !== d.p2) { toast("Ikke likt", "De to passordene er ikke like.", true); return false; }
                const { error } = await db.auth.updateUser({ password: d.p1 });
                if (error) throw error;
                return true;
              }
            });
            if (svar) toast("Byttet", "Passordet ditt er endret.");
          }
        }),
        knapp("Logg ut", { klasse: "stille", ikon: "ut", ved: () => db.auth.signOut() })
      ])
    })
  ]);
}
