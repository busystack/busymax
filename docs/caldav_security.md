# Generic CalDAV security and recovery

Calendar attachments are read from the existing cached DAV resource, including
the same pending-edit representation used by export. Viewing, saving and opening
attachments do not alter that resource or submit DAV mutations. Event and task
HTTP/HTTPS references use the normal external URI handler without DAV credentials
or cookies; other schemes and credential-bearing URLs are not launched.

Inline binary attachments require explicit Save. Strict base64 decoding checks
the alphabet, padding, pad bits and existing 16 MiB calendar-resource bound before
allocating bytes. At most 256 attachments per selected component, including its
alarm data, are listed. Invalid entries remain stored unchanged and cannot be
saved. MIME metadata and all original parameters remain in the raw resource;
valid MIME types are displayed and supplied to Android's normal document saver.
Filename hints cannot choose a directory or contain control/path characters.
Desktop saves stage in a private, uniquely named directory beside the explicitly
chosen destination, flush and atomically rename the data, reject symlink or
directory destinations, and remove staging files on completion/failure. Linux
files use mode 0600; Windows uses its normal destination ACLs. Android uses the
existing document-provider save interface. No binary is automatically opened,
executed or retained in a separate attachment cache. Alarm data can be saved;
this does not add alarm execution or audio playback. No generic upload service,
managed attachments, external-document cleanup or arbitrary-scheme execution is
implemented.

Generic accounts use HTTP Basic authentication over validated HTTPS. Account
URLs cannot contain credentials, fragments or query strings. Discovery resolves
well-known at the origin using HEAD before issuing the principal PROPFIND at
the validated service URI. RFC 6764 HTTP 303 is resolved as retrieval, without
replaying PROPFIND across a 303. The pinned transport enforces bounded,
same-origin HTTPS redirects; a selected installation must contain the resolved
service endpoint.
Principal, home, collection and member hrefs pass the existing DAV scope checks;
a remote href cannot grant another origin access to a credential. Nextcloud's
certificate trust and login extensions are not inherited by generic accounts.

Dedicated CalDAV secret records bind the username and password/app password to
the validated service authority. Production platform secure storage, the
authorization lease, cancellation and durable generation checks govern reads,
replacement and removal. A local lease never overrides a server's revocation or
expiry. BusyStack Server accounts use issued DAV secrets rather than normal
account passwords. Diagnostics must not include those secrets or Basic headers.

Discovery preserves unknown versus denied permissions. Unknown ACL properties
do not remove readable collections or promise write access. Mutations retain
their exact baseline and use conditional requests. After an authoritative
permission denial, only fresh, complete authenticated discovery with explicit
required grants can release blocked work. This cannot clear an authentication
failure. Discarding a blocked edit is allowed while permissions need recovery;
when no blocked work remains, complete authenticated rediscovery can restore the
account without an ACL grant for the discarded operation. Explicit account
revalidation uses the same rule and cannot strand retained blocked operations
by prematurely changing the account state. Missing collections and unresolved
edits remain recoverable.

The schema 23 migration introduced collection creation intent; the current
schema is 25 and retains that migration and subsequent journal diagnostics
and notice acknowledgments. Creation persists intent before dispatch: an unpredictable
UUID, an operation-specific reserved member URL, account/service/home identity,
component set and state. Matching names or deterministic title URLs cannot
authorize recovery. A fresh pre-existing target is a conflict. A dispatched
operation is reconciled by its persisted identity and verified remote state
before retry. A rejected journal cannot become successful reconciliation.
Account removal cascades the journal and does not delete remote collections.

Android creation/recovery holds an exclusive native lease for the persisted
operation across journal reload, remote checks, dispatch, and terminal state
writes. Refresh runs after releasing that lease. A retry's definitive rejection
is resolved with another read of its reserved URL: matching intent commits,
confirmed absence rejects, and a different collection rejects as a conflict.
Failed or incomplete verification retains the dispatched journal for recovery.
Rejected operations use the existing acknowledgments and release the pending
name reservation.

