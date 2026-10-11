import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/server.js';
import { openDb } from '../src/db.js';
import { createKlarna } from '../src/klarna.js';

const dir = mkdtempSync(join(tmpdir(), 'shop-test-'));
const config = {
  baseUrl: 'http://shop.test',
  adminToken: 'test-admin-token-123456789',
  publicDir: join(dir, 'public'),
  shop: { name: 'Test', currency: 'SEK', locale: 'sv-SE', country: 'SE' },
  shipping: { fee: 4900, freeOver: 50000, taxRate: 2500 },
};
const customer = {
  given_name: 'Testperson', family_name: 'Approved', email: 'test@example.com',
  street_address: 'Storgatan 1', postal_code: '12345', city: 'Stockholm',
};
let server, base, app;

before(async () => {
  app = createApp({ config, db: openDb(':memory:'), klarna: createKlarna({ mock: true }) });
  server = http.createServer(app.handler);
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => { server.close(); rmSync(dir, { recursive: true, force: true }); });

async function req(method, path, body, token) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: res.headers.get('content-type')?.includes('json') ? JSON.parse(text) : text, res };
}
const admin = (method, path, body) => req(method, '/api/admin' + path, body, config.adminToken);

test('admin API requires the token', async () => {
  assert.equal((await req('GET', '/api/admin/products')).status, 401);
  assert.equal((await req('GET', '/api/admin/products', null, 'wrong')).status, 401);
  assert.equal((await admin('GET', '/products')).status, 200);
});

test('full purchase: create product, check out, capture', async () => {
  const created = await admin('POST', '/products', { slug: 'mug', name: 'Mug <b>', price: 19900, stock: 3 });
  assert.equal(created.status, 200);
  assert.equal((await admin('POST', '/products', { slug: 'mug', name: 'Dup', price: 1 })).status, 409);
  assert.equal((await admin('POST', '/products', { slug: 'Bad Slug', name: 'x', price: 1 })).status, 400);
  const id = created.body.id;

  // Static storefront was rebuilt, with product names escaped.
  const page = await req('GET', '/p/mug/');
  assert.equal(page.status, 200);
  assert.match(page.body, /Mug &lt;b&gt;/);
  assert.equal((await req('GET', '/nope/')).status, 404);
  assert.equal((await req('GET', '/../package.json')).status, 404);
  assert.deepEqual((await req('GET', '/api/products')).body.map((p) => p.slug), ['mug']);

  // Client-sent prices are ignored entirely.
  const session = await req('POST', '/api/checkout/session', { items: [{ id, quantity: 2, price: 1 }], customer });
  assert.equal(session.status, 200);
  assert.equal(session.body.order_amount, 2 * 19900 + 4900);
  assert.equal(session.body.mock, true);

  const bad = await req('POST', '/api/checkout/complete', { checkout_id: session.body.checkout_id, authorization_token: 'nope' });
  assert.equal(bad.status, 402);
  assert.equal((await admin('GET', '/products')).body[0].stock, 3, 'stock restored after a failed authorization');

  const done = await req('POST', '/api/checkout/complete', { checkout_id: session.body.checkout_id, authorization_token: 'mock-authorized' });
  assert.equal(done.status, 200);
  assert.equal(done.body.redirect_url, 'http://shop.test/thanks/');
  assert.equal((await admin('GET', '/products')).body[0].stock, 1);

  const again = await req('POST', '/api/checkout/complete', { checkout_id: session.body.checkout_id, authorization_token: 'mock-authorized' });
  assert.equal(again.status, 409, 'a checkout can only be completed once');

  const [order] = (await admin('GET', '/orders')).body;
  assert.equal(order.status, 'authorized');
  assert.equal(order.amount, 44700);
  assert.equal(order.customer.country, 'SE');

  assert.equal((await admin('POST', `/orders/${order.id}/capture`)).body.status, 'captured');
  assert.equal((await admin('POST', `/orders/${order.id}/cancel`)).status, 409);
});

test('stock is enforced and cancelled orders restock', async () => {
  const { body: p } = await admin('POST', '/products', { slug: 'last-one', name: 'Last one', price: 1000, stock: 1 });
  const s1 = (await req('POST', '/api/checkout/session', { items: [{ id: p.id, quantity: 1 }], customer })).body;
  const s2 = (await req('POST', '/api/checkout/session', { items: [{ id: p.id, quantity: 1 }], customer })).body;
  assert.equal((await req('POST', '/api/checkout/complete', { checkout_id: s1.checkout_id, authorization_token: 'mock-authorized' })).status, 200);
  const lost = await req('POST', '/api/checkout/complete', { checkout_id: s2.checkout_id, authorization_token: 'mock-authorized' });
  assert.equal(lost.status, 409);
  assert.match(lost.body.error, /Not enough stock/);

  const order = (await admin('GET', '/orders')).body.find((o) => o.lines[0].name === 'Last one');
  assert.equal((await admin('POST', `/orders/${order.id}/cancel`)).body.status, 'cancelled');
  assert.equal(app.db.product(p.id).stock, 1);
  assert.match(readFileSync(join(config.publicDir, 'index.html'), 'utf8'), /Last one/);
});

test('validates checkout input', async () => {
  const r = await req('POST', '/api/checkout/session', { items: [{ id: 1, quantity: 1 }], customer: { ...customer, email: 'x' } });
  assert.equal(r.status, 400);
  assert.equal((await req('POST', '/api/checkout/session', { items: [], customer })).status, 400);
  const notJson = await fetch(base + '/api/checkout/session', { method: 'POST', body: 'x' });
  assert.equal(notJson.status, 415);
});
