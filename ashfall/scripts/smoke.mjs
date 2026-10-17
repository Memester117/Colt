import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const out = '/opt/cursor/artifacts/screenshots';
await mkdir(out, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
await page.goto('http://localhost:5173/', { waitUntil: 'networkidle' });

await page.getByRole('heading', { name: /Ashfall/i }).waitFor();
await page.screenshot({ path: `${out}/ashfall-title.png`, fullPage: true });

await page.getByRole('button', { name: 'Begin a journey' }).click();
await page.getByLabel('Name').fill('Kya');
await page.getByRole('option', { name: /Hearthwright/i }).click();
await page.screenshot({ path: `${out}/ashfall-create.png`, fullPage: true });
await page.getByRole('button', { name: 'Enter Hollowmere' }).click();

await page.getByRole('heading', { name: 'Hollowmere' }).waitFor({ timeout: 10000 });
await page.screenshot({ path: `${out}/ashfall-play-start.png`, fullPage: true });

// Talk to mayor
const talk = page.getByRole('button', { name: /mayor|Mira/i }).first();
await talk.click();
await page.waitForTimeout(400);

await page.getByPlaceholder(/type what you try/i).fill('look around carefully');
await page.getByRole('button', { name: 'Try' }).click();
await page.waitForTimeout(400);

await page.getByRole('button', { name: /Candle & Crow/i }).click();
await page.getByRole('heading', { name: /Candle/i }).waitFor();

// Deliver letter if present
const deliver = page.getByRole('button', { name: /Deliver the letter/i });
if (await deliver.count()) {
  await deliver.click();
  await page.waitForTimeout(400);
}

await page.getByRole('button', { name: 'Save', exact: true }).click();
await page.getByText('Journey saved.').waitFor({ timeout: 5000 });
await page.screenshot({ path: `${out}/ashfall-play-candleinn.png`, fullPage: true });

const logText = await page.locator('.log').innerText();
console.log('LOG_SNIPPET:', logText.slice(0, 400).replace(/\n/g, ' | '));
console.log('SCREENSHOTS_OK');
await browser.close();
