'use strict';
// Sikte: telefonsidan. Läser rörelsesensorerna, räknar ut åt vilket håll
// telefonen pekar jämfört med "centrera"-läget och skickar det till skärmen.

const ID_PREFIX = 'sikte-';
const $ = id => document.getElementById(id);
const DEG = Math.PI / 180;

const store = {
  get(k, d) { try { return localStorage.getItem('sikte.' + k) ?? d; } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem('sikte.' + k, v); } catch (e) { /* privat läge */ } },
};

const params = new URLSearchParams(location.search);
$('room').value = (params.get('rum') || '').toUpperCase();
$('name').value = store.get('name', '');
$('sens').value = store.get('sens', '45');
const savedGrip = store.get('grip', 'pointer');
for (const r of document.querySelectorAll('input[name=grip]')) r.checked = r.value === savedGrip;

let peer = null;
let conn = null;
let aspect = 16 / 9;
let grip = savedGrip;
let center = null;          // {yaw, pitch} när spelaren tryckte Centrera
let lastSend = 0;
let gotSensor = false;
let wakeLock = null;

// ---------- Anslutning ----------

function showError(text) { $('error').textContent = text; }

function show(section) {
  for (const id of ['setup', 'play', 'lost']) $(id).hidden = id !== section;
}

$('connect').addEventListener('click', async () => {
  showError('');
  const room = $('room').value.trim().toLowerCase();
  const name = $('name').value.trim();
  grip = document.querySelector('input[name=grip]:checked').value;
  if (!room) { showError('Skriv in rumskoden som visas på skärmen.'); return; }
  store.set('name', name);
  store.set('grip', grip);

  // iPhone kräver att sidan ber om lov, och det måste ske direkt efter ett tryck.
  const DOE = window.DeviceOrientationEvent;
  if (DOE && typeof DOE.requestPermission === 'function') {
    try {
      if (await DOE.requestPermission() !== 'granted') {
        showError('Du måste tillåta rörelse och orientering för att kunna sikta.');
        return;
      }
    } catch (e) {
      showError('Kunde inte få tillgång till rörelsesensorerna. Öppnas sidan via https?');
      return;
    }
  }
  if (!window.isSecureContext) {
    showError('Sidan måste öppnas via https för att sensorerna ska fungera.');
  }

  window.addEventListener('deviceorientation', onOrientation);
  connect(room, name);
});

$('reconnect').addEventListener('click', () => {
  connect($('room').value.trim().toLowerCase(), $('name').value.trim());
});

function connect(room, name) {
  if (typeof Peer === 'undefined') {
    showError('Kunde inte ladda PeerJS. Kontrollera internetanslutningen.');
    show('setup');
    return;
  }
  const btn = $('connect');
  btn.disabled = true;
  btn.textContent = 'Ansluter…';
  if (peer) peer.destroy();

  peer = new Peer({ debug: 1 });
  const timeout = setTimeout(() => fail('Fick inget svar från skärmen. Stämmer rumskoden?'), 15000);

  peer.on('open', () => {
    conn = peer.connect(ID_PREFIX + room, { metadata: { name }, serialization: 'json', reliable: true });
    conn.on('open', () => {
      clearTimeout(timeout);
      btn.disabled = false;
      btn.textContent = 'Anslut';
      center = null;
      show('play');
      keepAwake();
      setTimeout(checkSensor, 2000);
    });
    conn.on('data', onMessage);
    conn.on('close', () => lost('Anslutningen till skärmen bröts.'));
  });

  peer.on('error', err => {
    clearTimeout(timeout);
    if (err.type === 'peer-unavailable') fail(`Hittade inget rum med koden ${room.toUpperCase()}.`);
    else if (conn && conn.open) console.warn('PeerJS', err.type, err);
    else fail('Kunde inte ansluta (' + err.type + ').');
  });

  function fail(text) {
    clearTimeout(timeout);
    btn.disabled = false;
    btn.textContent = 'Anslut';
    if (peer) peer.destroy();
    if ($('play').hidden) { show('setup'); showError(text); } else lost(text);
  }
}

function lost(text) {
  $('lost-msg').textContent = text;
  show('lost');
}

function send(msg) {
  if (conn && conn.open) {
    try { conn.send(msg); } catch (e) { /* hanteras av close */ }
  }
}

