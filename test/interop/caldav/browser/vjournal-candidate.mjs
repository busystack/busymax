import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { verifyPasskey } from './server-qualification/authentication.mjs';
import { issueDavCredential } from './server-qualification/dav-credentials.mjs';
import {
  grantDirect, openCollection, provisionAccount, revokeDirect,
} from './server-qualification/portal-helpers.mjs';

const base = 'https://localhost:18448';
const accounts = JSON.parse(readFileSync('/private/accounts.json', 'utf8'));
const administratorPassword = readFileSync('/private/administrator-password', 'utf8').trim();
const lifecycleFile = 'busystack-lifecycle-account.json';
const credentialsFile = 'busystack-credentials.json';
const authenticatorsFile = 'busystack-authenticators.json';
function load(file, fallback) {
  try {
    return JSON.parse(readFileSync('/fixture/' + file, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    return fallback;
  }
}
function save(file, value) {
  writeFileSync('/fixture/' + file, JSON.stringify(value), { mode: 0o600 });
}
const lifecycle = load(lifecycleFile, null);
const credentials = load(credentialsFile, { endpoint: base + '/dav/' });
const keys = load(authenticatorsFile, {});
const passwords = { ...accounts, administrator: administratorPassword };
if (lifecycle) passwords[lifecycle.username] = lifecycle.password;
const privateValues = [...Object.values(passwords), ...Object.values(credentials)];
for (const userKeys of Object.values(keys)) {
  for (const credential of userKeys) privateValues.push(credential.privateKey);
}
const browser = await chromium.launch({ headless: true });

async function withSession(username, operation) {
  assert.ok(passwords[username], 'Expected a recorded disposable fixture account');
  const context = await browser.newContext();
  try {
    const page = await context.newPage();
    const cdp = await context.newCDPSession(page);
    await cdp.send('WebAuthn.enable');
    const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', { options: {
      protocol: 'ctap2', transport: 'internal', hasResidentKey: true,
      hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true,
    } });
    for (const credential of (keys[username] ?? [])) {
      await cdp.send('WebAuthn.addCredential', { authenticatorId, credential });
    }
    await page.goto(base + '/login');
    await page.locator('input[name=username]').fill(username);
    await page.locator('input[name=password]').fill(passwords[username]);
    await Promise.all([
      page.waitForURL(base + '/auth/continue'),
      page.getByRole('button', { name: 'Sign in', exact: true }).click(),
    ]);
    if (!keys[username]?.length) {
      await page.goto(base + '/security/passkeys');
      await page.getByRole('button', { name: 'Create passkey', exact: true }).click();
      await page.locator('#security-status').filter({ hasText: 'Passkey created.' }).waitFor();
    }
    await verifyPasskey(page, base);
    keys[username] = (await cdp.send('WebAuthn.getCredentials', { authenticatorId })).credentials;
    for (const credential of keys[username]) privateValues.push(credential.privateKey);
    save(authenticatorsFile, keys);
    await operation(page);
  } finally {
    await context.close();
  }
}

async function issue(username, label) {
  await withSession(username, async (page) => {
    const issued = await issueDavCredential(page, base, privateValues, label, username);
    credentials[username] = issued.credential;
    save(credentialsFile, credentials);
  });
}

async function groupPage(page, name) {
  await page.goto(base + '/admin/groups');
  await page.getByRole('link', { name, exact: true }).click();
  return new URL(page.url()).pathname.split('/').at(-1);
}

async function configureMembers(page, group, member) {
  const memberTable = page.locator('table').filter({
    has: page.getByRole('button', { name: 'Remove member', exact: true }),
  });
  let removals = memberTable.getByRole('button', { name: 'Remove member', exact: true });
  while (await removals.count()) {
    const form = removals.first().locator('..');
    await form.locator('input[name=confirmed]').check();
    await Promise.all([page.waitForURL(base + '/admin/groups/' + group), removals.first().click()]);
  }
  if (member) {
    const form = page.locator('form[action="/admin/groups/' + group + '/members"]');
    await form.locator('input[name=username]').fill(member);
    await form.locator('input[name=confirmed]').check();
    await Promise.all([page.waitForURL(base + '/admin/groups/' + group),
      form.getByRole('button', { name: 'Add member', exact: true }).click()]);
  }
}

