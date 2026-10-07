# Google desktop connections

In Settings → Accounts, choose **Add Google account**. **Connect with BusyMax** uses an explicitly configured BusyMax-managed registration. If this build has none, that action is unavailable with an explanation; neither original registrations nor custom clients are used as an automatic fallback.

Under **Other connection methods**, choose **Google Workspace organization** for a configuration managed by your organization, or **Custom OAuth client** for a project you manage. Both import the same Desktop OAuth JSON type. A work account does not require the Workspace path. Instructions remain in the setup modal; Back restores the form and Close cancels setup.

## Google Workspace organization

You may receive the Desktop OAuth JSON from your administrator and proceed directly to import. If creating it yourself:

1. Open [Google Cloud Console](https://console.cloud.google.com/cloud-resource-manager). Select a project owned by your Workspace organization. To create one, open **Manage resources → Create project**, enter **Project name**, choose your organization or one of its folders in **Parent resource**, and select **Create**. Select that project for the remaining steps. Creation requires Project Creator access; configuration requires [OAuth Config Editor](https://docs.cloud.google.com/iam/docs/roles-permissions/oauthconfig), and enabling APIs requires [Service Usage Admin](https://docs.cloud.google.com/iam/docs/roles-permissions/serviceusage) or equivalent permissions. Ask the administrator if blocked. See [Create projects](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects).
2. In **APIs & Services → Library**, open **Google Calendar API → Enable**, then repeat for **Google Tasks API**.
3. Open **Google Auth Platform → Branding → Get started**. Enter **BusyMax** as **App name**, select your **User support email**, and **Next**. Select **Internal** in Audience and **Next**. Enter your email in **Contact Information**, choose **Next**, accept the **User Data Policy**, and choose **Continue → Create**. Review Branding and Audience if already configured. Internal applies only to the project's parent organization and remains subject to administrator controls. It does not require Testing or a test-user list. See [Google's audience rules](https://support.google.com/cloud/answer/15549945?hl=en).
4. Review the scopes below with your administrator. Internal apps do not need to list scopes on the consent screen. If an administrator requests a listing, use **Data Access → Add or remove scopes**, add the values, **Update**, then **Save**. Admin policies may still restrict authorization.
5. In **Clients → Create client**, choose **Application type: Desktop app**, enter **BusyMax** in Name, and **Create**. Choose **Download JSON**, save it, return with Back, and use **Choose file…**. Review the project/client summary, choose **Connect**, and authorize the intended account with Calendar and Tasks access.

Import validates the local Desktop JSON. It does not establish organization ownership, Internal audience, publishing status, or verification of console settings.

## Custom OAuth client

1. Open [Google Cloud Console](https://console.cloud.google.com/). Select your project, or choose **New project**, enter a name, and **Create**. Keep that project selected.
2. Under **APIs & Services → Library**, enable **Google Calendar API** and **Google Tasks API**.
3. In **Google Auth Platform → Branding → Get started**, enter **BusyMax** in **App name**, choose your **User support email**, and **Next**. Select **External → Next**. Enter your email in **Contact Information → Next**, accept the **User Data Policy**, and **Continue → Create**.
4. Under **Branding → App domain**, add your **Authorized domains** before entering your homepage, privacy policy, and terms-of-service URLs. Choose **Save**. External production apps need these links. Use domains that you own; complete Search Console ownership verification when Google requires brand verification. [BusyMax's product privacy policy](https://busystack.org/privacy-busymax) is a product reference, not evidence that your project owns busystack.org or satisfies your own policy/domain obligations. Follow [Google's branding requirements](https://support.google.com/cloud/answer/15549049?hl=en).
5. In **Data Access → Add or remove scopes**, select the five scopes below. Use **Manually add scopes → Add to table** for any missing values, then **Update → Save**.
6. In **Audience**, select **Publish app** and confirm **In production**. Do not leave normal use in Testing: these Calendar/Tasks authorizations, including refresh tokens, expire after seven days. Publishing and verification are separate. Google documents published-but-unverified applications and a [personal-use exemption](https://support.google.com/cloud/answer/13464323?hl=en) for fewer than 100 users, subject to warnings and a user cap. Wider distribution may require branding/domain and scope approval. Follow the applicable [production-readiness requirements](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview); publishing does not mean credentials can never expire or be revoked.
7. In **Clients → Create client**, choose **Application type: Desktop app**, enter **BusyMax** as **Name**, and **Create**. Select **Download JSON**, save it, return with Back, choose **Choose file…**, and review the summary. Choose **Connect** and approve Calendar and Tasks access in your system browser.

## Required scopes

```text
openid
email
profile
https://www.googleapis.com/auth/tasks
https://www.googleapis.com/auth/calendar
```

These are BusyMax's existing desktop scopes. Imported endpoints, redirects, and scope declarations do not replace BusyMax's OAuth settings. Cancellation or an invalid replacement preserves the previous valid selection; staged configuration expires after ten minutes and is single-use. Re-import after expiry. Ordinary Reconnect uses the account's saved issuing registration. Explicit Replace registration chooses a method and preserves account identity and local data transactionally.

Android uses native authentication and is outside these desktop instructions. Production Google registration values and provider approvals are owner-controlled prerequisites, not results of local validation or tests.
