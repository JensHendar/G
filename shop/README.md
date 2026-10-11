# Kassa

A deliberately small alternative to WooCommerce and Shopify: products, a cart, Klarna checkout, orders. Nothing else.

- **Zero dependencies.** Runs on Node.js 22.13+ alone: built-in HTTP server, SQLite (`node:sqlite`), compression, and test runner. No `npm install`.
- **Headless.** All data goes through a JSON API (`/api/...`). The bundled storefront is one consumer of it. You can swap it for Next.js, Astro, an app, or anything else.
- **Fast.** The storefront is pre-rendered static HTML, rebuilt whenever a product changes. CSS is inlined and the only script is one ~7 KB module (cached immutably). A product page is about 1.4 KB over the wire, and the whole `public/` folder can sit behind any CDN.
- **Klarna native.** Uses Klarna Payments (session → widget authorization → order) and Order Management (capture on shipping, cancel).

## Quick start

```sh
cd shop
cp .env.example .env       # set ADMIN_TOKEN at minimum
npm run seed               # three demo products
npm start                  # http://localhost:3000, admin at /admin
npm test
```

Without Klarna credentials the checkout runs in **simulated mode**: the whole flow works end to end without a real payment. With `NODE_ENV=production`, startup fails unless credentials are set.

## Going live with Klarna

1. Get API credentials in the Klarna Merchant Portal (playground first).
2. Set `KLARNA_USERNAME`, `KLARNA_PASSWORD` and `KLARNA_API_URL` (`https://api.playground.klarna.com` for testing, `https://api.klarna.com` for live EU; NA/OC hosts are listed in `.env.example`).
3. Set `BASE_URL` to your public HTTPS URL, since Klarna redirects to `BASE_URL/thanks/` and posts fraud decisions to `BASE_URL/api/klarna/notification`.
4. Set `CURRENCY`, `LOCALE` and `COUNTRY` for your market.

## How a purchase works

```
browser                          server                              Klarna
  │ POST /api/checkout/session ──▶ prices cart from DB ──────────────▶ create session
  │ ◀── client_token ──────────── stores order snapshot (checkout)
  │ Klarna widget authorize ─────────────────────────────────────────▶ authorization_token
  │ POST /api/checkout/complete ─▶ reserve stock, mark checkout used ─▶ create order
  │ ◀── redirect_url ──────────── save order (authorized)
admin "Mark shipped" ───────────▶ /api/admin/orders/:id/capture ────▶ capture
```

- Prices always come from the database. Client-sent prices are ignored.
- Stock is reserved atomically before the order is placed, and returned if Klarna refuses the order or it is cancelled.
- A checkout can only be completed once, and expires after 55 minutes (Klarna tokens live 60).
- Payment is only *captured* when you mark an order shipped, as Klarna requires.

## API

Public:

| Method | Path | |
|---|---|---|
| GET | `/api/products` | Active products |
| GET | `/api/products/:slug` | One product |
| POST | `/api/checkout/session` | `{ items: [{id, quantity}], customer: {given_name, family_name, email, street_address, postal_code, city, phone?} }` |
| POST | `/api/checkout/complete` | `{ checkout_id, authorization_token }` |
| POST | `/api/klarna/notification` | Klarna callback for pending fraud decisions |

Admin (`Authorization: Bearer $ADMIN_TOKEN`):

| Method | Path | |
|---|---|---|
| GET / POST | `/api/admin/products` | List / create |
| PATCH / DELETE | `/api/admin/products/:id` | Update / delete |
| GET | `/api/admin/orders?limit=&offset=` | Newest first |
| POST | `/api/admin/orders/:id/capture` | Capture payment (ship) |
| POST | `/api/admin/orders/:id/cancel` | Cancel and restock |
| POST | `/api/admin/rebuild` | Re-render the storefront |

Money is always an integer in minor units with VAT included (`19900` = 199.00). `tax_rate` is in basis points (`2500` = 25%).

## Files

| | |
|---|---|
| `src/server.js` | HTTP server, API routes, static file serving (brotli/gzip, ETags) |
| `src/pricing.js` | Cart → Klarna order lines (the only place prices are computed) |
| `src/klarna.js` | Klarna Payments + Order Management client, plus simulated mode |
| `src/db.js` | SQLite schema and queries |
| `src/build.js` | Static storefront generator → `public/` |
| `web/` | Storefront CSS and cart/checkout script |
| `admin/index.html` | Admin page: products and orders |

## Deliberately left out

Accounts, discounts, variants, multi-currency, emails, themes and plugins. Add them only when a real shop needs them. Order confirmation emails are the obvious first addition (hook into `completeCheckout` in `src/server.js`). Until then, Klarna sends the customer its own purchase confirmation.

Run it behind a reverse proxy or CDN that terminates HTTPS. It is a single process with a SQLite file, so back up `DB_PATH`.
