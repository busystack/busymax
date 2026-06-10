# Google Setup

This setup is required to get `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`

## 1 Enable APIs

### 1.1 Create New Project

Go to `Google Cloud Console`: https://console.cloud.google.com

Click `Open project picker` (top-left corner) and create a new project. Then, select it.

### 1.1 Enable Task and Calendar API

Search and enable the following:

- Google Tasks API
- Google Calendar API

## 2 Google Auth Platform

### 2.1 Initial Setup

Go to `Google Auth Platform`: https://console.cloud.google.com/auth/

Click `Get Started`.

Enter:

- App name: <APP NAME>
- User support email: <YOUR EMAIL>
- Audience: `External`
- Contact Information: <YOUR EMAIL>

Click `Save`.

### 2.2 Branding

Click `Branding` to provide additional information if needed.

### 2.3 Audience

Click `Audience` to add test users. While publishing status is set to "Testing", only test users are
able to access the app.

### 2.4 Clients

Click `Clients` -> `Create Client` and enter:

- Application type: Desktop app
- Name: <APP NAME>

!!! **Important**: copy and save `Client ID` and `Client secret`. **You will no longer be able to
view or download the client secret once you close this dialog. Make sure you have copied or
downloaded the information below and securely stored it.** Use it as `GOOGLE_OAUTH_CLIENT_ID` and
`GOOGLE_OAUTH_CLIENT_SECRET`.

#### 2.5 Data Access

Click `Add or remove scopes`

Check the following:

- openid
- https://www.googleapis.com/auth/userinfo.email
- https://www.googleapis.com/auth/userinfo.profile
- https://www.googleapis.com/auth/tasks
- https://www.googleapis.com/auth/calendar

Click `Update` and `Save`.

Rationale:

```text
openid/email/profile -> stable account identity and display label
tasks -> Google Tasks create/edit/delete/sync
calendar -> CalendarList, Calendars, Events, Colors, Freebusy support
```
