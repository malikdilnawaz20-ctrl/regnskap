// =====================================================================
//  Innmeldinger — køen fra det offentlige familieskjemaet.
//
//  Ingenting havner i medlemsregisteret av seg selv. Medlemsansvarlig
//  ser gjennom familien, godkjenner, og først da opprettes familie og
//  medlemmer. Fødselsnummeret ligger kryptert til det skjer, vises bare
//  på forespørsel, og hvert oppslag skrives i revisjonssporet.
// =====================================================================

import {
  el, svg, kort, kpi, pille, tabell, felt, bekreft, toast, visFeil,
  tomTilstand, verktoylinje, skuff, knapp, tekstfelt, dato, tidspunkt,
  alder, antall, tom, db
} from "../lib.js";
import { S, kanMedlem, velgFra, paaNytt } from "../store.js";

const STATUS_MERKE = {
  ny:               { tekst: "Ny", farge: "gold" },
  under_behandling: { tekst: "Under behandling", farge: "blue" },
  godkjent:         { tekst: "Godkjent", farge: "green" },
  avvist:           { tekst: "Avvist", farge: "neutral" }
};

let filter = "ny";
let sok = "";

export const innmeldingerView = {
  tittel: "Innmeldinger",
  undertekst: "Familier som har meldt seg inn gjennom det offentlige skjemaet.",

  async bygg() {
    if (!S.orgId) return el("div", { class: "empty" }, "Velg en organisasjon for å se innmeldinger.");
    if (!kanMedlem()) {
      return tomTilstand({
        tittel: "Ikke tilgang",
        tekst: "Innmeldinger inneholder fødselsnummer og er derfor bare synlig for medlemsansvarlig, kasserer, styreleder og administrator.",
        ikon: "varsel"
      });
    }

    let innmeldinger = [], personer = [], lenke = null;
    try {
      const { data: iData, error: iErr } = await velgFra("innmeldinger").order("innsendt", { ascending: false });
      if (iErr) throw iErr;
      innmeldinger = iData || [];

      const { data: pData, error: pErr } = await velgFra("innmelding_personer").order("sortering");
      if (pErr) throw pErr;
      personer = pData || [];

      const { data: lData } = await velgFra("innmelding_lenker").maybeSingle();
      lenke = lData || null;
    } catch (e) {
      visFeil(e, "Henting av innmeldinger");
      return el("div", { class: "note bad" }, "Kunne ikke hente innmeldinger. Prøv å laste siden på nytt.");
    }

    const perInnmelding = new Map();
    for (const p of personer) {
      if (!perInnmelding.has(p.innmelding_id)) perInnmelding.set(p.innmelding_id, []);
      perInnmelding.get(p.innmelding_id).push(p);
    }

    const nye = innmeldinger.filter(i => i.status === "ny");
    const barnIKo = nye.reduce((n, i) =>
      n + (perInnmelding.get(i.id) || []).filter(p => p.rolle === "barn").length, 0);
    const godkjente = innmeldinger.filter(i => i.status === "godkjent");

    const rot = el("div", { class: "stack" });

    /* --- nøkkeltall ------------------------------------------------ */

    rot.append(el("div", { class: "grid g4" }, [
      kpi({ nokkel: "Venter på behandling", verdi: String(nye.length), under: antall(nye.length, "familie", "familier"), ikon: "varsel", farge: nye.length ? "gold" : undefined }),
      kpi({ nokkel: "Barn i køen", verdi: String(barnIKo), under: "Trenger drakt ved godkjenning", ikon: "medlemmer" }),
      kpi({ nokkel: "Godkjent", verdi: String(godkjente.length), under: "Lagt inn i medlemsregisteret", ikon: "ok" }),
      kpi({ nokkel: "Totalt mottatt", verdi: String(innmeldinger.length), under: "Siden skjemaet ble åpnet", ikon: "dokument" })
    ]));

    /* --- lenken ---------------------------------------------------- */

    if (lenke) {
      const url = new URL(`../innmelding/?klubb=${lenke.slug}`, location.href).href;
      rot.append(kort({
        eyebrow: "Del med foreldrene",
        tittel: "Lenke til innmeldingsskjemaet",
        beskrivelse: lenke.aapen
          ? "Send denne til foreldre, eller heng den opp som QR-kode i hallen. Ingen innlogging kreves."
          : "Skjemaet er stengt. Nye innmeldinger avvises inntil det åpnes igjen.",
        innhold: el("div", { class: "stack" }, [
          el("div", { class: "kv" }, [
            el("code", { class: "mono", style: "flex:1;min-width:0;overflow-wrap:anywhere" }, url),
            knapp("Kopier", {
              ikon: "dokument", klasse: "sm",
              ved: async () => {
                try { await navigator.clipboard.writeText(url); toast("Kopiert", "Lenken ligger på utklippstavlen."); }
                catch { toast("Kopiering gikk ikke", "Merk lenken og kopier manuelt.", true); }
              }
            }),
            knapp("Åpne", { ikon: "ut", klasse: "sm", ved: () => window.open(url, "_blank", "noopener") })
          ]),
          !lenke.aapen && el("div", { class: "note warn" }, "Skjemaet er stengt akkurat nå.")
        ])
      }));
    }

    /* --- listen ---------------------------------------------------- */

    const listeBoks = el("div");

    const tegnListe = () => {
      const q = sok.trim().toLowerCase();
      const utvalg = innmeldinger.filter(i => {
        if (filter !== "alle" && i.status !== filter) return false;
        if (!q) return true;
        const folk = (perInnmelding.get(i.id) || []).map(p => `${p.fornavn} ${p.etternavn}`).join(" ");
        return `${i.familienavn} ${i.referanse} ${i.kontakt_navn} ${i.kontakt_epost} ${i.sted} ${folk}`
          .toLowerCase().includes(q);
      });

      const rader = utvalg.map(i => {
        const folk = perInnmelding.get(i.id) || [];
        const barn = folk.filter(p => p.rolle === "barn").length;
        const m = STATUS_MERKE[i.status] || STATUS_MERKE.ny;
        return el("tr", { style: "cursor:pointer", onclick: () => aapne(i, folk) }, [
          el("td", {}, [
            el("b", {}, i.familienavn),
            el("div", { class: "sub" }, `${i.adresse}, ${i.postnr} ${i.sted}`)
          ]),
          el("td", {}, [
            `${folk.length} personer`,
            el("div", { class: "sub" }, `${folk.length - barn} voksne · ${barn} barn`)
          ]),
          el("td", {}, [
            i.kontakt_navn,
            el("div", { class: "sub" }, i.kontakt_telefon)
          ]),
          el("td", {}, tidspunkt(i.innsendt)),
          el("td", {}, pille(m.tekst, m.farge)),
          el("td", { class: "mono sub" }, i.referanse)
        ]);
      });

      tom(listeBoks).append(kort({
        tittel: "Innmeldinger",
        beskrivelse: "Klikk på en rad for å se familien og godkjenne.",
        innhold: el("div", { class: "stack" }, [
          verktoylinje({
            sok: { plassholder: "Søk etter familie, navn eller referanse …", verdi: sok, ved: v => { sok = v; tegnListe(); } },
            filtre: [
              el("select", {
                onchange: e => { filter = e.target.value; tegnListe(); }
              }, [
                { verdi: "ny", tekst: "Venter på behandling" },
                { verdi: "godkjent", tekst: "Godkjent" },
                { verdi: "avvist", tekst: "Avvist" },
                { verdi: "alle", tekst: "Alle" }
              ].map(v => el("option", { value: v.verdi, selected: v.verdi === filter }, v.tekst)))
            ]
          }),
          rader.length
            ? tabell(
                [{ t: "Familie" }, { t: "Størrelse" }, { t: "Foresatt" }, { t: "Mottatt" }, { t: "Status" }, { t: "Referanse" }],
                rader
              )
            : tomTilstand({
                tittel: filter === "ny" ? "Ingen innmeldinger venter" : "Ingenting å vise",
                tekst: filter === "ny"
                  ? "Køen er tom. Nye familier dukker opp her så snart de har sendt inn skjemaet."
                  : "Prøv et annet filter eller et annet søk.",
                ikon: "ok"
              })
        ])
      }));
    };

    tegnListe();
    rot.append(listeBoks);
    return rot;
  }
};

