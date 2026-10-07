# Microsoft desktop connections

In Settings → Accounts, choose **Add Microsoft account**. **Connect with BusyMax** uses an explicitly configured BusyMax-managed public registration. If this build has none, the action is unavailable with an explanation; original registrations are reserved for existing accounts and are never a fallback for new connections. Under **Other connection methods**, choose **Custom app registration**. No separate organization method is required.

## Custom app registration

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com/). Select a tenant where you can register applications, using Settings to switch directories if needed. Open **Entra ID → App registrations → New registration** and enter **BusyMax** in **Name**. If registration is blocked, ask the tenant administrator for app-registration access or a registration. See [Register an application](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app).
2. Under **Supported account types**, select the option that matches BusyMax's **Supported accounts** field, then **Register**:

   | Microsoft portal | BusyMax |
   | --- | --- |
   | Any Entra ID Tenant + Personal Microsoft accounts | Personal and organizational accounts |
   | Multiple Entra ID tenants | Organizational accounts |
   | Personal accounts only | Personal accounts |
   | Single tenant only – your tenant | One organizational tenant |

   In **Overview**, copy **Application (client) ID**. For one tenant, also copy **Directory (tenant) ID**. BusyMax requires the tenant ID only for that audience.
3. In **Authentication → Add a platform → Mobile and desktop applications**, select or enter **http://localhost**, then **Configure**. This is the existing system-browser redirect; the runtime uses an ephemeral loopback port. No client secret or confidential-client setup is needed. See [Desktop app configuration](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-configuration).
4. In **API permissions → Add a permission → Microsoft Graph → Delegated permissions**, search for each scope below and select **Add permissions**. Keep **User.Read** if already present. If organizational policy requires admin consent, ask an administrator to use **Grant admin consent** for the tenant. See [Configure API permissions](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-configure-app-access-web-apis).
5. Use Back to return to the form, paste **Application (client) ID**, choose the matching **Supported accounts**, and enter **Directory (tenant) ID** when shown. Select **Connect** and sign in to the intended account in your browser. Field checks are local validation; provider-side authorization and consent happen at Microsoft. BusyMax does not verify portal settings automatically.

## Required delegated scopes

```text
User.Read
Tasks.ReadWrite
Calendars.ReadWrite
openid
profile
email
offline_access
```

These match the existing `microsoftTodoOAuthScopes`. Shared-calendar (`Calendars.ReadWrite.Shared`) and category (`MailboxSettings.Read`) consent remain optional and are requested separately when those features are enabled; do not add them to mandatory onboarding permissions.

Instructions use the same setup modal with a fixed header and one scrolling body. Back preserves the form; Close cancels the whole setup. Audience changes clear the tenant both visibly and in submitted state. Valid staged configuration expires after ten minutes and is single-use. Re-enter/edit after expiry. Ordinary Reconnect, refresh, and optional consent use the registration saved with that account after restart. Explicit Replace registration preserves identity checks, rollback, and local data.

Android's native MSAL flow remains separate. The production app ID, audience, redirect, delegated permissions, and applicable consent are owner-controlled release prerequisites.
