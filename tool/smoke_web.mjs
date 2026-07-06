import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const url = process.env.SMOKE_URL ?? 'http://127.0.0.1:8080';
const expectedTitle = 'IGN Itinéraires';
const failures = [];

function collectFailures(page) {
  page.on('console', (message) => {
    if (message.type() === 'error') failures.push(`console: ${message.text()}`);
  });
  page.on('pageerror', (error) => failures.push(`page: ${error.message}`));
  page.on('requestfailed', (request) => {
    // Ignore network errors for external map tile services in CI environments
    const url = request.url();
    if (!url.includes('data.geopf.fr') && !url.includes('cartes.gouv.fr')) {
      failures.push(`request: ${url} (${request.failure()?.errorText ?? 'unknown'})`);
    }
  });
}

async function assertNonBlank(page, name) {
  const screenshot = PNG.sync.read(await page.screenshot());
  let sampled = 0;
  let nonBlank = 0;
  for (let y = 0; y < screenshot.height; y += 8) {
    for (let x = 0; x < screenshot.width; x += 8) {
      const offset = (screenshot.width * y + x) << 2;
      sampled += 1;
      if (
        screenshot.data[offset + 3] > 16 &&
        (screenshot.data[offset] < 245 ||
          screenshot.data[offset + 1] < 245 ||
          screenshot.data[offset + 2] < 245)
      ) {
        nonBlank += 1;
      }
    }
  }
  if (nonBlank / sampled < 0.01) throw new Error(`${name} viewport is blank`);
}

const browser = await chromium.launch();
try {
  for (const candidate of [
    { name: 'desktop', viewport: { width: 1366, height: 900 } },
    { name: 'mobile', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true },
  ]) {
    const page = await browser.newPage(candidate);
    collectFailures(page);
    const response = await page.goto(url, { waitUntil: 'domcontentloaded' });
    if (!response?.ok()) throw new Error(`${candidate.name} returned ${response?.status()}`);
    if ((await page.title()) !== expectedTitle) throw new Error(`${candidate.name} title is invalid`);

    const headers = response.headers();
    if (!headers['content-security-policy']?.includes('https://data.geopf.fr')) {
      throw new Error('CSP does not allow data.geopf.fr');
    }
    if (!headers['permissions-policy']?.includes('geolocation=(self)')) {
      throw new Error('Permissions-Policy does not allow same-origin geolocation');
    }

    try {
      await page.waitForFunction(
        () => Boolean(document.querySelector('flt-glass-pane, flutter-view')),
        undefined,
        { timeout: 60_000 },
      );
    } catch (error) {
      const details = failures.length === 0
        ? 'no browser error was reported'
        : failures.join('\n');
      throw new Error(
        `${candidate.name} Flutter startup failed: ${error.message}\n${details}`,
      );
    }
    await assertNonBlank(page, candidate.name);
    await page.close();
  }
} finally {
  await browser.close();
}

if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log(`Smoke check passed for ${url}`);
