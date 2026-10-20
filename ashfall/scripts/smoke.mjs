import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const out = '/opt/cursor/artifacts/screenshots';
await mkdir(out, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
await page.goto('http://localhost:5173/', { waitUntil: 'networkidle' });

await page.getByRole('button', { name: 'Begin a journey' }).click();
await page.getByLabel('Name').fill('Kya');
await page.getByRole('tab', { name: 'Make my own' }).click();
await page.getByLabel('Describe your calling').fill('tired knight with a soft heart');
await page.waitForTimeout(200);
await page.screenshot({ path: `${out}/ashfall-custom-class.png`, fullPage: true });
await page.getByRole('button', { name: 'Enter Hollowmere' }).click();
await page.getByRole('heading', { name: 'Hollowmere' }).waitFor({ timeout: 10000 });

await page.getByRole('button', { name: 'Mayor' }).click();
await page.waitForTimeout(300);
await page.getByRole('button', { name: /Look · rest · wait/i }).click();
await page.getByRole('button', { name: 'Look around' }).click();
await page.waitForTimeout(300);
await page.getByRole('button', { name: /Go somewhere/i }).click();
await page.getByRole('button', { name: /Candle/i }).click();
await page.getByRole('heading', { name: /Candle/i }).waitFor();
await page.screenshot({ path: `${out}/ashfall-decluttered-play.png`, fullPage: true });

console.log('SMOKE_OK');
await browser.close();
