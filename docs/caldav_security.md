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
failure. Missing collections and unresolved edits remain recoverable.

Schema 23 persists collection creation intent before dispatch: an unpredictable
UUID, an operation-specific reserved member URL, account/service/home identity,
component set and state. Matching names or deterministic title URLs cannot
authorize recovery. A fresh pre-existing target is a conflict. A dispatched
operation is reconciled by its persisted identity and verified remote state
before retry. Definitive rejection cannot become successful reconciliation.
Account removal cascades the journal and does not delete remote collections.

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
