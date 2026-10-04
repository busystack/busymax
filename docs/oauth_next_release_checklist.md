# Next-release registration retirement checklist

This checklist is for the release owner. It does not schedule or execute retirement.

- Confirm existing shared-account migration, cancel/failure rollback, restart, refresh and optional-consent evidence on Linux, Windows and correctly signed Android distribution builds.
- Audit unresolved provenance separately; never call an unidentified registration BusyStack-owned. Preserve unknown/corrupt secure records for explicit repair.
- Remove the retiring **desktop Google client** and **desktop/native Microsoft shared clients** only after the owner authorizes next-release retirement. Remove their protected injection from `.github/workflows/flutter-linux.yml`, Windows `build_release.ps1`/release configuration/package validation, Snap build tooling, and Android generated shared MSAL resource as appropriate.
- Runtime removal surfaces: BuildConfig's Google desktop shared ID/secret and Microsoft shared ID/authority fields, OAuthService/MicrosoftOAuthService original-registration resolution and legacy-binding refresh, Android original-resource resolution, and the pre-existing-account transition eligibility path. Retain versioned user-owned credential decoding, generation/journal recovery, account intent, safe errors and per-registration native MSAL clients.
- Retire the shared warning/migration policy only after handling accounts still bound to retiring clients; retain ordinary registration replacement/reconnect UI and packaged guides.
- **Do not delete Google's Cloud project while the approved Android package/signing-certificate registration depends on it.** Android Google remains native GIS and needs both Calendar and Tasks APIs and project quota. Desktop retirement is not native registration retirement. No application-ID, signing/distribution or API-key workaround is authorized.
- Remove shared values from release artifacts only after the runtime paths are retired. Transitional artifacts intentionally retain protected original registrations; imported user files, tokens and secrets must never be packaged or logged.
- Re-measure Android shared-project request budgets against actual usage/collection/page counts. Quota-adjustment evidence is a request preparation, not an approval or a quota-setting change.
- No invented release number/date, wall-clock expiry, remote disable switch or external Cloud/Entra deletion.
