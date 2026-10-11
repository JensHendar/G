import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const WEB = fileURLToPath(new URL('../web/', import.meta.url));

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/**
 * Render the whole storefront to static HTML. Pages are tiny, CSS is inlined and the only script is
 * a small cart module, so any page loads in one round trip from a CDN or this server.
 */
export function buildSite({ db, config }) {
  const { shop, shipping } = config;
  const fmt = new Intl.NumberFormat(shop.locale, { style: 'currency', currency: shop.currency });
  const money = (minor) => fmt.format(minor / 100);
  const products = db.products.active();

  const css = readFileSync(join(WEB, 'style.css'), 'utf8');
  const js = readFileSync(join(WEB, 'app.js'), 'utf8');
  const jsName = `app.${createHash('sha1').update(js).digest('hex').slice(0, 10)}.js`;

  const settings = { currency: shop.currency, locale: shop.locale, country: shop.country, shipping };
  const layout = (title, body, { description = '', page = '' } = {}) => `<!doctype html>
<html lang="${esc(shop.locale.split('-')[0])}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
${description ? `<meta name="description" content="${esc(description)}">` : ''}
<style>${css}</style>
<script type="module" src="/assets/${jsName}"></script>
</head>
<body data-page="${page}" data-settings="${esc(JSON.stringify(settings))}">
<header class="top"><div class="wrap">
<a class="brand" href="/">${esc(shop.name)}</a>
<a class="cart-link" href="/cart/">Cart <span data-cart-count>0</span></a>
</div></header>
<main class="wrap">${body}</main>
<footer class="wrap foot">${esc(shop.name)} &middot; Secure payment with Klarna</footer>
</body>
</html>`;

  const img = (p, i, cls) => p.image
    ? `<img class="${cls}" src="${esc(p.image)}" alt="${esc(p.name)}" width="800" height="800"${i > 3 ? ' loading="lazy"' : ''} decoding="async">`
    : `<div class="${cls} noimg"></div>`;
  const soldOut = (p) => p.stock !== null && p.stock <= 0;
  const buyButton = (p) => soldOut(p)
    ? '<button disabled>Sold out</button>'
    : `<button data-add="${p.id}">Add to cart</button>`;

  const pages = {
    'index.html': layout(shop.name, `
<ul class="grid">${products.map((p, i) => `
<li class="card">
<a href="/p/${p.slug}/">${img(p, i, 'thumb')}<h2>${esc(p.name)}</h2></a>
<p class="price">${money(p.price)}</p>
${buyButton(p)}
</li>`).join('')}
</ul>${products.length ? '' : '<p>No products yet.</p>'}`, { page: 'home' }),

    'cart/index.html': layout(`Cart · ${shop.name}`, `
<h1>Cart</h1>
<div data-cart-view><p>Your cart is empty.</p></div>
<form class="checkout" data-checkout hidden>
<h2>Delivery details</h2>
<div class="fields">
<label>First name<input name="given_name" autocomplete="given-name" required maxlength="100"></label>
<label>Last name<input name="family_name" autocomplete="family-name" required maxlength="100"></label>
<label class="wide">Email<input name="email" type="email" autocomplete="email" required maxlength="254"></label>
<label class="wide">Address<input name="street_address" autocomplete="street-address" required maxlength="200"></label>
<label>Postal code<input name="postal_code" autocomplete="postal-code" required maxlength="20"></label>
<label>City<input name="city" autocomplete="address-level2" required maxlength="100"></label>
<label class="wide">Phone<input name="phone" type="tel" autocomplete="tel" maxlength="30"></label>
</div>
<button type="submit">Continue to payment</button>
</form>
<section class="pay" data-pay hidden>
<h2>Payment</h2>
<div data-klarna-categories class="categories"></div>
<div id="klarna-container"></div>
<button type="button" data-pay-button>Pay</button>
</section>
<p class="error" data-error role="alert" hidden></p>`, { page: 'cart' }),

    'thanks/index.html': layout(`Thank you · ${shop.name}`, `
<h1>Thank you for your order!</h1>
<p data-order-number></p>
<p>A confirmation is on its way to your inbox. <a href="/">Continue shopping</a></p>`, { page: 'thanks' }),

    '404.html': layout(`Not found · ${shop.name}`, '<h1>Page not found</h1><p><a href="/">Go to the shop</a></p>'),
  };

  products.forEach((p) => {
    pages[`p/${p.slug}/index.html`] = layout(`${p.name} · ${shop.name}`, `
<article class="product">
${img(p, 0, 'hero')}
<div>
<h1>${esc(p.name)}</h1>
<p class="price">${money(p.price)}</p>
${buyButton(p)}
<div class="desc">${p.description.split(/\n{2,}/).map((para) => `<p>${esc(para)}</p>`).join('')}</div>
</div>
</article>`, { description: p.description.slice(0, 160), page: 'product' });
  });

  const catalog = products.map(({ id, slug, name, price, image, stock }) =>
    ({ id, slug, name, price, image, in_stock: stock === null || stock > 0 }));

  // Write to a temp dir and swap, so visitors never see a half-built site.
  const out = config.publicDir;
  const tmp = `${out}.tmp-${process.pid}`;
  rmSync(tmp, { recursive: true, force: true });
  const write = (rel, content) => {
    const file = join(tmp, rel);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, content);
  };
  for (const [rel, html] of Object.entries(pages)) write(rel, html);
  write('products.json', JSON.stringify(catalog));
  write(`assets/${jsName}`, js);
  write('robots.txt', 'User-agent: *\nDisallow: /cart/\nDisallow: /thanks/\nDisallow: /admin\n');
  rmSync(`${out}.old`, { recursive: true, force: true });
  try { renameSync(out, `${out}.old`); } catch (e) { if (e.code !== 'ENOENT') throw e; }
  renameSync(tmp, out);
  rmSync(`${out}.old`, { recursive: true, force: true });
  return { pages: Object.keys(pages).length };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { config } = await import('./config.js');
  const { openDb } = await import('./db.js');
  const db = openDb(config.dbPath);
  const { pages } = buildSite({ db, config });
  console.log(`Built ${pages} pages into ${config.publicDir}`);
}
