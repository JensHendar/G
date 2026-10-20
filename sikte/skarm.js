'use strict';
// Sikte: skärmsidan. Visar skjutbanan, tar emot telefoner via PeerJS (WebRTC)
// och räknar träffar. Telefonerna skickar bara sikte (normaliserat -1..1) och "skjut".

const COLORS = ['#ffcf4a', '#4dc3ff', '#ff6b8b', '#7be36a', '#c792ff', '#ff9f43', '#5ef2d6', '#f2f2f2'];
const ROUND_TIME = 60;
const COUNTDOWN = 3;
const ID_PREFIX = 'sikte-';
const ID_CHARS = 'abcdefghjkmnpqrstuvwxyz23456789';

const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
const $ = id => document.getElementById(id);
let W = 0, H = 0;

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  W = innerWidth;
  H = innerHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  for (const p of players.values()) send(p, { t: 'aspect', aspect: W / H });
}

// ---------- Spelare ----------

const players = new Map();
let colorIndex = 0;

function addPlayer(id, name, conn) {
  const p = {
    id, conn,
    name: (name || '').trim().slice(0, 14) || `Spelare ${players.size + 1}`,
    color: COLORS[colorIndex++ % COLORS.length],
    nx: 0, ny: 0,          // senaste sikte från telefonen
    x: W / 2, y: H / 2,    // utjämnad position på skärmen
    mouse: false,
    score: 0, hits: 0, shots: 0,
    flash: 0,
  };
  players.set(id, p);
  renderBoard();
  return p;
}

function removePlayer(id) {
  players.delete(id);
  renderBoard();
}

function send(p, msg) {
  if (p.conn && p.conn.open) {
    try { p.conn.send(msg); } catch (e) { /* kanalen stängs, hanteras av close */ }
  }
}

function aimTarget(p) {
  if (p.mouse) return [p.nx, p.ny];
  return [
    clamp(W / 2 + p.nx * W / 2, 0, W),
    clamp(H / 2 + p.ny * H / 2, 0, H),
  ];
}

// ---------- Nätverk ----------

let peer = null;
let roomId = '';

function makeId(n = 5) {
  let s = '';
  for (let i = 0; i < n; i++) s += ID_CHARS[Math.floor(Math.random() * ID_CHARS.length)];
  return s;
}

function setStatus(text, bad = false) {
  const el = $('status');
  el.textContent = text;
  el.classList.toggle('bad', bad);
}

function startPeer() {
  if (typeof Peer === 'undefined') {
    setStatus('Kunde inte ladda PeerJS. Kontrollera internetanslutningen.', true);
    return;
  }
  roomId = makeId();
  peer = new Peer(ID_PREFIX + roomId, { debug: 1 });

  peer.on('open', () => {
    showJoinInfo();
    setStatus(players.size ? '' : 'Väntar på spelare…');
  });

  peer.on('connection', conn => {
    conn.on('open', () => {
      const p = addPlayer(conn.peer, conn.metadata && conn.metadata.name, conn);
      send(p, { t: 'welcome', color: p.color, name: p.name, aspect: W / H });
      setStatus(`${p.name} anslöt.`);
    });
    conn.on('data', msg => onMessage(conn.peer, msg));
    conn.on('close', () => removePlayer(conn.peer));
    conn.on('error', () => removePlayer(conn.peer));
  });

  peer.on('disconnected', () => {
    setStatus('Tappade kontakten med servern, försöker igen…', true);
    setTimeout(() => peer && !peer.destroyed && peer.reconnect(), 1500);
  });

  peer.on('error', err => {
    if (err.type === 'unavailable-id') {
      peer.destroy();
      startPeer();
    } else if (['network', 'server-error', 'socket-error', 'socket-closed'].includes(err.type)) {
      setStatus('Kunde inte nå anslutningsservern. Försöker igen…', true);
      if (!peer.open) {
        peer.destroy();
        setTimeout(startPeer, 3000);
      }
    } else {
      console.warn('PeerJS', err.type, err);
    }
  });
}

