import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../web/app_loader.js', import.meta.url), 'utf8');
const currentBootstrap = `flutter_bootstrap.${'b'.repeat(64)}.js`;

async function start({ scope = 'https://example.org/ign-itineraires/', status = 200,
  bootstrap = currentBootstrap } = {}) {
  const requests = [];
  const scripts = [];
  const messages = [];
  let unregistered = false;
  const document = {
    baseURI: 'https://example.org/ign-itineraires/',
    createElement: (tag) => ({ tag, remove() {} }),
    head: { append: (script) => scripts.push(script) },
    body: { append: (...elements) => messages.push(...elements) },
  };
  const context = {
    URL, document,
    navigator: { serviceWorker: { getRegistration: async () => ({
      scope, unregister: async () => { unregistered = true; },
    }) } },
    fetch: async (url, options) => {
      requests.push({ url: url.href, cache: options.cache });
      return { ok: status === 200, status, json: async () => ({ bootstrap }) };
    },
  };
  await vm.runInNewContext(source, context);
  return { requests, scripts, messages, unregistered, context };
}

test('a returning visitor with a stale Flutter worker boots the fresh manifest without a reload', async () => {
  const result = await start();
  assert.equal(result.unregistered, true);
  assert.deepEqual(result.requests, [{
    url: 'https://example.org/ign-itineraires/release.json', cache: 'no-store',
  }]);
  // The old worker cached flutter_bootstrap.js and main.dart.js. Neither URL
  // is reused: hashed URLs pass through its RESOURCES allowlist to the network.
  assert.equal(result.scripts.length, 1);
  assert.equal(result.scripts[0].src, `https://example.org/ign-itineraires/${currentBootstrap}`);
  assert.equal(result.messages.length, 0);
});

test('does not unregister a worker belonging to another Pages project or parent scope', async () => {
  const result = await start({ scope: 'https://example.org/' });
  assert.equal(result.unregistered, false);
  assert.equal(result.scripts.length, 1);
});

test('an unavailable manifest offers recovery instead of silently running stale route code', async () => {
  const result = await start({ status: 503 });
  assert.equal(result.scripts.length, 0);
  assert.equal(result.messages[1].textContent, 'Réessayer');
});

test('rejects manifest paths outside the versioned bootstrap contract', async () => {
  const result = await start({ bootstrap: 'https://external.example/app.js' });
  assert.equal(result.scripts.length, 0);
  assert.equal(result.messages[1].textContent, 'Réessayer');
});

test('startup recovers from a failed manifest lookup without reloading the document', async () => {
  const result = await start({ status: 503 });
  result.context.fetch = async () => ({
    ok: true, json: async () => ({ bootstrap: currentBootstrap }),
  });
  await result.messages[1].onclick();
  assert.equal(result.scripts.length, 1);
  assert.equal(result.scripts[0].src, `https://example.org/ign-itineraires/${currentBootstrap}`);
});

test('legacy worker activation retires caching without reloading clients or deleting shared caches', async () => {
  const worker = await readFile(new URL('../web/retire_service_worker.js', import.meta.url), 'utf8');
  const events = {};
  const calls = [];
  vm.runInNewContext(worker, { self: {
    addEventListener: (event, handler) => { events[event] = handler; },
    skipWaiting: async () => calls.push('skipWaiting'),
    clients: { claim: async () => calls.push('claim') },
    registration: { unregister: async () => calls.push('unregister') },
  } });
  await events.install();
  let activation;
  events.activate({ waitUntil: (promise) => { activation = promise; } });
  await activation;
  assert.deepEqual(calls, ['skipWaiting', 'claim', 'unregister']);
});
