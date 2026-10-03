(() => {
  "use strict";

  // ---------- Economy (shared by every theme) ----------
  const BASE_COST = [15, 100, 1100, 12e3, 13e4, 1.4e6, 2e7, 3.3e8, 5.1e9, 7.5e10, 1e12, 1.4e13];
  const BASE_RATE = [0.1, 1, 8, 47, 260, 1400, 7800, 44e3, 26e4, 1.6e6, 1e7, 6.5e7];
  const PRICE_GROWTH = 1.15;
  const TIER_OWNED = [1, 10, 25, 50, 100];
  const TIER_COST = [10, 50, 500, 5e4, 5e6];
  const CLICK_COST = [100, 1e4, 1e6, 1e8, 1e10];
  const CLICK_DESC = ["Clicks are twice as strong.", "Clicks are twice as strong.", "Clicks also earn 1% of your income per second.", "Clicks also earn 2% of your income per second.", "Clicks also earn 5% of your income per second."];
  const ROMAN = ["I", "II", "III", "IV", "V"];
  const PRESTIGE_BONUS = 0.02;
  const ACH_BONUS = 0.01;
  const OFFLINE_RATE = 0.5;
  const OFFLINE_CAP = 8 * 3600;
  const STORE_PREFIX = "profession-clicker:";

  const $ = (sel) => document.querySelector(sel);
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* storage unavailable */ } },
    del(k) { try { localStorage.removeItem(k); } catch { /* storage unavailable */ } }
  };

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

  // ---------- State ----------
  let theme = null;
  let S = null;
  let buffs = [];
  let buyAmount = 1;
  let upgrades = [];
  let achievements = [];
  let previewing = false;

  function freshState() {
    return { v: 1, money: 0, runEarned: 0, allEarned: 0, clicks: 0, owned: Array(12).fill(0), ups: [], prestige: 0, golden: 0, ach: [], playTime: 0, saved: Date.now() };
  }

  function save() {
    if (!S || previewing) return;
    S.saved = Date.now();
    store.set(STORE_PREFIX + theme.id, JSON.stringify(S));
    store.set(STORE_PREFIX + "last", theme.id);
  }

  function load(id) {
    const raw = store.get(STORE_PREFIX + id);
    if (!raw) return null;
    try {
      const s = Object.assign(freshState(), JSON.parse(raw));
      s.owned = Array.from({ length: 12 }, (_, i) => s.owned[i] || 0);
      return s;
    } catch { return null; }
  }

  // ---------- Upgrades & achievements (generated per theme) ----------
  function buildUpgrades() {
    upgrades = [];
    theme.professions.forEach((p, i) => {
      TIER_OWNED.forEach((need, t) => {
        upgrades.push({
          id: `p${i}t${t}`, kind: "prof", prof: i, tier: t, icon: p.icon,
          name: `${theme.tiers[t]} (${p.name})`,
          desc: `${p.name}s are twice as productive. Unlocks at ${need} owned.`,
          cost: BASE_COST[i] * TIER_COST[t],
          unlocked: () => S.owned[i] >= need
        });
      });
    });
    theme.clickTiers.forEach((name, t) => {
      upgrades.push({
        id: `c${t}`, kind: "click", tier: t, icon: theme.clicker.icon, name,
        desc: CLICK_DESC[t], cost: CLICK_COST[t],
        unlocked: () => S.runEarned >= CLICK_COST[t] * 0.3
      });
    });
    upgrades.sort((a, b) => a.cost - b.cost);
  }

  function buildAchievements() {
    const cur = theme.currency;
    achievements = [];
    [1e2, 1e4, 1e6, 1e8, 1e10, 1e12, 1e15, 1e18, 1e21].forEach((n) =>
      achievements.push({ id: `e${n}`, icon: cur.icon, name: `Earn ${fmt(n)} ${cur.name}`, test: () => S.allEarned >= n }));
    [100, 1000, 5000, 20000].forEach((n) =>
      achievements.push({ id: `k${n}`, icon: theme.clicker.icon, name: `${theme.clicker.label} ${fmt(n)} times`, test: () => S.clicks >= n }));
    [10, 1e3, 1e5, 1e7, 1e9].forEach((n) =>
      achievements.push({ id: `r${n}`, icon: "⚡", name: `Make ${fmt(n)} ${cur.name} per second`, test: () => cpsBase() >= n }));
    [10, 100, 250, 500].forEach((n) =>
      achievements.push({ id: `t${n}`, icon: "👥", name: `Employ ${n} workers`, test: () => totalOwned() >= n }));
    theme.professions.forEach((p, i) => {
      achievements.push({ id: `h${i}`, icon: p.icon, name: `Hire your first ${p.name}`, test: () => S.owned[i] >= 1 });
      achievements.push({ id: `g${i}`, icon: p.icon, name: `${p.name} Guild: own 50`, test: () => S.owned[i] >= 50 });
    });
    [1, 10, 30].forEach((n) =>
      achievements.push({ id: `l${n}`, icon: theme.golden.icon, name: `Catch ${n} ${theme.golden.name}${n > 1 ? "s" : ""}`, test: () => S.golden >= n }));
    achievements.push({ id: "p1", icon: "🌟", name: `Earn your first ${theme.prestige.name.replace(/s$/, "")}`, test: () => S.prestige >= 1 });
  }

  const has = (id) => S.ups.includes(id);
  const totalOwned = () => S.owned.reduce((a, b) => a + b, 0);
  const buffMult = (type) => buffs.filter((b) => b.type === type).reduce((m, b) => m * b.mult, 1);
  const globalMult = () => (1 + PRESTIGE_BONUS * S.prestige) * (1 + ACH_BONUS * S.ach.length);

  function profMult(i) {
    let m = 1;
    for (let t = 0; t < 5; t++) if (has(`p${i}t${t}`)) m *= 2;
    return m;
  }
  const profRate = (i) => BASE_RATE[i] * profMult(i) * globalMult();
  function cpsBase() {
    let c = 0;
    for (let i = 0; i < 12; i++) c += S.owned[i] * profRate(i);
    return c;
  }
  const cps = () => cpsBase() * buffMult("prod");
  function clickValue() {
    let base = 1;
    if (has("c0")) base *= 2;
    if (has("c1")) base *= 2;
    let pct = 0;
    if (has("c2")) pct += 0.01;
    if (has("c3")) pct += 0.02;
    if (has("c4")) pct += 0.05;
    return (base * globalMult() + cps() * pct) * buffMult("click");
  }

  const unitCost = (i) => BASE_COST[i] * Math.pow(PRICE_GROWTH, S.owned[i]);
  const costOf = (i, n) => Math.ceil(unitCost(i) * (Math.pow(PRICE_GROWTH, n) - 1) / (PRICE_GROWTH - 1));
  function maxAffordable(i) {
    return Math.max(0, Math.floor(Math.log(S.money * (PRICE_GROWTH - 1) / unitCost(i) + 1) / Math.log(PRICE_GROWTH)));
  }
  function plannedAmount(i) {
    if (buyAmount !== "max") return buyAmount;
    return Math.max(1, maxAffordable(i));
  }

  const prestigeTotal = () => Math.floor(Math.cbrt(S.allEarned / 1e9));
  const prestigeGain = () => Math.max(0, prestigeTotal() - S.prestige);

  function earn(n) {
    S.money += n;
    S.runEarned += n;
    S.allEarned += n;
  }

  // ---------- Actions ----------
  function doClick(x, y) {
    const v = clickValue();
    earn(v);
    S.clicks++;
    world.press = 1;
    world.floatText(x, y, "+" + fmt(v), true);
    world.burst(x, y, theme.currency.icon, 5);
  }

  function buyProfession(i) {
    const n = plannedAmount(i);
    const c = costOf(i, n);
    if (S.money < c) return;
    S.money -= c;
    S.owned[i] += n;
    world.syncWalkers();
    renderShop(true);
  }

  function buyUpgrade(id) {
    const u = upgrades.find((x) => x.id === id);
    if (!u || has(id) || S.money < u.cost) return;
    S.money -= u.cost;
    S.ups.push(id);
    toast(`${u.icon} ${u.name} bought`);
    renderShop(true);
  }

  function catchGolden() {
    S.golden++;
    const roll = Math.random();
    const label = theme.golden.name;
    if (roll < 0.45) {
      const gain = Math.min(S.money * 0.15, cps() * 900) + 13 + clickValue() * 20;
      earn(gain);
      toast(`${theme.golden.icon} ${label}! Windfall of ${fmt(gain)} ${theme.currency.name}`);
    } else if (roll < 0.85) {
      buffs.push({ type: "prod", mult: 7, until: performance.now() + 30000, dur: 30000, name: "Frenzy", icon: "🔥" });
      toast(`${theme.golden.icon} ${label}! Frenzy: income x7 for 30s`);
    } else {
      buffs.push({ type: "click", mult: 25, until: performance.now() + 15000, dur: 15000, name: "Click storm", icon: "⚡" });
      toast(`${theme.golden.icon} ${label}! Click storm: clicks x25 for 15s`);
    }
  }

  function doPrestige() {
    const gain = prestigeGain();
    if (gain < 1) return;
    S.prestige += gain;
    S.money = 0;
    S.runEarned = 0;
    S.owned = Array(12).fill(0);
    S.ups = [];
    buffs = [];
    world.syncWalkers();
    closeModal();
    toast(`🌟 +${fmt(gain)} ${theme.prestige.name}. All income now +${fmt(S.prestige * PRESTIGE_BONUS * 100)}%`);
    save();
    renderShop(true);
  }

  function checkAchievements() {
    for (const a of achievements) {
      if (!S.ach.includes(a.id) && a.test()) {
        S.ach.push(a.id);
        toast(`🏆 Achievement: ${a.name} (+1% income)`);
      }
    }
  }

  // ---------- Toasts ----------
  function toast(text) {
    const el = document.createElement("div");
    el.className = "toast";
    el.textContent = text;
    $("#toasts").appendChild(el);
    setTimeout(() => el.classList.add("out"), 3000);
    setTimeout(() => el.remove(), 3500);
    const all = $("#toasts").children;
    if (all.length > 3) all[0].remove();
  }

  // ---------- World (canvas) ----------
  const world = {
    canvas: null, ctx: null, w: 0, h: 0, dpr: 1,
    walkers: [], particles: [], skyBits: [], golden: null, nextGolden: 0,
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
      this.dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.w = box.width;
      this.h = box.height;
      this.canvas.width = Math.round(this.w * this.dpr);
      this.canvas.height = Math.round(this.h * this.dpr);
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    },

    reset() {
      this.walkers = [];
      this.particles = [];
      this.golden = null;
      this.nextGolden = performance.now() + 45000 + Math.random() * 60000;
      this.skyBits = Array.from({ length: 7 }, (_, k) => ({
        icon: theme.sky[k % theme.sky.length], x: Math.random(), y: 0.05 + Math.random() * 0.3,
        s: 0.6 + Math.random() * 0.6, v: 0.004 + Math.random() * 0.01
      }));
      this.syncWalkers();
    },

    groundY() { return this.h * 0.68; },
    center() {
      const r = Math.min(this.w * 0.22, this.h * 0.2);
      return { x: this.w / 2, y: this.h * 0.36, r };
    },

    syncWalkers() {
      const want = [];
      for (let i = 11; i >= 0; i--) {
        const n = Math.min(S.owned[i], 4);
        for (let k = 0; k < n; k++) want.push(i);
      }
      const target = want.slice(0, 40);
      const counts = {};
      target.forEach((i) => (counts[i] = (counts[i] || 0) + 1));
      const kept = [];
      const have = {};
      for (const w of this.walkers) {
        have[w.prof] = (have[w.prof] || 0) + 1;
        if (have[w.prof] <= (counts[w.prof] || 0)) kept.push(w);
      }
      const now = {};
      kept.forEach((w) => (now[w.prof] = (now[w.prof] || 0) + 1));
      for (const i in counts) {
        for (let k = now[i] || 0; k < counts[i]; k++) {
          kept.push({
            prof: +i, x: Math.random(), depth: Math.random(), dir: Math.random() < 0.5 ? -1 : 1,
            speed: 0.02 + Math.random() * 0.03, phase: Math.random() * 6.28, pause: 0
          });
        }
      }
      this.walkers = kept.sort((a, b) => a.depth - b.depth);
    },

    hit(x, y) {
      if (this.golden) {
        const g = this.golden;
        if (Math.hypot(x - g.x * this.w, y - g.y * this.h) < 34) {
          this.burst(g.x * this.w, g.y * this.h, theme.golden.icon, 10);
          this.golden = null;
          catchGolden();
          return;
        }
      }
      const c = this.center();
      if (Math.hypot(x - c.x, y - c.y) < c.r * 1.05) doClick(x, y);
    },

    floatText(x, y, text, big) {
      this.particles.push({ kind: "text", x, y, vx: (Math.random() - 0.5) * 20, vy: -60, life: 1.1, max: 1.1, text, big });
    },
    burst(x, y, icon, n) {
      if (this.reduced) return;
      for (let k = 0; k < n; k++) {
        const a = Math.random() * Math.PI * 2, sp = 80 + Math.random() * 140;
        this.particles.push({ kind: "icon", x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 80, life: 0.9, max: 0.9, icon, size: 14 + Math.random() * 8 });
      }
      if (this.particles.length > 220) this.particles.splice(0, this.particles.length - 220);
    },

    update(dt, now) {
      this.t += dt;
      this.press = Math.max(0, this.press - dt * 6);
      for (const b of this.skyBits) b.x = (b.x + b.v * dt) % 1.1;
      for (const w of this.walkers) {
        if (w.pause > 0) { w.pause -= dt; continue; }
        w.x += w.dir * w.speed * dt;
        w.phase += dt * 8;
        if (w.x < 0.02 || w.x > 0.98) { w.dir *= -1; w.x = Math.min(0.98, Math.max(0.02, w.x)); }
        if (Math.random() < dt * 0.15) { w.pause = 0.6 + Math.random() * 1.2; w.dir = Math.random() < 0.5 ? -1 : 1; }
        if (!this.reduced && Math.random() < dt * 0.08) {
          const p = this.walkerPos(w);
          this.particles.push({ kind: "icon", x: p.x, y: p.y - p.s, vx: 0, vy: -40, life: 1, max: 1, icon: theme.currency.icon, size: 12, float: true });
        }
      }
      for (const p of this.particles) {
        p.life -= dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        if (p.kind === "icon" && !p.float) p.vy += 400 * dt;
      }
      this.particles = this.particles.filter((p) => p.life > 0);

      if (!this.golden && now > this.nextGolden) {
        this.golden = { x: 0.12 + Math.random() * 0.76, y: 0.12 + Math.random() * 0.5, born: now, life: 13000 };
        this.nextGolden = now + 60000 + Math.random() * 90000;
      }
      if (this.golden && now - this.golden.born > this.golden.life) {
        this.golden = null;
      }
    },

    walkerPos(w) {
      const gy = this.groundY();
      const y = gy + 18 + w.depth * (this.h - gy - 30);
      const s = 24 + w.depth * 16 + Math.min(this.h, 600) * 0.03;
      const bob = w.pause > 0 ? 0 : Math.abs(Math.sin(w.phase)) * 4;
      return { x: 16 + w.x * (this.w - 32), y: y - bob, s };
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

    draw(now) {
      const c = this.ctx, w = this.w, h = this.h, col = theme.colors;
      if (!w || !h) return;
      const gy = this.groundY();

      const sky = c.createLinearGradient(0, 0, 0, gy);
      sky.addColorStop(0, col.sky1);
      sky.addColorStop(1, col.sky2);
      c.fillStyle = sky;
      c.fillRect(0, 0, w, gy + 2);

      for (const b of this.skyBits) this.emoji(b.icon, b.x * (w + 80) - 40, b.y * h, 18 * b.s + 6, 0.8);

      const dsz = Math.max(26, Math.min(w / 9, h * 0.11));
      theme.decor.forEach((d, k) => {
        const x = (k + 0.5) * (w / theme.decor.length);
        this.emoji(d, x, gy - dsz * 0.42, dsz, 0.95);
      });

      const gr = c.createLinearGradient(0, gy, 0, h);
      gr.addColorStop(0, col.ground);
      gr.addColorStop(1, col.ground2);
      c.fillStyle = gr;
      c.fillRect(0, gy, w, h - gy);

      // Clicker: halo, rotating rays, then the icon itself.
      const ctr = this.center();
      const pulse = this.reduced ? 1 : 1 + Math.sin(this.t * 2) * 0.03;
      const scale = pulse * (1 - this.press * 0.08);
      c.save();
      c.translate(ctr.x, ctr.y);
      if (!this.reduced) {
        c.rotate(this.t * 0.25);
        c.fillStyle = col.accent;
        c.globalAlpha = 0.16;
        for (let k = 0; k < 12; k++) {
          c.rotate(Math.PI / 6);
          c.beginPath();
          c.moveTo(0, 0);
          c.lineTo(ctr.r * 1.6, -ctr.r * 0.16);
          c.lineTo(ctr.r * 1.6, ctr.r * 0.16);
          c.closePath();
          c.fill();
        }
        c.globalAlpha = 1;
      }
      c.restore();
      const halo = c.createRadialGradient(ctr.x, ctr.y, ctr.r * 0.2, ctr.x, ctr.y, ctr.r * 1.2);
      halo.addColorStop(0, "rgba(255,255,255,0.55)");
      halo.addColorStop(1, "rgba(255,255,255,0)");
      c.fillStyle = halo;
      c.beginPath();
      c.arc(ctr.x, ctr.y, ctr.r * 1.2, 0, Math.PI * 2);
      c.fill();
      this.emoji(theme.clicker.icon, ctr.x, ctr.y + ctr.r * 0.08, ctr.r * 1.5 * scale);

      for (const wk of this.walkers) {
        const p = this.walkerPos(wk);
        c.fillStyle = "rgba(0,0,0,0.18)";
        c.beginPath();
        c.ellipse(p.x, p.y + p.s * 0.45, p.s * 0.38, p.s * 0.12, 0, 0, Math.PI * 2);
        c.fill();
        this.emoji(theme.professions[wk.prof].icon, p.x, p.y, p.s, 1, wk.dir > 0);
      }

      if (this.golden) {
        const g = this.golden;
        const age = (now - g.born) / g.life;
        const a = age < 0.1 ? age / 0.1 : age > 0.8 ? (1 - age) / 0.2 : 1;
        const gx = g.x * w, gyy = g.y * h + Math.sin(this.t * 3) * 6;
        const gl = c.createRadialGradient(gx, gyy, 2, gx, gyy, 40);
        gl.addColorStop(0, `rgba(255,236,140,${0.8 * a})`);
        gl.addColorStop(1, "rgba(255,236,140,0)");
        c.fillStyle = gl;
        c.beginPath();
        c.arc(gx, gyy, 40, 0, Math.PI * 2);
        c.fill();
        this.emoji(theme.golden.icon, gx, gyy, 38 + Math.sin(this.t * 6) * 3, a);
      }

      for (const p of this.particles) {
        const a = Math.max(0, p.life / p.max);
        if (p.kind === "icon") this.emoji(p.icon, p.x, p.y, p.size, a);
        else {
          c.globalAlpha = a;
          c.font = `${p.big ? 22 : 15}px "Lilita One", "Arial Rounded MT Bold", sans-serif`;
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
    rows = theme.professions.map((p, i) => {
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
    const cur = theme.currency;
    $("#money").textContent = fmt(S.money);
    $("#money-name").textContent = cur.name;
    $("#cps").textContent = `${fmt(cps())} ${cur.name} per second · ${fmt(clickValue())} per click`;

    // Profession rows: revealed, mystery (next one), or hidden.
    let mysteryShown = false;
    rows.forEach((r, i) => {
      const p = theme.professions[i];
      const revealed = S.owned[i] > 0 || S.allEarned >= BASE_COST[i] * 0.6 || i === 0;
      let state = revealed ? "open" : mysteryShown ? "hidden" : "mystery";
      if (!revealed && !mysteryShown) mysteryShown = true;
      if (state !== r.state || force) {
        r.state = state;
        r.btn.hidden = state === "hidden";
        r.btn.classList.toggle("mystery", state === "mystery");
        r.icon.textContent = state === "open" ? p.icon : "❔";
        r.name.textContent = state === "open" ? p.name : "Unknown profession";
        r.desc.textContent = state === "open" ? p.desc : `Earn ${fmt(BASE_COST[i] * 0.6)} ${cur.name} in total to reveal.`;
      }
      if (state === "hidden") return;
      const n = plannedAmount(i);
      const cost = costOf(i, n);
      r.owned.textContent = S.owned[i] ? S.owned[i] : "";
      r.cost.textContent = `${cur.icon} ${fmt(cost)}${n > 1 ? ` · ×${n}` : ""}`;
      const total = S.owned[i] * profRate(i);
      const base = cpsBase();
      r.meta.textContent = state === "open"
        ? `${fmt(profRate(i))}/s each${S.owned[i] ? ` · ${fmt(total)}/s total${base ? ` (${Math.round((total / base) * 100)}%)` : ""}` : ""}`
        : "";
      const ok = S.money >= cost && state === "open";
      r.btn.disabled = state !== "open";
      r.btn.classList.toggle("afford", ok);
    });

    // Upgrade tiles: rebuild only when the available set changes.
    const avail = upgrades.filter((u) => !has(u.id) && u.unlocked());
    const key = avail.map((u) => u.id).join(",");
    const box = $("#upgrades");
    if (key !== lastUpgradeKey || force) {
      lastUpgradeKey = key;
      box.innerHTML = "";
      if (!avail.length) {
        box.innerHTML = `<p class="empty">Upgrades appear here as your workforce grows.</p>`;
      }
      avail.forEach((u) => {
        const b = document.createElement("button");
        b.className = "up";
        b.dataset.id = u.id;
        b.setAttribute("aria-label", `${u.name}: ${u.desc} Costs ${fmt(u.cost)} ${cur.name}`);
        b.innerHTML = `<span class="up-icon" aria-hidden="true">${u.icon}</span><span class="up-tier">${u.kind === "click" ? "✦" + ROMAN[u.tier] : ROMAN[u.tier]}</span>`;
        const show = () => showUpgradeInfo(u);
        b.addEventListener("pointerenter", show);
        b.addEventListener("focus", show);
        b.addEventListener("pointerleave", () => showUpgradeInfo(null));
        b.addEventListener("click", () => buyUpgrade(u.id));
        box.appendChild(b);
      });
      showUpgradeInfo(null);
    }
    box.querySelectorAll(".up").forEach((b) => {
      const u = upgrades.find((x) => x.id === b.dataset.id);
      b.classList.toggle("afford", S.money >= u.cost);
    });

    // Buff chips
    const now = performance.now();
    $("#buffs").innerHTML = buffs.map((b) =>
      `<span class="buff">${b.icon} ${b.name} ×${b.mult} <b>${Math.ceil((b.until - now) / 1000)}s</b></span>`).join("");

    const g = prestigeGain();
    const pb = $("#open-legacy");
    pb.classList.toggle("ready", g >= 1);
    pb.textContent = g >= 1 ? `🌟 +${fmt(g)} ${theme.prestige.name}` : "🌟 Legacy";
  }

  function showUpgradeInfo(u) {
    const el = $("#upgrade-info");
    if (!u) {
      el.innerHTML = `<span class="muted">Hover an upgrade to see what it does. Click to buy.</span>`;
      return;
    }
    el.innerHTML = `<b>${u.name}</b> · ${theme.currency.icon} ${fmt(u.cost)}<br><span class="muted">${u.desc}</span>`;
  }

  // ---------- Modals ----------
  function openModal(html) {
    $("#modal-body").innerHTML = html;
    $("#modal").hidden = false;
    $("#modal-close").focus();
  }
  function closeModal() { $("#modal").hidden = true; }

  function openLegacy() {
    const g = prestigeGain();
    const next = Math.pow(prestigeTotal() + 1, 3) * 1e9;
    const unlockedAch = achievements.filter((a) => S.ach.includes(a.id)).length;
    const cur = theme.currency;
    openModal(`
      <h2>${theme.name}</h2>
      <dl class="stats">
        <dt>Earned this run</dt><dd>${cur.icon} ${fmt(S.runEarned)}</dd>
        <dt>Earned all time</dt><dd>${cur.icon} ${fmt(S.allEarned)}</dd>
        <dt>Income</dt><dd>${fmt(cps())}/s</dd>
        <dt>Per click</dt><dd>${fmt(clickValue())}</dd>
        <dt>Clicks</dt><dd>${fmt(S.clicks)}</dd>
        <dt>Workers</dt><dd>${fmt(totalOwned())}</dd>
        <dt>${theme.golden.name}s caught</dt><dd>${S.golden}</dd>
        <dt>Time played</dt><dd>${fmtTime(S.playTime)}</dd>
      </dl>
      <h3>🌟 ${theme.prestige.name}</h3>
      <p>You hold <b>${fmt(S.prestige)}</b> ${theme.prestige.name}, each giving +2% to all income (now +${fmt(S.prestige * 2)}%).
      ${theme.prestige.verb} to start over with everything you've earned so far turned into ${theme.prestige.name}.</p>
      <p class="muted">Next one at ${fmt(next)} ${cur.name} earned all time.</p>
      <div class="confirm-row" id="prestige-row">
        <button class="btn primary" id="prestige-btn" ${g < 1 ? "disabled" : ""}>${g >= 1 ? `${theme.prestige.verb} for +${fmt(g)}` : "Not enough yet"}</button>
      </div>
      <h3>🏆 Achievements · ${unlockedAch}/${achievements.length}</h3>
      <p class="muted">Each achievement adds +1% to all income.</p>
      <div class="ach-grid">${achievements.map((a) => {
        const got = S.ach.includes(a.id);
        return `<span class="ach ${got ? "got" : ""}" title="${got ? a.name : "Locked: " + a.name}" aria-label="${got ? a.name : "Locked: " + a.name}">${got ? a.icon : "?"}</span>`;
      }).join("")}</div>
      <h3>Save</h3>
      <div class="confirm-row" id="wipe-row"><button class="btn ghost" id="wipe-btn">Erase ${theme.name} save</button></div>
    `);
    const pb = $("#prestige-btn");
    pb.addEventListener("click", () => confirmInline("#prestige-row", `Reset this run for +${fmt(g)} ${theme.prestige.name}?`, doPrestige));
    $("#wipe-btn").addEventListener("click", () => confirmInline("#wipe-row", "Erase everything in this theme? This can't be undone.", wipe));
  }

  function confirmInline(rowSel, question, action) {
    const row = $(rowSel);
    row.innerHTML = `<span>${question}</span><button class="btn primary" data-yes>Yes</button><button class="btn ghost" data-no>Cancel</button>`;
    row.querySelector("[data-yes]").addEventListener("click", action);
    row.querySelector("[data-no]").addEventListener("click", openLegacy);
  }

  function wipe() {
    store.del(STORE_PREFIX + theme.id);
    S = freshState();
    buffs = [];
    world.reset();
    closeModal();
    renderShop(true);
    toast("Save erased. Fresh start.");
  }

  // ---------- Theme picker ----------
  function openPicker(canClose) {
    const grid = $("#picker-grid");
    grid.innerHTML = "";
    THEMES.forEach((t) => {
      const s = load(t.id);
      const card = document.createElement("button");
      card.className = "theme-card";
      card.style.setProperty("--c-sky1", t.colors.sky1);
      card.style.setProperty("--c-sky2", t.colors.sky2);
      card.style.setProperty("--c-ground", t.colors.ground);
      card.innerHTML = `
        <span class="tc-scene" aria-hidden="true"><span class="tc-big">${t.clicker.icon}</span><span class="tc-row">${t.professions.slice(0, 6).map((p) => p.icon).join("")}</span></span>
        <span class="tc-name">${t.name}</span>
        <span class="tc-tag">${t.tagline}</span>
        <span class="tc-jobs">${t.professions.map((p) => p.name).join(" · ")}</span>
        <span class="tc-save">${s ? `Continue · ${t.currency.icon} ${fmt(s.allEarned)} earned` : "New game"}</span>`;
      card.addEventListener("click", () => { $("#picker").hidden = true; startTheme(t.id); });
      grid.appendChild(card);
    });
    $("#picker-close").hidden = !canClose;
    $("#picker").hidden = false;
  }

  function applyColors() {
    const r = document.documentElement.style;
    for (const [k, v] of Object.entries(theme.colors)) r.setProperty(`--${k}`, v);
    r.colorScheme = theme.id === "space" ? "dark" : "light";
    document.title = `${theme.name} · Profession Clicker`;
    $("#theme-name").textContent = theme.name;
    $("#world").setAttribute("aria-label", `${theme.clicker.label}. Press Space or Enter to click.`);
    $("#clicker-hint").textContent = `Tap the ${theme.clicker.icon} to ${theme.clicker.label.toLowerCase()}`;
  }

  function startTheme(id, injected, preview) {
    if (S && theme) save();
    previewing = !!preview;
    theme = THEMES.find((t) => t.id === id) || THEMES[0];
    S = injected || load(theme.id) || freshState();
    buffs = [];
    buildUpgrades();
    buildAchievements();
    applyColors();
    buildShop();
    world.reset();
    lastUpgradeKey = "";
    renderShop(true);

    const away = (Date.now() - S.saved) / 1000;
    if (!injected && away > 60 && cpsBase() > 0) {
      const gain = cpsBase() * Math.min(away, OFFLINE_CAP) * OFFLINE_RATE;
      earn(gain);
      toast(`While you were away (${fmtTime(Math.min(away, OFFLINE_CAP))}), your workers earned ${fmt(gain)} ${theme.currency.name}`);
    }
    if (!preview) save();
  }

  // ---------- Loop ----------
  let last = performance.now(), uiTimer = 0, achTimer = 0, saveTimer = 0;
  function frame(now) {
    const dt = Math.min(0.25, (now - last) / 1000);
    last = now;
    if (S && $("#picker").hidden) {
      earn(cps() * dt);
      S.playTime += dt;
      buffs = buffs.filter((b) => b.until > now);
      world.update(dt, now);
      world.draw(now);
      uiTimer += dt; achTimer += dt; saveTimer += dt;
      if (uiTimer > 0.1) { uiTimer = 0; renderShop(false); }
      if (achTimer > 1) { achTimer = 0; checkAchievements(); }
      if (saveTimer > 10) { saveTimer = 0; save(); }
    }
    requestAnimationFrame(frame);
  }

  // ---------- Boot ----------
  function start(data) {
    world.init();
    document.querySelectorAll("[data-amt]").forEach((b) => b.addEventListener("click", () => {
      buyAmount = b.dataset.amt === "max" ? "max" : +b.dataset.amt;
      document.querySelectorAll("[data-amt]").forEach((x) => x.setAttribute("aria-pressed", x === b ? "true" : "false"));
      renderShop(true);
    }));
    $("#open-picker").addEventListener("click", () => { save(); openPicker(true); });
    $("#picker-close").addEventListener("click", () => ($("#picker").hidden = true));
    $("#open-legacy").addEventListener("click", openLegacy);
    $("#modal-close").addEventListener("click", closeModal);
    $("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") closeModal(); });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") { closeModal(); if (theme) $("#picker").hidden = true; }
    });
    window.addEventListener("beforeunload", save);
    document.addEventListener("visibilitychange", () => { if (document.hidden) save(); });

    window.claude?.hot?.snapshot?.(() => ({ themeId: theme?.id, state: S }));

    if (data && data.themeId && data.state) startTheme(data.themeId, data.state);
    else {
      const lastId = store.get(STORE_PREFIX + "last");
      if (lastId && THEMES.some((t) => t.id === lastId)) startTheme(lastId);
      else { startTheme(THEMES[0].id, null, true); openPicker(false); }
    }
    requestAnimationFrame(frame);
  }

  window.claude?.hot?.ready ? window.claude.hot.ready(start) : start(window.claude?.hot?.data ?? {});
})();