function showJoinInfo() {
  const url = new URL('kontroll.html', location.href);
  url.searchParams.set('rum', roomId.toUpperCase());
  $('code').textContent = roomId.toUpperCase();
  $('join-url').textContent = url.protocol === 'file:'
    ? 'Sidan är öppnad som fil. Lägg den på en https-server (t.ex. GitHub Pages) så att telefonen når den.'
    : url.href;

  const box = $('qr');
  box.textContent = '';
  if (typeof qrcode === 'undefined') {
    box.textContent = 'QR-koden kunde inte laddas';
    return;
  }
  const qr = qrcode(0, 'M');
  qr.addData(url.href);
  qr.make();
  const img = new Image();
  img.alt = 'QR-kod till kontrollen';
  img.src = qr.createDataURL(8, 2);
  box.appendChild(img);
}

function onMessage(id, msg) {
  const p = players.get(id);
  if (!p || !msg || typeof msg !== 'object') return;
  if (msg.t === 'aim' && Number.isFinite(msg.x) && Number.isFinite(msg.y)) {
    p.nx = clamp(msg.x, -1.5, 1.5);
    p.ny = clamp(msg.y, -1.5, 1.5);
  } else if (msg.t === 'fire') {
    fire(p);
  }
}

// ---------- Spelets gång ----------

let phase = 'lobby';   // lobby | countdown | playing
let phaseTime = 0;
let roundLeft = 0;
let elapsed = 0;
let spawnTimer = 0;
let targets = [];
let popups = [];
let sparks = [];
let lastResults = null;

function setPhase(next) {
  phase = next;
  phaseTime = 0;
  document.body.classList.remove('lobby', 'countdown', 'playing');
  document.body.classList.add(next);
  if (next === 'lobby') {
    targets = [makeStartTarget()];
  }
}

function makeStartTarget() {
  return { kind: 'start', x: W / 2, y: H * 0.56, cy: H * 0.56, r: Math.min(W, H) * 0.13, vx: 0, age: 0, life: Infinity, bob: 0, phase: 0 };
}

function startCountdown() {
  for (const p of players.values()) { p.score = 0; p.hits = 0; p.shots = 0; }
  lastResults = null;
  $('results').hidden = true;
  targets = [];
  renderBoard();
  setPhase('countdown');
  sfx('start');
}

function startRound() {
  setPhase('playing');
  roundLeft = ROUND_TIME;
  elapsed = 0;
  spawnTimer = 0.3;
}

function endRound() {
  lastResults = [...players.values()]
    .map(p => ({ name: p.name, color: p.color, score: p.score, acc: p.shots ? Math.round(100 * p.hits / p.shots) : 0 }))
    .sort((a, b) => b.score - a.score);
  showResults();
  sfx('end');
  setPhase('lobby');
}

function showResults() {
  const el = $('results');
  if (!lastResults || !lastResults.length) { el.hidden = true; return; }
  el.innerHTML = '<h2>Rundan är slut</h2><ol></ol>';
  const list = el.querySelector('ol');
  lastResults.forEach((r, i) => {
    const li = document.createElement('li');
    li.innerHTML = `<span>${i + 1}.</span><i></i><span class="n"></span><small></small><b></b>`;
    li.querySelector('i').style.background = r.color;
    li.querySelector('.n').textContent = r.name;
    li.querySelector('small').textContent = `${r.acc}% träff`;
    li.querySelector('b').textContent = r.score;
    list.appendChild(li);
  });
  el.hidden = false;
}

const KINDS = {
  normal: { r: [36, 52], speed: [70, 170], weight: 58 },
  small:  { r: [18, 24], speed: [170, 280], weight: 22, points: 75 },
  gold:   { r: [20, 24], speed: [260, 360], weight: 6, points: 150 },
  bomb:   { r: [32, 40], speed: [60, 140], weight: 14, points: -100 },
};

