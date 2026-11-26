import { chmodSync, readFileSync, writeFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { verifyPasskey } from './server-qualification/authentication.mjs';
import { issueDavCredential } from './server-qualification/dav-credentials.mjs';
import { provisionAccount } from './server-qualification/portal-helpers.mjs';

const base = 'https://localhost:18448';
const accounts = JSON.parse(readFileSync('/private/accounts.json', 'utf8'));
const adminPassword = readFileSync('/private/administrator-password', 'utf8').trim();
const credentials = { endpoint: base + '/dav/' };
const privateValues = [adminPassword, ...Object.values(accounts)];
const browser = await chromium.launch({ headless: true });

async function login(username, password) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('WebAuthn.enable');
  await cdp.send('WebAuthn.addVirtualAuthenticator', { options: {
    protocol: 'ctap2', transport: 'internal', hasResidentKey: true,
    hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true,
  } });
  await page.goto(base + '/login');
  await page.locator('input[name=username]').fill(username);
  await page.locator('input[name=password]').fill(password);
  await Promise.all([
    page.waitForURL(base + '/auth/continue'),
    page.getByRole('button', { name: 'Sign in', exact: true }).click(),
  ]);
  await page.goto(base + '/security/passkeys');
  await page.getByRole('button', { name: 'Create passkey', exact: true }).click();
  await page.locator('#security-status').filter({ hasText: 'Passkey created.' }).waitFor();
  await verifyPasskey(page, base);
  return { context, page };
}

try {
  const administrator = await login('administrator', adminPassword);
  for (const [username, password] of Object.entries(accounts)) {
    await provisionAccount(administrator.page, base, username, 'Journal QA ' + username, password);
  }
  await administrator.context.close();
  for (const [username, password] of Object.entries(accounts)) {
    const { context, page } = await login(username, password);
    const issued = await issueDavCredential(page, base, privateValues, 'VJOURNAL QA', username);
    credentials[username] = issued.credential;
    await context.close();
  }
  const output = '/fixture/busystack-credentials.json';
  writeFileSync(output, JSON.stringify(credentials), { mode: 0o600 });
  chmodSync(output, 0o600);
  console.log('Candidate fixture accounts and app passwords provisioned.');
} catch (error) {
  let message = String(error);
  for (const secret of privateValues) message = message.replaceAll(secret, '[redacted]');
  console.error(message);
  process.exitCode = 1;
} finally {
  await browser.close();
}
