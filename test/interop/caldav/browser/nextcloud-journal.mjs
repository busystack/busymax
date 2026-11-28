import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';

try {
  const { nextcloud: profile } = JSON.parse(readFileSync('/fixture/profile.json', 'utf8'));
  const authority = new URL(profile.authority);
  const login = new URL(readFileSync(0, 'utf8').trim());
  assert.equal(authority.protocol, 'https:');
  assert.equal(authority.hostname, 'localhost');
  assert.equal(login.origin, authority.origin);
  assert.equal(login.username, '');
  assert.equal(login.password, '');
  assert.match(login.pathname, /\/login\/v2\/flow\//);
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.route('**/*', route => {
      if (new URL(route.request().url()).origin === authority.origin) {
        return route.continue();
      }
      return route.abort();
    });
    await page.goto(login.href);
    await page.getByText('Alternative log in using app password', { exact: true }).click();
    await page.locator('input[name="user"]').fill(profile.username);
    const password = page.locator('input[name="password"]');
    await password.fill(profile.password);
    const [response] = await Promise.all([
      page.waitForResponse(response => {
        const request = response.request();
        return request.method() === 'POST' &&
          new URL(request.url()).origin === authority.origin &&
          request.postData()?.includes('password=');
      }),
      password.evaluate(field => field.form.requestSubmit()),
    ]);
    assert.ok(response.status() >= 200 && response.status() < 400);
    await response.finished();
    console.log('Nextcloud test browser submitted authorization.');
  } finally {
    await browser.close();
  }
} catch {
  // Browser exceptions can contain the login URL and its one-time token.
  console.error('Nextcloud test browser could not complete authorization.');
  process.exitCode = 1;
}