function onMessage(msg) {
  if (!msg || typeof msg !== 'object') return;
  if (msg.t === 'welcome') {
    document.documentElement.style.setProperty('--me', msg.color);
    $('me-name').textContent = msg.name;
    if (msg.aspect) aspect = msg.aspect;
  } else if (msg.t === 'aspect') {
    aspect = msg.aspect || aspect;
  } else if (msg.t === 'state') {
    $('pad-score').textContent = msg.score;
    $('pad-time').textContent = msg.phase === 'playing' ? `${msg.time} s`
      : msg.phase === 'countdown' ? 'Gör dig redo!' : 'Skjut på startmålet';
  } else if (msg.t === 'hit') {
    $('pad-score').textContent = msg.score;
    pop((msg.pts > 0 ? '+' : '') + msg.pts, msg.pts < 0);
    vibrate(msg.pts < 0 ? [120, 40, 120] : [25, 30, 50]);
  }
}

function keepAwake() {
  if (!('wakeLock' in navigator) || wakeLock) return;
  navigator.wakeLock.request('screen')
    .then(lock => { wakeLock = lock; lock.addEventListener('release', () => { wakeLock = null; }); })
    .catch(() => {});
}
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && !$('play').hidden) keepAwake();
});

// ---------- Sikte ----------

// Riktningen telefonen pekar åt, som enhetsvektor i jordens koordinater
// (x öst, y nord, z upp). Rotationen är R = Rz(alpha) · Rx(beta) · Ry(gamma) enligt W3C.
function pointing(alpha, beta, gamma) {
  const cA = Math.cos(alpha * DEG), sA = Math.sin(alpha * DEG);
  const cB = Math.cos(beta * DEG), sB = Math.sin(beta * DEG);
  const cG = Math.cos(gamma * DEG), sG = Math.sin(gamma * DEG);
  if (grip === 'camera') {
    // Baksidan (kameran) pekar mot skärmen: telefonens -z-axel.
    return [
      -(cG * sA * sB + cA * sG),
      -(sA * sG - cA * cG * sB),
      -(cB * cG),
    ];
  }
  // Toppen av telefonen pekar mot skärmen: telefonens y-axel.
  return [-cB * sA, cA * cB, sB];
}

function onOrientation(e) {
  if (e.alpha == null || e.beta == null || e.gamma == null) return;
  gotSensor = true;
  const [vx, vy, vz] = pointing(e.alpha, e.beta, e.gamma);
  const yaw = Math.atan2(vx, vy) / DEG;
  const pitch = Math.asin(Math.max(-1, Math.min(1, vz))) / DEG;

  if (!center) {
    center = { yaw, pitch };
    if (!$('play').hidden) setMsg('Rikta mot mitten av skärmen och tryck Centrera om siktet hamnar fel.');
  }
  let dyaw = yaw - center.yaw;
  if (dyaw > 180) dyaw -= 360;
  if (dyaw < -180) dyaw += 360;
  const dpitch = pitch - center.pitch;

  // Reglaget: högre värde = känsligare = färre grader för att svepa över skärmen.
  const spanX = 110 - Number($('sens').value);
  const spanY = spanX / aspect;
  const x = dyaw / (spanX / 2);
  const y = -dpitch / (spanY / 2);

  const now = performance.now();
  if (now - lastSend >= 15) {
    lastSend = now;
    send({ t: 'aim', x: round(x), y: round(y) });
  }
}

function checkSensor() {
  if (!gotSensor) {
    setMsg('Inga rörelsedata kommer in. Telefonen saknar gyroskop eller så är sidan inte öppnad via https.', true);
  }
}

$('center').addEventListener('click', () => {
  center = null;
  vibrate(20);
  setMsg('Centrerat.');
});

$('sens').addEventListener('change', () => store.set('sens', $('sens').value));

// ---------- Skjut ----------

const fireBtn = $('fire');
fireBtn.addEventListener('pointerdown', e => {
  e.preventDefault();
  fireBtn.classList.add('down');
  send({ t: 'fire' });
  vibrate(12);
});
for (const ev of ['pointerup', 'pointercancel', 'pointerleave']) {
  fireBtn.addEventListener(ev, () => fireBtn.classList.remove('down'));
}
fireBtn.addEventListener('contextmenu', e => e.preventDefault());

function pop(text, negative) {
  const el = $('fire-pop');
  el.textContent = text;
  el.classList.toggle('neg', negative);
  el.classList.remove('show');
  void el.offsetWidth;
  el.classList.add('show');
}

function setMsg(text, bad = false) {
  const el = $('pad-msg');
  el.textContent = text;
  el.classList.toggle('bad', bad);
}

function vibrate(pattern) {
  if (navigator.vibrate) {
    try { navigator.vibrate(pattern); } catch (e) { /* stöds inte */ }
  }
}

function round(v) { return Math.round(v * 1000) / 1000; }
