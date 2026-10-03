# Google account setup

On Linux and Windows, BusyMax uses a Desktop OAuth client from your Google Cloud project. Configuration is saved with each account in operating-system credential storage. Android continues to use the approved native Google registration; do not import Desktop JSON on Android.

## Set up your project

1. In the [Google Cloud console](https://console.cloud.google.com/), create a project that you own or administer. Adding another client inside BusyStack's project does not create your own project or isolate project quota. The JSON project identifier is a description, not proof of ownership.
2. Enable **Google Calendar API** and **Google Tasks API** in that project.
3. Complete Google Auth Platform's Branding, Audience, Contact Information and Data Access sections. Follow the fields and verification requirements shown for your configuration; BusyMax cannot promise that branding, privacy-policy, domain or ownership fields may be omitted.
4. Add `openid`, `email`, `profile`, `https://www.googleapis.com/auth/tasks` and `https://www.googleapis.com/auth/calendar`. The identity scopes identify the account; both API scopes are required for BusyMax's unified Calendar and Tasks connection.
5. Under Clients, create a **Desktop app** OAuth client and download its JSON configuration. Do not create a Web client or service account. No Drive permission or API key is needed.
6. In BusyMax's account setup, read the guide, select the downloaded JSON, review the client/project summary, and authorize in the system browser. Select the intended Google account and grant both Calendar and Tasks access.
7. Refresh and verify a calendar and task list. Reconnect uses the account's current client. Replace registration authorizes a different client for that same account without changing its local ID.

The importer accepts `installed` configuration with a client ID, project ID and optional client secret, up to 64 KiB. It snapshots the file without modifying it; the original can be moved afterward. A configuration file describes your client, whereas a token file contains issued credentials and cannot be imported. Never share either file publicly. Imported endpoint URLs and redirect arrays cannot redirect credentials. BusyMax controls endpoints, scopes, PKCE and its ephemeral loopback callback. See [Google's native-app OAuth protocol](https://developers.google.com/identity/protocols/oauth2/native-app).

## Publishing, verification and organizational policies

External apps in **Testing** need listed test users. For BusyMax's API scopes, test authorization and refresh tokens expire after seven days. **In production** changes publishing status; it does not itself verify your app or guarantee permission approval. Unapproved sensitive/restricted scopes can still show an unverified-app warning and be subject to user caps. Internal audience is available for projects associated with an organization and limits access to that organization. Workspace or Advanced Protection restrictions may block authorization. See [Google's audience and publishing rules](https://support.google.com/cloud/answer/15549945?hl=en).

Small personal-use projects may qualify for verification exceptions, but those exceptions do not eliminate testing-token expiry, organization policy or all console requirements. Check the current [verification exceptions and requirements](https://support.google.com/cloud/answer/13464321) before publishing beyond personal use. Supply accurate branding, contacts and any required verified domains; do not impersonate BusyStack's official registration.

## Existing-account migration

Only accounts bound to the retiring desktop shared client display a retirement notice. They retain refresh, sync and reconnect during this release. Choose **Migrate now** on that account, configure your own project and authorize the same provider identity. Calendars, tasks, cached events, queued local changes and collection choices stay in place. Cancellation or failed authorization leaves the old connection and notice intact. After success, the account stays on its new registration across restart and has no switch back to the retiring registration. Removing/re-adding the account is not migration.

If the original registration is unavailable or provenance cannot be established, BusyMax preserves the account and credential record and reports that configuration problem. Do not try different clients with an old refresh token to discover its issuer.

## Troubleshooting

- **Wrong client type or malformed JSON:** download an installed Desktop client, not Web, service-account or token JSON. Use a regular local file; oversized and unsupported file sources are rejected.
- **Wrong account:** authorize the account selected for reconnect/migration. Email alone is insufficient; BusyMax checks the provider subject.
- **Missing permission/offline access:** grant both Calendar and Tasks and authorize again. A different client needs its own refresh token.
- **Redirect/browser failure:** use a Desktop client, allow the system browser and local callback, close stale tabs and retry.
- **Administrator restriction or testing expiry:** review project audience and organization policies; reconnect with the same configured client after addressing the cause.
- **Secure storage unavailable:** unlock or repair the operating-system credential store before retrying. Account data is retained.
- **Temporary outage/throttling:** wait for the provider cooldown; reconnecting or migrating does not fix quota errors.

User-owned projects still need efficient requests. Tasks has a documented 50,000-query/day courtesy limit, actual project quotas vary, and requested increases are not guaranteed. Calendar also applies project and per-user/project quotas. See [Tasks limits](https://developers.google.com/workspace/tasks/limits) and [Calendar quota guidance](https://developers.google.com/workspace/calendar/api/guides/quota).

Android's Google OAuth identity depends on the unique package/signing-certificate pairing. Desktop JSON cannot replace that native registration. The desktop client's retirement does **not** authorize deletion of the Cloud project still needed by Android. See [Google's pairing constraint](https://support.google.com/firebase/answer/6401008?hl=en).

Official documents checked during implementation; no authenticated Console walkthrough was performed.
