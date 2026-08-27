// =====================================================================
//  Økonomi — bilag, prosjekter, rapporter og kontingent.
//  Kassereren møter aldri debet/kredit: kategorien peker på riktig
//  regnskapskonto under panseret.
// =====================================================================

import {
  el, kpi, svg, kort, stat, pille, tabell, felt, skjemaModal, bekreft, toast, visFeil,
  laster, kr, kr0, tilOre, dato, datoKort, iDag, eksporterExcel, lesExcel, velg, db
} from "../lib.js";
import { S, kanOkonomi, velgFra, settInn, paaNytt, aarNaa, erAdmin } from "../store.js";
import { apneArsrapport, apneRevisjonsgrunnlag } from "./rapportmal.js";

/* =====================================================================
   Felles hjelpere
   ===================================================================== */

async function hentKategorier(retning) {
  const { data, error } = await velgFra("categories", "id,navn,retning,konto_nummer,sortering")
    .eq("retning", retning).eq("aktiv", true).order("sortering");
  if (error) throw error;
  return data || [];
}

async function hentAlleKategorier() {
  const { data, error } = await velgFra("categories", "id,navn,retning,sortering")
    .eq("aktiv", true).order("sortering");
  if (error) throw error;
  return data || [];
}

async function hentProsjekter() {
  const { data, error } = await velgFra("projects", "id,navn").order("navn");
  if (error) throw error;
  return data || [];
}

async function hentKontoer() {
  const { data, error } = await velgFra("accounts", "id,navn,type").eq("aktiv", true).order("navn");
  if (error) throw error;
  return data || [];
}

async function hentVedleggMap(ids) {
  const map = new Map();
  if (!ids || !ids.length) return map;
  const { data, error } = await velgFra("attachments", "id,transaction_id,filnavn,storage_path,mime,storrelse,opprettet")
    .in("transaction_id", ids)
    .order("opprettet", { ascending: true });
  if (error) throw error;
  for (const vedlegg of data || []) {
    const liste = map.get(vedlegg.transaction_id) || [];
    liste.push(vedlegg);
    map.set(vedlegg.transaction_id, liste);
  }
  return map;
}

async function apneVedlegg(vedlegg) {
  try {
    const { data, error } = await db.storage.from("bilag").createSignedUrl(vedlegg.storage_path, 60);
    if (error) throw error;
    window.open(data.signedUrl, "_blank", "noopener");
  } catch (e) {
    visFeil(e, "Åpning av vedlegg");
  }
}

function vedleggsLenker(vedlegg) {
  return el("div", { class: "filelinks" }, vedlegg.map(fil => el("button", {
    class: "btn stille sm filelink",
    title: "Åpne " + fil.filnavn,
    onclick: e => { e.stopPropagation(); apneVedlegg(fil); }
  }, [
    el("span", { html: svg("dokument") }),
    el("span", { class: "filelink-name" }, fil.filnavn)
  ])));
}

