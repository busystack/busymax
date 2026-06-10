# Microsoft Setup

This setup is required to get `MICROSOFT_OAUTH_CLIENT_ID`.

## 1 Create app registration

Open Microsoft Entra: https://entra.microsoft.com

Go to:

```text
App registrations -> New registration
```

Enter:
- **Name**: <APP NAME>
- **Supported account types**: `Any Entra ID Tenant + Personal Microsoft accounts`
- **Redirect**: `Public client/native mobile & desktop` with url `http://localhost`

Click "Register".

Copy `Application (client) ID` and use as `MICROSOFT_OAUTH_CLIENT_ID`.

## 2 Add Microsoft Graph delegated permissions

Go to:

```text
App registrations -> <APP NAME> -> API permissions -> Add a permission -> Microsoft Graph -> Delegated permissions
```

Add:

```text
User.Read
Tasks.ReadWrite
Calendars.ReadWrite
```
