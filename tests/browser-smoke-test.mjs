import { chromium } from 'playwright';
import fs from 'node:fs';

const appUrl = process.env.APP_URL || 'http://127.0.0.1:8787/';
const evidencePath = process.env.EVIDENCE_PATH || 'browser-smoke-evidence.json';
const cases = [
  { id: 'SYN_01', regimen: 'CAP', cycle: 1, age: 47.25, platelets: 137.5, haemoglobin: 10.35, expected: '14.9%', css: 'risk-lower' },
  { id: 'SYN_06', regimen: '5FUOXLIRI', cycle: 20, age: 78.75, platelets: 337.5, haemoglobin: 15.85, expected: '24.8%', css: 'risk-reference' },
  { id: 'SYN_02', regimen: 'CAPOXL', cycle: 4, age: 53.75, platelets: 177.5, haemoglobin: 11.45, expected: '51.7%', css: 'risk-higher' }
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function findAppFrame(page, timeoutMs = 180000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      if (await frame.locator('[data-testid="calculate-risk"]').count()) return frame;
    }
    await sleep(500);
  }
  throw new Error('The calculator button did not become available.');
}

async function waitForText(frame, selector, expected, timeoutMs = 45000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const locator = frame.locator(selector);
    if (await locator.count()) {
      const text = (await locator.first().textContent() || '').trim();
      if (text === expected) return text;
    }
    await sleep(250);
  }
  throw new Error(`Expected ${expected} in ${selector}.`);
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
const evidence = [];

try {
  await page.goto(appUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  const frame = await findAppFrame(page);

  for (const item of cases) {
    const regimenSelect = frame.locator('#regimen');
    await regimenSelect.waitFor({ state: 'attached' });
    await regimenSelect.evaluate((element, value) => {
      if (!element.selectize) {
        throw new Error('The Shiny regimen Selectize control is not initialised.');
      }
      element.selectize.setValue(value);
    }, item.regimen);
    await sleep(300);
    await frame.locator('#cycle').fill(String(item.cycle));
    await frame.locator('#age').fill(String(item.age));
    await frame.locator('#platelets').fill(String(item.platelets));
    await frame.locator('#haemoglobin').fill(String(item.haemoglobin));
    await frame.locator('[data-testid="calculate-risk"]').click();

    const observed = await waitForText(frame, '[data-testid="risk-value"]', item.expected);
    const card = frame.locator('[data-testid="risk-card"]');
    const className = await card.getAttribute('class');
    if (!className || !className.split(/\s+/).includes(item.css)) {
      throw new Error(`${item.id}: expected CSS class ${item.css}, observed ${className}.`);
    }
    evidence.push({ ...item, observed, observedClass: className, passed: true });
  }

  await page.screenshot({ path: 'browser-smoke-passed.png', fullPage: true });
  fs.writeFileSync(evidencePath, JSON.stringify({ appUrl, evidence }, null, 2));
  console.log(`Functional browser check passed: ${evidence.length}/${cases.length} cases.`);
} catch (error) {
  await page.screenshot({ path: 'browser-smoke-failed.png', fullPage: true }).catch(() => {});
  fs.writeFileSync(evidencePath, JSON.stringify({ appUrl, evidence, error: String(error) }, null, 2));
  throw error;
} finally {
  await browser.close();
}