Native import preserves organizer and attendee properties. Generic CalDAV
servers advertising RFC 6638 implicit scheduling may send invitations or meeting
updates when those objects are created, including stored files without `METHOD`.
Every platform's import preview, task-duplication action and conflict-duplication
action require explicit consent for attendee-bearing CalDAV data. Conflict
duplication presents the same decision for VEVENT and VTODO; cancelling
leaves the snapshot and original operation unresolved. The resolution service
passes an explicit decision to the durable create queue. Presentation hints
cannot bypass that queue guard, including after a snapshot changes.
The application/service boundary rejects an unconsented create before queueing;
recursive task duplication rolls
back atomically if a descendant requires consent. Accepted creates retain the
decision with their persisted operation for restart/retry. Servers implementing
implicit VTODO scheduling may deliver task messages; a stored VTODO alone does
not demonstrate delivery. Nextcloud retains its provider-specific scheduling
suppression. For servers advertising `calendar-auto-schedule`, synchronization
also reconciles server-owned scheduling metadata and uses Schedule-Tag validators;
this does not expose Nextcloud scheduling controls. See [RFC 6638](https://www.rfc-editor.org/rfc/rfc6638.html).

Account HTTP clients reuse a bounded set of idle request lanes only within the
same credential, trust configuration and durable authorization generation.
Termination closes the affected lane; authorization writers still wait for all
active response leases. Reused private TLS connections also check certificate
validity before each request. Optional collection method hints last at most
24 hours and are separate from ACL grants; uncached probes run at concurrency
four. Network/server failures in these optional probes do not hide readable
collections; authentication, TLS and cancellation remain authoritative.

Creation-failure notices are read reactively from local storage in Settings,
independently of connectivity or the outcome of account synchronization.
Acknowledgment remains a presentation-only operation.

Discovery inspects each advertised home's resource type. A home can itself be
a calendar; ordinary collections are traversed with Depth 1, a visited-target
set, at most 256 inventory requests and eight descendant levels. Cancellation,
denied branches and incomplete traversal prevent replacement of the persisted
inventory. A direct-home calendar grants no inferred parent administration
privilege. Property updates use the calendar's own authoritative ACL. Deletion
requires the actual immediate parent's unbind grant within a verified home of
the same principal; a distant advertised root or another principal's home cannot
authorize it. Collection method advertisement and parent ACLs are independent;
positive MKCALENDAR or extended MKCOL evidence selects the normal creation
path. With the user's explicitly approved policy, an unavailable OPTIONS on a
nonexistent reserved child (including 404) leaves method capability unknown.
A target Allow on a successful OPTIONS or HTTP 405 is method evidence, even
when empty (RFC 9110 sections 10.2.1 and 15.5.6). If it omits calendar creation
methods, creation remains unsupported. A 405 without Allow leaves method
capability unknown under the existing fallback policy. Explicit denials remain
blocked. An unknown method permits MKCALENDAR only
for an already persisted, explicitly requested creation intent and a fresh
parent bind/write/all grant. Unknown parent ACL cannot authorize this fallback.
Discovery persists unknown/supported/unsupported/denied separately from ACLs;
it never advertises MKCALENDAR merely because calendar-access is present.
Recovery may continue that same authorized journal after verifying its reserved
URL; it cannot invent an intent or blindly replay an uncertain request.

A PROPFIND fallback requires an unambiguous collection response and complete,
valid member href/ETag data. The collection ETag is optional. Failed/incomplete
inventories retain the stable cursor, cache, projections and pending writes.
RFC 4918 property-level error details are permitted in a propstat with one
property container and one status; a DAV:error must contain condition elements
and no non-whitespace direct text. Structured condition details and unknown
conditions are legal. Only successful properties establish capabilities; failed
optional ACL properties remain unknown. Mandatory resource types, resource-level
failures and full inventory completeness remain independently validated.
These checks do not impose full-inventory rules on RFC 6578 deltas or 507 pages.
A collection DELETE 207 is inspected for member failures. Partial deletion
refreshes children while retaining the surviving collection and reports partial
failure. Malformed or lost responses require reconciliation; discovery success
alone does not confirm deletion, and uncertain destructive work is not repeated.

The existing XML parser, byte limits, timeouts, cancellation and response
validation remain in force. Incomplete inventories cannot advance a complete
sync baseline. Calendar-multiget property-level 404, missing calendar data or
ETag, and omitted members require safe GET reconciliation. Only a resource-level
404 or authoritative GET 404 establishes deletion. Failed/denied/malformed GET
retains the cache, projections, pending operations and stable cursor. Duplicate
multiget hrefs, including identical duplicates, fail the batch before promotion;
response order cannot decide resource existence. Cancellation is checked before
promotion. Existing repository transactions atomically promote the complete
batch and cursor; they do not need a schema change. Successful PUT responses
without ETag require retrieval of the stored representation and authoritative
validator before another edit. Narrow
timezone comparison equivalence does not ignore unrelated properties or permit
blind replay.

The maintained [qualification record](caldav_qualification.md) separates actual
live/native evidence from deterministic coverage. The isolated
[Docker fixtures](../test/interop/caldav/README.md) trust their generated CA only
inside fixture clients or private browser containers. They do not disable TLS
validation or alter host trust. Disposable credentials, private keys and
authenticator material remain outside tracked source.
