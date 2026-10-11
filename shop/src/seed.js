import { config } from './config.js';
import { openDb } from './db.js';
import { buildSite } from './build.js';

const db = openDb(config.dbPath);
const demo = [
  { slug: 'linen-tote', name: 'Linen Tote Bag', price: 29900, stock: 25,
    description: 'Sturdy washed-linen tote with an inner pocket.\n\nMade in Portugal.' },
  { slug: 'ceramic-mug', name: 'Stoneware Mug', price: 19900, stock: 40,
    description: 'Hand-glazed stoneware mug, 350 ml. Dishwasher safe.' },
  { slug: 'wool-beanie', name: 'Merino Beanie', price: 34900, stock: null,
    description: 'Soft merino wool beanie in one size.' },
];
let added = 0;
for (const p of demo) {
  if (!db.raw.prepare('SELECT 1 FROM products WHERE slug = ?').get(p.slug)) { db.createProduct(p); added++; }
}
buildSite({ db, config });
console.log(`Added ${added} demo products and rebuilt the storefront.`);
