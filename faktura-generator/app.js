// =====================================================================
//  Faktura generator — skall, innlogging og navigasjon.
//
//  Regnskapsførerfirmaet lager faktura PÅ VEGNE AV leverandøren.
//  Leverandøren står som avsender, leverandørens egen kunde er mottaker.
//
//  Designkravet er lav terskel: fra åpning til ferdig faktura skal det
//  være så få steg som mulig. Derfor er Fakturaer forsiden, «Ny faktura»
//  åpner rett i redigering, og «Lag lik» er den knappen som brukes mest.
// =====================================================================

import {
  el, tom, svg, felt, knapp, laster, toast, visFeil, settOppTema, db, ER_KONFIGURERT
} from "../app/lib.js";
import { S, hentBruker, hentOrganisasjoner, settOrg, kanOkonomi } from "../app/store.js";
import { fakturaerView, redigerView } from "./views/fakturaer.js";
import { leverandorerView } from "./views/leverandorer.js";

const RUTER = {
  fakturaer:    { tittel: "Fakturaer", ikon: "kvittering", view: () => fakturaerView },
  leverandorer: { tittel: "Leverandører", ikon: "bygg", view: () => leverandorerView },
  rediger:      { tittel: "Faktura", ikon: "kvittering", view: () => redigerView, skjult: true }
};

const SYNLIGE = Object.keys(RUTER).filter(id => !RUTER[id].skjult);

let ruteNaa = "fakturaer";
const rot = document.getElementById("rot");

settOppTema();
window.addEventListener("sf:tegn", () => tegn());
window.addEventListener("hashchange", () => { lesRute(); tegn(); });

start();

async function start() {
  if (!ER_KONFIGURERT) return visIkkeKonfigurert();
  tom(rot).append(laster("Starter Faktura generator …"));
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
  const kandidat = location.hash.replace(/^#\/?/, "").split("/").filter(Boolean).pop();
  if (kandidat && RUTER[kandidat]) ruteNaa = kandidat;
}

function gaTil(rute) {
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
      el("h1", {}, "Mangler oppsett"),
      el("p", { class: "sub" }, "Supabase-verdiene er ikke fylt inn i app/config.js. Uten dem finner appen ingen database.")
    ])));
}

/* =====================================================================
   Innlogging — samme konto som resten av Saksflyt
   ===================================================================== */

function visInnlogging() {
  const epost = el("input", { type: "email", autocomplete: "email", placeholder: "navn@firmaet.no" });
  const passord = el("input", { type: "password", autocomplete: "current-password", placeholder: "Passord" });
  const knappen = el("button", { class: "btn primary blokk" }, "Logg inn");
  const beskjed = el("div", {});

  async function send() {
    const e = epost.value.trim(), p = passord.value;
    if (!e || !p) {
      beskjed.replaceChildren(el("div", { class: "note bad" }, "Fyll inn både e-post og passord."));
      return;
    }
    knappen.disabled = true; knappen.textContent = "Et øyeblikk …";
    try {
      const { error } = await db.auth.signInWithPassword({ email: e, password: p });
      if (error) throw error;
      location.reload();
    } catch (err) {
      const m = String(err.message || err);
      beskjed.replaceChildren(el("div", { class: "note bad" },
        /Invalid login/i.test(m) ? "Feil e-post eller passord."
          : /Email not confirmed/i.test(m) ? "E-posten er ikke bekreftet ennå. Sjekk innboksen din."
            : m));
      knappen.disabled = false; knappen.textContent = "Logg inn";
    }
  }

  knappen.addEventListener("click", send);
  [epost, passord].forEach(i => i.addEventListener("keydown", ev => { if (ev.key === "Enter") send(); }));

  tom(rot).append(el("div", { class: "auth" },
    el("div", { class: "auth-card" }, [
      el("div", { class: "sb-logo" }, "F"),
      el("h1", {}, "Faktura generator"),
      el("p", { class: "sub" }, "Faktura på vegne av leverandørene dine."),
      el("div", { class: "stack", style: "gap:13px" }, [
        felt("E-post", epost),
        felt("Passord", passord),
        beskjed,
        knappen
      ])
    ])));
}

