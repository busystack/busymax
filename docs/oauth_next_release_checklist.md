# Desktop OAuth release checklist

Official desktop releases support explicitly active BusyMax-managed registrations and optional organization/custom registrations. Shared-client retirement is not a prerequisite or a scheduled action.

## Google external prerequisites

- The owner must supply a real production Desktop OAuth client ID/secret and its actual project ID through `BUSYMAX_GOOGLE_OAUTH_CLIENT_ID`, `BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET`, and `BUSYMAX_GOOGLE_OAUTH_PROJECT_ID`.
- Configure branding, support/contact details, Calendar and Tasks APIs, and the existing five scopes. Complete In production publishing and any applicable branding/domain and scope approval/verification. Publishing alone is not verification; tests cannot establish either.
- BusyStack-owned production branding uses `https://busystack.org/privacy-busymax`. Other project owners must satisfy their own domain and policy obligations.

## Microsoft external prerequisites

- The owner must supply a real public app ID and explicit supported-account authority (`common`, `organizations`, `consumers`, or a tenant UUID) through `BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID` and `BUSYMAX_MICROSOFT_OAUTH_AUTHORITY_TENANT`.
- Configure Mobile and desktop applications with `http://localhost`, existing mandatory delegated permissions, and applicable administrator consent. Optional shared-calendar/category consent stays optional. No client secret is used.

## Preserve existing registrations and data

- Retain protected `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `MICROSOFT_OAUTH_CLIENT_ID`, and original Microsoft authority separately. Supply `GOOGLE_OAUTH_PROJECT_ID` only when known truthfully; unknown legacy project metadata is omitted rather than fabricated.
- Do not overwrite original values with a new production registration. They resolve only eligible accounts actually issued under them. They never enable Connect with BusyMax or act as an implicit fallback.
- Account envelopes persist the issuing registration, origin, audience, secret where applicable, and tokens. After restart/build changes, refresh, ordinary Reconnect, and Microsoft optional consent use that account's binding. Active registrations do not receive retirement notices.
- Explicit Replace registration retains identity checks, transactional rollback, generations, secure storage, local data, and session reconciliation. Audit unresolved provenance separately; preserve unknown/corrupt records for repair.
- Do not retire/delete any Cloud project, Entra registration, or native Android configuration without separate owner authorization. Android GIS/MSAL and signing/distribution identities remain unchanged.

## Build and acceptance gates

- `dart run tool/check_desktop_oauth_config.dart` validates environment values; `--config <dart-defines.json>` validates a define file. Missing production registrations fail official release validation and are reported as separate external prerequisites. Syntactic validity does not mean provider approval.
- Linux push packaging validates and injects active and original values separately. Unconfigured validation builds display the recommended action as unavailable and retain custom setup. Windows official configuration validates the same prerequisites; synthetic CI values are restricted to explicitly nonproduction CI packages. `-Ci -Unconfigured -Stage WindowsCompile` exercises the unavailable state only.
- Run locked dependency resolution, localization generation, formatting, analysis, full tests, platform boundaries, Linux release build and diff checks. Run Windows release/native/MSIX validation on Windows and affected Android regressions.
- Inspect actual production Settings dialogs, native menus, all instruction pages and errors in light/dark, narrow, enlarged-text, long-label and keyboard cases. Use isolated synthetic configurations; owner-authorized accounts are required for real provider authorization.
- Review cancellation, invalid/cancelled replacement, expiry, disposal/stale work, duplicate submits, wrong account, missing scopes, secure-storage failure, restart/reconnect and optional-consent evidence before publication.

Production Google and Microsoft values and approvals have not been supplied for this change. Keep both recommended actions unavailable until the owner supplies configuration and completes the respective external prerequisites.
