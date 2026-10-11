import { resolve } from 'node:path';

const env = process.env;
const int = (v, d) => (v === undefined || v === '' ? d : Number.parseInt(v, 10));

export const config = {
  port: int(env.PORT, 3000),
  baseUrl: (env.BASE_URL || 'http://localhost:3000').replace(/\/$/, ''),
  dbPath: env.DB_PATH || './data/shop.db',
  adminToken: env.ADMIN_TOKEN || '',
  production: env.NODE_ENV === 'production',
  publicDir: resolve(env.PUBLIC_DIR || './public'),

  shop: {
    name: env.SHOP_NAME || 'Kassa',
    currency: env.CURRENCY || 'SEK',
    locale: env.LOCALE || 'sv-SE',
    country: env.COUNTRY || 'SE',
  },

  shipping: {
    fee: int(env.SHIPPING_FEE, 4900),
    freeOver: int(env.FREE_SHIPPING_OVER, 50000),
    taxRate: int(env.SHIPPING_TAX_RATE, 2500),
  },

  klarna: {
    username: env.KLARNA_USERNAME || '',
    password: env.KLARNA_PASSWORD || '',
    apiUrl: (env.KLARNA_API_URL || 'https://api.playground.klarna.com').replace(/\/$/, ''),
  },
};

// Without credentials the checkout is simulated, which is only allowed outside production.
config.klarna.mock = !config.klarna.username;
if (config.klarna.mock && config.production) {
  throw new Error('KLARNA_USERNAME and KLARNA_PASSWORD are required when NODE_ENV=production');
}
if (config.production && config.adminToken.length < 24) {
  throw new Error('ADMIN_TOKEN must be at least 24 characters when NODE_ENV=production');
}