function harKontoutskrift(t) {
  return String(t.bilagsnummer || "").startsWith("FIKEN-")
    || /^\[Fiken\b/i.test(t.beskrivelse || "");
}

function vedleggCelle(t, vedleggMap) {
  const vedlegg = vedleggMap.get(t.id) || [];
  if (vedlegg.length) return el("div", { class: "filelinks" }, [
    pille("✓ Vedlagt", "green"),
    vedleggsLenker(vedlegg)
  ]);
  if (harKontoutskrift(t)) return pille("✓ Kontoutskrift", "green");
  if (t.type === "inntekt") return pille("✓ Bankført", "green");
  if (t.type === "overforing") return pille("✓ Bankført", "green");
  return pille("Mangler vedlegg", "gold");
}

function erInternOverforing(t) {
  const kategori = t.categories?.navn || "";
  const beskrivelse = t.beskrivelse || "";
  return t.type === "overforing"
    || kategori === "Overføring internkonto"
    || /overføring\s+(internkonto|mellom\s+egne\s+kontoer)/i.test(beskrivelse);
}

function statusTekst(s) {
  return { planlegges: "Planlegges", aktiv: "Aktiv", avsluttet: "Avsluttet", rapportert: "Rapportert" }[s] || s;
}
function statusFarge(s) {
  return { planlegges: "neutral", aktiv: "blue", avsluttet: "neutral", rapportert: "green" }[s] || "neutral";
}

/* =====================================================================
   hentOkonomiTall — brukes av forsiden
   ===================================================================== */

export async function hentOkonomiTall() {
  const tomtall = { inntekt_ore: 0, utgift_ore: 0, resultat_ore: 0, ubetalt_ore: 0, saldo_ore: 0, manglerVedlegg: 0 };
  if (!S.orgId) return tomtall;
  try {
    const aar = aarNaa();

    const { data: kontoer, error: e2 } = await velgFra("accounts", "aapningssaldo_ore");
    if (e2) throw e2;

    const { data: alleTxn, error: e3 } = await velgFra("transactions",
      "id,bilagsnummer,type,belop_ore,regnskapsaar,beskrivelse,categories(navn)");
    if (e3) throw e3;

    const { data: krav, error: e4 } = await velgFra("payment_claims", "belop_ore,betalt_ore,status")
      .not("status", "in", "(betalt,kansellert,fritatt)");
    if (e4) throw e4;

    const { data: vedlegg, error: e6 } = await velgFra("attachments", "transaction_id");
    if (e6) throw e6;

    const synligeTxn = (alleTxn || []).filter(t => !erInternOverforing(t));
    const aarTxn = synligeTxn.filter(t => t.regnskapsaar === aar);
    const aapning = (kontoer || []).reduce((s, k) => s + (k.aapningssaldo_ore || 0), 0);
    const bevegelse = synligeTxn.reduce((s, t) =>
      s + (t.type === "inntekt" ? t.belop_ore : t.type === "utgift" ? -t.belop_ore : 0), 0);
    const ubetalt = (krav || []).reduce((s, k) => s + Math.max(0, (k.belop_ore || 0) - (k.betalt_ore || 0)), 0);
    const inntekt_ore = aarTxn.filter(t => t.type === "inntekt").reduce((s, t) => s + t.belop_ore, 0);
    const utgift_ore = aarTxn.filter(t => t.type === "utgift").reduce((s, t) => s + t.belop_ore, 0);

    const harVedlegg = new Set((vedlegg || []).map(v => v.transaction_id));
    const manglerVedlegg = (aarTxn || []).filter(t =>
      t.type === "utgift" && !harKontoutskrift(t) && !harVedlegg.has(t.id)).length;

    return {
      inntekt_ore,
      utgift_ore,
      resultat_ore: inntekt_ore - utgift_ore,
      ubetalt_ore: ubetalt,
      saldo_ore: aapning + bevegelse,
      manglerVedlegg
    };
  } catch (e) {
    visFeil(e, "Henting av økonomitall");
    return tomtall;
  }
}

/* =====================================================================
   okonomiView
   ===================================================================== */

async function hentTransaksjoner(filter) {
  let sp = velgFra("transactions",
    "id,bilagsnummer,dato,type,beskrivelse,belop_ore,motpart,category_id,project_id,categories(navn),projects(navn)")
    .eq("regnskapsaar", filter.aar)
    .order("dato", { ascending: false })
    .order("bilagsnummer", { ascending: false });
  if (filter.category_id) sp = sp.eq("category_id", filter.category_id);
  if (filter.project_id) sp = sp.eq("project_id", filter.project_id);
  if (filter.sok) {
    const s = filter.sok.trim().replace(/[,()%]/g, " ");
    if (s) sp = sp.or(`beskrivelse.ilike.%${s}%,motpart.ilike.%${s}%,bilagsnummer.ilike.%${s}%`);
  }
  const { data, error } = await sp;
  if (error) throw error;
  return (data || []).filter(t => !erInternOverforing(t));
}

function txnRad(t, vedleggMap) {
  return el("tr", { class: "klikk", onclick: () => apneBilag(t.id) }, [
    el("td", { class: "mono" }, t.bilagsnummer),
    el("td", {}, datoKort(t.dato)),
    el("td", {}, [
      el("span", {}, t.beskrivelse),
      t.motpart ? el("span", { class: "who" }, t.motpart) : null
    ]),
    el("td", {}, t.categories?.navn || "—"),
    el("td", {}, t.projects?.navn || "—"),
    el("td", { class: "num" }, (t.type === "utgift" ? "− " : "") + kr(t.belop_ore)),
    el("td", {}, vedleggCelle(t, vedleggMap))
  ]);
}

async function apneBilag(id) {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang til økonomi.", true); return; }
  try {
    const { data: t, error } = await velgFra("transactions", "*").eq("id", id).single();
    if (error) throw error;

    const [kategorier, kontoer, prosjekter, vedleggMap] = await Promise.all([
      hentKategorier(t.type), hentKontoer(), hentProsjekter(), hentVedleggMap([id])
    ]);

    const dokumentasjonHolder = el("div", { class: "bilag-dokumentasjon" });
    const tegnDokumentasjon = async (map = null) => {
      const gjeldende = map || await hentVedleggMap([id]);
      const vedlegg = gjeldende.get(id) || [];
      dokumentasjonHolder.replaceChildren(
        el("div", { class: "between" }, [
          el("div", {}, [
            el("b", {}, "Dokumentasjon"),
            el("span", { class: "who" }, vedlegg.length
              ? `${vedlegg.length} ${vedlegg.length === 1 ? "fil" : "filer"}`
              : t.type === "inntekt" ? "Valgfritt for innbetalinger" : "Ingen fil vedlagt")
          ]),
          el("button", {
            class: "btn sm",
            onclick: async () => {
              const lastetOpp = await lastOppKvittering(id);
              if (lastetOpp) await tegnDokumentasjon();
            }
          }, [el("span", { html: svg("last") }), "Last opp"])
        ]),
        vedlegg.length ? vedleggsLenker(vedlegg) : null
      );
    };
    await tegnDokumentasjon(vedleggMap);

    const resultat = await skjemaModal({
      tittel: "Bilag " + t.bilagsnummer,
      beskrivelse: t.type === "utgift" ? "Utgift" : t.type === "inntekt" ? "Inntekt" : "Overføring",
      lagreTekst: "Lagre endringer",
      felter: [
        { navn: "dato", label: "Dato", type: "date", verdi: t.dato },
        { navn: "belop", label: "Beløp", type: "text", verdi: kr(t.belop_ore) },
        { navn: "beskrivelse", label: "Hva gjaldt det?", type: "text", verdi: t.beskrivelse, bredde: "full" },
        { navn: "motpart", label: "Hvem", type: "text", verdi: t.motpart || "" },
        { navn: "category_id", label: "Kategori", type: "select", verdi: t.category_id, valg: kategorier.map(k => ({ verdi: k.id, tekst: k.navn })) },
        { navn: "project_id", label: "Prosjekt", type: "select", verdi: t.project_id || "", valg: [{ verdi: "", tekst: "— Ingen —" }, ...prosjekter.map(p => ({ verdi: p.id, tekst: p.navn }))] },
        { navn: "account_id", label: "Konto", type: "select", verdi: t.account_id || "", valg: kontoer.map(k => ({ verdi: k.id, tekst: k.navn })) }
      ],
      ekstra: dokumentasjonHolder,
      onLagre: async (data) => {
        const belop_ore = tilOre(data.belop);
        if (!(belop_ore > 0)) { toast("Kan ikke lagre", "Beløpet må være større enn null.", true); return false; }
        if (!data.beskrivelse) { toast("Kan ikke lagre", "Du må skrive hva det gjaldt.", true); return false; }
        if (!data.dato) { toast("Kan ikke lagre", "Du må velge en dato.", true); return false; }
        const kategori = kategorier.find(k => k.id === data.category_id);
        const { error: feil } = await db.from("transactions").update({
          dato: data.dato,
          beskrivelse: data.beskrivelse,
          belop_ore,
          motpart: data.motpart || null,
          category_id: data.category_id || null,
          konto_nummer: kategori?.konto_nummer ?? t.konto_nummer,
          project_id: data.project_id || null,
          account_id: data.account_id || null,
          regnskapsaar: new Date(data.dato).getFullYear()
        }).eq("id", id);
        if (feil) throw feil;
        return true;
      },
      onSlett: kanOkonomi() ? async () => {
        const { error: feil } = await db.from("transactions").delete().eq("id", id);
        if (feil) throw feil;
      } : null
    });

    if (resultat === "slettet") { toast("Bilag slettet", "Bilaget er fjernet."); paaNytt(); }
    else if (resultat !== null) { toast("Bilag oppdatert", "Endringene er lagret."); paaNytt(); }
  } catch (e) {
    visFeil(e, "Åpning av bilag");
  }
}

export const okonomiView = {
  tittel: "Økonomi",
  undertekst: "Oversikt over inntekter, utgifter, saldo og bilag.",
  async bygg() {
    const filter = { aar: aarNaa(), category_id: "", project_id: "", sok: "" };

    const [tall, alleKategorier, prosjekter] = await Promise.all([
      hentOkonomiTall(), hentAlleKategorier(), hentProsjekter()
    ]);

    const statsRad = el("div", { class: "grid g4" }, [
      kpi({ ikon: "okonomi", nokkel: "Saldo", verdi: kr(tall.saldo_ore) + " kr" }),
      kpi({ ikon: "opp", nokkel: "Inntekter hittil i år", verdi: kr(tall.inntekt_ore) + " kr" }),
      kpi({ ikon: "betaling", nokkel: "Utgifter hittil i år", verdi: kr(tall.utgift_ore) + " kr" }),
      kpi({ ikon: "rapport", nokkel: "Resultat", verdi: kr(tall.resultat_ore) + " kr", farge: tall.resultat_ore >= 0 ? "pos" : "neg" })
    ]);

    const hurtigRad = kanOkonomi()
      ? el("div", { class: "grid g2" }, [
          el("button", { class: "btn big primary", onclick: () => registrerModal("utgift") }, [
            el("span", {}, "Registrer utgift"),
            el("small", {}, "Kvittering, faktura eller kontantutlegg")
          ]),
          el("button", { class: "btn big", onclick: () => registrerModal("inntekt") }, [
            el("span", {}, "Registrer inntekt"),
            el("small", {}, "Medlemskontingent, tilskudd, salg og gaver")
          ])
        ])
      : el("div", { class: "note info" }, "Rollen din gir bare lesetilgang til økonomi. Be en administrator eller kasserer om å registrere bilag.");

    const aarValg = [];
    for (let a = aarNaa() + 1; a >= aarNaa() - 5; a--) aarValg.push({ verdi: String(a), tekst: String(a) });
    const aarSel = velg("aar", aarValg, String(filter.aar));
    const kategoriSel = velg("kategori",
      [{ verdi: "", tekst: "Alle kategorier" }, ...alleKategorier.map(k => ({ verdi: k.id, tekst: k.navn + (k.retning === "utgift" ? " (utgift)" : " (inntekt)") }))],
      "");
    const prosjektSel = velg("prosjekt",
      [{ verdi: "", tekst: "Alle prosjekter" }, ...prosjekter.map(p => ({ verdi: p.id, tekst: p.navn }))],
      "");

    const tabellHolder = el("div");

    async function lastTabell() {
      tabellHolder.replaceChildren(laster("Henter transaksjoner …"));
      try {
        const rader = await hentTransaksjoner(filter);
        const vedleggMap = await hentVedleggMap(rader.map(r => r.id));
        tabellHolder.replaceChildren(tabell(
          [{ t: "Bilag" }, { t: "Dato" }, { t: "Beskrivelse" }, { t: "Kategori" }, { t: "Prosjekt" }, { t: "Beløp", num: true }, { t: "Vedlegg" }],
          rader.map(t => txnRad(t, vedleggMap)),
          "Ingen transaksjoner funnet for dette filteret."
        ));
      } catch (e) {
        visFeil(e, "Henting av transaksjoner");
        tabellHolder.replaceChildren(el("div", { class: "empty" }, "Klarte ikke å hente transaksjoner."));
      }
    }

    aarSel.addEventListener("change", () => { filter.aar = Number(aarSel.value); lastTabell(); });
    kategoriSel.addEventListener("change", () => { filter.category_id = kategoriSel.value; lastTabell(); });
    prosjektSel.addEventListener("change", () => { filter.project_id = prosjektSel.value; lastTabell(); });

    let sokTimer;
    const sokInput = el("input", {
      type: "text", placeholder: "Søk i beskrivelse, motpart eller bilagsnummer",
      oninput: e => {
        clearTimeout(sokTimer);
        const verdi = e.target.value;
        sokTimer = setTimeout(() => { filter.sok = verdi; lastTabell(); }, 350);
      }
    });

    const filterRad = el("div", { class: "grid g4" }, [
      felt("Regnskapsår", aarSel),
      felt("Kategori", kategoriSel),
      felt("Prosjekt", prosjektSel),
      felt("Søk", sokInput)
    ]);

    const eksportKnapp = el("button", {
      class: "btn", onclick: async () => {
        try {
          const rader = await hentTransaksjoner(filter);
          await eksporterExcel(`transaksjoner-${filter.aar}.xlsx`, {
            Transaksjoner: rader.map(t => ({
              "Bilagsnr": t.bilagsnummer, "Dato": datoKort(t.dato), "Type": t.type === "utgift" ? "Utgift" : "Inntekt",
              "Beskrivelse": t.beskrivelse, "Motpart": t.motpart || "", "Kategori": t.categories?.navn || "",
              "Prosjekt": t.projects?.navn || "",
              "Beløp (kr)": Number((t.belop_ore / 100).toFixed(2)) * (t.type === "utgift" ? -1 : 1)
            }))
          });
          toast("Eksportert", "Regnearket er lastet ned.");
        } catch (e) { visFeil(e, "Eksport"); }
      }
    }, "Eksporter til Excel");

    await lastTabell();

    return el("div", { class: "stack" }, [
      statsRad,
      hurtigRad,
      kort({ tittel: "Transaksjoner", beskrivelse: "Alle bilag for valgt regnskapsår.", innhold: [filterRad, tabellHolder], hoyre: eksportKnapp })
    ]);
  }
};

/* =====================================================================
   registrerModal — hjertet i produktet
   ===================================================================== */

function velgFil() {
  return new Promise(resolve => {
    const input = el("input", { type: "file", accept: "image/*,.pdf", style: "display:none" });
    input.addEventListener("change", () => resolve(input.files[0] || null));
    document.body.append(input);
    input.click();
    setTimeout(() => input.remove(), 60000);
  });
}

async function tilbyKvitteringsopplasting(transaksjonsId) {
  const vilLaste = await bekreft(
    "Last opp kvittering?",
    "Du kan laste opp kvitteringen eller fakturaen nå, eller senere fra bilaget.",
    "Velg fil"
  );
  if (!vilLaste) return;

  const lastetOpp = await lastOppKvittering(transaksjonsId);
  if (lastetOpp) paaNytt();
}

async function lastOppKvittering(transaksjonsId) {
  const fil = await velgFil();
  if (!fil) return false;

  try {
    const sti = `${S.orgId}/${transaksjonsId}/${fil.name}`;
    const { error: opplastingsfeil } = await db.storage.from("bilag").upload(sti, fil, { upsert: true });
    if (opplastingsfeil) throw opplastingsfeil;

    const { error: radfeil } = await settInn("attachments", {
      transaction_id: transaksjonsId,
      filnavn: fil.name,
      storage_path: sti,
      mime: fil.type || null,
      storrelse: fil.size || null,
      lastet_opp_av: S.bruker?.id || null
    });
    if (radfeil) throw radfeil;

    toast("Kvittering lastet opp", fil.name);
    return true;
  } catch (e) {
    toast(
      "Opplasting av kvittering feilet",
      "Bilaget er lagret, men kvitteringen kunne ikke lastes opp. Prøv igjen fra bilaget. (" + (e?.message || "ukjent feil") + ")",
      true
    );
    return false;
  }
}

export async function registrerModal(type) {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang til økonomi.", true); return false; }

  let kategorier, kontoer, prosjekter;
  try {
    [kategorier, kontoer, prosjekter] = await Promise.all([hentKategorier(type), hentKontoer(), hentProsjekter()]);
  } catch (e) { visFeil(e, "Henting av lister"); return false; }

  const erUtgift = type === "utgift";

  if (!kategorier.length) {
    toast("Mangler kategorier", `Det finnes ingen ${erUtgift ? "utgifts" : "inntekts"}kategorier ennå. Legg til i innstillinger først.`, true);
    return false;
  }

  let lagretId = null;

  const resultat = await skjemaModal({
    tittel: erUtgift ? "Registrer utgift" : "Registrer inntekt",
    beskrivelse: "Bilagsnummer settes automatisk.",
    lagreTekst: "Lagre",
    felter: [
      { navn: "dato", label: "Dato", type: "date", verdi: iDag() },
      { navn: "belop", label: "Beløp", type: "text", plassholder: "0,00" },
      { navn: "beskrivelse", label: "Hva gjaldt det?", type: "text", bredde: "full" },
      { navn: "motpart", label: erUtgift ? "Hvem (leverandør)" : "Hvem (betaler)", type: "text" },
      { navn: "category_id", label: "Kategori", type: "select", valg: kategorier.map(k => ({ verdi: k.id, tekst: k.navn })) },
      { navn: "project_id", label: "Prosjekt (valgfritt)", type: "select", valg: [{ verdi: "", tekst: "— Ingen —" }, ...prosjekter.map(p => ({ verdi: p.id, tekst: p.navn }))] },
      { navn: "account_id", label: erUtgift ? "Betalt fra konto" : "Inn på konto", type: "select", valg: kontoer.map(k => ({ verdi: k.id, tekst: k.navn })) }
    ],
    onLagre: async (data) => {
      const belop_ore = tilOre(data.belop);
      if (!(belop_ore > 0)) { toast("Kan ikke lagre", "Beløpet må være større enn null.", true); return false; }
      if (!data.beskrivelse) { toast("Kan ikke lagre", "Du må skrive hva det gjaldt.", true); return false; }
      if (!data.dato) { toast("Kan ikke lagre", "Du må velge en dato.", true); return false; }

      const kategori = kategorier.find(k => k.id === data.category_id);
      const rad = {
        dato: data.dato,
        type,
        beskrivelse: data.beskrivelse,
        belop_ore,
        motpart: data.motpart || null,
        category_id: data.category_id || null,
        konto_nummer: kategori?.konto_nummer ?? null,
        project_id: data.project_id || null,
        account_id: data.account_id || null,
        regnskapsaar: new Date(data.dato).getFullYear()
      };

      const { data: rad2, error } = await settInn("transactions", rad).select("id").single();
      if (error) throw error;
      lagretId = rad2.id;
      return true;
    }
  });

  if (resultat === null) return false;

  toast(erUtgift ? "Utgift registrert" : "Inntekt registrert", "Bilaget er lagret.");
  paaNytt();

  if (lagretId) await tilbyKvitteringsopplasting(lagretId);

  return true;
}

/* =====================================================================
   prosjekterView
   ===================================================================== */

async function hentProsjektStatus() {
  const [{ data: prosjekter, error: e1 }, { data: status, error: e2 }] = await Promise.all([
    velgFra("projects", "*").order("navn"),
    velgFra("v_prosjekt_status", "project_id,brukt_ore,mottatt_ore,gjenstaar_ore")
  ]);
  if (e1) throw e1;
  if (e2) throw e2;
  const statusMap = new Map((status || []).map(s => [s.project_id, s]));
  return (prosjekter || []).map(p => ({
    ...p,
    ...(statusMap.get(p.id) || { brukt_ore: 0, mottatt_ore: 0, gjenstaar_ore: p.tilskudd_ore })
  }));
}

function prosjektKort(p, rot) {
  const pct = p.tilskudd_ore > 0 ? Math.round((p.brukt_ore / p.tilskudd_ore) * 100) : 0;
  return kort({
    eyebrow: p.tilskuddsgiver || "Uten tilskuddsgiver",
    tittel: p.navn,
    beskrivelse: p.beskrivelse || null,
    innhold: [
      el("dl", { class: "kv" }, [
        el("dt", {}, "Tilskudd"), el("dd", {}, kr0(p.tilskudd_ore) + " kr"),
        el("dt", {}, "Brukt"), el("dd", {}, kr0(p.brukt_ore) + " kr"),
        el("dt", {}, "Gjenstår"), el("dd", {}, kr0(p.gjenstaar_ore) + " kr")
      ]),
      kpi({ nokkel: "Brukt av tilskudd", verdi: pct + " %", andel: pct }),
      pille(statusTekst(p.status), statusFarge(p.status))
    ],
    hoyre: el("button", { class: "btn sm", onclick: () => visProsjektDetalj(rot, p.id) }, "Åpne")
  });
}

async function nyttProsjektModal() {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang.", true); return false; }
  const resultat = await skjemaModal({
    tittel: "Nytt prosjekt",
    beskrivelse: "Registrer et prosjekt eller tilskudd som skal følges opp separat.",
    felter: [
      { navn: "navn", label: "Navn", type: "text", bredde: "full" },
      { navn: "beskrivelse", label: "Beskrivelse", type: "textarea", bredde: "full" },
      { navn: "tilskuddsgiver", label: "Tilskuddsgiver", type: "text" },
      { navn: "tilskudd", label: "Tilskudd", type: "text", plassholder: "0,00" },
      { navn: "start_dato", label: "Start", type: "date" },
      { navn: "slutt_dato", label: "Slutt", type: "date" },
      { navn: "rapportfrist", label: "Rapporteringsfrist", type: "date" },
      {
        navn: "status", label: "Status", type: "select", valg: [
          { verdi: "planlegges", tekst: "Planlegges" },
          { verdi: "aktiv", tekst: "Aktiv" },
          { verdi: "avsluttet", tekst: "Avsluttet" },
          { verdi: "rapportert", tekst: "Rapportert" }
        ]
      }
    ],
    onLagre: async (data) => {
      if (!data.navn) { toast("Kan ikke lagre", "Prosjektet må ha et navn.", true); return false; }
      const { error } = await settInn("projects", {
        navn: data.navn,
        beskrivelse: data.beskrivelse || null,
        tilskuddsgiver: data.tilskuddsgiver || null,
        tilskudd_ore: tilOre(data.tilskudd),
        start_dato: data.start_dato || null,
        slutt_dato: data.slutt_dato || null,
        rapportfrist: data.rapportfrist || null,
        status: data.status
      });
      if (error) throw error;
      return true;
    }
  });
  return resultat !== null;
}

async function eksporterProsjekt(p, bilag) {
  try {
    const rader = bilag.map(t => ({
      "Bilagsnr": t.bilagsnummer,
      "Dato": datoKort(t.dato),
      "Type": t.type === "utgift" ? "Utgift" : "Inntekt",
      "Beskrivelse": t.beskrivelse,
      "Motpart": t.motpart || "",
      "Kategori": t.categories?.navn || "",
      "Beløp (kr)": Number((t.belop_ore / 100).toFixed(2)) * (t.type === "utgift" ? -1 : 1)
    }));
    const trygtNavn = p.navn.replace(/[^\wæøåÆØÅ -]/g, "").trim() || "prosjekt";
    await eksporterExcel(`prosjektregnskap-${trygtNavn}.xlsx`, { Bilag: rader });
    toast("Eksportert", "Prosjektregnskapet er lastet ned.");
  } catch (e) { visFeil(e, "Eksport av prosjektregnskap"); }
}

async function visProsjektDetalj(rot, id) {
  rot.replaceChildren(laster("Henter prosjektregnskap …"));
  try {
    const { data: p, error: e1 } = await velgFra("projects", "*").eq("id", id).single();
    if (e1) throw e1;

    const { data: bilag, error: e2 } = await velgFra("transactions",
      "id,bilagsnummer,dato,type,beskrivelse,belop_ore,motpart,category_id,categories(navn)")
      .eq("project_id", id).order("dato");
    if (e2) throw e2;

    const idListe = (bilag || []).map(t => t.id);
    const vedleggMap = await hentVedleggMap(idListe);

    const sumPerKategori = new Map();
    for (const t of bilag || []) {
      const navn = t.categories?.navn || "Uten kategori";
      const fortegn = t.type === "utgift" ? -1 : 1;
      sumPerKategori.set(navn, (sumPerKategori.get(navn) || 0) + fortegn * t.belop_ore);
    }

    const brukt = (bilag || []).filter(t => t.type === "utgift").reduce((s, t) => s + t.belop_ore, 0);
    const mottatt = (bilag || []).filter(t => t.type === "inntekt").reduce((s, t) => s + t.belop_ore, 0);

    const tilbake = el("button", { class: "btn sm", onclick: () => visProsjektListe(rot) }, "← Tilbake til prosjekter");
    const eksportKnapp = el("button", { class: "btn", onclick: () => eksporterProsjekt(p, bilag || []) }, "Eksporter prosjektregnskap");

    const sammendrag = kort({
      tittel: p.navn,
      eyebrow: p.tilskuddsgiver || "Uten tilskuddsgiver",
      beskrivelse: p.beskrivelse,
      innhold: el("dl", { class: "kv" }, [
        el("dt", {}, "Tilskudd"), el("dd", {}, kr0(p.tilskudd_ore) + " kr"),
        el("dt", {}, "Mottatt"), el("dd", {}, kr0(mottatt) + " kr"),
        el("dt", {}, "Brukt"), el("dd", {}, kr0(brukt) + " kr"),
        el("dt", {}, "Gjenstår"), el("dd", {}, kr0(p.tilskudd_ore - brukt) + " kr"),
        el("dt", {}, "Rapporteringsfrist"), el("dd", {}, dato(p.rapportfrist))
      ]),
      hoyre: eksportKnapp
    });

    const kategoriKort = kort({
      tittel: "Sum per kategori",
      innhold: tabell(
        [{ t: "Kategori" }, { t: "Beløp", num: true }],
        [...sumPerKategori.entries()].map(([navn, sum]) => el("tr", {}, [
          el("td", {}, navn), el("td", { class: "num" }, (sum < 0 ? "− " : "") + kr(Math.abs(sum)))
        ])),
        "Ingen bilag ennå."
      )
    });

    const bilagKort = kort({
      tittel: "Bilag",
      beskrivelse: (bilag || []).length + " bilag knyttet til prosjektet.",
      innhold: tabell(
        [{ t: "Bilag" }, { t: "Dato" }, { t: "Beskrivelse" }, { t: "Kategori" }, { t: "Beløp", num: true }, { t: "Vedlegg" }],
        (bilag || []).map(t => el("tr", {}, [
          el("td", { class: "mono" }, t.bilagsnummer),
          el("td", {}, datoKort(t.dato)),
          el("td", {}, [el("span", {}, t.beskrivelse), t.motpart ? el("span", { class: "who" }, t.motpart) : null]),
          el("td", {}, t.categories?.navn || "—"),
          el("td", { class: "num" }, (t.type === "utgift" ? "− " : "") + kr(t.belop_ore)),
          el("td", {}, vedleggCelle(t, vedleggMap))
        ])),
        "Ingen bilag registrert på dette prosjektet ennå."
      )
    });

    rot.replaceChildren(tilbake, sammendrag, kategoriKort, bilagKort);
  } catch (e) {
    visFeil(e, "Henting av prosjektdetaljer");
  }
}

async function visProsjektListe(rot) {
  rot.replaceChildren(laster("Henter prosjekter …"));
  try {
    const prosjekter = await hentProsjektStatus();

    const topprad = el("div", { class: "between" }, [
      kanOkonomi() ? null : el("div", { class: "note info" }, "Rollen din gir bare lesetilgang til prosjekter."),
      kanOkonomi() ? el("button", {
        class: "btn primary", onclick: async () => {
          const ok = await nyttProsjektModal();
          if (ok) { toast("Prosjekt opprettet", "Prosjektet er lagt til."); paaNytt(); }
        }
      }, "Nytt prosjekt") : null
    ]);

    const kortListe = el("div", { class: "grid g3" },
      prosjekter.length
        ? prosjekter.map(p => prosjektKort(p, rot))
        : [el("div", { class: "empty" }, "Ingen prosjekter registrert ennå.")]
    );

    rot.replaceChildren(topprad, kortListe);
  } catch (e) {
    visFeil(e, "Henting av prosjekter");
    rot.replaceChildren(el("div", { class: "empty" }, "Klarte ikke å hente prosjekter."));
  }
}

export const prosjekterView = {
  tittel: "Prosjekter",
  undertekst: "Tilskudd, prosjektregnskap og rapportering til tilskuddsgivere.",
  async bygg() {
    const rot = el("div", { class: "stack" });
    await visProsjektListe(rot);
    return rot;
  }
};

/* =====================================================================
   rapporterView
   ===================================================================== */

async function hentResultatregnskap(aar) {
  const { data, error } = await velgFra("transactions", "type,belop_ore,category_id,categories(navn)")
    .eq("regnskapsaar", aar);
  if (error) throw error;
  const inntekter = new Map(), utgifter = new Map();
  for (const t of data || []) {
    const m = t.type === "inntekt" ? inntekter : t.type === "utgift" ? utgifter : null;
    if (!m) continue;
    const navn = t.categories?.navn || "Uten kategori";
    m.set(navn, (m.get(navn) || 0) + t.belop_ore);
  }
  const sumInn = [...inntekter.values()].reduce((s, v) => s + v, 0);
  const sumUt = [...utgifter.values()].reduce((s, v) => s + v, 0);
  return { inntekter, utgifter, sumInn, sumUt, resultat: sumInn - sumUt };
}

async function hentBalanse() {
  const { data: kontoer, error: e1 } = await velgFra("accounts", "id,navn,aapningssaldo_ore").eq("aktiv", true);
  if (e1) throw e1;
  const { data: txn, error: e2 } = await velgFra("transactions", "account_id,type,belop_ore");
  if (e2) throw e2;

  const bevegelse = new Map();
  for (const t of txn || []) {
    if (!t.account_id) continue;
    const delta = t.type === "inntekt" ? t.belop_ore : t.type === "utgift" ? -t.belop_ore : 0;
    bevegelse.set(t.account_id, (bevegelse.get(t.account_id) || 0) + delta);
  }
  const bankrader = (kontoer || []).map(k => ({ navn: k.navn, saldo_ore: k.aapningssaldo_ore + (bevegelse.get(k.id) || 0) }));
  const sumBank = bankrader.reduce((s, k) => s + k.saldo_ore, 0);

  const { data: krav, error: e3 } = await velgFra("payment_claims", "belop_ore,betalt_ore,status")
    .not("status", "in", "(betalt,kansellert,fritatt)");
  if (e3) throw e3;
  const fordringer = (krav || []).reduce((s, k) => s + Math.max(0, (k.belop_ore || 0) - (k.betalt_ore || 0)), 0);

  return { bankrader, sumBank, fordringer, sumEiendeler: sumBank + fordringer };
}

async function eksporterResultatregnskap(aar) {
  const r = await hentResultatregnskap(aar);
  const rader = [
    ...[...r.inntekter.entries()].map(([k, v]) => ({ Type: "Inntekt", Kategori: k, "Beløp (kr)": Number((v / 100).toFixed(2)) })),
    ...[...r.utgifter.entries()].map(([k, v]) => ({ Type: "Utgift", Kategori: k, "Beløp (kr)": -Number((v / 100).toFixed(2)) })),
    { Type: "SUM", Kategori: "Resultat", "Beløp (kr)": Number((r.resultat / 100).toFixed(2)) }
  ];
  await eksporterExcel(`resultatregnskap-${aar}.xlsx`, { Resultatregnskap: rader });
}

async function eksporterBalanse() {
  const b = await hentBalanse();
  const rader = [
    ...b.bankrader.map(k => ({ Konto: k.navn, "Saldo (kr)": Number((k.saldo_ore / 100).toFixed(2)) })),
    { Konto: "Kundefordringer (ubetalte krav)", "Saldo (kr)": Number((b.fordringer / 100).toFixed(2)) },
    { Konto: "Sum eiendeler", "Saldo (kr)": Number((b.sumEiendeler / 100).toFixed(2)) }
  ];
  await eksporterExcel("balanse.xlsx", { Balanse: rader });
}

async function eksporterHovedbok(aar) {
  const { data, error } = await velgFra("transactions", "bilagsnummer,dato,type,beskrivelse,belop_ore,konto_nummer,categories(navn)")
    .eq("regnskapsaar", aar).order("konto_nummer").order("dato");
  if (error) throw error;
  const rader = (data || []).map(t => ({
    "Konto": t.konto_nummer || "",
    "Kategori": t.categories?.navn || "",
    "Bilagsnr": t.bilagsnummer,
    "Dato": datoKort(t.dato),
    "Beskrivelse": t.beskrivelse,
    "Beløp (kr)": Number((t.belop_ore / 100).toFixed(2)) * (t.type === "utgift" ? -1 : 1)
  }));
  await eksporterExcel(`hovedbok-${aar}.xlsx`, { Hovedbok: rader });
}

async function eksporterBilagsjournal(aar) {
  const { data, error } = await velgFra("transactions",
    "bilagsnummer,dato,type,beskrivelse,motpart,belop_ore,categories(navn),projects(navn)")
    .eq("regnskapsaar", aar).order("bilagsnummer");
  if (error) throw error;
  const rader = (data || []).map(t => ({
    "Bilagsnr": t.bilagsnummer, "Dato": datoKort(t.dato), "Type": t.type === "utgift" ? "Utgift" : "Inntekt",
    "Beskrivelse": t.beskrivelse, "Motpart": t.motpart || "", "Kategori": t.categories?.navn || "",
    "Prosjekt": t.projects?.navn || "", "Beløp (kr)": Number((t.belop_ore / 100).toFixed(2))
  }));
  await eksporterExcel(`bilagsjournal-${aar}.xlsx`, { Bilagsjournal: rader });
}

async function eksporterAlleProsjekter() {
  const prosjekter = await hentProsjektStatus();
  const rader = prosjekter.map(p => ({
    "Prosjekt": p.navn, "Tilskuddsgiver": p.tilskuddsgiver || "", "Tilskudd (kr)": Number((p.tilskudd_ore / 100).toFixed(2)),
    "Brukt (kr)": Number((p.brukt_ore / 100).toFixed(2)), "Gjenstår (kr)": Number((p.gjenstaar_ore / 100).toFixed(2)),
    "Status": statusTekst(p.status)
  }));
  await eksporterExcel("prosjektregnskap.xlsx", { Prosjekter: rader });
}

async function eksporterPerAktivitet(aar) {
  const { data, error } = await velgFra("transactions", "type,belop_ore,activity_id,activities(navn)").eq("regnskapsaar", aar);
  if (error) throw error;
  const map = new Map();
  for (const t of data || []) {
    const navn = t.activities?.navn || "Uten aktivitet";
    const rad = map.get(navn) || { inntekt: 0, utgift: 0 };
    if (t.type === "inntekt") rad.inntekt += t.belop_ore; else if (t.type === "utgift") rad.utgift += t.belop_ore;
    map.set(navn, rad);
  }
  const rader = [...map.entries()].map(([navn, r]) => ({
    "Aktivitet": navn, "Inntekter (kr)": Number((r.inntekt / 100).toFixed(2)),
    "Utgifter (kr)": Number((r.utgift / 100).toFixed(2)), "Resultat (kr)": Number(((r.inntekt - r.utgift) / 100).toFixed(2))
  }));
  await eksporterExcel(`aktiviteter-${aar}.xlsx`, { Aktiviteter: rader });
}

async function eksporterAarsoversikt(aar) {
  const r = await hentResultatregnskap(aar);
  const b = await hentBalanse();
  const resultatRader = [
    ...[...r.inntekter.entries()].map(([k, v]) => ({ Type: "Inntekt", Kategori: k, "Beløp (kr)": Number((v / 100).toFixed(2)) })),
    ...[...r.utgifter.entries()].map(([k, v]) => ({ Type: "Utgift", Kategori: k, "Beløp (kr)": -Number((v / 100).toFixed(2)) })),
    { Type: "SUM", Kategori: "Resultat", "Beløp (kr)": Number((r.resultat / 100).toFixed(2)) }
  ];
  const balanseRader = [
    ...b.bankrader.map(k => ({ Konto: k.navn, "Saldo (kr)": Number((k.saldo_ore / 100).toFixed(2)) })),
    { Konto: "Kundefordringer", "Saldo (kr)": Number((b.fordringer / 100).toFixed(2)) }
  ];
  await eksporterExcel(`arsoversikt-${aar}.xlsx`, { Resultatregnskap: resultatRader, Balanse: balanseRader });
}

async function laasAar(aar) {
  if (!erAdmin()) { toast("Ikke tilgang", "Bare administrator eller styreleder kan låse regnskapsår.", true); return; }
  const ok = await bekreft(
    "Lås regnskapsåret " + aar + "?",
    "Når året er låst kan ingen bilag i dette regnskapsåret lenger endres eller slettes. Feil rettes med et korrigeringsbilag i stedet.",
    "Lås året"
  );
  if (!ok) return;
  try {
    const { error } = await db.from("fiscal_years").upsert({
      organization_id: S.orgId, aar, laast: true, laast_av: S.bruker?.id || null, laast_tid: new Date().toISOString()
    }, { onConflict: "organization_id,aar" });
    if (error) throw error;
    toast("Regnskapsåret er låst", aar + " er nå låst for endringer.");
    paaNytt();
  } catch (e) { visFeil(e, "Låsing av regnskapsår"); }
}

function parseImportDato(v) {
  if (!v) return null;
  if (v instanceof Date) return isNaN(v) ? null : v.toISOString().slice(0, 10);
  const s = String(v).trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  const norsk = s.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})$/);
  if (norsk) return `${norsk[3]}-${norsk[2].padStart(2, "0")}-${norsk[1].padStart(2, "0")}`;
  const d = new Date(s);
  return isNaN(d) ? null : d.toISOString().slice(0, 10);
}

