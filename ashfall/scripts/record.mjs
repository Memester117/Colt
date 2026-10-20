import { chromium } from 'playwright';
import { mkdir, copyFile } from 'node:fs/promises';

const out = '/opt/cursor/artifacts';
await mkdir(`${out}/screenshots`, { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  recordVideo: { dir: `${out}/videos-tmp`, size: { width: 1280, height: 800 } },
});
const page = await context.newPage();
await page.goto('http://localhost:5173/', { waitUntil: 'networkidle' });
await page.waitForTimeout(600);
await page.getByRole('button', { name: 'Begin a journey' }).click();
await page.getByLabel('Name').fill('Kya');
await page.getByRole('option', { name: /Hearthwright/i }).click();
await page.waitForTimeout(400);
await page.getByRole('button', { name: 'Enter Hollowmere' }).click();
await page.getByRole('heading', { name: 'Hollowmere' }).waitFor();
await page.waitForTimeout(500);
await page.getByRole('button', { name: /mayor|Mira/i }).first().click();
await page.waitForTimeout(700);
await page.getByPlaceholder(/type what you try/i).fill('go to the candle inn');
await page.getByRole('button', { name: 'Try' }).click();
await page.waitForTimeout(900);
const deliver = page.getByRole('button', { name: /Deliver the letter/i });
if (await deliver.count()) {
  await deliver.click();
  await page.waitForTimeout(800);
}
await page.getByRole('button', { name: 'Save', exact: true }).click();
await page.getByText('Journey saved.').waitFor();
await page.waitForTimeout(600);
const vid = await page.video().path();
await context.close();
await browser.close();
await copyFile(vid, `${out}/ashfall-playthrough.webm`);
console.log('VIDEO', `${out}/ashfall-playthrough.webm`);
