# Apple iCloud Calendar setup

BusyMax connects directly to Apple iCloud Calendar over CalDAV. This profile
synchronizes calendar collections and `VEVENT` resources only. It does not
connect to Apple Reminders.

## Before connecting

You need:

- an Apple Account with two-factor authentication enabled;
- the email address used by that Apple Account; and
- a dedicated app-specific password for BusyMax.

Do not enter your primary Apple Account password in BusyMax. Apple documents
app-specific passwords as the fallback for third-party apps that cannot use
Apple's account-authorization contract. BusyMax's Linux client does not use an
undocumented Apple authorization flow.

## Create the password and connect

1. Sign in at [account.apple.com](https://account.apple.com/).
2. Open **Sign-In and Security**, then **App-Specific Passwords**.
3. Generate a password with a recognizable label such as `BusyMax Linux`.
4. In BusyMax, open **Add account** and choose **Apple iCloud Calendar**.
5. Enter the Apple Account email and the complete generated password. BusyMax
   trims accidental whitespace but otherwise treats the password as opaque.
6. Select **Connect**. BusyMax validates the credential and discovers the
   account's calendars before saving it.

BusyMax starts discovery at `https://caldav.icloud.com/`, follows only
validated Apple iCloud CalDAV destinations, and requires normal platform TLS
certificate validation. There is no invalid-certificate, HTTP, or custom
iCloud-server option.

## Calendars and editing

BusyMax shows discovered event calendars and derives whether each one is
writable from DAV privileges. Shared or subscribed read-only calendars remain
visible but their edit controls are disabled. Event content is cached locally
for offline viewing; offline edits to writable calendars are queued and later
sent with conditional ETag checks.

Calendar collection creation, deletion, rename, color, and ordering are not
supported for iCloud. Invitations and scheduling changes are also not
supported.

## Reconnect, revoke, or remove

- If Apple rejects the credential, existing cached data and pending work stay
  local. Generate a replacement app-specific password, then use **Reconnect**.
- To revoke access remotely, remove the BusyMax password at
  [account.apple.com](https://account.apple.com/) under **App-Specific
  Passwords**. BusyMax cannot revoke an Apple password through CalDAV.
- Removing the account from BusyMax removes its local credential, cached DAV
  objects, projections, cursors, conflicts, and pending operations. It does
  not revoke the remote Apple password; revoke it manually as well.
- Apple states that changing or resetting the primary Apple Account password
  automatically revokes all app-specific passwords.

Apple's current instructions are [Sign in to apps with your Apple Account
using app-specific passwords](https://support.apple.com/en-gb/102654) and
[Access your iCloud Mail, Calendar and Contacts in third-party
apps](https://support.apple.com/en-ie/121539).

This setup is specific to Apple iCloud and cannot be used for arbitrary CalDAV
servers.
