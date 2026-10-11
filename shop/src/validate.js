import { httpError } from './db.js';

const str = (v, max) => typeof v === 'string' && v.trim().length > 0 && v.length <= max;
const nonNegInt = (v) => Number.isInteger(v) && v >= 0;

/** Validate an admin product payload. `partial` allows updates that omit fields. */
export function validateProduct(body, { partial = false } = {}) {
  if (!body || typeof body !== 'object') throw httpError(400, 'Expected a JSON object');
  const out = {};
  const check = (key, ok, msg) => {
    if (body[key] === undefined) {
      if (!partial && ['slug', 'name', 'price'].includes(key)) throw httpError(400, `${key} is required`);
      return;
    }
    if (!ok(body[key])) throw httpError(400, msg);
    out[key] = body[key];
  };
  check('slug', (v) => typeof v === 'string' && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(v) && v.length <= 80,
    'slug must be lowercase letters, digits and dashes');
  check('name', (v) => str(v, 200), 'name must be 1-200 characters');
  check('description', (v) => typeof v === 'string' && v.length <= 10000, 'description is too long');
  check('price', nonNegInt, 'price must be a non-negative integer in minor units');
  check('tax_rate', (v) => nonNegInt(v) && v <= 10000, 'tax_rate must be basis points (2500 = 25%)');
  check('image', (v) => v === '' || (typeof v === 'string' && v.length <= 2000 && /^(https:\/\/|\/)/.test(v)),
    'image must be an https:// URL or a path starting with /');
  check('stock', (v) => v === null || nonNegInt(v), 'stock must be a non-negative integer or null');
  if (body.active !== undefined) {
    if (typeof body.active !== 'boolean') throw httpError(400, 'active must be true or false');
    out.active = body.active ? 1 : 0;
  }
  return out;
}

/** Validate the customer details collected on the checkout page, returned in Klarna address shape. */
export function validateCustomer(c, country) {
  if (!c || typeof c !== 'object') throw httpError(400, 'Customer details are required');
  const fields = {
    given_name: 100, family_name: 100, email: 254, street_address: 200, postal_code: 20, city: 100,
  };
  const out = {};
  for (const [key, max] of Object.entries(fields)) {
    if (!str(c[key], max)) throw httpError(400, `${key.replace('_', ' ')} is required`);
    out[key] = c[key].trim();
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(out.email)) throw httpError(400, 'Enter a valid email address');
  if (c.phone !== undefined && c.phone !== '') {
    if (!str(c.phone, 30)) throw httpError(400, 'phone is too long');
    out.phone = c.phone.trim();
  }
  out.country = country;
  return out;
}
