// One-shot kill service worker — see reference_deploy_procedure.
// Installs, claims open clients, deletes every Cache API entry, then
// unregisters itself. Future deploys ship with --pwa-strategy=none
// so no SW is generated; this file is the migration path for users
// who still have the old offline-first SW registered.

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
