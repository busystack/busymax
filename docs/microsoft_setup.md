# Microsoft OAuth registration

This guide is for developers and release maintainers who configure a BusyMax
build. People installing an already configured package do not need their own
Microsoft Entra application.

BusyMax reads the public-client application ID from the compile-time setting
`MICROSOFT_OAUTH_CLIENT_ID`.

## Create the application registration

1. In the [Microsoft Entra admin center](https://entra.microsoft.com/), open
   **App registrations** and select **New registration**.
2. Enter an application name.
3. Select the supported account type that includes both organizational
   directories and personal Microsoft accounts.
4. Register the application and copy its **Application (client) ID**.
5. Under **Authentication**, add the **Mobile and desktop applications**
   platform and the redirect URI:

   ```text
   http://localhost
   ```

BusyMax opens the system browser and listens on an ephemeral localhost port.
Microsoft's
[desktop registration guidance](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-desktop-app-sign-in)
uses this redirect for a system-browser desktop flow.

## Add delegated permissions

Under **API permissions**, add these **delegated** Microsoft Graph permissions:

```text
User.Read
Tasks.ReadWrite
Calendars.ReadWrite
```

These are provider-console permission names. At runtime BusyMax requests their
fully qualified Graph scope strings together with the identity scopes
`openid`, `profile`, and `email`, plus `offline_access` so it can request
refresh tokens. See the official
[Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
and
[OpenID Connect scope reference](https://learn.microsoft.com/en-us/entra/identity-platform/scopes-oidc).

Supply the application ID as `MICROSOFT_OAUTH_CLIENT_ID`. It is embedded in
the desktop package, so treat it as public application configuration and do not
commit private build configuration. Do not create or embed a client secret:
BusyMax uses an authorization-code flow with PKCE as a public client, not a
confidential-client flow.