function byggForhandsvisning(rader, mapping, kategoriListe, prosjektListe) {
  const inntektMarkorer = ["inntekt", "inn", "income", "kredit", "+"];
  return rader.map(rad => {
    const datoObj = parseImportDato(rad[mapping.dato]);
    const beskrivelse = String(rad[mapping.beskrivelse] ?? "").trim();
    let belop_ore = tilOre(rad[mapping.belop]);
    let type;
    if (mapping.retningModus === "fortegn") {
      type = belop_ore < 0 ? "utgift" : "inntekt";
      belop_ore = Math.abs(belop_ore);
    } else {
      const markor = String(rad[mapping.retningKolonne] ?? "").trim().toLowerCase();
      type = inntektMarkorer.includes(markor) ? "inntekt" : "utgift";
      belop_ore = Math.abs(belop_ore);
    }

    let category_id = null, kategoriNavn = "";
    if (mapping.kategori) {
      const navn = String(rad[mapping.kategori] ?? "").trim();
      const treff = kategoriListe.find(k => k.retning === type && k.navn.toLowerCase() === navn.toLowerCase());
      if (treff) { category_id = treff.id; kategoriNavn = treff.navn; } else if (navn) kategoriNavn = navn + " (ikke funnet)";
    }

    let project_id = null, prosjektNavn = "";
    if (mapping.prosjekt) {
      const navn = String(rad[mapping.prosjekt] ?? "").trim();
      const treff = prosjektListe.find(p => p.navn.toLowerCase() === navn.toLowerCase());
      if (treff) { project_id = treff.id; prosjektNavn = treff.navn; } else if (navn) prosjektNavn = navn + " (ikke funnet)";
    }

    const gyldig = !!datoObj && !!beskrivelse && belop_ore > 0;
    return { gyldig, dato: datoObj, beskrivelse, belop_ore, type, category_id, project_id, kategoriNavn, prosjektNavn };
  });
}