function spawnTarget() {
  if (targets.length >= 10) return;
  let roll = Math.random() * 100;
  let kind = 'normal';
  for (const [k, v] of Object.entries(KINDS)) {
    if ((roll -= v.weight) < 0) { kind = k; break; }
  }
  const def = KINDS[kind];
  const scale = Math.min(W, H) / 800 + 0.25;
  const r = rand(...def.r) * scale;
  const t = { kind, r, age: 0, phase: Math.random() * 6.28, bob: rand(0, 30) };
  const hard = 1 + elapsed / ROUND_TIME * 0.6;

  if (kind !== 'gold' && Math.random() < 0.45) {
    // Poppar upp på ett ställe och försvinner igen.
    t.x = rand(r + 40, W - r - 40);
    t.y = rand(H * 0.18, H * 0.72);
    t.vx = 0;
    t.bob = 0;
    t.life = rand(1.6, 2.6) / hard;
  } else {
    const fromLeft = Math.random() < 0.5;
    const speed = rand(...def.speed) * scale * hard;
    t.x = fromLeft ? -r : W + r;
    t.y = rand(H * 0.16, H * 0.7);
    t.vx = fromLeft ? speed : -speed;
    t.life = (W + 2 * r) / speed;
  }
  t.cy = t.y;
  targets.push(t);
}

function targetScale(t) {
  if (t.kind === 'start') return 1 + Math.sin(t.age * 3) * 0.03;
  if (t.vx !== 0) return 1;
  const pop = Math.min(1, t.age / 0.15);
  const out = Math.min(1, (t.life - t.age) / 0.2);
  return Math.max(0, Math.min(pop, out));
}

function fire(p) {
  p.shots++;
  p.flash = 1;
  sfx('shot');

  let hit = null;
  for (let i = targets.length - 1; i >= 0; i--) {
    const t = targets[i];
    if (Math.hypot(p.x - t.x, p.y - t.cy) <= t.r * targetScale(t)) { hit = t; break; }
  }
  if (!hit) { send(p, { t: 'miss' }); return; }

  if (hit.kind === 'start') {
    if (phase === 'lobby') startCountdown();
    return;
  }
  if (phase !== 'playing') return;

  let pts;
  if (hit.kind === 'normal') {
    const d = Math.hypot(p.x - hit.x, p.y - hit.cy) / hit.r;
    pts = d < 0.3 ? 50 : d < 0.65 ? 25 : 10;
  } else {
    pts = KINDS[hit.kind].points;
  }
  p.score += pts;
  if (pts > 0) p.hits++;
  targets.splice(targets.indexOf(hit), 1);

  burst(hit.x, hit.cy, hit.kind === 'bomb' ? '#ff7a2f' : hit.kind === 'gold' ? '#ffd84a' : p.color, hit.kind === 'bomb' ? 40 : 18);
  popups.push({ x: hit.x, y: hit.cy - hit.r, text: (pts > 0 ? '+' : '') + pts, color: pts > 0 ? p.color : '#ff5c5c', age: 0 });
  sfx(hit.kind === 'bomb' ? 'boom' : hit.kind === 'gold' ? 'gold' : 'hit');
  send(p, { t: 'hit', pts, score: p.score });
  renderBoard();
}

function burst(x, y, color, n) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2;
    const s = rand(80, 360);
    sparks.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 60, age: 0, life: rand(0.4, 0.8), color });
  }
}

// ---------- Uppdatering ----------

let last = performance.now();
let syncTimer = 0;

function tick(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  update(dt);
  draw();
  requestAnimationFrame(tick);
}

