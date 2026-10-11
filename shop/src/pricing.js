import { httpError } from './db.js';

const MAX_QTY = 99;
const MAX_LINES = 50;

/** VAT contained in a VAT-inclusive amount, using the same rounding Klarna validates against. */
export function taxOf(total, taxRate) {
  return total - Math.round((total * 10000) / (10000 + taxRate));
}

/**
 * Turn a client cart ([{ id, quantity }]) into Klarna-shaped order lines using prices from the
 * database only. The client never decides what anything costs.
 */
export function priceCart(items, getProduct, { shipping }) {
  if (!Array.isArray(items) || items.length === 0) throw httpError(400, 'Cart is empty');
  if (items.length > MAX_LINES) throw httpError(400, 'Too many items in cart');

  const merged = new Map();
  for (const item of items) {
    const id = Number(item?.id);
    const quantity = Number(item?.quantity);
    if (!Number.isInteger(id) || !Number.isInteger(quantity) || quantity < 1) {
      throw httpError(400, 'Invalid cart item');
    }
    merged.set(id, (merged.get(id) || 0) + quantity);
  }

  const lines = [];
  for (const [id, quantity] of merged) {
    const p = getProduct(id);
    if (!p || !p.active) throw httpError(409, 'A product in your cart is no longer available');
    if (quantity > MAX_QTY) throw httpError(400, `At most ${MAX_QTY} of each product`);
    if (p.stock !== null && p.stock < quantity) throw httpError(409, `Only ${p.stock} left of ${p.name}`);
    const total = p.price * quantity;
    lines.push({
      type: 'physical',
      reference: String(p.id),
      name: p.name,
      quantity,
      unit_price: p.price,
      tax_rate: p.tax_rate,
      total_amount: total,
      total_tax_amount: taxOf(total, p.tax_rate),
    });
  }

  const subtotal = lines.reduce((s, l) => s + l.total_amount, 0);
  const fee = subtotal >= shipping.freeOver ? 0 : shipping.fee;
  lines.push({
    type: 'shipping_fee',
    reference: 'shipping',
    name: 'Shipping',
    quantity: 1,
    unit_price: fee,
    tax_rate: shipping.taxRate,
    total_amount: fee,
    total_tax_amount: taxOf(fee, shipping.taxRate),
  });

  return {
    order_lines: lines,
    order_amount: lines.reduce((s, l) => s + l.total_amount, 0),
    order_tax_amount: lines.reduce((s, l) => s + l.total_tax_amount, 0),
  };
}

/** Product lines only, as { id, quantity }, for stock handling. */
export const stockItems = (order) =>
  order.order_lines.filter((l) => l.type === 'physical').map((l) => ({ id: Number(l.reference), quantity: l.quantity }));
