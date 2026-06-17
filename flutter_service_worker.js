self.addEventListener('install', (event) => { self.skipWaiting(); });
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try { const k = await caches.keys(); await Promise.all(k.map((x)=>caches.delete(x))); } catch (_) {}
    try { await self.registration.unregister(); } catch (_) {}
    const cl = await self.clients.matchAll({ type: 'window' });
    for (const c of cl) { try { c.navigate(c.url); } catch (_) {} }
  })());
});