function update(dt) {
  phaseTime += dt;

  if (phase === 'countdown' && phaseTime >= COUNTDOWN) startRound();
  if (phase === 'playing') {
    roundLeft -= dt;
    elapsed += dt;
    spawnTimer -= dt;
    if (spawnTimer <= 0) {
      spawnTarget();
      spawnTimer = Math.max(0.35, 1.0 - elapsed * 0.012) * rand(0.7, 1.3);
    }
    if (roundLeft <= 0) endRound();
  }

  for (const t of targets) {
    t.age += dt;
    t.x += t.vx * dt;
    if (t.kind === 'start') {
      t.x = W / 2;
      t.y = H * 0.56;
      t.r = Math.min(W, H) * 0.13;
    }
    t.cy = t.y + Math.sin(t.age * 3 + t.phase) * t.bob;
  }
  targets = targets.filter(t => t.age < t.life);

  const k = 1 - Math.exp(-dt * 22);
  for (const p of players.values()) {
    const [tx, ty] = aimTarget(p);
    p.x += (tx - p.x) * k;
    p.y += (ty - p.y) * k;
    p.flash = Math.max(0, p.flash - dt * 5);
  }

  for (const s of sparks) {
    s.age += dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.vy += 600 * dt;
  }
  sparks = sparks.filter(s => s.age < s.life);
  for (const pop of popups) pop.age += dt;
  popups = popups.filter(pop => pop.age < 1);

  const timer = $('timer');
  if (phase === 'playing') {
    const left = Math.max(0, Math.ceil(roundLeft));
    timer.textContent = left;
    timer.classList.toggle('low', left <= 10);
  } else {
    timer.textContent = '';
  }

  syncTimer -= dt;
  if (syncTimer <= 0) {
    syncTimer = 0.25;
    const time = phase === 'playing' ? Math.max(0, Math.ceil(roundLeft)) : null;
    for (const p of players.values()) send(p, { t: 'state', phase, time, score: p.score });
  }
}

// ---------- Rita ----------

function draw() {
  drawBackground();
  for (const t of targets) drawTarget(t);
  for (const s of sparks) {
    ctx.globalAlpha = 1 - s.age / s.life;
    ctx.fillStyle = s.color;
    ctx.beginPath();
    ctx.arc(s.x, s.y, 3.5, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  drawCounter();

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const pop of popups) {
    ctx.globalAlpha = 1 - pop.age;
    ctx.font = '36px "Lilita One", sans-serif';
    ctx.lineWidth = 5;
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.strokeText(pop.text, pop.x, pop.y - pop.age * 50);
    ctx.fillStyle = pop.color;
    ctx.fillText(pop.text, pop.x, pop.y - pop.age * 50);
  }
  ctx.globalAlpha = 1;

  if (phase === 'countdown') {
    const n = Math.ceil(COUNTDOWN - phaseTime);
    const f = phaseTime % 1;
    ctx.font = `${Math.min(W, H) * (0.3 - f * 0.08)}px "Lilita One", sans-serif`;
    ctx.globalAlpha = 1 - f * 0.6;
    ctx.fillStyle = '#ffcf4a';
    ctx.strokeStyle = 'rgba(0,0,0,0.4)';
    ctx.lineWidth = 10;
    ctx.strokeText(n, W / 2, H * 0.45);
    ctx.fillText(n, W / 2, H * 0.45);
    ctx.globalAlpha = 1;
  }

  if (phase === 'lobby' && players.size === 0) {
    ctx.font = '22px "Atkinson Hyperlegible", sans-serif';
    ctx.fillStyle = 'rgba(255,255,255,0.8)';
    ctx.fillText('Skanna QR-koden med telefonen, eller klicka med musen för att testa', W / 2, H * 0.56 + Math.min(W, H) * 0.13 + 36);
  }

  for (const p of players.values()) drawCrosshair(p);
}

function drawBackground() {
  const sky = ctx.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, '#1d2b4a');
  sky.addColorStop(0.6, '#3d5a80');
  sky.addColorStop(1, '#6b8fb5');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, W, H);

  // Kulisser: två lager kullar.
  ctx.fillStyle = '#2c4a3e';
  ctx.beginPath();
  ctx.moveTo(0, H * 0.78);
  for (let x = 0; x <= W; x += 40) ctx.lineTo(x, H * 0.74 + Math.sin(x * 0.006) * 30 + Math.sin(x * 0.017) * 12);
  ctx.lineTo(W, H);
  ctx.lineTo(0, H);
  ctx.fill();
  ctx.fillStyle = '#22392f';
  ctx.beginPath();
  ctx.moveTo(0, H * 0.84);
  for (let x = 0; x <= W; x += 40) ctx.lineTo(x, H * 0.82 + Math.sin(x * 0.009 + 2) * 18);
  ctx.lineTo(W, H);
  ctx.lineTo(0, H);
  ctx.fill();
}

