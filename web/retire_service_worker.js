// Migration for browsers that still run Flutter's old offline-first worker.
// Activate immediately and stop intercepting requests, without reloading tabs
// or deleting origin-wide caches shared with other GitHub Pages projects.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.clients.claim();
    await self.registration.unregister();
  })());
});