async function importerRader(gyldigeRader, filnavn, antallLest, antallAvvist) {
  const porsjonstorrelse = 200;
  let antallImportert = 0;
  for (let i = 0; i < gyldigeRader.length; i += porsjonstorrelse) {
    const porsjon = gyldigeRader.slice(i, i + porsjonstorrelse).map(r => ({
      dato: r.dato, type: r.type, beskrivelse: r.beskrivelse, belop_ore: r.belop_ore,
      category_id: r.category_id, project_id: r.project_id,
      regnskapsaar: new Date(r.dato).getFullYear()
    }));
    const { error } = await settInn("transactions", porsjon);
    if (error) throw error;
    antallImportert += porsjon.length;
  }

  const { error: jobbFeil } = await settInn("import_jobs", {
    type: "transaksjoner", filnavn,
    antall_lest: antallLest, antall_importert: antallImportert, antall_avvist: antallAvvist,
    status: "fullfort", utfort_av: S.bruker?.id || null
  });
  if (jobbFeil) throw jobbFeil;

  toast("Import fullført", antallImportert + " transaksjoner ble importert.");
  paaNytt();
}

async function importVeiviser() {
  return new Promise(resolve => {
    let steg = 1;
    let rader = [];
    let kolonner = [];
    let filnavn = "";
    let mapping = { dato: "", beskrivelse: "", belop: "", retningModus: "fortegn", retningKolonne: "", kategori: "", prosjekt: "" };
    let forhandsvisning = [];
    let kategoriListe = [];
    let prosjektListe = [];

    const overlay = el("div", { class: "overlay" });
    const overskrift = el("p", {}, "Steg 1 av 3");
    const kropp = el("div", { class: "modal-body" });
    const fot = el("div", { class: "modal-foot" });
    const modal = el("div", { class: "modal" }, [
      el("div", { class: "modal-head" }, [el("h2", {}, "Importer historisk regnskap fra Excel"), overskrift]),
      kropp, fot
    ]);
    overlay.append(modal);

    const lukk = (v) => { overlay.remove(); resolve(v); };
    overlay.addEventListener("click", e => { if (e.target === overlay) lukk(false); });

    function tegn() {
      overskrift.textContent = "Steg " + steg + " av 3";
      kropp.replaceChildren();
      fot.replaceChildren();

      if (steg === 1) {
        const filInput = el("input", { type: "file", accept: ".xlsx,.xls,.csv" });
        kropp.append(felt("Velg fil med historiske transaksjoner", filInput, "Første rad må være kolonneoverskrifter."));
        fot.append(
          el("button", { class: "btn", onclick: () => lukk(false) }, "Avbryt"),
          el("button", {
            class: "btn primary", onclick: async () => {
              const fil = filInput.files[0];
              if (!fil) { toast("Velg en fil", "Du må velge en fil før du kan fortsette.", true); return; }
              try {
                filnavn = fil.name;
                rader = await lesExcel(fil);
                if (!rader.length) { toast("Tom fil", "Fant ingen rader i filen.", true); return; }
                kolonner = Object.keys(rader[0]);
                [kategoriListe, prosjektListe] = await Promise.all([hentAlleKategorier(), hentProsjekter()]);
                steg = 2; tegn();
              } catch (e) { visFeil(e, "Lesing av fil"); }
            }
          }, "Neste")
        );
      }

      else if (steg === 2) {
        const kolonneValg = [{ verdi: "", tekst: "— Velg kolonne —" }, ...kolonner.map(k => ({ verdi: k, tekst: k }))];
        const datoSel = velg("dato", kolonneValg, mapping.dato);
        const beskrSel = velg("beskrivelse", kolonneValg, mapping.beskrivelse);
        const belopSel = velg("belop", kolonneValg, mapping.belop);
        const retningModusSel = velg("retningModus", [
          { verdi: "fortegn", tekst: "Fortegn på beløp (minus = utgift)" },
          { verdi: "kolonne", tekst: "Egen kolonne for inn/ut" }
        ], mapping.retningModus);
        const retningKolonneSel = velg("retningKolonne", kolonneValg, mapping.retningKolonne);
        const kategoriSel = velg("kategori", kolonneValg, mapping.kategori);
        const prosjektSel = velg("prosjekt", kolonneValg, mapping.prosjekt);

        const retningKolonneFelt = felt("Kolonne for inn/ut", retningKolonneSel,
          "Ord som «inn», «inntekt» eller «+» tolkes som inntekt. Alt annet tolkes som utgift.");
        retningKolonneFelt.style.display = mapping.retningModus === "kolonne" ? "" : "none";
        retningModusSel.addEventListener("change", () => {
          retningKolonneFelt.style.display = retningModusSel.value === "kolonne" ? "" : "none";
        });

        kropp.append(el("div", { class: "grid g2" }, [
          felt("Dato-kolonne", datoSel),
          felt("Beskrivelse-kolonne", beskrSel),
          felt("Beløp-kolonne", belopSel),
          felt("Hvordan avgjøres inn/ut?", retningModusSel),
          retningKolonneFelt,
          felt("Kategori-kolonne (valgfritt)", kategoriSel, "Kobles mot eksisterende kategorinavn."),
          felt("Prosjekt-kolonne (valgfritt)", prosjektSel, "Kobles mot eksisterende prosjektnavn.")
        ]));

        fot.append(
          el("button", { class: "btn", onclick: () => { steg = 1; tegn(); } }, "Tilbake"),
          el("button", {
            class: "btn primary", onclick: () => {
              mapping = {
                dato: datoSel.value, beskrivelse: beskrSel.value, belop: belopSel.value,
                retningModus: retningModusSel.value, retningKolonne: retningKolonneSel.value,
                kategori: kategoriSel.value, prosjekt: prosjektSel.value
              };
              if (!mapping.dato || !mapping.beskrivelse || !mapping.belop) {
                toast("Mangler kobling", "Du må koble dato, beskrivelse og beløp.", true); return;
              }
              if (mapping.retningModus === "kolonne" && !mapping.retningKolonne) {
                toast("Mangler kobling", "Velg kolonnen som viser inn/ut.", true); return;
              }
              forhandsvisning = byggForhandsvisning(rader, mapping, kategoriListe, prosjektListe);
              steg = 3; tegn();
            }
          }, "Neste — forhåndsvis")
        );
      }

      else if (steg === 3) {
        const gyldige = forhandsvisning.filter(r => r.gyldig);
        const ugyldige = forhandsvisning.filter(r => !r.gyldig);

        kropp.append(
          el("div", { class: "note " + (ugyldige.length ? "warn" : "ok") },
            gyldige.length + " av " + forhandsvisning.length + " rader er gyldige og vil bli importert." +
            (ugyldige.length ? " " + ugyldige.length + " rader mangler dato, beskrivelse eller gyldig beløp og hoppes over." : "")
          ),
          tabell(
            [{ t: "Dato" }, { t: "Beskrivelse" }, { t: "Type" }, { t: "Beløp", num: true }, { t: "Kategori" }, { t: "Prosjekt" }, { t: "Status" }],
            forhandsvisning.slice(0, 25).map(r => el("tr", {}, [
              el("td", {}, r.dato ? datoKort(r.dato) : "—"),
              el("td", {}, r.beskrivelse || "—"),
              el("td", {}, r.type === "utgift" ? "Utgift" : "Inntekt"),
              el("td", { class: "num" }, kr(r.belop_ore || 0)),
              el("td", {}, r.kategoriNavn || "—"),
              el("td", {}, r.prosjektNavn || "—"),
              el("td", {}, r.gyldig ? pille("Gyldig", "green") : pille("Feil", "red"))
            ]))
          ),
          forhandsvisning.length > 25 ? el("p", { class: "hint" }, "Viser de første 25 av " + forhandsvisning.length + " rader.") : null
        );

        const importKnapp = el("button", {
          class: "btn primary", disabled: !gyldige.length, onclick: async () => {
            importKnapp.disabled = true; importKnapp.textContent = "Importerer …";
            try {
              await importerRader(gyldige, filnavn, forhandsvisning.length, ugyldige.length);
              lukk(true);
            } catch (e) {
              visFeil(e, "Import");
              importKnapp.disabled = false; importKnapp.textContent = "Importer " + gyldige.length + " rader";
            }
          }
        }, "Importer " + gyldige.length + " rader");

        fot.append(el("button", { class: "btn", onclick: () => { steg = 2; tegn(); } }, "Tilbake"), importKnapp);
      }
    }

    document.body.append(overlay);
    tegn();
  });
}

