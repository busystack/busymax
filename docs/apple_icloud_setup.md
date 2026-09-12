# Apple iCloud Calendar setup

BusyMax connects to Apple iCloud Calendar from Linux and Windows. It
synchronizes calendar collections and events; Apple Reminders is not supported.

## Before connecting

You need:

- an Apple Account with two-factor authentication enabled;
- the email address for that Apple Account; and
- a dedicated app-specific password for BusyMax.

Do not enter your primary Apple Account password in BusyMax.

## Connect

1. Sign in at [account.apple.com](https://account.apple.com/).
2. Open **Sign-In and Security > App-Specific Passwords**.
3. Generate a password with a recognizable label such as `BusyMax`.
4. In BusyMax, open **Add account** and choose **Apple iCloud Calendar**.
5. Enter the Apple Account email and the complete app-specific password.
6. Select **Connect**. BusyMax validates the credential and discovers the
   account's calendars before saving the account.

BusyMax connects only to Apple iCloud over HTTPS with normal platform
certificate validation. This profile cannot connect to arbitrary CalDAV
servers.

## Calendars and editing

BusyMax shows discovered event calendars and follows their reported
permissions. Shared or subscribed read-only calendars remain visible without
editing controls. Event data is cached for offline viewing; supported edits to
writable calendars can be queued and synchronized later with conflict checks.

Creating, deleting, renaming, recoloring, or reordering iCloud calendar
collections is not supported. BusyMax also does not support Apple Reminders,
calendar invitations, or scheduling changes for this provider. See the
[provider support matrix](provider_support_matrix.md).

## Reconnect, revoke, or remove

- If Apple rejects the credential, use **Reconnect** with a replacement
  app-specific password. Cached content and pending work remain available while
  reconnection is required.
- To revoke access remotely, delete the BusyMax app-specific password under
  **Sign-In and Security > App-Specific Passwords** at
  [account.apple.com](https://account.apple.com/). BusyMax cannot revoke it
  remotely through Calendar.
- Removing the account in BusyMax removes its local credential and local
  account data. It does **not** revoke the app-specific password at Apple, so
  revoke that password separately.
- Apple states that changing or resetting the primary Apple Account password
  revokes all app-specific passwords.

Apple's current guidance is
[Sign in to apps with your Apple Account using app-specific passwords](https://support.apple.com/en-gb/102654)
and
[Access your iCloud data in third-party apps](https://support.apple.com/en-ie/121539).
