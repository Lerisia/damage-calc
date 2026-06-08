// One-shot kill service worker.
//
// Older Flutter builds shipped an offline-first PWA service worker
// that cached every asset; deploying a fix didn't reach users until
// their SW noticed the update (usually 2 page-loads of delay), and
// in the meantime they were stuck on the buggy cached version.
//
// All future builds use `flutter build web --pwa-strategy=none`, so
// no SW is generated. This file replaces the cached SW one final
// time with a body that:
//   1. Takes control of open pages immediately (claim()).
//   2. Deletes every Cache API entry the old SW had populated.
//   3. Unregisters itself.
//   4. Triggers a reload so the page re-fetches fresh assets from
//      the network on the next paint.
//
// Once a user has hit this once, they have no SW and no stale
// caches; future deploys land instantly.

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const cacheKeys = await caches.keys();
      await Promise.all(cacheKeys.map((k) => caches.delete(k)));
    } catch (_) {}
    try {
      await self.registration.unregister();
    } catch (_) {}
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      try {
        client.navigate(client.url);
      } catch (_) {}
    }
  })());
});
