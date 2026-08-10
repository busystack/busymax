# Microsoft OAuth setup

BusyMax requires a Microsoft public-client application ID, supplied as
`MICROSOFT_OAUTH_CLIENT_ID` at build time.

## Create the application registration

1. Open [Microsoft Entra](https://entra.microsoft.com/).
2. Go to **App registrations** and select **New registration**.
3. Enter an application name.
4. Select the account type that supports both organizational and personal
   Microsoft accounts.
5. Add a **Public client/native mobile and desktop** redirect URI:

   ```text
   http://localhost
   ```

6. Register the application and copy its **Application (client) ID**. Supply
   that value as `MICROSOFT_OAUTH_CLIENT_ID`.

## Add delegated Microsoft Graph permissions

Under **API permissions**, add these delegated Microsoft Graph permissions:

```text
User.Read
Tasks.ReadWrite
Calendars.ReadWrite
```

Do not create or embed a client secret. BusyMax uses the public-client OAuth
flow.