export const rapporterView = {
  tittel: "Rapporter",
  undertekst: "Standardrapporter, resultatregnskap og import av historikk.",
  async bygg() {
    let aar = aarNaa();
    const resultatHolder = el("div");

    async function lastResultat() {
      resultatHolder.replaceChildren(laster("Henter resultatregnskap …"));
      try {
        const r = await hentResultatregnskap(aar);
        resultatHolder.replaceChildren(
          el("div", { class: "grid g2" }, [
            tabell([{ t: "Inntekter" }, { t: "Beløp", num: true }],
              [...r.inntekter.entries()].map(([k, v]) => el("tr", {}, [el("td", {}, k), el("td", { class: "num" }, kr(v))])),
              "Ingen inntekter registrert."),
            tabell([{ t: "Utgifter" }, { t: "Beløp", num: true }],
              [...r.utgifter.entries()].map(([k, v]) => el("tr", {}, [el("td", {}, k), el("td", { class: "num" }, kr(v))])),
              "Ingen utgifter registrert.")
          ]),
          el("div", { class: "grid g3" }, [
            kpi({ nokkel: "Sum inntekter", verdi: kr(r.sumInn) + " kr" }),
            kpi({ nokkel: "Sum utgifter", verdi: kr(r.sumUt) + " kr" }),
            kpi({ ikon: "rapport", nokkel: "Resultat", verdi: kr(r.resultat) + " kr", farge: r.resultat >= 0 ? "pos" : "neg" })
          ])
        );
      } catch (e) {
        visFeil(e, "Henting av resultatregnskap");
        resultatHolder.replaceChildren(el("div", { class: "empty" }, "Klarte ikke å hente tall."));
      }
    }

    const aarValg = [];
    for (let a = aarNaa() + 1; a >= aarNaa() - 6; a--) aarValg.push({ verdi: String(a), tekst: String(a) });
    const aarSelect = velg("aar", aarValg, String(aar));
    aarSelect.addEventListener("change", () => { aar = Number(aarSelect.value); lastResultat(); });

    await lastResultat();

    function knappRad(tekst, fn) {
      return el("button", {
        class: "btn", onclick: async () => {
          try { await fn(); toast("Rapport klar", tekst + " er lastet ned."); }
          catch (e) { visFeil(e, tekst); }
        }
      }, tekst);
    }

    const rapportKnapper = el("div", { class: "grid g3" }, [
      knappRad("Resultatregnskap", () => eksporterResultatregnskap(aar)),
      knappRad("Balanse", () => eksporterBalanse()),
      knappRad("Hovedbok", () => eksporterHovedbok(aar)),
      knappRad("Bilagsjournal", () => eksporterBilagsjournal(aar)),
      knappRad("Prosjektregnskap", () => eksporterAlleProsjekter()),
      knappRad("Inntekter og utgifter per aktivitet", () => eksporterPerAktivitet(aar)),
      knappRad("Årsoversikt (tallgrunnlag)", () => eksporterAarsoversikt(aar))
    ]);

    // Selve årsrapporten er et dokument, ikke et regneark. Excel-filene
    // under er råtallene til videre bearbeiding.
    function dokumentKnapp(tekst, klasse, fn) {
      return el("button", {
        class: "btn " + klasse, onclick: async () => {
          try { await fn(); } catch (e) { visFeil(e, tekst); }
        }
      }, tekst);
    }

    const arsrapportKort = kort({
      tittel: "Årsrapport",
      beskrivelse: "Ferdig oppsatt dokument til årsmøtet, revisor og kontrollutvalget: "
        + "forside med nøkkeltall, resultatregnskap med fjorårstall, beholdning avstemt "
        + "mot bank, noter og full bilagsjournal. Åpne dokumentet og velg «Skriv ut eller "
        + "lagre som PDF».",
      innhold: el("div", { class: "actions" }, [
        dokumentKnapp("Åpne årsrapporten for " + aar, "primary", () => apneArsrapport(aar)),
        dokumentKnapp("Revisjonsgrunnlag " + aar, "", () => apneRevisjonsgrunnlag(aar))
      ])
    });

    const importKort = kanOkonomi() ? kort({
      tittel: "Importer historisk regnskap",
      beskrivelse: "Hent inn transaksjoner fra et tidligere regnskapssystem via Excel.",
      innhold: el("button", {
        class: "btn primary", onclick: async () => {
          const importert = await importVeiviser();
          if (importert && erAdmin()) await laasAar(aar);
        }
      }, "Importer historisk regnskap fra Excel")
    }) : null;

    const laasKort = erAdmin() ? kort({
      tittel: "Lås regnskapsår",
      beskrivelse: "Låser bilag i valgt år mot endring. Bruk når året er ferdig kontrollert.",
      innhold: el("button", { class: "btn danger", onclick: () => laasAar(aar) }, "Lås " + aar)
    }) : null;

    return el("div", { class: "stack" }, [
      kort({ tittel: "Velg regnskapsår", innhold: felt("Regnskapsår", aarSelect) }),
      kort({ tittel: "Resultatregnskap", beskrivelse: "Inntekter og utgifter per kategori for valgt år.", innhold: resultatHolder }),
      arsrapportKort,
      kort({
        tittel: "Tallgrunnlag i Excel",
        beskrivelse: "Råtall til videre bearbeiding hos regnskapsfører eller i eget regneark. "
          + "Selve årsrapporten lager du som PDF i kortet over.",
        innhold: rapportKnapper
      }),
      importKort,
      laasKort,
      !kanOkonomi() ? el("div", { class: "note info" }, "Rollen din gir bare lesetilgang til rapporter og eksport.") : null
    ]);
  }
};