/* ---------------------------------------------------------------
   Detaljvisning
   --------------------------------------------------------------- */

function aapne(inm, folk) {
  const barn = folk.filter(p => p.rolle === "barn");
  const behandlet = inm.status === "godkjent" || inm.status === "avvist";

  const innhold = el("div", { class: "stack" });

  innhold.append(el("div", { class: "kv" }, [
    el("div", {}, [el("span", { class: "sub" }, "Adresse"), el("div", {}, `${inm.adresse}, ${inm.postnr} ${inm.sted}`)]),
  ]));

  innhold.append(kort({
    tittel: "Foresatt",
    klasse: "flat",
    innhold: el("div", { class: "stack" }, [
      el("div", {}, inm.kontakt_navn),
      el("div", { class: "sub" }, [
        el("a", { href: "tel:" + inm.kontakt_telefon.replace(/\s/g, "") }, inm.kontakt_telefon),
        " · ",
        el("a", { href: "mailto:" + inm.kontakt_epost }, inm.kontakt_epost)
      ])
    ])
  }));

  if (inm.notat) {
    innhold.append(el("div", { class: "note info" }, [el("div", {}, [el("b", {}, "Fra familien: "), inm.notat])]));
  }

  /* --- personene ------------------------------------------------- */

  const personBoks = el("div", { class: "stack" });
  for (const p of folk) {
    const fnrFelt = el("span", { class: "mono" }, p.fnr_maskert);
    const harFnr = !!p.fnr_maskert && !/slettet/.test(p.fnr_maskert);

    const rad = el("div", { class: "rowline" }, [
      el("div", { style: "flex:1;min-width:0" }, [
        el("b", {}, `${p.fornavn} ${p.etternavn}`),
        el("div", { class: "sub" }, [
          pille(p.rolle === "barn" ? "Barn" : "Voksen", p.rolle === "barn" ? "teal" : "blue"),
          " ",
          `${dato(p.fodselsdato)} · ${alder(p.fodselsdato)} år`,
          p.gren ? ` · ${p.gren}` : "",
          p.draktstorrelse ? ` · drakt ${p.draktstorrelse}` : "",
          p.samtykke_bilder ? " · samtykke bilder" : " · ikke samtykke bilder"
        ])
      ]),
      el("div", { style: "display:flex;align-items:center;gap:10px" }, [
        fnrFelt,
        harFnr && knapp("Vis", {
          klasse: "sm stille",
          tittel: "Oppslaget logges i revisjonssporet",
          ved: async (e) => {
            try {
              const { data, error } = await db.rpc("les_fodselsnummer", { p_person_id: p.id });
              if (error) throw error;
              fnrFelt.textContent = data || "—";
              fnrFelt.style.color = "var(--teal)";
              e?.target?.closest("button")?.remove();
              toast("Vist", "Oppslaget er skrevet i revisjonssporet.");
            } catch (err) { visFeil(err, "Oppslag av fødselsnummer"); }
          }
        })
      ])
    ]);
    personBoks.append(rad);
  }

  innhold.append(kort({
    tittel: `${folk.length} personer`,
    beskrivelse: barn.length
      ? `${folk.length - barn.length} voksne og ${antall(barn.length, "barn som skal ha drakt", "barn som skal ha drakt")}.`
      : "Ingen barn i denne innmeldingen.",
    innhold: personBoks
  }));

  innhold.append(el("div", { class: "note warn" }, [
    el("div", {}, [
      el("b", {}, "Fødselsnummer. "),
      "Vises bare når du ber om det, og hvert oppslag logges med navn og tidspunkt. ",
      "Ved godkjenning slettes nummeret herfra — medlemsregisteret beholder bare fødselsdatoen."
    ])
  ]));

  if (behandlet) {
    innhold.append(el("div", { class: inm.status === "godkjent" ? "note ok" : "note" }, [
      el("div", {}, inm.status === "godkjent"
        ? `Godkjent ${tidspunkt(inm.behandlet)}. Familien og medlemmene ligger i registeret.`
        : `Avvist ${tidspunkt(inm.behandlet)}.${inm.avvist_grunn ? " Grunn: " + inm.avvist_grunn : ""}`)
    ]));
  }

  /* --- knapper ---------------------------------------------------- */

  const bunn = behandlet ? null : el("div", { style: "display:flex;gap:10px;width:100%" }, [
    knapp("Avvis", {
      klasse: "danger",
      ved: async () => {
        const grunn = prompt("Kort grunn til avvisning (valgfritt):", "");
        if (grunn === null) return;
        try {
          const { error } = await db.rpc("avvis_innmelding", { p_id: inm.id, p_grunn: grunn });
          if (error) throw error;
          toast("Avvist", "Fødselsnummer er slettet fra innmeldingen.");
          s.lukk(); paaNytt();
        } catch (e) { visFeil(e, "Avvisning"); }
      }
    }),
    el("div", { style: "flex:1" }),
    knapp("Godkjenn og opprett medlemmer", {
      klasse: "primary",
      ved: async () => {
        const ja = await bekreft(
          "Godkjenne innmeldingen?",
          `Det opprettes én familie og ${folk.length} medlemmer i registeret. Fødselsnummer slettes fra innmeldingen i samme operasjon.`,
          "Ja, godkjenn"
        );
        if (!ja) return;
        try {
          const { data, error } = await db.rpc("godkjenn_innmelding", { p_id: inm.id });
          if (error) throw error;
          toast("Godkjent", `${data.antall} medlemmer opprettet under ${inm.familienavn}.`);
          s.lukk(); paaNytt();
        } catch (e) { visFeil(e, "Godkjenning"); }
      }
    })
  ]);

  const s = skuff({
    tittel: inm.familienavn,
    undertittel: `${inm.referanse} · mottatt ${tidspunkt(inm.innsendt)}`,
    innhold,
    bunn
  });
}
