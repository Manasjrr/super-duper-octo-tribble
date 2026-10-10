// Service worker de l'appli web expéditrice : affiche les notifications envoyées par Nova.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data ? event.data.text() : '' }; }
  const body = d.subtitle ? d.subtitle + '\n' + (d.body || '') : (d.body || '');
  event.waitUntil(self.registration.showNotification(d.title || ' ', { body: body, tag: d.id, data: d }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
});
