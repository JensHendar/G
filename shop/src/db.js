import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS products (
  id          INTEGER PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price       INTEGER NOT NULL,              -- minor units, VAT included
  tax_rate    INTEGER NOT NULL DEFAULT 2500, -- basis points, 2500 = 25%
  image       TEXT NOT NULL DEFAULT '',
  stock       INTEGER,                       -- NULL = not tracked
  active      INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS checkouts (
  id                TEXT PRIMARY KEY,
  klarna_session_id TEXT,
  data              TEXT NOT NULL,           -- JSON snapshot: order lines, amounts, customer
  completed         INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS orders (
  id              INTEGER PRIMARY KEY,
  checkout_id     TEXT NOT NULL UNIQUE,
  klarna_order_id TEXT,
  status          TEXT NOT NULL,             -- authorized | pending | captured | cancelled
  fraud_status    TEXT,
  currency        TEXT NOT NULL,
  amount          INTEGER NOT NULL,
  tax_amount      INTEGER NOT NULL,
  email           TEXT NOT NULL,
  customer        TEXT NOT NULL,             -- JSON
  lines           TEXT NOT NULL,             -- JSON
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
`;

const PRODUCT_FIELDS = ['slug', 'name', 'description', 'price', 'tax_rate', 'image', 'stock', 'active'];

export function openDb(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA);

  const q = {
    allProducts: db.prepare('SELECT * FROM products ORDER BY id'),
    activeProducts: db.prepare('SELECT * FROM products WHERE active = 1 ORDER BY id'),
    productById: db.prepare('SELECT * FROM products WHERE id = ?'),
    productBySlug: db.prepare('SELECT * FROM products WHERE slug = ? AND active = 1'),
    deleteProduct: db.prepare('DELETE FROM products WHERE id = ?'),
    takeStock: db.prepare('UPDATE products SET stock = stock - ? WHERE id = ? AND stock IS NOT NULL AND stock >= ?'),
    returnStock: db.prepare('UPDATE products SET stock = stock + ? WHERE id = ? AND stock IS NOT NULL'),

    insertCheckout: db.prepare('INSERT INTO checkouts (id, klarna_session_id, data) VALUES (?, ?, ?)'),
    checkoutById: db.prepare(
      "SELECT *, (julianday('now') - julianday(created_at)) * 1440 AS age_minutes FROM checkouts WHERE id = ?"),
    claimCheckout: db.prepare('UPDATE checkouts SET completed = 1 WHERE id = ? AND completed = 0'),
    releaseCheckout: db.prepare('UPDATE checkouts SET completed = 0 WHERE id = ?'),

    insertOrder: db.prepare(`INSERT INTO orders
      (checkout_id, klarna_order_id, status, fraud_status, currency, amount, tax_amount, email, customer, lines)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    orders: db.prepare('SELECT * FROM orders ORDER BY id DESC LIMIT ? OFFSET ?'),
    orderById: db.prepare('SELECT * FROM orders WHERE id = ?'),
    orderByKlarnaId: db.prepare('SELECT * FROM orders WHERE klarna_order_id = ?'),
    setOrderStatus: db.prepare('UPDATE orders SET status = ?, fraud_status = COALESCE(?, fraud_status) WHERE id = ?'),
  };

  const tx = (fn) => {
    db.exec('BEGIN IMMEDIATE');
    try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; }
  };

  const parseOrder = (o) => o && { ...o, customer: JSON.parse(o.customer), lines: JSON.parse(o.lines) };

  return {
    raw: db,
    close: () => db.close(),

    products: { all: () => q.allProducts.all(), active: () => q.activeProducts.all() },
    product: (id) => q.productById.get(id),
    productBySlug: (slug) => q.productBySlug.get(slug),

    createProduct(p) {
      const cols = PRODUCT_FIELDS.filter((f) => p[f] !== undefined);
      const r = db.prepare(`INSERT INTO products (${cols.join(',')}) VALUES (${cols.map(() => '?').join(',')})`)
        .run(...cols.map((c) => p[c]));
      return q.productById.get(r.lastInsertRowid);
    },
    updateProduct(id, p) {
      const cols = PRODUCT_FIELDS.filter((f) => p[f] !== undefined);
      if (cols.length) {
        db.prepare(`UPDATE products SET ${cols.map((c) => `${c} = ?`).join(',')} WHERE id = ?`)
          .run(...cols.map((c) => p[c]), id);
      }
      return q.productById.get(id);
    },
    deleteProduct: (id) => q.deleteProduct.run(id).changes > 0,

    createCheckout: (id, klarnaSessionId, data) => q.insertCheckout.run(id, klarnaSessionId, JSON.stringify(data)),
    checkout(id) {
      const c = q.checkoutById.get(id);
      return c && { ...c, data: JSON.parse(c.data) };
    },

    /** Mark the checkout used and take stock for its lines, atomically. Throws on conflict. */
    reserve(checkoutId, items) {
      tx(() => {
        if (q.claimCheckout.run(checkoutId).changes !== 1) throw httpError(409, 'Checkout already completed');
        for (const { id, quantity } of items) {
          const p = q.productById.get(id);
          if (!p || !p.active) throw httpError(409, 'A product in your cart is no longer available');
          if (p.stock !== null && q.takeStock.run(quantity, id, quantity).changes !== 1) {
            throw httpError(409, `Not enough stock for ${p.name}`);
          }
        }
      });
    },
    /** Undo `reserve` after the payment provider refused the order, so the customer can retry. */
    release(checkoutId, items) {
      tx(() => {
        q.releaseCheckout.run(checkoutId);
        for (const { id, quantity } of items) q.returnStock.run(quantity, id);
      });
    },
    /** Put stock back for a cancelled order. The checkout stays used. */
    restock(items) {
      tx(() => { for (const { id, quantity } of items) q.returnStock.run(quantity, id); });
    },

    createOrder(o) {
      const r = q.insertOrder.run(o.checkout_id, o.klarna_order_id, o.status, o.fraud_status, o.currency,
        o.amount, o.tax_amount, o.email, JSON.stringify(o.customer), JSON.stringify(o.lines));
      return parseOrder(q.orderById.get(r.lastInsertRowid));
    },
    orders: (limit = 50, offset = 0) => q.orders.all(limit, offset).map(parseOrder),
    order: (id) => parseOrder(q.orderById.get(id)),
    orderByKlarnaId: (kid) => parseOrder(q.orderByKlarnaId.get(kid)),
    setOrderStatus: (id, status, fraudStatus = null) => q.setOrderStatus.run(status, fraudStatus, id),
  };
}

export function httpError(status, message) {
  return Object.assign(new Error(message), { status, expose: true });
}
