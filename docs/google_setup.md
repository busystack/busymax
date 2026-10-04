# Google account setup

On Linux and Windows, BusyMax uses a Desktop OAuth client from your Google Cloud project. Configuration is saved with each account in operating-system credential storage. Android continues to use the approved native Google registration; do not import Desktop JSON on Android.

## Set up your project

1. Open the [Google Cloud Console](https://console.cloud.google.com/). Use the project selector at the top to select your own project, or choose **New project**, enter a name and select **Create**. Keep that project selected for the remaining steps.
2. Open **APIs & Services → Library**. Search for **Google Calendar API**, open its page and select **Enable**. Return to Library and repeat for **Google Tasks API**.
3. Open **Google Auth Platform → Branding**. For a new configuration, select **Get started**. Enter **BusyMax** as the app name, select your own support email and choose **Next**. In **Audience**, select **External** for a personal Google account; **Internal** is restricted to accounts in the project's organization. Choose **Next**, enter your email under **Contact Information**, then choose **Next**. Accept the User Data Policy and choose **Continue → Create**. If already configured, review Branding and Audience.
4. For **External** in **Testing**, open **Audience → Test users → Add users**, enter the Google account you will connect and choose **Save**. Only listed test users can connect; authorizations and refresh tokens expire after seven days. See [Google's audience requirements](https://support.google.com/cloud/answer/15549945?hl=en).
5. Open **Data Access → Add or remove scopes**. Select `openid`, `email`, `profile`, `https://www.googleapis.com/auth/tasks` and `https://www.googleapis.com/auth/calendar`, using **Manually add scopes** if needed. For manual entry, paste the missing values and choose **Add to table**. Choose **Update**, then **Save**. Both Calendar and Tasks access are required.
6. Open **Clients → Create client**. Set **Application type** to **Desktop app**, enter **BusyMax** as the name and select **Create**. In the creation dialog, select **Download JSON** and save the file.
7. In BusyMax Settings, add a Google account and choose **Choose file…**. Review the project and client ID, then select **Connect** and approve calendar and task access in your browser. **Setup instructions** opens an additional bounded modal with a fixed title and **×** close control, without a form footer. Close the instructions to return to the unchanged account form underneath. Required values have Copy controls; the scope group has **Copy all**. **Replace…** keeps the previous valid selection if you cancel or choose an invalid file.

The instructions follow Google's [consent-screen setup](https://developers.google.com/workspace/guides/configure-oauth-consent) and [desktop credential creation](https://developers.google.com/workspace/guides/create-credentials). They do not verify changes made in the Console.

Imported selections expire after ten minutes and are single-use. If the selection expires before connecting, select the JSON again.

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

Official desktop setup documents checked on 2026-10-04; no authenticated Console walkthrough was performed.