/* =====================================================================
   kontingentView
   ===================================================================== */

function statusPille(s) {
  const kart = {
    ikke_betalt: ["Ikke betalt", "gold"], delvis_betalt: ["Delvis betalt", "blue"],
    betalt: ["Betalt", "green"], forfalt: ["Forfalt", "red"],
    fritatt: ["Fritatt", "neutral"], kansellert: ["Kansellert", "neutral"]
  };
  const [tekst, farge] = kart[s] || [s, "neutral"];
  return pille(tekst, farge);
}

async function hentAlleKrav() {
  const { data, error } = await velgFra("payment_claims", "*, members(fornavn,etternavn), fees(navn,type)").order("forfall");
  if (error) throw error;
  return data || [];
}

async function registrerBetalingModal(k) {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang.", true); return; }
  const resultat = await skjemaModal({
    tittel: "Registrer betaling",
    beskrivelse: (k.members ? k.members.fornavn + " " + k.members.etternavn : "Ukjent medlem") + " — " + k.beskrivelse,
    felter: [
      { navn: "belop", label: "Beløp innbetalt nå", type: "text", plassholder: "0,00",
        hint: "Betalt så langt: " + kr(k.betalt_ore) + " kr av " + kr(k.belop_ore) + " kr." }
    ],
    onLagre: async (data) => {
      const innbetalt_ore = tilOre(data.belop);
      if (!(innbetalt_ore > 0)) { toast("Kan ikke lagre", "Beløpet må være større enn null.", true); return false; }
      const nyttBetalt = k.betalt_ore + innbetalt_ore;
      const nyStatus = nyttBetalt >= k.belop_ore ? "betalt" : "delvis_betalt";
      const { error } = await db.from("payment_claims").update({ betalt_ore: nyttBetalt, status: nyStatus }).eq("id", k.id);
      if (error) throw error;
      return true;
    }
  });
  if (resultat !== null) { toast("Betaling registrert", "Kravet er oppdatert."); paaNytt(); }
}

