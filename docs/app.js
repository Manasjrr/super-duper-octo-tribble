// Appli web « expéditrice » de Nova.
// 1) Dans Safari : explique comment l'ajouter à l'écran d'accueil.
// 2) Une fois ouverte depuis l'écran d'accueil : active les notifications push et renvoie
//    l'abonnement à Nova, qui pourra ensuite envoyer des notifications depuis cette appli.
(function () {
  'use strict';

  const root = document.documentElement;
  const slot = root.dataset.slot;
  const custom = root.dataset.custom === '1';
  const app = document.getElementById('app');
  const query = new URLSearchParams(location.search);
  const hash = new URLSearchParams(location.hash.slice(1));
  const standalone = window.navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;

  const store = {
    get(k) { try { return localStorage.getItem(slot + ':' + k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(slot + ':' + k, v); } catch (e) { /* stockage indisponible */ } },
  };

  function b64urlToBytes(s) {
    s = s.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4) s += '=';
    const bin = atob(s);
    return Uint8Array.from(bin, (c) => c.charCodeAt(0));
  }

  function b64urlEncode(str) {
    const bytes = new TextEncoder().encode(str);
    let bin = '';
    bytes.forEach((b) => { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function setMeta(name, content) {
    const el = document.querySelector('meta[name="' + name + '"]');
    if (el) el.setAttribute('content', content);
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  // --- Personnalisation (emplacements « Perso ») transmise par Nova dans l'adresse ---
  if (custom) {
    const name = hash.get('name') || store.get('name');
    const icon = hash.get('icon') || store.get('icon');
    if (name) {
      document.title = name;
      setMeta('apple-mobile-web-app-title', name);
      store.set('name', name);
    }
    if (icon) {
      const href = 'data:image/jpeg;base64,' + icon.replace(/-/g, '+').replace(/_/g, '/');
      document.querySelector('link[rel="apple-touch-icon"]').setAttribute('href', href);
      store.set('icon', icon);
    }
  }

  // --- Clé publique de Nova (VAPID) ---
  let key = query.get('k') || hash.get('k') || store.get('key');
  if (key) store.set('key', key);

  function iconSrc() {
    const link = document.querySelector('link[rel="apple-touch-icon"]');
    return link ? link.getAttribute('href') : 'icon-180.png';
  }

  function header() {
    return '<header><img class="icon" src="' + esc(iconSrc()) + '" alt=""><h1>' + esc(document.title) + '</h1>' +
      '<p class="sub">Expéditeur de notifications pour Nova</p></header>';
  }

  // --- Dans Safari : installation ---
  function renderInstall() {
    app.innerHTML = header() +
      '<section class="card"><h2>Ajoute cette appli à ton écran d\'accueil</h2><ol>' +
      '<li>Touche le bouton <b>Partager</b> <span class="glyph">⬆︎</span> en bas de Safari.</li>' +
      '<li>Choisis <b>Sur l\'écran d\'accueil</b>. Tu peux renommer l\'appli.</li>' +
      '<li>Ouvre la nouvelle icône depuis l\'écran d\'accueil pour activer les notifications.</li>' +
      '</ol></section>' +
      (key ? '' : '<p class="warn">Ouvre cette page depuis Nova (Configurations › Applis expéditrices) pour qu\'elle reçoive la clé de Nova.</p>');
  }

  // --- Dans l'appli installée : activation ---
  function renderActivate(message) {
    const sub = store.get('sub');
    const granted = 'Notification' in window && Notification.permission === 'granted';
    let html = header();
    if (sub && granted) {
      html += '<section class="card ok"><h2>Connectée à Nova ✓</h2>' +
        '<p>Nova peut envoyer des notifications depuis cette appli. Tu peux la fermer.</p>' +
        '<button id="resend" class="secondary">Renvoyer la connexion à Nova</button>' +
        '<button id="test" class="secondary">Notification de test</button></section>';
    } else {
      html += '<section class="card"><h2>Activer les notifications</h2>';
      if (!key) {
        html += '<p>Dans Nova, touche « Installer » sur cet expéditeur : la clé est copiée. Puis colle-la ici.</p>' +
          '<button id="paste" class="secondary">Coller la clé de Nova</button>';
      }
      html += '<button id="activate"' + (key ? '' : ' disabled') + '>Activer les notifications</button></section>';
    }
    if (message) html += '<p class="warn">' + esc(message) + '</p>';
    app.innerHTML = html;

    const on = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', fn); };
    on('paste', pasteKey);
    on('activate', activate);
    on('resend', () => sendToNova(store.get('sub')));
    on('test', testNotification);
  }

  async function pasteKey() {
    try {
      const text = (await navigator.clipboard.readText()).trim();
      const m = text.match(/^NOVA-KEY:([A-Za-z0-9_-]+)$/);
      if (!m) { renderActivate('Le presse-papiers ne contient pas de clé Nova.'); return; }
      key = m[1];
      store.set('key', key);
      renderActivate();
    } catch (e) {
      renderActivate('Impossible de lire le presse-papiers : ' + e.message);
    }
  }

  async function activate() {
    try {
      // La demande d'autorisation doit être la première action après le toucher.
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') { renderActivate('Notifications refusées. Autorise-les dans Réglages › Notifications.'); return; }
      const reg = await navigator.serviceWorker.register('sw.js');
      await navigator.serviceWorker.ready;
      const old = await reg.pushManager.getSubscription();
      if (old) await old.unsubscribe();
      const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64urlToBytes(key) });
      const j = sub.toJSON();
      const payload = b64urlEncode(JSON.stringify({
        slot: slot, name: document.title, endpoint: j.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth,
      }));
      store.set('sub', payload);
      renderActivate();
      sendToNova(payload);
    } catch (e) {
      renderActivate('Échec de l\'activation : ' + e.message);
    }
  }

  function sendToNova(payload) {
    if (!payload) return;
    try { navigator.clipboard.writeText('NOVA-SUB:' + payload); } catch (e) { /* facultatif */ }
    window.location.href = 'nova://persona?d=' + payload;
  }

  async function testNotification() {
    const reg = await navigator.serviceWorker.ready;
    reg.showNotification(document.title, { body: 'Notification de test' });
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }

  if (standalone) renderActivate(); else renderInstall();
})();
