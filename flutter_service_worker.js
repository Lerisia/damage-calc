self.addEventListener('install', (event) => { self.skipWaiting(); });
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try { const k = await caches.keys(); await Promise.all(k.map((x)=>caches.delete(x))); } catch (_) {}
    try { await self.registration.unregister(); } catch (_) {}
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const c of clients) { try { c.navigate(c.url); } catch (_) {} }
  })());
});
