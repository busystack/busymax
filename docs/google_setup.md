# Google OAuth registration

This guide is for developers and release maintainers who configure a BusyMax
build. People installing an already configured package do not need to create a
Google Cloud project.

BusyMax reads the Google desktop OAuth client ID and client secret from the
compile-time settings `GOOGLE_OAUTH_CLIENT_ID` and
`GOOGLE_OAUTH_CLIENT_SECRET`.

## Configure Google APIs and consent

1. Create or select a project in the
   [Google Cloud console](https://console.cloud.google.com/).
2. Enable the Google Tasks API and Google Calendar API.
3. Open [Google Auth Platform](https://console.cloud.google.com/auth/), complete
   the Branding, Audience, and Contact Information setup, and keep development
   accounts under **Audience > Test users** while the app is in testing.
4. Under **Data Access**, add the Google Tasks read/write scope
   `https://www.googleapis.com/auth/tasks` and the Google Calendar read/write
   scope `https://www.googleapis.com/auth/calendar`.

BusyMax's runtime authorization request also contains the OpenID Connect scope
strings `openid`, `email`, and `profile`. Google may show the last two in
the console as `https://www.googleapis.com/auth/userinfo.email` and
`https://www.googleapis.com/auth/userinfo.profile`. These identity scopes
provide the account identity and display label; the Tasks and Calendar scopes
authorize provider data access.

Google documents the current console areas in
[Get started with Google Auth Platform](https://support.google.com/cloud/answer/15544987)
and the Tasks permission in
[Choose Google Tasks API scopes](https://developers.google.com/workspace/tasks/auth).

## Create the desktop client

1. Open **Google Auth Platform > Clients** and select **Create client**.
2. Choose **Desktop app** as the application type.
3. Give the client a recognizable name and create it.
4. Supply the resulting client ID and client secret to the BusyMax build.

BusyMax opens the system browser and listens on a temporary
`http://127.0.0.1:<port>/` loopback callback. Do not configure a web
application client or a hosted redirect endpoint for this flow.

Desktop OAuth configuration is embedded in the application package and can be
extracted; it is not a protected server-side secret. Use credentials dedicated
to this desktop application, restrict access to the build configuration, and
never commit credentials or generated credential files. Google's
[OAuth client documentation](https://support.google.com/cloud/answer/15549257)
describes desktop applications as public clients.
