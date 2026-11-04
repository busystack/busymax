# Generic CalDAV security and recovery

Generic accounts use HTTP Basic authentication over validated HTTPS. Account
URLs cannot contain credentials, fragments or query strings. Discovery resolves
well-known at the origin and permits bounded, same-origin HTTPS redirects.
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

Schema 23 persists collection creation intent before dispatch: an unpredictable
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
Every platform's import preview requires explicit consent for attendee-bearing
CalDAV data; the import service rejects an unconsented import before queueing or
projecting any resources. Nextcloud retains its provider-specific scheduling
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

The existing XML parser, byte limits, timeouts, cancellation and response
validation remain in force. Incomplete inventories cannot advance a complete
sync baseline. Successful PUT responses without ETag require retrieval of the
stored representation and authoritative validator before another edit. Narrow
timezone comparison equivalence does not ignore unrelated properties or permit
blind replay.

The maintained [qualification record](caldav_qualification.md) separates actual
live/native evidence from deterministic coverage. The isolated
[Docker fixtures](../test/interop/caldav/README.md) trust their generated CA only
inside fixture clients or private browser containers. They do not disable TLS
validation or alter host trust. Disposable credentials, private keys and
authenticator material remain outside tracked source.
