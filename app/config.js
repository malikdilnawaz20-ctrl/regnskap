// =====================================================================
//  Oppsett — fyll inn dine egne Supabase-verdier her.
//  Begge verdiene er offentlige og trygge å legge i GitHub:
//  anon-nøkkelen gir ingen tilgang uten innlogging, fordi all
//  tilgangskontroll ligger i rad-nivå-sikkerheten i databasen.
// =====================================================================

export const SUPABASE_URL = "https://bunqdzvtocayqlddcjmf.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_RA9TlDf3i-pO8_TcgfXQKw_rYwwt5jp";

// Merkevare. Produktnavnet er bevisst ikke låst i koden.
export const MERKE = {
  navn: "Saksflyt",
  moduler: {
    regnskap: { navn: "Saksflyt Regnskap", beskrivelse: "Økonomi, bilag, prosjekter og rapporter" },
    medlem: { navn: "Saksflyt Medlem", beskrivelse: "Medlemsregister, aktiviteter og kontingent" },
    saksbehandling: { navn: "Saksflyt Saksbehandling", beskrivelse: "Saker, frister og timeføring" }
  }
};

export const ER_KONFIGURERT =
  SUPABASE_URL.startsWith("http") && SUPABASE_ANON_KEY.length > 20;
