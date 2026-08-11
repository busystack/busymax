# Google OAuth setup

BusyMax requires a Google desktop OAuth client. Its client ID and client secret
are supplied as `GOOGLE_OAUTH_CLIENT_ID` and
`GOOGLE_OAUTH_CLIENT_SECRET` at build time.

## Create a Google Cloud project

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable the Google Tasks API and Google Calendar API.

## Configure the consent screen

1. Open [Google Auth Platform](https://console.cloud.google.com/auth/).
2. Complete the initial setup with the application name, support email,
   audience, and contact email.
3. Under **Audience**, add development accounts as test users while the app is
   in testing mode.
4. Under **Data access**, add these scopes:

   ```text
   openid
   https://www.googleapis.com/auth/userinfo.email
   https://www.googleapis.com/auth/userinfo.profile
   https://www.googleapis.com/auth/tasks
   https://www.googleapis.com/auth/calendar
   ```

The identity scopes provide the stable account identity and display label. The
Tasks and Calendar scopes allow BusyMax to synchronize and edit the
corresponding data.

## Create the desktop client

1. Open **Clients** and select **Create client**.
2. Choose **Desktop app** as the application type.
3. Give the client a recognizable name.
4. Store the client ID and client secret securely and provide them to the build
   as `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`.

Use only credentials created for this desktop application. Do not commit them
to the repository.
