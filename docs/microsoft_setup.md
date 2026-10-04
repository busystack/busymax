# Microsoft account setup

BusyMax connects with a user-provided **public/native application registration**. Linux and Windows use the system browser and localhost callback. Android keeps native MSAL and supports multiple accounts with registration-specific client selection. **No client secret or signing private key is required.**

## Registration access and supported accounts

You need access to an Entra tenant that permits app registration and an appropriate role or administrator assistance. A personal Microsoft account can sign in to an application whose audience includes personal accounts, but it does not automatically have tenant app-registration privileges. Microsoft's [registration quickstart](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app) describes current prerequisites and roles.

1. Sign in to the [Entra admin center](https://entra.microsoft.com/). Use **Settings** to choose a tenant where you can register applications. Open **Entra ID → App registrations → New registration** and enter **BusyMax** as the name. Ask the tenant administrator for access if registration is blocked.
2. Under **Supported account types**, choose **Personal accounts only**, **Multiple Entra ID tenants**, **Any Entra ID Tenant + Personal Microsoft accounts**, or **Single tenant only**, matching the audience you will select in BusyMax. Select **Register**.
3. From **Overview**, copy **Application (client) ID**. This identifies the application. **Directory (tenant) ID** identifies a directory and is a different value.
4. In BusyMax, enter the client ID and matching audience. For one organizational tenant, also enter its tenant UUID. The configured sign-in authority (`common`, `organizations`, `consumers`, or the selected tenant UUID) is distinct from the authenticated account's actual tenant context.

BusyMax constructs authority endpoints on `login.microsoftonline.com` and uses Microsoft Graph. Arbitrary authority URLs, alternate clouds, Graph hosts, application permissions, client secrets and private keys are not accepted by setup.

## Linux and Windows redirect

Open **Authentication → Add a platform → Mobile and desktop applications**. Select or enter the system-browser redirect **`http://localhost`**, then select **Configure** to save it. BusyMax listens on an ephemeral localhost port. Configure a public desktop client, not a confidential Web application. See [Microsoft's desktop registration guidance](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration). PKCE, state and the redirect destination are application-controlled.

## Android redirect

Open Microsoft setup in the installed BusyMax app. It shows the package name, signature hash and redirect URI calculated from **that installed signing identity**, and checks the manifest callback configuration. Add the Android platform to the registration using those displayed public values. A development build and a distribution build may have different signing certificates: do not copy another variant's signature hash. Do not supply a signing private key.

MSAL configuration includes client ID, redirect URI, authority/audience and `MULTIPLE` account mode. BusyMax selects the registration and native account for silent acquisition and optional consent; it does not export refresh tokens or implement its own cache. A correctly signed build needs a matching manifest redirect even when the shared registration is omitted. See [MSAL Android configuration](https://learn.microsoft.com/en-us/entra/msal/android/msal-configuration).

## Delegated permissions and authorization

Open **API permissions → Add a permission → Microsoft Graph → Delegated permissions**. Search for and select `User.Read`, `Tasks.ReadWrite`, `Calendars.ReadWrite`, `openid`, `profile`, `email` and `offline_access`, then select **Add permissions**. Keep `User.Read` if already present. If the organization requires administrator consent, ask an administrator to use **Grant admin consent** for the tenant. BusyMax also requests `openid profile email offline_access` in the desktop authorization flow. Do not select application permissions. Depending on tenant policy, an administrator may need to approve consent; app registration alone does not guarantee permission approval.

`Calendars.ReadWrite.Shared` is requested explicitly when opening shared calendars. `MailboxSettings.Read` is requested explicitly for category lookup. Neither is a mandatory new-account permission. Base Calendar and Tasks functionality remains available if optional consent is declined. See the [Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference).

In BusyMax Settings, enter the client ID and matching **Supported accounts**. **Directory (tenant) ID** appears only for **One organizational tenant**; switching away clears it. Fields are checked locally as you edit and again when you press **Connect**. This check does not contact Microsoft or verify portal settings. Authorize the intended account in your browser and verify both Calendar and To Do reads. Staged selections expire after ten minutes; edit or re-enter the fields if the selection expires. **Setup instructions** opens an additional bounded modal with a fixed title and **×** close control, without a form footer. Close the instructions to return to the unchanged account form underneath. Required values have Copy controls; scopes are grouped once with **Copy all**. Reconnect uses the current registration. Replace registration targets that same Graph identity and tenant, preserving the local account ID and data.

## Existing shared accounts

During this release, eligible existing desktop and Android Microsoft accounts continue through their original registration and display an account-specific retirement notice. **Migrate now** opens setup targeted to that account. Successful migration removes only its notice, survives restart and does not offer a return to the shared registration. Cancellation, wrong-account consent, insufficient scopes, timeout or storage failure preserves existing authorization and local data. Retirement is controlled by the owner in the next release; there is no calendar expiry or remote disable mechanism in BusyMax.

## Troubleshooting

- **Audience/tenant mismatch:** use supported account types matching the form. Personal accounts need personal support; a tenant-specific choice requires its Directory/tenant UUID.
- **Wrong client ID/type/redirect:** use Application/client ID from a public/native registration; desktop needs `http://localhost`, Android needs the installed package/signature redirect.
- **Wrong account:** authorize the selected Graph user in the same actual tenant. A login hint or matching email is not an identity check.
- **Missing scopes/admin restriction:** grant the delegated base permissions or ask the tenant administrator. Optional consent is feature-specific.
- **Secure storage/configuration unavailable:** repair configuration or unlock credential storage and retry; do not remove an account to migrate it.
- **Outage or throttling:** wait and retain credentials. BusyMax honors `Retry-After` and stores long cooldowns rather than retrying early. See [Graph throttling](https://learn.microsoft.com/en-us/graph/throttling).

Official desktop setup documents checked on 2026-10-04; no authenticated Entra portal walkthrough was performed.
