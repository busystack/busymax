import {randomBytes} from 'node:crypto';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, existsSync, chownSync} from 'node:fs';

const base = 'https://localhost:18448';
const runtime = '/fixtures/.runtime/';
const passwords = JSON.parse(readFileSync('/private/accounts.json', 'utf8'));
passwords.administrator = readFileSync('/private/administrator-password', 'utf8').trimEnd();
const lifecycleFile = runtime + 'busystack-lifecycle-account.json';
if (existsSync(lifecycleFile)) {
  const account = JSON.parse(readFileSync(lifecycleFile, 'utf8'));
  passwords[account.username] = account.password;
}
const keyFile = runtime + 'busystack-authenticators.json';
const keys = existsSync(keyFile) ? JSON.parse(readFileSync(keyFile, 'utf8')) : {};
const credentialFile = runtime + 'busystack-credentials.json';
const credentials = existsSync(credentialFile) ? JSON.parse(readFileSync(credentialFile, 'utf8')) : {};
const privateValues = Object.values(passwords);
function save(path, value) {
  writeFileSync(path, JSON.stringify(value), {mode: 0o600});
  chownSync(path, 1000, 1000);
}
const browser = await chromium.launch({headless: true});
console.log('Browser qualification: Playwright 1.61.1; Chromium ' + browser.version());
async function login(username) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('WebAuthn.enable');
  const {authenticatorId} = await cdp.send('WebAuthn.addVirtualAuthenticator', {options: {
    protocol: 'ctap2', transport: 'internal', hasResidentKey: true,
    hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true,
  }});
  for (const credential of keys[username] || []) {
    privateValues.push(credential.privateKey);
    await cdp.send('WebAuthn.addCredential', {authenticatorId, credential});
  }
  await page.goto(base + '/login');
  await page.locator('input[name=username]').fill(username);
  await page.locator('input[name=password]').fill(passwords[username]);
  await Promise.all([page.waitForURL(base + '/'), page.getByRole('button', {name: 'Verify password', exact: true}).click()]);
  if (!keys[username]?.length) {
    await page.goto(base + '/security/passkeys');
    await page.getByRole('button', {name: 'Register passkey', exact: true}).click();
    await page.locator('#security-status').filter({hasText: 'Passkey registered.'}).waitFor();
    await Promise.all([page.waitForURL(base + '/'), page.getByRole('button', {name: 'Verify passkey to complete MFA', exact: true}).click()]);
  } else {
    await page.goto(base + '/login');
    await Promise.all([page.waitForURL(base + '/'), page.getByRole('button', {name: 'Verify passkey', exact: true}).click()]);
  }
  keys[username] = (await cdp.send('WebAuthn.getCredentials', {authenticatorId})).credentials;
  save(keyFile, keys);
  return {context, page};
}
async function issue(username, label) {
  const {context, page} = await login(username);
  const displayed = await page.locator('section').filter({has: page.getByRole('heading', {name: 'Connect a CalDAV client', exact: true})}).locator('code').allTextContents();
  assert.equal(displayed[1], username);
  const form = page.locator('form[action="/credentials"]');
  await form.locator('input[name=label]').fill(label);
  await form.locator('input[name=days]').fill('1');
  const [response] = await Promise.all([page.waitForResponse(r => r.url() === base + '/credentials' && r.request().method() === 'POST'),
    form.getByRole('button', {name: 'Issue credential', exact: true}).click()]);
  assert.ok((response.headers()['cache-control'] || '').includes('no-store'));
  await page.getByRole('heading', {name: 'New DAV credential', exact: true}).waitFor();
  const secret = await page.locator('code').innerText();
  assert.equal(secret.length, 80);
  privateValues.push(secret, Buffer.from(username + ':' + secret).toString('base64'));
  credentials[username] = secret;
  credentials.endpoint = displayed[0];
  save(credentialFile, credentials);
  if (username === 'alice') save(runtime + 'busystack-credential-label.json', {label, credentialId: secret.split('.')[0]});
  await context.close();
}
try {
  const mode = process.argv[2] || 'provision';
  if (mode === 'prepare-lifecycle') {
    const username = 'busymax-life-' + randomBytes(6).toString('hex');
    const password = randomBytes(32).toString('base64url');
    privateValues.push(password);
    passwords[username] = password;
    save(lifecycleFile, {username, password, owner: 'BusyMax isolated lifecycle qualification'});
    const {context, page} = await login('administrator');
    await page.goto(base + '/admin');
    const form = page.locator('form[action="/admin/accounts"]');
    await form.locator('input[name=username]').fill(username);
    await form.locator('input[name=displayName]').fill('BusyMax disposable lifecycle QA');
    await form.locator('input[name=password]').fill(password);
    await Promise.all([page.waitForURL(base + '/admin'), form.getByRole('button', {name: 'Create account', exact: true}).click()]);
    await page.locator('li').filter({hasText: username}).waitFor();
    await context.close();
    await issue(username, 'BusyMax QA primary');
    console.log('Fresh disposable lifecycle account provisioned through supported administration and MFA (identity not printed).');
  } else if (mode === 'provision') {
    const {context, page} = await login('administrator');
    for (const username of ['alice', 'bob', 'disabled']) {
      await page.goto(base + '/admin');
      const form = page.locator('form[action="/admin/accounts"]');
      await form.locator('input[name=username]').fill(username);
      await form.locator('input[name=displayName]').fill('BusyMax QA ' + username);
      await form.locator('input[name=password]').fill(passwords[username]);
      await Promise.all([page.waitForURL(base + '/admin'), form.getByRole('button', {name: 'Create account', exact: true}).click()]);
      await page.locator('li').filter({hasText: username}).waitFor();
    }
    await context.close();
    for (const username of ['alice', 'bob', 'disabled']) await issue(username, 'BusyMax QA primary');
    console.log('Supported administrator provisioning, password plus WebAuthn MFA and named DAV credential issuance passed.');
  } else if (mode === 'share') {
    const [owner, name, recipient, permission] = process.argv.slice(3);
    assert.ok(['READ', 'WRITE', 'REVOKE'].includes(permission));
    const {context, page} = await login(owner);
    const form = page.locator('form[action="/shares"]').filter({has: page.locator('select[name=collection]')});
    await form.locator('select[name=collection]').selectOption({label: name});
    await form.locator('input[name=username]').fill(recipient);
    await form.locator('select[name=permission]').selectOption(permission);
    await Promise.all([page.waitForURL(base + '/'), form.getByRole('button', {name: 'Save access', exact: true}).click()]);
    await context.close();
    console.log('Owner-controlled sharing workflow completed.');
  } else if (['group-create', 'group-members', 'group-delete'].includes(mode)) {
    const [name, members = ''] = process.argv.slice(3);
    const {context, page} = await login('administrator');
    await page.goto(base + '/admin/groups');
    if (mode === 'group-create') {
      const form = page.locator('form[action="/admin/groups"]');
      await form.locator('input[name=name]').fill(name);
      await form.locator('textarea[name=usernames]').fill(members);
      await Promise.all([page.waitForURL(base + '/admin/groups'), form.getByRole('button', {name: 'Create group', exact: true}).click()]);
    } else {
      const card = page.locator('article').filter({has: page.getByRole('heading', {name, exact: true})});
      if (mode === 'group-members') {
        await card.locator('textarea[name=usernames]').fill(members);
        await Promise.all([page.waitForURL(base + '/admin/groups'), card.getByRole('button', {name: 'Save group', exact: true}).click()]);
      } else {
        await Promise.all([page.waitForURL(base + '/admin/groups'), card.getByRole('button', {name: 'Delete group', exact: true}).click()]);
      }
    }
    await context.close();
    console.log('Supported sharing-group administration completed.');
  } else if (mode === 'group-share') {
    const [owner, name, group, permission] = process.argv.slice(3);
    assert.ok(['READ', 'WRITE'].includes(permission));
    const {context, page} = await login(owner);
    const form = page.locator('form[action="/group-shares"]');
    await form.locator('select[name=collection]').selectOption({label: name});
    await form.locator('select[name=group]').selectOption({label: group});
    await form.locator('select[name=permission]').selectOption(permission);
    await Promise.all([page.waitForURL(base + '/'), form.getByRole('button', {name: 'Save group access', exact: true}).click()]);
    await context.close();
    console.log('Owner-controlled group sharing completed.');
  } else if (mode === 'issue') {
    await issue(process.argv[3], process.argv[4]);
    console.log('Named DAV credential issued through completed MFA.');
  } else if (mode === 'revoke') {
    const {context, page} = await login(process.argv[3]);
    const entry = page.locator('li').filter({hasText: process.argv[4]});
    await Promise.all([page.waitForURL(base + '/'), entry.getByRole('button', {name: 'Revoke', exact: true}).click()]);
    await context.close();
    console.log('Named DAV credential revoked through completed MFA.');
  } else if (mode === 'disable') {
    const {context, page} = await login('administrator');
    await page.goto(base + '/admin');
    const entry = page.locator('li').filter({hasText: process.argv[3]});
    await Promise.all([page.waitForURL(base + '/admin'), entry.getByRole('button', {name: 'Disable account', exact: true}).click()]);
    await context.close();
    console.log('Disposable account disabled through supported administration.');
  } else {
    throw Error('Unknown browser fixture action');
  }
} catch (error) {
  let diagnostic = String(error.stack || error);
  for (const value of [...privateValues, ...Object.values(credentials)]) {
    if (typeof value === 'string' && value.length > 8) diagnostic = diagnostic.replaceAll(value, '[redacted]');
  }
  console.error(diagnostic);
  process.exitCode = 1;
} finally {
  await browser.close();
}