function drawCounter() {
  // Disken längst fram på skjutbanan.
  const y = H * 0.86;
  ctx.fillStyle = '#7a4a2a';
  ctx.fillRect(0, y, W, H - y);
  ctx.fillStyle = '#9c6236';
  ctx.fillRect(0, y, W, 10);
  ctx.fillStyle = 'rgba(0,0,0,0.18)';
  for (let x = 0; x < W; x += 120) ctx.fillRect(x, y + 10, 3, H - y);
  ctx.fillStyle = '#c0392b';
  for (let x = 0; x < W; x += 60) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 60, 0);
    ctx.lineTo(x + 30, 26);
    ctx.fill();
  }
}

function drawTarget(t) {
  const s = targetScale(t);
  if (s <= 0) return;
  const r = t.r * s;

  ctx.save();
  ctx.translate(t.x, t.cy);

  // Pinne
  if (t.kind !== 'start') {
    ctx.fillStyle = '#5b3a1f';
    ctx.fillRect(-4, r * 0.6, 8, H);
  }

  if (t.kind === 'bomb') {
    ctx.fillStyle = '#1b1b1f';
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.18)';
    ctx.beginPath(); ctx.arc(-r * 0.35, -r * 0.35, r * 0.3, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#c9a26b'; ctx.lineWidth = 4;
    ctx.beginPath(); ctx.moveTo(r * 0.5, -r * 0.8); ctx.quadraticCurveTo(r * 0.9, -r * 1.3, r * 0.6, -r * 1.5); ctx.stroke();
    ctx.fillStyle = Math.sin(t.age * 30) > 0 ? '#ffde59' : '#ff7a2f';
    ctx.beginPath(); ctx.arc(r * 0.6, -r * 1.5, 6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ff5c5c';
    ctx.font = `${r * 0.7}px "Lilita One", sans-serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('−100', 0, r * 0.1);
  } else if (t.kind === 'gold') {
    const g = ctx.createRadialGradient(-r * 0.3, -r * 0.3, 1, 0, 0, r);
    g.addColorStop(0, '#fff6c4'); g.addColorStop(0.5, '#ffd84a'); g.addColorStop(1, '#b8860b');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
    ctx.rotate(t.age * 2);
    ctx.fillStyle = '#fff';
    star(0, 0, r * 0.55, r * 0.22);
  } else {
    const rings = t.kind === 'small'
      ? ['#2d7dd2', '#fff', '#2d7dd2']
      : ['#d7263d', '#fff', '#d7263d', '#fff', '#d7263d'];
    rings.forEach((c, i) => {
      ctx.fillStyle = c;
      ctx.beginPath();
      ctx.arc(0, 0, r * (1 - i / rings.length), 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.strokeStyle = 'rgba(0,0,0,0.35)';
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.stroke();
    if (t.kind === 'start') {
      ctx.font = `${r * 0.26}px "Lilita One", sans-serif`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillStyle = '#fff';
      ctx.strokeStyle = 'rgba(0,0,0,0.6)';
      ctx.lineWidth = 6;
      ctx.strokeText('SKJUT FÖR', 0, -r * 0.14);
      ctx.fillText('SKJUT FÖR', 0, -r * 0.14);
      ctx.strokeText('ATT STARTA', 0, r * 0.18);
      ctx.fillText('ATT STARTA', 0, r * 0.18);
    }
  }
  ctx.restore();
}

function star(x, y, outer, inner) {
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + i * Math.PI / 5;
    const r = i % 2 ? inner : outer;
    ctx.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
  }
  ctx.closePath();
  ctx.fill();
}

function drawCrosshair(p) {
  const { x, y } = p;
  ctx.save();
  ctx.translate(x, y);
  ctx.lineCap = 'round';
  for (const [w, c] of [[6, 'rgba(0,0,0,0.5)'], [3, p.color]]) {
    ctx.lineWidth = w;
    ctx.strokeStyle = c;
    ctx.beginPath(); ctx.arc(0, 0, 20, 0, Math.PI * 2); ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-30, 0); ctx.lineTo(-10, 0);
    ctx.moveTo(10, 0); ctx.lineTo(30, 0);
    ctx.moveTo(0, -30); ctx.lineTo(0, -10);
    ctx.moveTo(0, 10); ctx.lineTo(0, 30);
    ctx.stroke();
  }
  ctx.fillStyle = p.color;
  ctx.beginPath(); ctx.arc(0, 0, 3, 0, Math.PI * 2); ctx.fill();
  if (p.flash > 0) {
    ctx.globalAlpha = p.flash;
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(0, 0, 20 + (1 - p.flash) * 30, 0, Math.PI * 2); ctx.stroke();
    ctx.globalAlpha = 1;
  }
  ctx.font = '700 15px "Atkinson Hyperlegible", sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.lineWidth = 4;
  ctx.strokeStyle = 'rgba(0,0,0,0.6)';
  ctx.strokeText(p.name, 0, 36);
  ctx.fillStyle = p.color;
  ctx.fillText(p.name, 0, 36);
  ctx.restore();
}

function renderBoard() {
  const board = $('board');
  board.textContent = '';
  const sorted = [...players.values()].sort((a, b) => b.score - a.score);
  for (const p of sorted) {
    const li = document.createElement('li');
    const dot = document.createElement('i');
    dot.style.background = p.color;
    const name = document.createElement('span');
    name.textContent = p.name;
    const score = document.createElement('b');
    score.textContent = p.score;
    li.append(dot, name, score);
    board.appendChild(li);
  }
}

// ---------- Ljud ----------

let audio = null;
let soundOn = false;

function sfx(kind) {
  if (!soundOn || !audio) return;
  const t = audio.currentTime;
  const o = audio.createOscillator();
  const g = audio.createGain();
  o.connect(g).connect(audio.destination);
  const tone = {
    shot:  ['square', 900, 120, 0.08, 0.12],
    hit:   ['triangle', 520, 1040, 0.15, 0.25],
    gold:  ['triangle', 880, 1760, 0.3, 0.25],
    boom:  ['sawtooth', 160, 40, 0.5, 0.35],
    start: ['triangle', 440, 880, 0.3, 0.2],
    end:   ['triangle', 660, 220, 0.6, 0.2],
  }[kind];
  const [type, f0, f1, dur, vol] = tone;
  o.type = type;
  o.frequency.setValueAtTime(f0, t);
  o.frequency.exponentialRampToValueAtTime(f1, t + dur);
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.start(t);
  o.stop(t + dur + 0.02);
}

function toggleSound(force) {
  soundOn = force ?? !soundOn;
  if (soundOn && !audio) {
    try { audio = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { soundOn = false; }
  }
  if (audio && audio.state === 'suspended') audio.resume();
  $('sound').textContent = soundOn ? '🔊' : '🔇';
  $('sound').setAttribute('aria-label', soundOn ? 'Stäng av ljud' : 'Slå på ljud');
}

$('sound').addEventListener('click', () => toggleSound());

// ---------- Mus (för att testa utan telefon) ----------

function mousePlayer() {
  let p = players.get('mouse');
  if (!p) {
    p = addPlayer('mouse', 'Mus', null);
    p.mouse = true;
  }
  return p;
}

canvas.addEventListener('pointermove', e => {
  if (e.pointerType !== 'mouse') return;
  const p = players.get('mouse');
  if (p) { p.nx = e.clientX; p.ny = e.clientY; }
});

canvas.addEventListener('pointerdown', e => {
  const first = !players.has('mouse');
  const p = mousePlayer();
  p.nx = e.clientX; p.ny = e.clientY;
  if (first) { p.x = e.clientX; p.y = e.clientY; }
  if (!audio) toggleSound(true);
  fire(p);
});

// ---------- Start ----------

function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function rand(a, b) { return a + Math.random() * (b - a); }

addEventListener('resize', resize);
resize();
setPhase('lobby');
startPeer();
requestAnimationFrame(tick);
