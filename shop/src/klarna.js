import { randomUUID } from 'node:crypto';

/**
 * Minimal Klarna Payments + Order Management client.
 * Flow: createSession -> (browser widget authorizes) -> createOrder -> capture / cancel.
 * With no credentials configured it returns simulated responses so the shop runs locally.
 */
export function createKlarna({ username, password, apiUrl, mock }) {
  const auth = 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64');

  async function call(method, path, body) {
    const res = await fetch(apiUrl + path, {
      method,
      headers: {
        Authorization: auth,
        'Content-Type': 'application/json',
        'Klarna-Idempotency-Key': randomUUID(),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
    });
    const text = await res.text();
    const data = text ? JSON.parse(text) : null;
    if (!res.ok) {
      const detail = data?.error_messages?.join('; ') || data?.error_code || res.statusText;
      throw Object.assign(new Error(`Klarna ${method} ${path} failed (${res.status}): ${detail}`), {
        status: 502,
        klarnaStatus: res.status,
      });
    }
    return data;
  }

  if (mock) {
    return {
      mock: true,
      createSession: async () => ({
        session_id: 'mock-' + randomUUID(),
        client_token: 'mock',
        payment_method_categories: [{ identifier: 'klarna', name: 'Klarna (simulated)' }],
      }),
      createOrder: async (authorizationToken) => {
        if (authorizationToken !== 'mock-authorized') {
          throw Object.assign(new Error('Simulated authorization rejected'), { status: 402, expose: true });
        }
        return { order_id: 'mock-' + randomUUID(), fraud_status: 'ACCEPTED', redirect_url: null };
      },
      getOrder: async (orderId) => ({ order_id: orderId, fraud_status: 'ACCEPTED', status: 'AUTHORIZED' }),
      capture: async () => {},
      cancel: async () => {},
    };
  }

  return {
    mock: false,
    createSession: (order) => call('POST', '/payments/v1/sessions', order),
    createOrder: (authorizationToken, order) =>
      call('POST', `/payments/v1/authorizations/${encodeURIComponent(authorizationToken)}/order`, order),
    getOrder: (orderId) => call('GET', `/ordermanagement/v1/orders/${encodeURIComponent(orderId)}`),
    capture: (orderId, amount) =>
      call('POST', `/ordermanagement/v1/orders/${encodeURIComponent(orderId)}/captures`, { captured_amount: amount }),
    cancel: (orderId) => call('POST', `/ordermanagement/v1/orders/${encodeURIComponent(orderId)}/cancel`),
  };
}