async function execute([action, ...args]) {
  switch (action) {
    case 'provision':
      await withSession('administrator', async (page) => {
        for (const [username, password] of Object.entries(accounts)) {
          await provisionAccount(page, base, username, 'Journal QA ' + username, password);
        }
      });
      for (const username of Object.keys(accounts)) await issue(username, 'VJOURNAL QA');
      break;
    case 'prepare-lifecycle': {
      const username = 'busymax-life-' + randomBytes(6).toString('hex');
      const password = randomBytes(32).toString('base64url');
      privateValues.push(password);
      passwords[username] = password;
      const account = { username, password };
      await withSession('administrator', async (page) => {
        account.id = await provisionAccount(page, base, username, 'BusyMax lifecycle fixture', password);
      });
      save(lifecycleFile, account);
      await issue(username, 'BusyMax QA primary');
      break;
    }
    case 'issue':
      await issue(args[0], args[1]);
      break;
    case 'revoke':
      await withSession(args[0], async (page) => {
        await page.goto(base + '/security/credentials');
        const row = page.locator('tbody tr').filter({ hasText: args[1] });
        await Promise.all([page.waitForURL(base + '/security/credentials'),
          row.getByRole('button', { name: 'Revoke', exact: true }).click()]);
      });
      break;
    case 'disable':
      assert.equal(args[0], lifecycle?.username);
      await withSession('administrator', async (page) => {
        const url = base + '/admin/accounts/' + lifecycle.id;
        await page.goto(url);
        const form = page.locator('form[action="/admin/accounts/' + lifecycle.id + '/disable"]');
        await form.locator('input[name=confirmed]').check();
        await Promise.all([page.waitForURL(url), form.getByRole('button', { name: 'Disable account', exact: true }).click()]);
        await page.getByText('Disabled', { exact: true }).waitFor();
      });
      break;
    case 'share': {
      const [owner, title, username, permission] = args;
      await withSession(owner, async (page) => {
        const collection = await openCollection(page, base, title);
        if (permission === 'REVOKE') {
          await revokeDirect(page, base, collection, username);
        } else {
          const url = base + '/collections/' + collection + '/sharing';
          await page.goto(url);
          const row = page.locator('table').filter({
            has: page.locator('caption').filter({ hasText: 'Accounts with direct grants' }),
          }).locator('tbody tr').filter({ has: page.getByText(username, { exact: true }) });
          if (await row.count()) {
            await row.locator('select[name=permission]').selectOption(permission);
            await Promise.all([page.waitForURL(url),
              row.getByRole('button', { name: 'Save direct grant', exact: true }).click()]);
          } else {
            await grantDirect(page, base, collection, username, permission);
          }
        }
      });
      break;
    }
    case 'group-create':
    case 'group-members':
    case 'group-delete': {
      const [name, member] = args;
      await withSession('administrator', async (page) => {
        let group;
        if (action === 'group-create') {
          await page.goto(base + '/admin/groups');
          const form = page.locator('form[action="/admin/groups"]');
          await form.locator('input[name=name]').fill(name);
          await Promise.all([page.waitForURL(/\/admin\/groups\/[a-f0-9-]{36}$/i),
            form.getByRole('button', { name: 'Create group', exact: true }).click()]);
          group = new URL(page.url()).pathname.split('/').at(-1);
        } else {
          group = await groupPage(page, name);
        }
        if (action === 'group-delete') {
          const form = page.locator('form[action="/admin/groups/' + group + '/delete"]');
          await form.locator('input[name=confirmed]').check();
          await Promise.all([page.waitForURL(base + '/admin/groups'),
            form.getByRole('button', { name: 'Delete group', exact: true }).click()]);
        } else {
          await configureMembers(page, group, member);
        }
      });
      break;
    }
    case 'group-share': {
      const [owner, title, group, permission] = args;
      await withSession(owner, async (page) => {
        const collection = await openCollection(page, base, title);
        const url = base + '/collections/' + collection + '/sharing';
        await page.goto(url);
        const row = page.locator('table').filter({
          has: page.locator('caption').filter({ hasText: 'Groups with grants for this collection' }),
        }).locator('tbody tr').filter({ has: page.getByText(group, { exact: true }) });
        if (await row.count()) {
          await row.locator('select[name=permission]').selectOption(permission);
          await Promise.all([page.waitForURL(url), row.getByRole('button', { name: 'Save group grant', exact: true }).click()]);
        } else {
          const form = page.locator('form[action="/group-shares"]').filter({ has: page.locator('select[name=group]') });
          await form.locator('..').locator('summary').click();
          await form.locator('select[name=group]').selectOption({ label: group });
          await form.locator('select[name=permission]').selectOption(permission);
          await Promise.all([page.waitForURL(url), form.getByRole('button', { name: 'Grant group access', exact: true }).click()]);
        }
      });
      break;
    }
    default:
      throw Error('Unknown candidate browser action');
  }
  console.log('Candidate fixture action completed: ' + action);
}

try {
  await execute(process.argv.slice(2));
} catch (error) {
  let message = String(error);
  for (const secret of privateValues.filter(Boolean)) message = message.replaceAll(secret, '[redacted]');
  console.error(message);
  process.exitCode = 1;
} finally {
  await browser.close();
}
