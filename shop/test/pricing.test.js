import { test } from 'node:test';
import assert from 'node:assert/strict';
import { priceCart, taxOf } from '../src/pricing.js';

const products = {
  1: { id: 1, name: 'Mug', price: 19900, tax_rate: 2500, stock: 5, active: 1 },
  2: { id: 2, name: 'Book', price: 24900, tax_rate: 600, stock: null, active: 1 },
  3: { id: 3, name: 'Hidden', price: 100, tax_rate: 2500, stock: null, active: 0 },
};
const get = (id) => products[id];
const cfg = { shipping: { fee: 4900, freeOver: 50000, taxRate: 2500 } };

test('taxOf extracts VAT from inclusive amounts', () => {
  assert.equal(taxOf(12500, 2500), 2500);
  assert.equal(taxOf(10600, 600), 600);
  assert.equal(taxOf(0, 2500), 0);
});

test('prices lines from the database and adds shipping', () => {
  const o = priceCart([{ id: 1, quantity: 1 }, { id: '1', quantity: 1 }], get, cfg);
  assert.equal(o.order_lines.length, 2);
  assert.deepEqual(o.order_lines[0], {
    type: 'physical', reference: '1', name: 'Mug', quantity: 2, unit_price: 19900, tax_rate: 2500,
    total_amount: 39800, total_tax_amount: 7960,
  });
  assert.equal(o.order_lines[1].total_amount, 4900);
  assert.equal(o.order_amount, 39800 + 4900);
  assert.equal(o.order_tax_amount, 7960 + 980);
});

test('free shipping at the threshold, mixed VAT rates sum correctly', () => {
  const o = priceCart([{ id: 1, quantity: 1 }, { id: 2, quantity: 2 }], get, cfg);
  assert.equal(o.order_lines.at(-1).total_amount, 0);
  assert.equal(o.order_amount, 19900 + 49800);
  assert.equal(o.order_tax_amount, o.order_lines.reduce((s, l) => s + l.total_tax_amount, 0));
});

test('rejects bad carts', () => {
  assert.throws(() => priceCart([], get, cfg), /empty/);
  assert.throws(() => priceCart([{ id: 1, quantity: 0 }], get, cfg), /Invalid/);
  assert.throws(() => priceCart([{ id: 1, quantity: 1.5 }], get, cfg), /Invalid/);
  assert.throws(() => priceCart([{ id: 1, quantity: 6 }], get, cfg), /Only 5 left/);
  assert.throws(() => priceCart([{ id: 3, quantity: 1 }], get, cfg), /no longer available/);
  assert.throws(() => priceCart([{ id: 99, quantity: 1 }], get, cfg), /no longer available/);
});
