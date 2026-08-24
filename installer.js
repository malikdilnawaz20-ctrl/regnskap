/* =====================================================================
   Saksflyt som app på telefonen

   Dette er ikke en app fra App Store eller Google Play. Det er selve
   nettsiden som legges på hjem-skjermen og åpnes uten adressefelt, med
   eget ikon. På Android og i Chrome kan nettleseren spørre direkte; på
   iPhone må brukeren gjøre det selv, og da forteller vi hvordan.

   Filen kan brukes både fra portalen og fra appen. Den legger seg på
   window.Saksflyt og gjør ingenting av seg selv før noen ber om det.
   ===================================================================== */

(function () {
  "use strict";

  let ventendeSporsmaal = null;

  const erStandalone = () =>
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone === true;

  const erIOS = () =>
    /iphone|ipad|ipod/i.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

  const erSafari = () =>
    /^((?!chrome|android|crios|fxios).)*safari/i.test(navigator.userAgent);

  window.addEventListener("beforeinstallprompt", e => {
    e.preventDefault();
    ventendeSporsmaal = e;
    window.dispatchEvent(new CustomEvent("saksflyt:kan-installeres"));
  });

  window.addEventListener("appinstalled", () => {
    ventendeSporsmaal = null;
    window.dispatchEvent(new CustomEvent("saksflyt:installert"));
  });

  /** Registrer tjenestearbeideren. Uten den er appen ikke installerbar. */
  function settOppArbeider() {
    if (!("serviceWorker" in navigator)) return;
    if (location.protocol !== "https:" && location.hostname !== "localhost") return;
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/sw.js").catch(() => { });
    });
  }

  /**
   * Hva kan vi tilby denne brukeren?
   *   "installert"    — appen ligger allerede på hjem-skjermen
   *   "kan-spørre"    — nettleseren lar oss spørre direkte
   *   "ios-manuelt"   — iPhone/iPad: brukeren må gjøre det selv
   *   "ikke-mulig"    — nettleseren støtter det ikke
   */
  function tilstand() {
    if (erStandalone()) return "installert";
    if (ventendeSporsmaal) return "kan-spørre";
    if (erIOS() && erSafari()) return "ios-manuelt";
    return "ikke-mulig";
  }

  /** Ber nettleseren om å installere. Returnerer true hvis brukeren sa ja. */
  async function installer() {
    if (!ventendeSporsmaal) return false;
    ventendeSporsmaal.prompt();
    const { outcome } = await ventendeSporsmaal.userChoice;
    ventendeSporsmaal = null;
    return outcome === "accepted";
  }

  const IOS_STEG = [
    "Trykk på Del-knappen nederst i Safari",
    "Bla ned og velg «Legg til på Hjem-skjerm»",
    "Trykk «Legg til» øverst til høyre"
  ];

  window.Saksflyt = { settOppArbeider, tilstand, installer, erStandalone, erIOS, IOS_STEG };
})();
