(() => {
  "use strict";

  const K = window.KINGDOM;
  const P = K.professions;
  const N = P.length;
  const IDX = Object.fromEntries(P.map((p, i) => [p.id, i]));

  // ---------- Rules ----------
  const PRICE_GROWTH = 1.15;
  const TIER_OWNED = [1, 10, 25, 50, 100];
  const TIER_COST = [10, 50, 500, 5e4, 5e6];
  const ROMAN = ["I", "II", "III", "IV", "V"];
  const CHARTER_BONUS = 0.02;
  const ACH_BONUS = 0.01;
  const OFFLINE_CAP = 8 * 3600;
  const RAID_MIN_WORKERS = 15;
  const SAVE_KEY = "kingdom-clicker:save";
  const LEGACY_KEY = "profession-clicker:kingdom";

  const $ = (sel) => document.querySelector(sel);
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* storage unavailable */ } },
    del(k) { try { localStorage.removeItem(k); } catch { /* storage unavailable */ } }
  };
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  // ---------- Formatting ----------
  const SUFFIX = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"];
  function fmt(n) {
    if (!isFinite(n)) return "∞";
    if (n < 1000) {
      if (n < 10 && n % 1) return n.toFixed(1);
      return Math.floor(n).toString();
    }
    const e = Math.floor(Math.log10(n) / 3);
    if (e >= SUFFIX.length) return n.toExponential(2).replace("+", "");
    const v = n / Math.pow(1000, e);
    return (v < 10 ? v.toFixed(2) : v < 100 ? v.toFixed(1) : Math.floor(v).toString()) + " " + SUFFIX[e];
  }
  function fmtTime(s) {
    s = Math.floor(s);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    if (h) return `${h}h ${m}m`;
    if (m) return `${m}m ${s % 60}s`;
    return `${s}s`;
  }
  const pct = (x) => `${Math.round(x * 100)}%`;

  // ---------- State ----------
  let S = null;
  let buffs = [];
  let buyAmount = 1;
  let upgrades = [];
  let achievements = [];
  let lastRank = 0;

  function freshState() {
    return {
      v: 2, name: "Oakhollow", money: 0, runEarned: 0, allEarned: 0, clicks: 0,
      owned: Array(N).fill(0), ups: [], charters: 0, chartersSpent: 0, perks: [],
      golden: 0, bandits: 0, ach: [], playTime: 0, muted: false, saved: Date.now()
    };
  }

  function save() {
    if (!S) return;
    S.saved = Date.now();
    store.set(SAVE_KEY, JSON.stringify(S));
  }

  function load() {
    const raw = store.get(SAVE_KEY);
    if (raw) {
      try {
        const s = Object.assign(freshState(), JSON.parse(raw));
        s.owned = Array.from({ length: N }, (_, i) => s.owned[i] || 0);
        return s;
      } catch { /* fall through to a fresh game */ }
    }
    return migrateLegacy();
  }

  // Carry over a save from the multi-theme version (12 professions, flat prestige).
  function migrateLegacy() {
    const raw = store.get(LEGACY_KEY);
    if (!raw) return null;
    try {
      const old = JSON.parse(raw);
      const s = freshState();
      Object.assign(s, {
        money: old.money || 0, runEarned: old.runEarned || 0, allEarned: old.allEarned || 0,
        clicks: old.clicks || 0, golden: old.golden || 0, playTime: old.playTime || 0,
        charters: old.prestige || 0, saved: old.saved || Date.now()
      });
      (old.owned || []).forEach((n, i) => { if (K.legacyIndex[i] != null) s.owned[K.legacyIndex[i]] = n; });
      s.ups = (old.ups || []).map((id) => {
        const m = /^p(\d+)t(\d)$/.exec(id);
        return m ? `p${K.legacyIndex[+m[1]]}t${m[2]}` : id;
      });
      return s;
    } catch { return null; }
  }

  // ---------- Derived values ----------
  const has = (id) => S.ups.includes(id);
  const perk = (id) => S.perks.includes(id);
  const totalOwned = () => S.owned.reduce((a, b) => a + b, 0);
  const chartersFree = () => S.charters - S.chartersSpent;
  const buffMult = (type) => buffs.filter((b) => b.type === type).reduce((m, b) => m * b.mult, 1);

  function rankIndex() {
    const w = totalOwned();
    let r = 0;
    K.ranks.forEach((rk, i) => { if (w >= rk.workers) r = i; });
    return r;
  }
  const seasonIndex = () => Math.floor(Math.max(0, S.playTime) / K.seasonLength) % K.seasons.length;
  const season = () => K.seasons[seasonIndex()];

  function seasonMult(i) {
    const m = season().boost[P[i].id] ?? 1;
    if (!perk("almanac")) return m;
    return m > 1 ? 1 + (m - 1) * 2 : 1;
  }

  function synergyMult(i) {
    let bonus = 0;
    K.synergies.forEach((sy, k) => {
      if (IDX[sy.to] === i && has(`s${k}`)) bonus += sy.pct * S.owned[IDX[sy.from]];
    });
    return 1 + bonus;
  }

  function globalMult() {
    let m = (1 + CHARTER_BONUS * S.charters) * (1 + ACH_BONUS * S.ach.length) * (1 + K.ranks[rankIndex()].bonus);
    K.edicts.forEach((e, k) => { if (e.mult && has(`e${k}`)) m *= e.mult; });
    if (perk("dynasty")) m *= 1.5;
    return m;
  }

  function tierMult(i) {
    let m = 1;
    for (let t = 0; t < 5; t++) if (has(`p${i}t${t}`)) m *= 2;
    return m;
  }
  const profRate = (i) => P[i].rate * tierMult(i) * synergyMult(i) * seasonMult(i) * globalMult();
  function cpsBase() {
    let c = 0;
    for (let i = 0; i < N; i++) if (S.owned[i]) c += S.owned[i] * profRate(i);
    return c;
  }
  const cps = () => cpsBase() * buffMult("prod");
  function clickValue() {
    let base = 1;
    if (has("c0")) base *= 2;
    if (has("c1")) base *= 2;
    if (perk("tutor")) base *= 3;
    let share = 0;
    if (has("c2")) share += 0.01;
    if (has("c3")) share += 0.02;
    if (has("c4")) share += 0.05;
    return (base * globalMult() + cps() * share) * buffMult("click");
  }

  const discount = () => (perk("recruits") ? 0.95 : 1);
  const unitCost = (i) => P[i].cost * discount() * Math.pow(PRICE_GROWTH, S.owned[i]);
  const costOf = (i, n) => Math.ceil(unitCost(i) * (Math.pow(PRICE_GROWTH, n) - 1) / (PRICE_GROWTH - 1));
  const maxAffordable = (i) => Math.max(0, Math.floor(Math.log(S.money * (PRICE_GROWTH - 1) / unitCost(i) + 1) / Math.log(PRICE_GROWTH)));
  const plannedAmount = (i) => (buyAmount === "max" ? Math.max(1, maxAffordable(i)) : buyAmount);

  const chartersPossible = () => Math.floor(Math.cbrt(S.allEarned / 1e9));
  const charterGain = () => Math.max(0, chartersPossible() - S.charters);

  function cloverRate() {
    let r = 1;
    K.edicts.forEach((e, k) => { if (e.clover && has(`e${k}`)) r *= e.clover; });
    if (perk("bloodline")) r *= 1.25;
    return r;
  }
  const watchActive = () => K.edicts.some((e, k) => e.watch && has(`e${k}`));

  function earn(n) {
    S.money += n;
    S.runEarned += n;
    S.allEarned += n;
  }

  // ---------- Upgrades & achievements ----------
  function buildUpgrades() {
    upgrades = [];
    P.forEach((p, i) => {
      TIER_OWNED.forEach((need, t) => {
        upgrades.push({
          id: `p${i}t${t}`, icon: p.icon, badge: ROMAN[t], name: `${K.tiers[t]}: ${p.name}s`,
          desc: `${p.name}s are twice as productive.`, cost: p.cost * TIER_COST[t],
          unlocked: () => S.owned[i] >= need
        });
      });
    });
    K.clickUpgrades.forEach((c, t) => {
      upgrades.push({ id: `c${t}`, icon: K.clicker.icon, badge: "✦" + ROMAN[t], name: c.name, desc: c.desc, cost: c.cost,
        unlocked: () => S.runEarned >= c.cost * 0.3 });
    });
    K.synergies.forEach((sy, k) => {
      upgrades.push({ id: `s${k}`, icon: P[IDX[sy.to]].icon, badge: "⇄", name: sy.name,
        desc: `${sy.desc} Needs ${sy.need} of each.`, cost: sy.cost,
        unlocked: () => S.owned[IDX[sy.to]] >= sy.need && S.owned[IDX[sy.from]] >= sy.need });
    });
    K.edicts.forEach((e, k) => {
      upgrades.push({ id: `e${k}`, icon: "📜", badge: "★", name: `Edict: ${e.name}`, desc: e.desc, cost: e.cost,
        unlocked: () => rankIndex() >= e.rank });
    });
    upgrades.sort((a, b) => a.cost - b.cost);
  }

  function buildAchievements() {
    const A = (id, icon, name, test) => achievements.push({ id, icon, name, test });
    achievements = [];
    [1e2, 1e4, 1e6, 1e8, 1e10, 1e12, 1e15, 1e18, 1e21].forEach((n) => A(`e${n}`, K.currency.icon, `Earn ${fmt(n)} gold`, () => S.allEarned >= n));
    [100, 1000, 5000, 20000].forEach((n) => A(`k${n}`, K.clicker.icon, `Collect taxes ${fmt(n)} times`, () => S.clicks >= n));
    [10, 1e3, 1e5, 1e7, 1e9, 1e11].forEach((n) => A(`r${n}`, "⚡", `Make ${fmt(n)} gold per second`, () => cpsBase() >= n));
    [10, 100, 250, 500, 1000].forEach((n) => A(`t${n}`, "👥", `Employ ${n} workers`, () => totalOwned() >= n));
    K.ranks.slice(1).forEach((rk, k) => A(`rank${k + 1}`, "🏰", `Grow into a ${rk.name}`, () => rankIndex() >= k + 1));
    P.forEach((p, i) => {
      A(`h${i}`, p.icon, `Hire your first ${p.name}`, () => S.owned[i] >= 1);
      A(`g${i}`, p.icon, `${p.name} Guild: own 50 ${p.name}s`, () => S.owned[i] >= 50);
    });
    [1, 10, 30].forEach((n) => A(`l${n}`, K.golden.icon, `Catch ${n} four-leaf clover${n > 1 ? "s" : ""}`, () => S.golden >= n));
    [1, 25, 100].forEach((n) => A(`b${n}`, K.bandit.icon, `Defeat ${n} bandit${n > 1 ? "s" : ""}`, () => S.bandits >= n));
    [1, 6, 12].forEach((n) => A(`sy${n}`, "⇄", `Unite ${n} guild${n > 1 ? "s" : ""} with synergies`, () => S.ups.filter((u) => u[0] === "s").length >= n));
    A("seasons", "📅", "Rule through all four seasons", () => S.playTime >= K.seasonLength * 4);
    A("ch1", "🌟", "Earn your first Royal Charter", () => S.charters >= 1);
    [1, 6, 12].forEach((n) => A(`pk${n}`, "👑", `Hold ${n} royal perk${n > 1 ? "s" : ""}`, () => S.perks.length >= n));
  }

  // ---------- Sound ----------
  let actx = null;
  function sound(notes, step = 0.06, type = "sine", vol = 0.06) {
    if (S.muted) return;
    try {
      actx = actx || new (window.AudioContext || window.webkitAudioContext)();
      const t0 = actx.currentTime;
      notes.forEach((f, k) => {
        const o = actx.createOscillator(), g = actx.createGain();
        o.type = type;
        o.frequency.value = f;
        g.gain.setValueAtTime(0, t0 + k * step);
        g.gain.linearRampToValueAtTime(vol, t0 + k * step + 0.01);
        g.gain.exponentialRampToValueAtTime(0.0001, t0 + k * step + step * 1.8);
        o.connect(g).connect(actx.destination);
        o.start(t0 + k * step);
        o.stop(t0 + k * step + step * 2);
      });
    } catch { /* audio unavailable */ }
  }
  const sfx = {
    click: () => sound([880 + Math.random() * 80, 1320], 0.04, "triangle", 0.04),
    buy: () => sound([523, 784], 0.07, "triangle"),
    upgrade: () => sound([659, 880, 1175], 0.07, "triangle"),
    clover: () => sound([784, 988, 1175, 1568], 0.08, "sine", 0.07),
    hit: () => sound([180, 110], 0.06, "square", 0.04),
    alarm: () => sound([440, 330, 440, 330], 0.12, "sawtooth", 0.03),
    fanfare: () => sound([523, 659, 784, 1047], 0.12, "triangle", 0.07)
  };

  // ---------- Actions ----------
  function doClick(x, y) {
    const v = clickValue();
    earn(v);
    S.clicks++;
    world.press = 1;
    world.floatText(x, y, "+" + fmt(v));
    world.burst(x, y, K.currency.icon, 5);
    sfx.click();
  }

  function buyProfession(i) {
    const n = plannedAmount(i);
    const c = costOf(i, n);
    if (S.money < c) return;
    S.money -= c;
    S.owned[i] += n;
    world.syncWalkers();
    sfx.buy();
    checkRank();
    renderShop(true);
  }

  function buyUpgrade(id) {
    const u = upgrades.find((x) => x.id === id);
    if (!u || has(id) || S.money < u.cost) return;
    S.money -= u.cost;
    S.ups.push(id);
    sfx.upgrade();
    toast(`${u.icon} ${u.name}`);
    renderShop(true);
  }

  function checkRank() {
    const r = rankIndex();
    if (r > lastRank) {
      toast(`🏰 Your ${K.ranks[lastRank].name.toLowerCase()} is now a ${K.ranks[r].name}! All income +${pct(K.ranks[r].bonus)}`);
      sfx.fanfare();
      world.burst(world.w / 2, world.groundY() - 30, "🎉", 18);
    }
    lastRank = r;
  }

  function catchClover() {
    S.golden++;
    sfx.clover();
    const roll = Math.random();
    const long = perk("meadow") ? 2 : 1;
    if (roll < 0.45) {
      const gain = (Math.min(S.money * 0.15, cps() * 900) + 13 + clickValue() * 20) * (perk("hoard") ? 3 : 1);
      earn(gain);
      toast(`🍀 Windfall! +${fmt(gain)} gold`);
    } else if (roll < 0.85) {
      buffs.push({ type: "prod", mult: 7, until: performance.now() + 30000 * long, name: "Frenzy", icon: "🔥" });
      toast(`🍀 Frenzy! All income ×7 for ${30 * long}s`);
    } else {
      buffs.push({ type: "click", mult: 25, until: performance.now() + 15000 * long, name: "Tax storm", icon: "⚡" });
      toast(`🍀 Tax storm! Clicks ×25 for ${15 * long}s`);
    }
  }

  function defeatBandit(b, x, y) {
    b.state = "down";
    S.bandits++;
    const loot = Math.max(cps() * 15, clickValue() * 10, 25);
    earn(loot);
    world.floatText(x, y - 20, `+${fmt(loot)}`);
    world.burst(x, y, "💥", 6);
    sfx.hit();
  }

  function banditEscaped() {
    if (perk("gates")) return 0;
    const knights = S.owned[IDX.knight];
    const stolen = S.money * (0.015 / (1 + knights / 10));
    S.money -= stolen;
    return stolen;
  }

  function doPrestige() {
    const gain = charterGain();
    if (gain < 1) return;
    S.charters += gain;
    S.money = perk("purse") ? 1000 : 0;
    S.runEarned = 0;
    S.owned = Array(N).fill(0);
    if (perk("founders")) [0, 1, 2].forEach((i) => (S.owned[i] = 10));
    S.ups = perk("legacy") ? S.ups.filter((u) => /^p\d+t0$/.test(u)) : [];
    buffs = [];
    lastRank = rankIndex();
    world.raid = null;
    world.syncWalkers();
    closeModal();
    sfx.fanfare();
    toast(`🌟 A new dynasty begins with ${fmt(gain)} more Royal Charter${gain > 1 ? "s" : ""}. Spend them in 👑 Charters.`);
    save();
    renderShop(true);
  }

  function buyPerk(id) {
    const p = K.perks.find((x) => x.id === id);
    if (!p || perk(id) || chartersFree() < p.cost) return;
    S.chartersSpent += p.cost;
    S.perks.push(id);
    sfx.upgrade();
    toast(`${p.icon} ${p.name} granted`);
    openCharters();
  }

  function checkAchievements() {
    for (const a of achievements) {
      if (!S.ach.includes(a.id) && a.test()) {
        S.ach.push(a.id);
        toast(`🏆 ${a.name} (+1% income)`);
      }
    }
  }

  // ---------- Toasts & chronicle ----------
  function toast(text) {
    const el = document.createElement("div");
    el.className = "toast";
    el.textContent = text;
    $("#toasts").appendChild(el);
    setTimeout(() => el.classList.add("out"), 3400);
    setTimeout(() => el.remove(), 3900);
    const all = $("#toasts").children;
    if (all.length > 3) all[0].remove();
  }

  const chronicleApi = {
    owned: (id) => S.owned[IDX[id]], rank: () => rankIndex(), season: () => seasonIndex(),
    bandits: () => S.bandits, clovers: () => S.golden, charters: () => S.charters
  };
  let lastLine = -1;
  function nextChronicle() {
    const pool = K.chronicle.map((c, i) => i).filter((i) => i !== lastLine && (!K.chronicle[i].when || K.chronicle[i].when(chronicleApi)));
    // Prefer lines tied to your progress over the generic ones.
    const specific = pool.filter((i) => K.chronicle[i].when);
    const pick = specific.length && Math.random() < 0.75 ? specific : pool;
    lastLine = pick[Math.floor(Math.random() * pick.length)];
    const el = $("#chronicle-text");
    el.classList.remove("show");
    void el.offsetWidth;
    el.textContent = K.chronicle[lastLine].text;
    el.classList.add("show");
  }

  // ---------- World (canvas) ----------
  const world = {
    canvas: null, ctx: null, w: 0, h: 0,
    walkers: [], particles: [], weather: [], clouds: [],
    golden: null, nextGolden: 0, raid: null, nextRaid: 0, raidStolen: 0, raidEscaped: 0,
    press: 0, t: 0, reduced: false,

    init() {
      this.canvas = $("#world");
      this.ctx = this.canvas.getContext("2d");
      this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      new ResizeObserver(() => this.resize()).observe(this.canvas.parentElement);
      this.canvas.addEventListener("pointerdown", (e) => {
        const r = this.canvas.getBoundingClientRect();
        this.hit(e.clientX - r.left, e.clientY - r.top);
      });
      this.canvas.addEventListener("keydown", (e) => {
        if (e.key === " " || e.key === "Enter") {
          e.preventDefault();
          const c = this.center();
          doClick(c.x, c.y - c.r * 0.6);
        }
      });
      this.resize();
    },

    resize() {
      const box = this.canvas.parentElement.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.w = box.width;
      this.h = box.height;
      this.canvas.width = Math.round(this.w * dpr);
      this.canvas.height = Math.round(this.h * dpr);
      this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      this.pad = ($(".chronicle")?.offsetHeight || 40) + 14; // keep sprites above the chronicle bar
    },

    reset() {
      const now = performance.now();
      this.walkers = [];
      this.particles = [];
      this.weather = [];
      this.golden = null;
      this.raid = null;
      this.nextGolden = now + 40000 + Math.random() * 50000;
      this.nextRaid = now + 120000 + Math.random() * 120000;
      this.clouds = Array.from({ length: 5 }, () => ({ x: Math.random(), y: 0.05 + Math.random() * 0.25, s: 0.7 + Math.random() * 0.6, v: 0.004 + Math.random() * 0.008 }));
      this.syncWalkers();
    },

    groundY() { return this.h * 0.64; },
    center() {
      const r = Math.min(this.w * 0.16, this.h * 0.145);
      return { x: this.w / 2, y: this.h * 0.38, r };
    },

    // A few sprites per profession, newest professions first, capped for performance.
    syncWalkers() {
      const counts = {};
      let total = 0;
      for (let i = N - 1; i >= 0 && total < 44; i--) {
        const n = Math.min(S.owned[i], 3, 44 - total);
        if (n) counts[i] = n;
        total += n;
      }
      const kept = [], have = {};
      for (const w of this.walkers) {
        have[w.prof] = (have[w.prof] || 0) + 1;
        if (have[w.prof] <= (counts[w.prof] || 0)) kept.push(w);
      }
      const now = {};
      kept.forEach((w) => (now[w.prof] = (now[w.prof] || 0) + 1));
      for (const i in counts) {
        for (let k = now[i] || 0; k < counts[i]; k++) {
          kept.push({ prof: +i, x: Math.random(), depth: Math.random(), dir: Math.random() < 0.5 ? -1 : 1,
            speed: 0.02 + Math.random() * 0.03, phase: Math.random() * 6.28, pause: 0 });
        }
      }
      this.walkers = kept.sort((a, b) => a.depth - b.depth);
    },

    startRaid() {
      const n = 3 + Math.floor(Math.random() * 3) + Math.min(3, rankIndex());
      const slow = watchActive() ? 0.7 : 1;
      this.raid = Array.from({ length: n }, (_, k) => ({
        x: 1.05 + k * 0.07 + Math.random() * 0.05, depth: Math.random(),
        speed: (0.055 + Math.random() * 0.03) * slow, phase: Math.random() * 6, state: "run", fade: 1
      }));
      this.raidStolen = 0;
      this.raidEscaped = 0;
      sfx.alarm();
      toast("🥷 Bandits! Click them before they escape with your gold.");
    },

    hit(x, y) {
      if (this.golden) {
        const g = this.golden;
        if (Math.hypot(x - g.x * this.w, y - g.y * this.h) < 36) {
          this.burst(g.x * this.w, g.y * this.h, K.golden.icon, 10);
          this.golden = null;
          catchClover();
          return;
        }
      }
      if (this.raid) {
        for (const b of this.raid) {
          if (b.state !== "run") continue;
          const p = this.groundPos(b.x, b.depth, 0);
          if (Math.hypot(x - p.x, y - p.y) < p.s * 0.8 + 8) { defeatBandit(b, p.x, p.y); return; }
        }
      }
      const c = this.center();
      if (Math.hypot(x - c.x, y - c.y) < c.r * 1.05) doClick(x, y);
    },

    floatText(x, y, text) {
      this.particles.push({ kind: "text", x, y, vx: (Math.random() - 0.5) * 20, vy: -60, life: 1.1, max: 1.1, text });
    },
    burst(x, y, icon, n) {
      if (this.reduced) return;
      for (let k = 0; k < n; k++) {
        const a = Math.random() * Math.PI * 2, sp = 80 + Math.random() * 140;
        this.particles.push({ kind: "icon", x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 80, life: 0.9, max: 0.9, icon, size: 14 + Math.random() * 8 });
      }
      if (this.particles.length > 240) this.particles.splice(0, this.particles.length - 240);
    },

    update(dt, now) {
      this.t += dt;
      this.press = Math.max(0, this.press - dt * 6);
      for (const c of this.clouds) c.x = (c.x + c.v * dt) % 1.15;

      for (const w of this.walkers) {
        if (w.pause > 0) { w.pause -= dt; continue; }
        w.x += w.dir * w.speed * dt;
        w.phase += dt * 8;
        if (w.x < 0.02 || w.x > 0.98) { w.dir *= -1; w.x = Math.min(0.98, Math.max(0.02, w.x)); }
        if (Math.random() < dt * 0.15) { w.pause = 0.6 + Math.random() * 1.2; w.dir = Math.random() < 0.5 ? -1 : 1; }
        if (!this.reduced && Math.random() < dt * 0.06) {
          const p = this.groundPos(w.x, w.depth, 0);
          this.particles.push({ kind: "icon", x: p.x, y: p.y - p.s, vx: 0, vy: -40, life: 1, max: 1, icon: K.currency.icon, size: 12, float: true });
        }
      }

      for (const p of this.particles) {
        p.life -= dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        if (p.kind === "icon" && !p.float) p.vy += 400 * dt;
      }
      this.particles = this.particles.filter((p) => p.life > 0);

      // Weather
      const wx = season().weather;
      if (wx && !this.reduced && this.weather.length < 70 && Math.random() < dt * (wx === "snow" ? 30 : 6)) {
        this.weather.push({ x: Math.random() * this.w, y: -10, vx: wx === "snow" ? 0 : 20 + Math.random() * 20, vy: 25 + Math.random() * 30, r: 1.5 + Math.random() * 2.5, sway: Math.random() * 6, kind: wx });
      }
      for (const f of this.weather) {
        f.y += f.vy * dt;
        f.x += (f.vx + Math.sin(this.t + f.sway) * 12) * dt;
      }
      this.weather = this.weather.filter((f) => f.y < this.h + 10);

      // Clover
      if (!this.golden && now > this.nextGolden) {
        this.golden = { x: 0.12 + Math.random() * 0.76, y: 0.12 + Math.random() * 0.45, born: now, life: 13000 };
        this.nextGolden = now + (60000 + Math.random() * 90000) / cloverRate();
      }
      if (this.golden && now - this.golden.born > this.golden.life) this.golden = null;

      // Bandits
      if (!this.raid && now > this.nextRaid) {
        if (totalOwned() >= RAID_MIN_WORKERS) this.startRaid();
        this.nextRaid = now + 150000 + Math.random() * 150000;
      }
      if (this.raid) {
        for (const b of this.raid) {
          if (b.state === "run") {
            b.x -= b.speed * dt;
            b.phase += dt * 12;
            if (b.x < -0.04) {
              b.state = "gone";
              this.raidStolen += banditEscaped();
              this.raidEscaped++;
            }
          } else if (b.state === "down") {
            b.fade -= dt * 1.5;
          }
        }
        if (this.raid.every((b) => b.state === "gone" || (b.state === "down" && b.fade <= 0))) {
          const caught = this.raid.filter((b) => b.state === "down").length;
          const esc = this.raidEscaped, s = esc > 1 ? "s" : "";
          if (!esc) toast(`🛡️ All ${caught} bandits caught. The realm is safe.`);
          else if (this.raidStolen > 0) toast(`🥷 ${esc} bandit${s} escaped with ${fmt(this.raidStolen)} gold. More Knights means less stolen.`);
          else toast(`🚪 ${esc} bandit${s} escaped, but the Iron Gates kept your gold safe.`);
          this.raid = null;
        }
      }
    },

    groundPos(x, depth, bob) {
      const gy = this.groundY();
      const s = (0.05 + depth * 0.025) * Math.min(this.h, this.w * 1.1) + 6;
      const y = gy + s * 0.5 + depth * Math.max(0, this.h - this.pad - gy - s);
      return { x: 16 + x * (this.w - 32), y: y - bob, s };
    },

    emoji(icon, x, y, size, alpha = 1, flip = false) {
      const c = this.ctx;
      c.globalAlpha = alpha;
      c.fillStyle = "#000"; // color glyphs inherit fillStyle's alpha
      c.font = `${size}px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif`;
      c.textAlign = "center";
      c.textBaseline = "middle";
      if (flip) {
        c.save(); c.translate(x, y); c.scale(-1, 1); c.fillText(icon, 0, 0); c.restore();
      } else c.fillText(icon, x, y);
      c.globalAlpha = 1;
    },

    shadow(x, y, s) {
      const c = this.ctx;
      c.fillStyle = "rgba(0,0,0,0.18)";
      c.beginPath();
      c.ellipse(x, y + s * 0.45, s * 0.38, s * 0.12, 0, 0, Math.PI * 2);
      c.fill();
    },

    draw(now) {
      const c = this.ctx, w = this.w, h = this.h, se = season();
      if (!w || !h) return;
      const gy = this.groundY();

      const sky = c.createLinearGradient(0, 0, 0, gy);
      sky.addColorStop(0, se.sky[0]);
      sky.addColorStop(1, se.sky[1]);
      c.fillStyle = sky;
      c.fillRect(0, 0, w, gy + 2);

      c.fillStyle = seasonIndex() === 3 ? "rgba(255,255,255,0.7)" : "rgba(255,236,160,0.9)";
      c.beginPath();
      c.arc(w * 0.87, h * 0.1, Math.min(w, h) * 0.045, 0, Math.PI * 2);
      c.fill();
      for (const cl of this.clouds) this.emoji("☁️", cl.x * (w + 100) - 50, cl.y * h, 26 * cl.s, 0.9);

      // Skyline grows with your settlement; trees follow the season.
      const skyline = K.ranks[rankIndex()].skyline;
      const dsz = Math.max(26, Math.min(w / (skyline.length + 1), h * 0.11));
      skyline.forEach((d, k) => {
        const icon = d === "🌳" || d === "🌲" ? se.tree : d;
        this.emoji(icon, (k + 0.5) * (w / skyline.length), gy - dsz * 0.42, dsz);
      });

      const gr = c.createLinearGradient(0, gy, 0, h);
      gr.addColorStop(0, se.ground[0]);
      gr.addColorStop(1, se.ground[1]);
      c.fillStyle = gr;
      c.fillRect(0, gy, w, h - gy);

      // Money bag: rays, halo, icon.
      const ctr = this.center();
      const pulse = this.reduced ? 1 : 1 + Math.sin(this.t * 2) * 0.03;
      const scale = pulse * (1 - this.press * 0.08);
      if (!this.reduced) {
        c.save();
        c.translate(ctr.x, ctr.y);
        c.rotate(this.t * 0.25);
        c.fillStyle = "rgba(255,214,90,0.28)";
        for (let k = 0; k < 12; k++) {
          c.rotate(Math.PI / 6);
          c.beginPath();
          c.moveTo(0, 0);
          c.lineTo(ctr.r * 1.6, -ctr.r * 0.16);
          c.lineTo(ctr.r * 1.6, ctr.r * 0.16);
          c.closePath();
          c.fill();
        }
        c.restore();
      }
      const halo = c.createRadialGradient(ctr.x, ctr.y, ctr.r * 0.2, ctr.x, ctr.y, ctr.r * 1.2);
      halo.addColorStop(0, "rgba(255,250,220,0.65)");
      halo.addColorStop(1, "rgba(255,250,220,0)");
      c.fillStyle = halo;
      c.beginPath();
      c.arc(ctr.x, ctr.y, ctr.r * 1.2, 0, Math.PI * 2);
      c.fill();
      this.emoji(K.clicker.icon, ctr.x, ctr.y + ctr.r * 0.08, ctr.r * 1.5 * scale);

      // Workers and bandits share the ground, drawn back to front.
      const sprites = this.walkers.map((wk) => ({ depth: wk.depth, draw: () => {
        const p = this.groundPos(wk.x, wk.depth, wk.pause > 0 ? 0 : Math.abs(Math.sin(wk.phase)) * 4);
        this.shadow(p.x, p.y, p.s);
        this.emoji(P[wk.prof].icon, p.x, p.y, p.s, 1, wk.dir > 0);
      } }));
      if (this.raid) {
        for (const b of this.raid) {
          if (b.state === "gone" || b.fade <= 0) continue;
          sprites.push({ depth: b.depth, draw: () => {
            const run = b.state === "run";
            const p = this.groundPos(b.x, b.depth, run ? Math.abs(Math.sin(b.phase)) * 6 : 0);
            this.shadow(p.x, p.y, p.s);
            if (run) {
              c.fillStyle = "rgba(200,30,20,0.28)";
              c.beginPath();
              c.arc(p.x, p.y, p.s * 0.75, 0, Math.PI * 2);
              c.fill();
              this.emoji("💰", p.x + p.s * 0.35, p.y + p.s * 0.2, p.s * 0.45);
            }
            this.emoji(run ? K.bandit.icon : "😵", p.x, p.y, p.s * 1.05, run ? 1 : Math.max(0, b.fade));
          } });
        }
      }
      sprites.sort((a, b) => a.depth - b.depth).forEach((s) => s.draw());

      for (const f of this.weather) {
        if (f.kind === "snow") {
          c.fillStyle = "rgba(255,255,255,0.9)";
          c.beginPath();
          c.arc(f.x, f.y, f.r, 0, Math.PI * 2);
          c.fill();
        } else {
          this.emoji(f.kind === "petals" ? "🌸" : "🍂", f.x, f.y, 8 + f.r * 2, 0.85);
        }
      }

      if (this.golden) {
        const g = this.golden;
        const age = (now - g.born) / g.life;
        const a = age < 0.1 ? age / 0.1 : age > 0.8 ? (1 - age) / 0.2 : 1;
        const gx = g.x * w, gyy = g.y * h + Math.sin(this.t * 3) * 6;
        const gl = c.createRadialGradient(gx, gyy, 2, gx, gyy, 42);
        gl.addColorStop(0, `rgba(255,236,140,${0.85 * a})`);
        gl.addColorStop(1, "rgba(255,236,140,0)");
        c.fillStyle = gl;
        c.beginPath();
        c.arc(gx, gyy, 42, 0, Math.PI * 2);
        c.fill();
        this.emoji(K.golden.icon, gx, gyy, 38 + Math.sin(this.t * 6) * 3, a);
      }

      for (const p of this.particles) {
        const a = Math.max(0, p.life / p.max);
        if (p.kind === "icon") this.emoji(p.icon, p.x, p.y, p.size, a);
        else {
          c.globalAlpha = a;
          c.font = `22px "Lilita One", "Arial Rounded MT Bold", sans-serif`;
          c.textAlign = "center";
          c.lineWidth = 4;
          c.strokeStyle = "rgba(0,0,0,0.45)";
          c.strokeText(p.text, p.x, p.y);
          c.fillStyle = "#fff";
          c.fillText(p.text, p.x, p.y);
          c.globalAlpha = 1;
        }
      }
    }
  };

  // ---------- Shop UI ----------
  let rows = [];
  function buildShop() {
    const list = $("#professions");
    list.innerHTML = "";
    rows = P.map((p, i) => {
      const btn = document.createElement("button");
      btn.className = "prof";
      btn.id = `prof-${i}`;
      btn.innerHTML = `
        <span class="prof-icon" aria-hidden="true"></span>
        <span class="prof-body">
          <span class="prof-name"></span>
          <span class="prof-desc"></span>
          <span class="prof-meta"></span>
        </span>
        <span class="prof-side">
          <span class="prof-owned"></span>
          <span class="prof-cost"></span>
        </span>`;
      btn.addEventListener("click", () => buyProfession(i));
      list.appendChild(btn);
      return {
        btn, icon: btn.querySelector(".prof-icon"), name: btn.querySelector(".prof-name"),
        desc: btn.querySelector(".prof-desc"), meta: btn.querySelector(".prof-meta"),
        owned: btn.querySelector(".prof-owned"), cost: btn.querySelector(".prof-cost"), state: ""
      };
    });
  }

  let lastUpgradeKey = "";
  function renderShop(force) {
    $("#money").textContent = fmt(S.money);
    $("#cps").textContent = `${fmt(cps())} gold per second · ${fmt(clickValue())} per click`;

    // Realm title, season and rank progress.
    const r = rankIndex();
    $("#realm-title").textContent = `${K.ranks[r].name} of ${S.name}`;
    const se = season();
    const left = K.seasonLength - (S.playTime % K.seasonLength);
    $("#season").textContent = `${se.icon} ${se.name} · ${Math.ceil(left)}s`;
    $("#season").title = se.blurb;
    $("#season-blurb").textContent = se.blurb;
    const next = K.ranks[r + 1];
    if (next) {
      const w = totalOwned(), from = K.ranks[r].workers;
      $("#rank-progress").hidden = false;
      $("#rank-label").textContent = `${w} / ${next.workers} workers to become a ${next.name} (+${pct(next.bonus)} income)`;
      $("#rank-fill").style.width = `${Math.min(100, ((w - from) / (next.workers - from)) * 100)}%`;
    } else $("#rank-progress").hidden = true;

    // Profession rows: revealed, mystery (the next one), or hidden.
    let mysteryShown = false;
    rows.forEach((row, i) => {
      const p = P[i];
      const revealed = i === 0 || S.owned[i] > 0 || S.allEarned >= p.cost * 0.6;
      const state = revealed ? "open" : mysteryShown ? "hidden" : "mystery";
      if (!revealed && !mysteryShown) mysteryShown = true;
      if (state !== row.state || force) {
        row.state = state;
        row.btn.hidden = state === "hidden";
        row.btn.classList.toggle("mystery", state === "mystery");
        row.icon.textContent = state === "open" ? p.icon : "❔";
        row.name.textContent = state === "open" ? p.name : "Unknown profession";
        row.desc.textContent = state === "open" ? p.desc : `Earn ${fmt(p.cost * 0.6)} gold in total to reveal.`;
      }
      if (state === "hidden") return;
      const n = plannedAmount(i);
      const cost = costOf(i, n);
      row.owned.textContent = S.owned[i] || "";
      row.cost.textContent = `${K.currency.icon} ${fmt(cost)}${n > 1 ? ` · ×${n}` : ""}`;
      if (state === "open") {
        const total = S.owned[i] * profRate(i);
        const base = cpsBase();
        const sm = seasonMult(i);
        const tag = sm !== 1 ? ` · ${se.icon} ×${sm}` : "";
        row.meta.textContent = `${fmt(profRate(i))}/s each${S.owned[i] ? ` · ${fmt(total)}/s total${base ? ` (${pct(total / base)})` : ""}` : ""}${tag}`;
        row.meta.classList.toggle("penalty", sm < 1);
      } else row.meta.textContent = "";
      row.btn.disabled = state !== "open";
      row.btn.classList.toggle("afford", state === "open" && S.money >= cost);
    });

    // Upgrade tiles: rebuild only when the available set changes.
    const avail = upgrades.filter((u) => !has(u.id) && u.unlocked());
    const key = avail.map((u) => u.id).join(",");
    const box = $("#upgrades");
    if (key !== lastUpgradeKey || force) {
      lastUpgradeKey = key;
      box.innerHTML = avail.length ? "" : `<p class="empty">Upgrades appear here as your workforce grows.</p>`;
      avail.forEach((u) => {
        const b = document.createElement("button");
        b.className = "up";
        b.dataset.id = u.id;
        b.setAttribute("aria-label", `${u.name}: ${u.desc} Costs ${fmt(u.cost)} gold`);
        b.innerHTML = `<span class="up-icon" aria-hidden="true">${u.icon}</span><span class="up-tier">${u.badge}</span>`;
        const show = () => showUpgradeInfo(u);
        b.addEventListener("pointerenter", show);
        b.addEventListener("focus", show);
        b.addEventListener("pointerleave", () => showUpgradeInfo(null));
        b.addEventListener("click", () => buyUpgrade(u.id));
        box.appendChild(b);
      });
      $("#upgrade-count").textContent = avail.length ? `${avail.length} available` : "";
      showUpgradeInfo(null);
    }
    box.querySelectorAll(".up").forEach((b) => {
      const u = upgrades.find((x) => x.id === b.dataset.id);
      b.classList.toggle("afford", S.money >= u.cost);
    });

    const now = performance.now();
    $("#buffs").innerHTML = buffs.map((b) => `<span class="buff">${b.icon} ${b.name} ×${b.mult} <b>${Math.ceil((b.until - now) / 1000)}s</b></span>`).join("");

    const g = charterGain();
    const cb = $("#open-charters");
    cb.classList.toggle("ready", g >= 1 || K.perks.some((p) => !perk(p.id) && chartersFree() >= p.cost));
    cb.textContent = g >= 1 ? `👑 +${fmt(g)} Charters` : "👑 Charters";
    $("#mute").textContent = S.muted ? "🔇" : "🔊";
    $("#mute").setAttribute("aria-label", S.muted ? "Turn sound on" : "Turn sound off");
  }

  function showUpgradeInfo(u) {
    $("#upgrade-info").innerHTML = u
      ? `<b>${esc(u.name)}</b> · ${K.currency.icon} ${fmt(u.cost)}<br><span class="muted">${esc(u.desc)}</span>`
      : `<span class="muted">Hover an upgrade to see what it does. Click to buy.</span>`;
  }

  // ---------- Modals ----------
  function openModal(html, label) {
    $("#modal-body").innerHTML = html;
    $("#modal-sheet").setAttribute("aria-label", label);
    $("#modal").hidden = false;
    $("#modal-close").focus();
  }
  function closeModal() { $("#modal").hidden = true; }

  function openRealm() {
    const got = achievements.filter((a) => S.ach.includes(a.id)).length;
    const r = rankIndex();
    openModal(`
      <h2>The Realm</h2>
      <label class="field" for="realm-name">Name your realm
        <input id="realm-name" maxlength="24" value="${esc(S.name)}" autocomplete="off">
      </label>
      <dl class="stats">
        <dt>Settlement</dt><dd>${K.ranks[r].name} (+${pct(K.ranks[r].bonus)} income)</dd>
        <dt>Season</dt><dd>${season().icon} ${season().name}</dd>
        <dt>Gold this dynasty</dt><dd>🪙 ${fmt(S.runEarned)}</dd>
        <dt>Gold all time</dt><dd>🪙 ${fmt(S.allEarned)}</dd>
        <dt>Income</dt><dd>${fmt(cps())}/s</dd>
        <dt>Per click</dt><dd>${fmt(clickValue())}</dd>
        <dt>Kingdom multiplier</dt><dd>×${globalMult().toFixed(2)}</dd>
        <dt>Taxes collected</dt><dd>${fmt(S.clicks)}</dd>
        <dt>Workers</dt><dd>${fmt(totalOwned())}</dd>
        <dt>Clovers caught</dt><dd>${S.golden}</dd>
        <dt>Bandits defeated</dt><dd>${S.bandits}</dd>
        <dt>Time on the throne</dt><dd>${fmtTime(S.playTime)}</dd>
      </dl>
      <h3>🏆 Achievements · ${got}/${achievements.length}</h3>
      <p class="muted">Each achievement adds +1% to all income. Hover one to read it.</p>
      <div class="ach-grid">${achievements.map((a) => {
        const own = S.ach.includes(a.id);
        const t = esc(own ? a.name : "Locked: " + a.name);
        return `<span class="ach ${own ? "got" : ""}" title="${t}" aria-label="${t}">${own ? a.icon : "?"}</span>`;
      }).join("")}</div>
      <h3>Save</h3>
      <div class="confirm-row" id="wipe-row"><button class="btn ghost" id="wipe-btn">Erase save</button></div>
    `, "The realm");
    $("#realm-name").addEventListener("input", (e) => {
      S.name = e.target.value.trim().slice(0, 24) || "Oakhollow";
      renderShop(false);
    });
    $("#wipe-btn").addEventListener("click", () => confirmInline("#wipe-row", "Erase your whole kingdom, charters and all? This can't be undone.", wipe, openRealm));
  }

  function openCharters() {
    const g = charterGain();
    const next = Math.pow(chartersPossible() + 1, 3) * 1e9;
    const free = chartersFree();
    openModal(`
      <h2>👑 Royal Charters</h2>
      <p>You have earned <b>${fmt(S.charters)}</b> Royal Charters. Each one adds +2% to all income forever (now +${fmt(S.charters * 2)}%).
      Spend them on royal perks below. Spending doesn't reduce the +2% bonus.</p>
      <p class="muted">Charters come from all the gold you've ever earned. The next one comes at ${fmt(next)} gold in total.</p>
      <div class="confirm-row" id="prestige-row">
        <button class="btn primary" id="prestige-btn" ${g < 1 ? "disabled" : ""}>${g >= 1 ? `Found a new dynasty for +${fmt(g)}` : "Not enough gold for a new charter yet"}</button>
      </div>
      <p class="muted small">A new dynasty resets your gold, workers and upgrades. You keep charters, perks, achievements and stats.</p>
      <h3>Royal perks · ${fmt(free)} charter${free === 1 ? "" : "s"} to spend</h3>
      <div class="perk-grid">${K.perks.map((p) => {
        const owned = perk(p.id);
        const can = !owned && free >= p.cost;
        return `<div class="perk ${owned ? "owned" : ""}">
          <span class="perk-icon" aria-hidden="true">${p.icon}</span>
          <span class="perk-body"><b>${p.name}</b><span class="muted">${p.desc}</span></span>
          <button class="btn ${can ? "primary" : ""}" data-perk="${p.id}" ${can ? "" : "disabled"}>${owned ? "Granted" : `${p.cost} 📜`}</button>
        </div>`;
      }).join("")}</div>
    `, "Royal charters");
    $("#prestige-btn").addEventListener("click", () => confirmInline("#prestige-row", `Start a new dynasty for +${fmt(g)} Royal Charters?`, doPrestige, openCharters));
    document.querySelectorAll("[data-perk]").forEach((b) => b.addEventListener("click", () => buyPerk(b.dataset.perk)));
  }

  function confirmInline(rowSel, question, action, back) {
    const row = $(rowSel);
    row.innerHTML = `<span>${question}</span><button class="btn primary" data-yes>Yes</button><button class="btn ghost" data-no>Cancel</button>`;
    row.querySelector("[data-yes]").addEventListener("click", action);
    row.querySelector("[data-no]").addEventListener("click", back);
  }

  function wipe() {
    store.del(SAVE_KEY);
    store.del(LEGACY_KEY);
    S = freshState();
    buffs = [];
    lastRank = 0;
    world.reset();
    closeModal();
    renderShop(true);
    toast("Save erased. A humble hamlet once more.");
  }

  // ---------- Loop ----------
  let last = performance.now(), uiTimer = 0, achTimer = 0, saveTimer = 0, newsTimer = 0, lastSeason = -1;
  function frame(now) {
    const dt = Math.max(0, Math.min(0.25, (now - last) / 1000)); // rAF time can trail performance.now()
    last = now;
    earn(cps() * dt);
    S.playTime += dt;
    buffs = buffs.filter((b) => b.until > now);
    world.update(dt, now);
    world.draw(now);
    uiTimer += dt; achTimer += dt; saveTimer += dt; newsTimer += dt;
    if (uiTimer > 0.1) { uiTimer = 0; renderShop(false); }
    if (achTimer > 1) {
      achTimer = 0;
      checkAchievements();
      checkRank();
      const si = seasonIndex();
      if (si !== lastSeason) {
        if (lastSeason !== -1) toast(`${season().icon} ${season().name} arrives. ${season().blurb}`);
        lastSeason = si;
      }
    }
    if (newsTimer > 11) { newsTimer = 0; nextChronicle(); }
    if (saveTimer > 10) { saveTimer = 0; save(); }
    requestAnimationFrame(frame);
  }

  // ---------- Boot ----------
  function start(data) {
    S = (data && data.state) || load() || freshState();
    S.owned = Array.from({ length: N }, (_, i) => S.owned[i] || 0);
    buildUpgrades();
    buildAchievements();
    buildShop();
    world.init();
    world.reset();
    lastRank = rankIndex();

    document.querySelectorAll("[data-amt]").forEach((b) => b.addEventListener("click", () => {
      buyAmount = b.dataset.amt === "max" ? "max" : +b.dataset.amt;
      document.querySelectorAll("[data-amt]").forEach((x) => x.setAttribute("aria-pressed", x === b ? "true" : "false"));
      renderShop(true);
    }));
    $("#open-realm").addEventListener("click", openRealm);
    $("#open-charters").addEventListener("click", openCharters);
    $("#mute").addEventListener("click", () => { S.muted = !S.muted; renderShop(false); });
    $("#modal-close").addEventListener("click", closeModal);
    $("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") closeModal(); });
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeModal(); });
    window.addEventListener("beforeunload", save);
    document.addEventListener("visibilitychange", () => { if (document.hidden) save(); });
    window.claude?.hot?.snapshot?.(() => ({ state: S }));

    renderShop(true);
    const away = (Date.now() - S.saved) / 1000;
    if (!data?.state && away > 60 && cpsBase() > 0) {
      const gain = cpsBase() * Math.min(away, OFFLINE_CAP) * (perk("memory") ? 1 : 0.5);
      earn(gain);
      toast(`While you were away (${fmtTime(Math.min(away, OFFLINE_CAP))}), your workers earned ${fmt(gain)} gold`);
    }
    nextChronicle();
    save();
    requestAnimationFrame(frame);
  }

  window.claude?.hot?.ready ? window.claude.hot.ready(start) : start(window.claude?.hot?.data ?? {});
})();
