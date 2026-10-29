# Desktop OAuth release prerequisites

Locally built Linux releases read the BusyMax-managed Google Desktop registration
from an external OAuth JSON through the
[local release command](beta_snap_release.md). Supply a valid `installed` object
with the client ID, secret and actual project ID. Keep credential JSON outside
Git. Original Google credentials are not required.

## Google Console prerequisites

Before distribution, verify the supplied client's project in Google Auth
Platform and API Library:

- Calendar API (`calendar-json.googleapis.com`) and Tasks API
  (`tasks.googleapis.com`) enabled.
- The existing required scopes: `openid`, `email`, `profile`,
  `https://www.googleapis.com/auth/calendar` and
  `https://www.googleapis.com/auth/tasks`.
- Optional read-only contacts: People API (`people.googleapis.com`) enabled and
  `https://www.googleapis.com/auth/contacts.readonly` listed/approved when
  applicable. Contacts consent remains separate; no write access is requested.
- Audience External for a public BusyMax registration, publishing In production,
  actual verification status and scope approval for the scopes above. Internal
  Workspace registrations remain a separate custom setup choice.
- BusyMax branding/logo, user-support and developer-contact emails, application
  homepage, verified policy domain and
  `https://busystack.org/privacy-busymax`, plus required consent-screen
  disclosures. Confirm that the supplied Desktop client belongs to this project.

Use `gcloud services list --enabled --project=<project-id>` to inspect enabled
APIs. Confirm approved scopes, verification status and branding/support details
in the Console, then exercise real provider round trips. A Desktop JSON or
successful login does not establish these prerequisites. Google's [audience guidance](https://support.google.com/cloud/answer/15549945?hl=en)
describes Testing's test-user restrictions and seven-day authorizations.
[Consent configuration](https://developers.google.com/workspace/guides/configure-oauth-consent)
and [sensitive-scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
explain the additional approval requirements. Publishing alone is not verification.

## Microsoft and other providers

Supply the established `MICROSOFT_OAUTH_CLIENT_ID` in ignored local public settings;
no Microsoft secret or new app is needed. Preserve its existing public-client
redirect and permissions. Managed `BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID` remains
optional until a real application is supplied. An explicitly managed Microsoft
client uses `common`; custom clients retain their own audience/tenant choices.
When no managed replacement is supplied, **Connect with BusyMax** uses the
established `MICROSOFT_OAUTH_CLIENT_ID` and its configured authority. That client
is also accepted in custom setup; it is not retired merely because Google changed.
Verify expired Microsoft grants receive a clear reconnect instruction. Optional
contacts retain `Contacts.Read`. Nextcloud, iCloud and read-only contacts flows
must pass their existing regressions; none use release OAuth secrets.

## Existing accounts and build gates

The new Google client must only populate `BUSYMAX_GOOGLE_OAUTH_*`. Account-bound
credentials record their issuing registration and authorization generation.
For an unavailable legacy client, synchronization marks the existing account
reconnect-required without opening a browser. The user initiates a targeted
replacement flow; verified Google subjects must match. Unverifiable identities
retain their accounts and pending work and offer a separate connection, never
an email-based merge. Failed/cancelled attempts preserve the prior state.

`tool/check_desktop_oauth_config.dart` validates environment values or `--config`
JSON. Managed Google ID/secret/real project metadata and fixed privacy policy
are required. Original Google credentials and managed Microsoft are optional.
Supplied incomplete/invalid optional values and known CI fixtures are rejected;
values are never printed. Syntax cannot prove external Console approval.

Linux CI validates source without credentials or artifact uploads. Official
Linux packaging uses `tool/release/build_snap_local.sh`, locked dependencies,
exact source/version gates, native tests, compiled configuration inspection and
fresh isolated Snap checks. No new GitHub OAuth variable/secret is needed.
Windows and Android keep their existing CI/toolchain and native architectures.
No cloud registration, Android signing identity, or Store record is changed.

Complete interactive upgrade, wrong-account/cancellation, permissions,
network/rate-limit, browser callback, restart, secret storage and actual
Calendar/Tasks/contacts acceptance before publishing. Keep cloud prerequisites
and real provider evidence separate from automated build/test results.
