// The storefront's only script: cart in localStorage plus the Klarna checkout on /cart/.
const settings = JSON.parse(document.body.dataset.settings);
const fmt = new Intl.NumberFormat(settings.locale, { style: 'currency', currency: settings.currency });
const money = (minor) => fmt.format(minor / 100);
const $ = (sel, root = document) => root.querySelector(sel);
const KEY = 'cart';

const loadCart = () => { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch { return {}; } };
function saveCart(cart) {
  try { localStorage.setItem(KEY, JSON.stringify(cart)); } catch {}
  updateCount(cart);
}
function updateCount(cart = loadCart()) {
  const n = Object.values(cart).reduce((a, b) => a + b, 0);
  document.querySelectorAll('[data-cart-count]').forEach((el) => { el.textContent = n; });
}

document.addEventListener('click', (e) => {
  const btn = e.target.closest('[data-add]');
  if (!btn) return;
  const cart = loadCart();
  cart[btn.dataset.add] = Math.min((cart[btn.dataset.add] || 0) + 1, 99);
  saveCart(cart);
  btn.textContent = 'Added ✓';
  setTimeout(() => { btn.textContent = 'Add to cart'; }, 1200);
});
addEventListener('storage', (e) => e.key === KEY && updateCount());
updateCount();

const page = document.body.dataset.page;
if (page === 'cart') initCart();
if (page === 'thanks') {
  saveCart({});
  const order = sessionStorage.getItem('order');
  if (order) $('[data-order-number]').textContent = `Order number: ${order}`;
}

async function api(path, body) {
  const res = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Something went wrong, please try again');
  return data;
}

async function initCart() {
  const view = $('[data-cart-view]');
  const form = $('[data-checkout]');
  const pay = $('[data-pay]');
  const errorEl = $('[data-error]');
  const showError = (msg) => { errorEl.textContent = msg; errorEl.hidden = !msg; };
  const catalog = new Map((await (await fetch('/products.json')).json()).map((p) => [String(p.id), p]));
  let session = null;

  function render() {
    const cart = loadCart();
    for (const id of Object.keys(cart)) if (!catalog.has(id)) delete cart[id];
    saveCart(cart);
    const rows = Object.entries(cart).map(([id, qty]) => ({ p: catalog.get(id), qty }));
    // Any cart change invalidates an open payment session.
    session = null;
    pay.hidden = true;
    form.hidden = rows.length === 0;
    if (!rows.length) { view.innerHTML = '<p>Your cart is empty. <a href="/">Continue shopping</a></p>'; return; }
    const subtotal = rows.reduce((s, r) => s + r.p.price * r.qty, 0);
    const ship = subtotal >= settings.shipping.freeOver ? 0 : settings.shipping.fee;
    view.innerHTML = `<table class="lines"><tbody>${rows.map(({ p, qty }) => `
<tr><td><a href="/p/${p.slug}/"></a></td>
<td><input type="number" min="0" max="99" value="${qty}" data-qty="${p.id}" aria-label="Quantity"></td>
<td class="num">${money(p.price * qty)}</td>
<td><button type="button" class="link" data-remove="${p.id}" aria-label="Remove">✕</button></td></tr>`).join('')}
</tbody><tfoot>
<tr><td colspan="2">Shipping</td><td class="num">${ship ? money(ship) : 'Free'}</td><td></td></tr>
<tr class="total"><td colspan="2">Total</td><td class="num">${money(subtotal + ship)}</td><td></td></tr>
</tfoot></table>`;
    // Names are set as text so product data can never inject markup.
    view.querySelectorAll('td > a').forEach((a, i) => { a.textContent = rows[i].p.name; });
  }

  view.addEventListener('change', (e) => {
    const id = e.target.dataset.qty;
    if (!id) return;
    const cart = loadCart();
    const qty = Math.max(0, Math.min(99, Math.floor(Number(e.target.value)) || 0));
    if (qty) cart[id] = qty; else delete cart[id];
    saveCart(cart);
    // Re-render after the event, since 'change' can fire while the input is being blurred.
    setTimeout(render);
  });
  view.addEventListener('click', (e) => {
    const id = e.target.dataset.remove;
    if (!id) return;
    const cart = loadCart();
    delete cart[id];
    saveCart(cart);
    render();
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    showError('');
    const submit = $('button[type=submit]', form);
    submit.disabled = true;
    try {
      const customer = Object.fromEntries(new FormData(form));
      const items = Object.entries(loadCart()).map(([id, quantity]) => ({ id: Number(id), quantity }));
      session = { ...(await api('/api/checkout/session', { items, customer })), customer };
      await showPayment(session);
    } catch (err) {
      showError(err.message);
    } finally {
      submit.disabled = false;
    }
  });

  let category = null;
  async function showPayment(s) {
    const cats = $('[data-klarna-categories]');
    const container = $('#klarna-container');
    cats.innerHTML = '';
    container.innerHTML = '';
    pay.hidden = false;
    if (s.mock) {
      container.innerHTML = '<p class="mock">Simulated Klarna checkout. Set KLARNA_USERNAME / KLARNA_PASSWORD to use the real widget.</p>';
      return;
    }
    await loadKlarna();
    window.Klarna.Payments.init({ client_token: s.client_token });
    s.payment_method_categories.forEach((c, i) => {
      const label = document.createElement('label');
      const radio = Object.assign(document.createElement('input'), { type: 'radio', name: 'klarna-cat', value: c.identifier, checked: i === 0 });
      radio.addEventListener('change', () => loadCategory(c.identifier));
      label.append(radio, ' ', c.name);
      cats.append(label);
    });
    cats.hidden = s.payment_method_categories.length < 2;
    loadCategory(s.payment_method_categories[0]?.identifier);
  }
  function loadCategory(id) {
    category = id;
    window.Klarna.Payments.load({ container: '#klarna-container', payment_method_category: id }, {}, (res) => {
      if (!res.show_form) showError('Klarna is not available for this order.');
    });
  }

  $('[data-pay-button]').addEventListener('click', async (e) => {
    if (!session) return;
    showError('');
    e.target.disabled = true;
    try {
      const token = session.mock ? 'mock-authorized' : await authorize(session.customer);
      if (!token) return;
      const done = await api('/api/checkout/complete', { checkout_id: session.checkout_id, authorization_token: token });
      sessionStorage.setItem('order', done.order_id);
      saveCart({});
      location.href = done.redirect_url;
    } catch (err) {
      showError(err.message);
    } finally {
      e.target.disabled = false;
    }
  });

  function authorize(customer) {
    const address = Object.fromEntries(Object.entries(customer).filter(([, v]) => v));
    address.country = settings.country;
    return new Promise((resolve) => {
      window.Klarna.Payments.authorize({ payment_method_category: category },
        { billing_address: address, shipping_address: address },
        (res) => {
          if (res.approved && res.authorization_token) return resolve(res.authorization_token);
          if (res.show_form === false) showError('Klarna could not approve this purchase.');
          resolve(null);
        });
    });
  }

  render();
}

let klarnaLoading;
function loadKlarna() {
  klarnaLoading ??= new Promise((resolve, reject) => {
    const s = Object.assign(document.createElement('script'), { src: 'https://x.klarnacdn.net/kp/lib/v1/api.js', async: true });
    s.onload = resolve;
    s.onerror = () => { klarnaLoading = null; reject(new Error('Could not load Klarna, please try again')); };
    document.head.append(s);
  });
  return klarnaLoading;
}