/* =====================================================================
   Skall
   ===================================================================== */

function tegn() {
  if (!S.bruker) return visInnlogging();
  if (!S.orgId) {
    tom(rot).append(el("div", { class: "auth" },
      el("div", { class: "auth-card" }, [
        el("h1", {}, "Ingen organisasjon"),
        el("p", { class: "sub" }, "Brukeren din er ikke koblet til noen organisasjon ennå. Be en administrator om tilgang.")
      ])));
    return;
  }

  tom(rot);
  const innhold = el("div", { id: "innhold" });
  rot.append(el("div", { class: "app" }, [
    byggSidepanel(),
    el("main", { class: "main" }, [byggTopp(), innhold])
  ]));
  rot.append(byggMobilnav());
  tegnInnhold(innhold);
}

function byggSidepanel() {
  const nav = el("nav", { class: "sidebar" });

  nav.append(el("div", { class: "sb-brand" }, [
    el("div", { class: "sb-logo" }, "F"),
    el("div", {}, [
      el("b", {}, "Faktura generator"),
      el("span", {}, S.org?.navn || "")
    ])
  ]));

  if (S.organisasjoner.length > 1) {
    const orgvelger = el("select", {
      class: "orgpick", "aria-label": "Velg organisasjon",
      onchange: e => { settOrg(e.target.value); tegn(); }
    }, S.organisasjoner.map(o => el("option", { value: o.organization_id }, o.org.navn)));
    orgvelger.value = S.orgId;
    nav.append(orgvelger);
  }

  const punkter = el("div", { class: "sb-group" }, SYNLIGE.map(id =>
    el("button", {
      class: "sb-item" + (aktiv(id) ? " on" : ""),
      onclick: () => gaTil(id)
    }, [el("span", { html: svg(RUTER[id].ikon) }), RUTER[id].tittel])));
  nav.append(punkter);

  nav.append(el("div", { class: "sb-bunn" }, [
    el("a", { class: "sb-item", href: "/" }, [el("span", { html: svg("pil") }), "Til Saksflyt"]),
    el("button", { class: "sb-item", onclick: () => db.auth.signOut() },
      [el("span", { html: svg("ut") }), "Logg ut"])
  ]));

  return nav;
}

function byggMobilnav() {
  return el("nav", { class: "mobilnav" }, SYNLIGE.map(id =>
    el("button", {
      class: aktiv(id) ? "on" : "",
      onclick: () => gaTil(id)
    }, [el("span", { html: svg(RUTER[id].ikon) }), RUTER[id].tittel])));
}

function aktiv(id) {
  return ruteNaa === id || (id === "fakturaer" && ruteNaa === "rediger");
}

function byggTopp() {
  const v = RUTER[ruteNaa].view();
  return el("div", { class: "topbar" }, [
    el("div", {}, [
      el("h1", {}, v.tittel || RUTER[ruteNaa].tittel),
      v.undertekst && el("p", { class: "sub" }, v.undertekst)
    ])
  ]);
}

async function tegnInnhold(boks) {
  tom(boks).append(laster());
  try {
    const node = await RUTER[ruteNaa].view().bygg();
    tom(boks).append(node);
  } catch (e) {
    visFeil(e, "Henting");
    tom(boks).append(el("div", { class: "empty" }, [
      el("b", {}, "Fikk ikke hentet innholdet"),
      el("p", {}, "Noe gikk galt underveis."),
      el("div", { class: "actions" }, knapp("Prøv igjen", { klasse: "primary", ved: () => tegn() }))
    ]));
  }
}

export { gaTil, kanOkonomi, toast };