function kravRad(k) {
  return el("tr", { class: kanOkonomi() ? "klikk" : null, onclick: kanOkonomi() ? () => registrerBetalingModal(k) : null }, [
    el("td", {}, k.members ? k.members.fornavn + " " + k.members.etternavn : "—"),
    el("td", {}, k.beskrivelse),
    el("td", { class: "num" }, kr(k.belop_ore)),
    el("td", { class: "num" }, kr(k.betalt_ore)),
    el("td", {}, datoKort(k.forfall)),
    el("td", {}, statusPille(k.status))
  ]);
}

async function hentMedlemmerForSats(sats, aktivitetIdOverride) {
  const aktivitetId = aktivitetIdOverride || sats.activity_id || null;
  let q = velgFra("members", "id").eq("status", "aktiv");
  if (aktivitetId) {
    const { data: koblinger, error } = await db.from("member_activities").select("member_id").eq("activity_id", aktivitetId);
    if (error) throw error;
    const ider = (koblinger || []).map(kb => kb.member_id);
    if (!ider.length) return [];
    q = q.in("id", ider);
  }
  const { data: medlemmer, error: e2 } = await q;
  if (e2) throw e2;

  const { data: eksisterende, error: e3 } = await velgFra("payment_claims", "member_id").eq("fee_id", sats.id);
  if (e3) throw e3;
  const harAllerede = new Set((eksisterende || []).map(kk => kk.member_id));

  return (medlemmer || []).filter(m => !harAllerede.has(m.id));
}

