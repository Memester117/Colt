import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
page.on('console', (m) => {
  if (m.type() === 'error') console.log('CONSOLE', m.text());
});
await page.goto('http://localhost:5173/', { waitUntil: 'networkidle' });
await page.getByRole('button', { name: 'Begin a journey' }).click();
await page.getByLabel('Name').fill('Kya');
await page.getByRole('tab', { name: 'Make my own' }).click();
await page.getByLabel('Describe your calling').fill('tired knight with a soft heart');
await page.waitForTimeout(400);
console.log('disabled', await page.getByRole('button', { name: 'Enter Hollowmere' }).isDisabled());
console.log('preview', await page.locator('.class-preview').innerText().catch(() => 'none'));
await page.getByRole('button', { name: 'Enter Hollowmere' }).click();
await page.waitForTimeout(1000);
console.log('h1', await page.locator('h1').allInnerTexts());
console.log('buttons', await page.locator('button').allInnerTexts());
await page.screenshot({ path: '/opt/cursor/artifacts/screenshots/ashfall-debug.png', fullPage: true });
await browser.close();
