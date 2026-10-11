import http from 'node:http';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { brotliCompressSync, gzipSync } from 'node:zlib';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config as defaultConfig } from './config.js';
import { openDb, httpError } from './db.js';
import { createKlarna } from './klarna.js';
import { priceCart, stockItems } from './pricing.js';
import { validateCustomer, validateProduct } from './validate.js';
import { buildSite } from './build.js';

const CHECKOUT_TTL_MINUTES = 55; // Klarna authorization tokens live for 60 minutes
const MAX_BODY = 64 * 1024;
const ADMIN_HTML = fileURLToPath(new URL('../admin/index.html', import.meta.url));

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.avif': 'image/avif', '.ico': 'image/x-icon', '.txt': 'text/plain',
};
const COMPRESSIBLE = new Set(['.html', '.js', '.css', '.json', '.svg', '.txt']);

export function createApp({ config = defaultConfig, db, klarna } = {}) {
  db ??= openDb(config.dbPath);
  klarna ??= createKlarna(config.klarna);
  const { shop } = config;

  const rebuild = () => { buildSite({ db, config }); staticCache.clear(); };

  // ---------- public API ----------

  const publicProduct = ({ id, slug, name, description, price, tax_rate, image, stock }) =>
    ({ id, slug, name, description, price, tax_rate, image, in_stock: stock === null || stock > 0 });

  async function createSession(req) {
    const body = await readJson(req);
    const customer = validateCustomer(body.customer, shop.country);
    const order = priceCart(body.items, db.product, config);
    const checkoutId = randomBytes(16).toString('hex');
    const klarnaOrder = {
      purchase_country: shop.country,
      purchase_currency: shop.currency,
      locale: shop.locale,
      intent: 'buy',
      ...order,
      merchant_reference1: checkoutId,
      merchant_urls: {
        confirmation: `${config.baseUrl}/thanks/`,
        notification: `${config.baseUrl}/api/klarna/notification`,
      },
    };
    const session = await klarna.createSession(klarnaOrder);
    db.createCheckout(checkoutId, session.session_id, { klarnaOrder, customer });
    return {
      checkout_id: checkoutId,
      client_token: session.client_token,
      payment_method_categories: session.payment_method_categories,
      mock: klarna.mock,
      order_lines: order.order_lines,
      order_amount: order.order_amount,
      order_tax_amount: order.order_tax_amount,
      currency: shop.currency,
    };
  }

  async function completeCheckout(req) {
    const { checkout_id, authorization_token } = await readJson(req);
    if (typeof checkout_id !== 'string' || typeof authorization_token !== 'string') {
      throw httpError(400, 'checkout_id and authorization_token are required');
    }
    const checkout = db.checkout(checkout_id);
    if (!checkout) throw httpError(404, 'Checkout not found');
    if (checkout.age_minutes > CHECKOUT_TTL_MINUTES) throw httpError(410, 'Checkout expired, please start again');

    const { klarnaOrder, customer } = checkout.data;
    const items = stockItems(klarnaOrder);
    db.reserve(checkout_id, items);

    let placed;
    try {
      placed = await klarna.createOrder(authorization_token, {
        ...klarnaOrder,
        billing_address: customer,
        shipping_address: customer,
      });
    } catch (err) {
      db.release(checkout_id, items);
      throw err;
    }

    const rejected = placed.fraud_status === 'REJECTED';
    if (rejected) db.restock(items);
    const order = db.createOrder({
      checkout_id,
      klarna_order_id: placed.order_id,
      status: rejected ? 'cancelled' : placed.fraud_status === 'PENDING' ? 'pending' : 'authorized',
      fraud_status: placed.fraud_status,
      currency: klarnaOrder.purchase_currency,
      amount: klarnaOrder.order_amount,
      tax_amount: klarnaOrder.order_tax_amount,
      email: customer.email,
      customer,
      lines: klarnaOrder.order_lines,
    });
    if (rejected) throw httpError(402, 'The payment was declined');
    return { order_id: order.id, redirect_url: placed.redirect_url || `${config.baseUrl}/thanks/` };
  }

  // Klarna calls this when a PENDING fraud decision resolves. The payload is not trusted:
  // the order's state is fetched from Klarna directly.
  async function klarnaNotification(req) {
    const { order_id } = await readJson(req);
    const order = typeof order_id === 'string' && db.orderByKlarnaId(order_id);
    if (!order || order.status !== 'pending') return { ok: true };
    const remote = await klarna.getOrder(order_id);
    if (remote.fraud_status === 'ACCEPTED') db.setOrderStatus(order.id, 'authorized', 'ACCEPTED');
    if (remote.fraud_status === 'REJECTED' || remote.status === 'CANCELLED') {
      db.setOrderStatus(order.id, 'cancelled', remote.fraud_status);
      db.restock(stockItems({ order_lines: order.lines }));
    }
    return { ok: true };
  }

  // ---------- admin API ----------

  const tokenHash = config.adminToken && createHash('sha256').update(config.adminToken).digest();
  function requireAdmin(req) {
    const given = /^Bearer (.+)$/.exec(req.headers.authorization || '')?.[1];
    const ok = tokenHash && given &&
      timingSafeEqual(tokenHash, createHash('sha256').update(given).digest());
    if (!ok) throw httpError(401, 'Unauthorized');
  }

  async function createProduct(req) {
    const data = validateProduct(await readJson(req));
    let p;
    try { p = db.createProduct(data); } catch (e) { throw uniqueSlug(e); }
    rebuild();
    return p;
  }
  async function updateProduct(req, id) {
    if (!db.product(id)) throw httpError(404, 'Product not found');
    let p;
    try { p = db.updateProduct(id, validateProduct(await readJson(req), { partial: true })); } catch (e) { throw uniqueSlug(e); }
    rebuild();
    return p;
  }
  function deleteProduct(id) {
    if (!db.deleteProduct(id)) throw httpError(404, 'Product not found');
    rebuild();
    return { ok: true };
  }

  async function captureOrder(id) {
    const o = db.order(id);
    if (!o) throw httpError(404, 'Order not found');
    if (o.status !== 'authorized') throw httpError(409, `Cannot capture an order that is ${o.status}`);
    await klarna.capture(o.klarna_order_id, o.amount);
    db.setOrderStatus(id, 'captured');
    return db.order(id);
  }
  async function cancelOrder(id) {
    const o = db.order(id);
    if (!o) throw httpError(404, 'Order not found');
    if (!['authorized', 'pending'].includes(o.status)) throw httpError(409, `Cannot cancel an order that is ${o.status}`);
    await klarna.cancel(o.klarna_order_id);
    db.setOrderStatus(id, 'cancelled');
    db.restock(stockItems({ order_lines: o.lines }));
    return db.order(id);
  }

  // ---------- routing ----------

  const routes = [
    ['GET', /^\/api\/products$/, () => db.products.active().map(publicProduct)],
    ['GET', /^\/api\/products\/([a-z0-9-]+)$/, (req, slug) => {
      const p = db.productBySlug(slug);
      if (!p) throw httpError(404, 'Product not found');
      return publicProduct(p);
    }],
    ['POST', /^\/api\/checkout\/session$/, createSession],
    ['POST', /^\/api\/checkout\/complete$/, completeCheckout],
    ['POST', /^\/api\/klarna\/notification$/, klarnaNotification],

    ['GET', /^\/api\/admin\/products$/, () => db.products.all(), true],
    ['POST', /^\/api\/admin\/products$/, createProduct, true],
    ['PATCH', /^\/api\/admin\/products\/(\d+)$/, (req, id) => updateProduct(req, Number(id)), true],
    ['DELETE', /^\/api\/admin\/products\/(\d+)$/, (req, id) => deleteProduct(Number(id)), true],
    ['GET', /^\/api\/admin\/orders$/, (req, _, url) =>
      db.orders(Math.min(Number(url.searchParams.get('limit')) || 50, 200), Number(url.searchParams.get('offset')) || 0), true],
    ['POST', /^\/api\/admin\/orders\/(\d+)\/capture$/, (req, id) => captureOrder(Number(id)), true],
    ['POST', /^\/api\/admin\/orders\/(\d+)\/cancel$/, (req, id) => cancelOrder(Number(id)), true],
    ['POST', /^\/api\/admin\/rebuild$/, () => { rebuild(); return { ok: true }; }, true],
  ];

  const staticCache = new Map();

  async function handler(req, res) {
    const url = new URL(req.url, 'http://x');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    try {
      if (url.pathname.startsWith('/api/')) {
        for (const [method, re, fn, admin] of routes) {
          const m = re.exec(url.pathname);
          if (!m || method !== req.method) continue;
          if (admin) requireAdmin(req);
          return sendJson(res, 200, await fn(req, m[1], url));
        }
        throw httpError(404, 'Not found');
      }
      if (req.method !== 'GET' && req.method !== 'HEAD') throw httpError(405, 'Method not allowed');
      if (url.pathname === '/admin' || url.pathname === '/admin/') {
        res.setHeader('X-Frame-Options', 'DENY');
        return serveFile(req, res, ADMIN_HTML, 'no-store');
      }
      return serveStatic(req, res, url.pathname);
    } catch (err) {
      const status = err.status || 500;
      if (status >= 500) console.error(err);
      // Klarna errors are logged but the customer gets a generic message.
      const message = err.expose ? err.message : status === 502 ? 'Payment provider error, please try again' : 'Internal error';
      if (!res.headersSent) sendJson(res, status, { error: message });
      else res.end();
    }
  }

  async function serveStatic(req, res, pathname) {
    let path;
    try { path = resolve(config.publicDir, '.' + decodeURIComponent(pathname)); } catch { throw httpError(400, 'Bad path'); }
    if (path !== config.publicDir && !path.startsWith(config.publicDir + sep)) throw httpError(404, 'Not found');
    try {
      if ((await stat(path)).isDirectory()) path = join(path, 'index.html');
      const cache = pathname.startsWith('/assets/') ? 'public, max-age=31536000, immutable' : 'public, max-age=0, must-revalidate';
      return await serveFile(req, res, path, cache);
    } catch (err) {
      if (err.code !== 'ENOENT' && err.code !== 'ENOTDIR') throw err;
      return await serveFile(req, res, join(config.publicDir, '404.html'), 'no-store', 404)
        .catch(() => sendJson(res, 404, { error: 'Not found' }));
    }
  }

  async function serveFile(req, res, path, cacheControl, status = 200) {
    let entry = staticCache.get(path);
    if (!entry) {
      const raw = await readFile(path);
      const ext = extname(path);
      entry = {
        type: TYPES[ext] || 'application/octet-stream',
        etag: '"' + createHash('sha1').update(raw).digest('base64url') + '"',
        raw,
        br: COMPRESSIBLE.has(ext) && raw.length > 512 ? brotliCompressSync(raw) : null,
        gzip: COMPRESSIBLE.has(ext) && raw.length > 512 ? gzipSync(raw) : null,
      };
      staticCache.set(path, entry);
    }
    res.setHeader('Content-Type', entry.type);
    res.setHeader('Cache-Control', cacheControl);
    res.setHeader('ETag', entry.etag);
    res.setHeader('Vary', 'Accept-Encoding');
    if (status === 200 && req.headers['if-none-match'] === entry.etag) { res.writeHead(304); return res.end(); }
    const accept = req.headers['accept-encoding'] || '';
    let body = entry.raw;
    if (entry.br && /\bbr\b/.test(accept)) { body = entry.br; res.setHeader('Content-Encoding', 'br'); }
    else if (entry.gzip && /\bgzip\b/.test(accept)) { body = entry.gzip; res.setHeader('Content-Encoding', 'gzip'); }
    res.setHeader('Content-Length', body.length);
    res.writeHead(status);
    res.end(req.method === 'HEAD' ? undefined : body);
  }

  return { handler, db, rebuild };
}

function uniqueSlug(e) {
  return /UNIQUE/.test(e.message) ? httpError(409, 'A product with that slug already exists') : e;
}

function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(body);
}

async function readJson(req) {
  if (!/^application\/json\b/.test(req.headers['content-type'] || '')) throw httpError(415, 'Expected application/json');
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw httpError(413, 'Request body too large');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { throw httpError(400, 'Invalid JSON'); }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const app = createApp();
  app.rebuild();
  const server = http.createServer(app.handler);
  server.listen(defaultConfig.port, () => {
    console.log(`Shop running at ${defaultConfig.baseUrl} (admin: ${defaultConfig.baseUrl}/admin)`);
    if (defaultConfig.klarna.mock) console.warn('Klarna credentials not set: checkout is SIMULATED.');
    if (!defaultConfig.adminToken) console.warn('ADMIN_TOKEN not set: the admin API is disabled.');
  });
  const stop = () => server.close(() => { app.db.close(); process.exit(0); });
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}