async function opprettKravModal() {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang.", true); return false; }

  const [{ data: satser, error: e1 }, { data: aktiviteter, error: e2 }] = await Promise.all([
    velgFra("fees", "*").eq("aktiv", true).order("navn"),
    velgFra("activities", "id,navn").eq("aktiv", true).order("navn")
  ]);
  if (e1) { visFeil(e1, "Henting av satser"); return false; }
  if (e2) { visFeil(e2, "Henting av aktiviteter"); return false; }
  if (!satser?.length) { toast("Ingen satser", "Du må opprette en sats under «Nye satser» først.", true); return false; }

  return new Promise(resolve => {
    const satsSel = velg("sats", satser.map(s => ({ verdi: s.id, tekst: s.navn + " — " + kr0(s.belop_ore) + " kr" })), satser[0].id);
    const aktivitetSel = velg("aktivitet",
      [{ verdi: "", tekst: "— Alle medlemmer —" }, ...(aktiviteter || []).map(a => ({ verdi: a.id, tekst: a.navn }))], "");
    const forhandsvisning = el("p", { class: "hint" }, "Velg sats og aktivitet for å se hvor mange krav som opprettes.");
    let medlemmer = [];

    async function oppdaterForhandsvisning() {
      forhandsvisning.textContent = "Beregner …";
      try {
        const sats = satser.find(s => s.id === satsSel.value);
        medlemmer = await hentMedlemmerForSats(sats, aktivitetSel.value);
        forhandsvisning.textContent = medlemmer.length + " medlemmer vil få et krav på " + kr0(sats.belop_ore) +
          " kr (medlemmer som allerede har et krav på denne satsen telles ikke med).";
      } catch (e) { visFeil(e, "Beregning"); forhandsvisning.textContent = "Klarte ikke å beregne."; }
    }
    satsSel.addEventListener("change", oppdaterForhandsvisning);
    aktivitetSel.addEventListener("change", oppdaterForhandsvisning);

    const overlay = el("div", { class: "overlay" });
    const lukk = v => { overlay.remove(); resolve(v); };

    const opprettKnapp = el("button", {
      class: "btn primary", onclick: async () => {
        if (!medlemmer.length) { toast("Ingen medlemmer", "Det er ingen medlemmer å opprette krav for.", true); return; }
        opprettKnapp.disabled = true; opprettKnapp.textContent = "Oppretter …";
        try {
          const sats = satser.find(s => s.id === satsSel.value);
          const forfall = new Date(); forfall.setDate(forfall.getDate() + 30);
          const forfallDato = forfall.toISOString().slice(0, 10);
          const rader = medlemmer.map(m => ({
            member_id: m.id, fee_id: sats.id, beskrivelse: sats.navn,
            belop_ore: sats.belop_ore, forfall: forfallDato
          }));
          const { error } = await settInn("payment_claims", rader);
          if (error) throw error;
          toast("Krav opprettet", rader.length + " betalingskrav er opprettet.");
          lukk(true);
        } catch (e) {
          visFeil(e, "Opprettelse av krav");
          opprettKnapp.disabled = false; opprettKnapp.textContent = "Opprett krav";
        }
      }
    }, "Opprett krav");

    overlay.append(el("div", { class: "modal" }, [
      el("div", { class: "modal-head" }, [el("h2", {}, "Opprett krav"), el("p", {}, "Velg en sats og hvilke medlemmer som skal få krav.")]),
      el("div", { class: "modal-body" }, [
        el("div", { class: "grid g2" }, [felt("Sats", satsSel), felt("Aktivitet", aktivitetSel)]),
        forhandsvisning
      ]),
      el("div", { class: "modal-foot" }, [el("button", { class: "btn", onclick: () => lukk(false) }, "Avbryt"), opprettKnapp])
    ]));
    overlay.addEventListener("click", e => { if (e.target === overlay) lukk(false); });
    document.body.append(overlay);
    oppdaterForhandsvisning();
  });
}

async function nySatsModal() {
  if (!kanOkonomi()) { toast("Ikke tilgang", "Rollen din gir bare lesetilgang.", true); return false; }
  const { data: aktiviteter, error } = await velgFra("activities", "id,navn").eq("aktiv", true).order("navn");
  if (error) { visFeil(error, "Henting av aktiviteter"); return false; }

  const resultat = await skjemaModal({
    tittel: "Ny sats",
    beskrivelse: "Satser brukes til å opprette betalingskrav for medlemmer.",
    felter: [
      { navn: "navn", label: "Navn", type: "text", bredde: "full" },
      {
        navn: "type", label: "Type", type: "select", valg: [
          { verdi: "medlemskontingent", tekst: "Medlemskontingent" },
          { verdi: "treningsavgift", tekst: "Treningsavgift" },
          { verdi: "aktivitetsavgift", tekst: "Aktivitetsavgift" },
          { verdi: "annet", tekst: "Annet" }
        ]
      },
      {
        navn: "intervall", label: "Intervall", type: "select", valg: [
          { verdi: "engangs", tekst: "Engangs" },
          { verdi: "maanedlig", tekst: "Månedlig" },
          { verdi: "halvaarlig", tekst: "Halvårlig" },
          { verdi: "aarlig", tekst: "Årlig" }
        ]
      },
      { navn: "belop", label: "Beløp", type: "text", plassholder: "0,00" },
      {
        navn: "activity_id", label: "Aktivitet (valgfritt)", type: "select",
        valg: [{ verdi: "", tekst: "— Ingen —" }, ...(aktiviteter || []).map(a => ({ verdi: a.id, tekst: a.navn }))]
      }
    ],
    onLagre: async (data) => {
      if (!data.navn) { toast("Kan ikke lagre", "Satsen må ha et navn.", true); return false; }
      const belop_ore = tilOre(data.belop);
      if (!(belop_ore >= 0)) { toast("Kan ikke lagre", "Beløpet kan ikke være negativt.", true); return false; }
      const { error: feil } = await settInn("fees", {
        navn: data.navn, type: data.type, intervall: data.intervall,
        belop_ore, activity_id: data.activity_id || null
      });
      if (feil) throw feil;
      return true;
    }
  });
  return resultat !== null;
}

async function lastKontingent(rot) {
  rot.replaceChildren(laster("Henter betalingskrav …"));
  try {
    const krav = await hentAlleKrav();
    const kontingent = krav.filter(k => k.fees?.type === "medlemskontingent");
    const trening = krav.filter(k => k.fees?.type === "treningsavgift");
    const andre = krav.filter(k => !kontingent.includes(k) && !trening.includes(k));

    const knappRad = kanOkonomi() ? el("div", { class: "actions" }, [
      el("button", {
        class: "btn primary", onclick: async () => { const ok = await opprettKravModal(); if (ok) paaNytt(); }
      }, "Opprett krav"),
      el("button", {
        class: "btn", onclick: async () => {
          const ok = await nySatsModal();
          if (ok) { toast("Sats opprettet", "Satsen kan nå brukes til å opprette krav."); paaNytt(); }
        }
      }, "Nye satser")
    ]) : el("div", { class: "note info" }, "Rollen din gir bare lesetilgang til kontingent.");

    const kravTabell = (liste, tomtekst) => tabell(
      [{ t: "Medlem" }, { t: "Beskrivelse" }, { t: "Beløp", num: true }, { t: "Betalt", num: true }, { t: "Forfall" }, { t: "Status" }],
      liste.map(kravRad), tomtekst
    );

    rot.replaceChildren(
      knappRad,
      kort({ tittel: "Medlemskontingent", innhold: kravTabell(kontingent, "Ingen krav om medlemskontingent ennå.") }),
      kort({ tittel: "Treningsavgift", innhold: kravTabell(trening, "Ingen krav om treningsavgift ennå.") }),
      andre.length ? kort({ tittel: "Andre avgifter", innhold: kravTabell(andre, "Ingen andre avgifter ennå.") }) : null
    );
  } catch (e) {
    visFeil(e, "Henting av betalingskrav");
    rot.replaceChildren(el("div", { class: "empty" }, "Klarte ikke å hente betalingskrav."));
  }
}

export const kontingentView = {
  tittel: "Kontingent",
  undertekst: "Betalingskrav, satser og innbetalinger — kontingent og treningsavgift holdt atskilt.",
  async bygg() {
    const rot = el("div", { class: "stack" });
    await lastKontingent(rot);
    return rot;
  }
};
