/* StayDesk · service worker (versión 25.8)
   Qué hace: guarda la propia página de StayDesk en el dispositivo para que abra rápido y también SIN Internet.
   Qué NO hace: no guarda datos del hotel (esos viven en el dispositivo, dentro de la app) ni toca nada que no sea de este mismo sitio.
   Cómo se actualiza: al abrir la app con Internet, revisa en segundo plano si hay una página nueva; si la hay, la guarda y avisa
   para que la próxima vez que se abra ya sea la nueva. Una página que no sea de StayDesk (por ejemplo la de acceso al Wi-Fi del hotel)
   nunca reemplaza a la guardada. */
'use strict';
const VER = '25.8';
const CACHE = 'staydesk-shell-' + VER;
const PAGE = 'index.html';
const MARK = '__sdVer';                       /* texto que solo tiene la página de StayDesk */

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    const r = await fetch(new Request(PAGE, { cache: 'reload' }));
    const t = r.ok ? await r.clone().text() : '';
    if (!t.includes(MARK)) throw new Error('la página no es la de StayDesk');
    await c.put(PAGE, r);
    await self.skipWaiting();
  })());
});

async function tell(msg) {
  for (const c of await self.clients.matchAll({ includeUncontrolled: true })) c.postMessage(msg);
}

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    let hubo = false;                                  /* ¿había una versión anterior guardada? */
    for (const k of await caches.keys()) if (k.startsWith('staydesk-shell-') && k !== CACHE) { await caches.delete(k); hubo = true; }
    await self.clients.claim();
    if (hubo) await tell({ t: 'sd-updated' });          /* la próxima vez que abran la app ya será la nueva */
  })());
});

/* trae la página de la red y, si es de StayDesk y cambió, la guarda y avisa */
async function refresh(cache, old) {
  try {
    const res = await fetch(PAGE, { cache: 'no-cache' });
    if (!res.ok) return;
    const txt = await res.clone().text();
    if (!txt.includes(MARK)) return;
    const prev = old ? await old.clone().text() : '';
    if (txt !== prev) { await cache.put(PAGE, res); if (prev) await tell({ t: 'sd-updated' }); }
  } catch (_) { /* sin red: se queda lo guardado */ }
}

self.addEventListener('fetch', e => {
  const r = e.request;
  if (r.method !== 'GET') return;
  const u = new URL(r.url);
  if (u.origin !== self.location.origin) return;
  const dir = new URL('./', self.location).pathname;
  const isPage = r.mode === 'navigate' || u.pathname === dir || u.pathname === dir + PAGE;
  if (!isPage) return;                         /* lo demás va directo a la red, como siempre */
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(PAGE);
    if (hit) { e.waitUntil(refresh(cache, hit.clone())); return hit; }      /* copia hecha ANTES de entregar la página: después su contenido ya se gastó */
    try {
      const res = await fetch(r);
      return res;
    } catch (_) {
      return new Response('StayDesk: sin conexión y todavía no hay una copia guardada. Abre la app una vez con Internet.', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    }
  })());
});
