/* =====================================================================
   Saksflyt — tjenestearbeider
   Bevisst forsiktig: appen henter alltid fra nettet først, slik at en
   ny versjon aldri blir liggende igjen i en gammel hurtigbuffer.
   Bufferen finnes bare for at appen skal åpne seg når telefonen er
   uten dekning — da får du siste versjon du faktisk har besøkt.
   ===================================================================== */

const BUFFER = "saksflyt-v1";
const SKALL = ["/", "/app/", "/app/index.html", "/manifest.webmanifest"];

self.addEventListener("install", e => {
  self.skipWaiting();
  e.waitUntil(caches.open(BUFFER).then(c => c.addAll(SKALL).catch(() => {})));
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(navn => Promise.all(navn.filter(n => n !== BUFFER).map(n => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;
  // Aldri buffer kall mot Supabase eller andre tjenester
  e.respondWith(
    fetch(e.request)
      .then(svar => {
        if (svar && svar.status === 200) {
          const kopi = svar.clone();
          caches.open(BUFFER).then(c => c.put(e.request, kopi)).catch(() => {});
        }
        return svar;
      })
      .catch(() => caches.match(e.request).then(t => t || caches.match("/app/")))
  );
});
