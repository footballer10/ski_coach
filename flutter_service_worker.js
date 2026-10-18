// The web demo no longer caches itself for offline use. This replaces the
// old cache worker in browsers that installed it: it deletes the old cache,
// removes itself, and reloads open tabs so they get the current version.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    for (const client of await self.clients.matchAll({ type: 'window' })) client.navigate(client.url);
  })());
});
