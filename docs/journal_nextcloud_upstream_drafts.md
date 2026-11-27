# Nextcloud journal interoperability issue drafts

These reports are prepared locally. Each probe used the official unmodified
`nextcloud:35.0.3-apache` image with manifest digest
`sha256:f44180601f18e7664557232b4c5edb0eb4a82d649c05b93313f4e15909553d42`.
The running version was 35.0.3.2 with PHP 8.5.13, SQLite, SabreDAV 4.7.0 and
Sabre VObject 4.5.6. Searches of the Nextcloud server tracker for
`RDATE getDateTimes` and the Sabre VObject tracker for `XML-REFERENCE` and
`9253` returned no matching issues on November 27, 2026.

Both reports use a disposable journal-only collection created by MKCALENDAR.
Discover the current principal and its calendar home before creating the
collection. Use `Content-Type: text/calendar; charset=utf-8` and
`If-None-Match: *` for creation. For replacement, first store the same UID and
journal without the test property, GET the authoritative resource, and use
its strong ETag in `If-Match`. After either rejection, GET the target and
compare the previous bytes and ETag when applicable. PROPFIND of the
collection and its members confirms the same inventory and sync token.

Use the source-controlled fixture generator to reproduce the recorded bytes,
including CRLF and an intact calendar envelope. The corpus SHA-256 is
`68fe8ab310463333ddc6371c3b8b58744223b3f78f3a41152b47d15e498847a0`.
The 22-operation rerun reproduced the 10 rejections with intact state,
and all 12 controls passed. [Fixture corpus](https://github.com/busystack/caldav-server/blob/75685be70c48a776322f957a17d937b5352a279b/qualification/fixtures/vjournal/admission-v1.json)
[Independent request and readback script](https://github.com/busystack/caldav-server/blob/75685be70c48a776322f957a17d937b5352a279b/qualification/clients/journal-admission.py)

## Nextcloud server draft · Dated VJOURNAL with a PERIOD recurrence cannot be stored

Start with a journal containing a UID, DTSTAMP and
`DTSTART:20261125T090000Z`. Add one of the following properties and send it
as described above. RFC 5545 §3.8.5.2 permits both PERIOD forms as recurrence
dates in VJOURNAL. The expected result is successful storage and a GET
retaining the complete recurrence property and its parameters.
[RFC 5545 §3.8.5.2](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.5.2)

```text
RDATE;VALUE=PERIOD:20261126T090000Z/20261126T110000Z
RDATE;VALUE=PERIOD:20261126T090000Z/PT2H
```

The server responds HTTP 500 in both create and conditional replacement.
The DAV response reports exception `Error` with message
`Call to undefined method Sabre\VObject\Property\ICalendar\Period::getDateTimes()`.
However, a direct call to the shipped `Sabre\VObject\Reader::read()` parses
both fixtures and creates the `Period` class. Inspection with
`method_exists($property, 'getDateTimes')` returns false. The backend calls
that method at `apps/dav/lib/CalDAV/CalDavBackend.php:3451`. The logged stack
includes `getDenormalizedData → createCalendarObject → createFile → httpPut`.
The parser's
successful admission and the failing backend call give the Nextcloud server
tracker an independent case to investigate.
[Nextcloud backend](https://github.com/nextcloud/server/blob/v35.0.3/apps/dav/lib/CalDAV/CalDavBackend.php)
[Shipped Period class](https://github.com/nextcloud/3rdparty/blob/8d85b94d76506730b13deac503e12ed79234ee22/sabre/vobject/lib/Property/ICalendar/Period.php)

| Fixture | SHA-256 of CRLF probe body with UID `<ID>-trace` |
| --- | --- |
| J15-start-end | `e851b7438a265f773ace58949e52ac339a84b9a6d938639bf6bf00cd0e28dafe` |
| J15-start-duration | `f768ace6d9aa45f734d52f2aa9979ab84ad396507f085eac4a2f780c69ceede7` |

## Sabre VObject draft · Explicit RFC 9253 reference types fail during parsing

Use the three J12 typed-reference fixtures separately. For the UID targets
store `target-fixture` in the same collection. The XML fixture has an
absolute URI with an XPointer fragment. Each resource should read back with
its explicit VALUE unchanged. A LINK with VALUE=URI and a legacy RELATED-TO
are positive controls. [RFC 9253 §§2, 7, 9.1](https://www.rfc-editor.org/rfc/rfc9253.html#section-2)

```text
LINK;VALUE=UID:target-fixture
LINK;VALUE=XML-REFERENCE:https://example.invalid/journal.xml#xpointer(/journal)
RELATED-TO;VALUE=UID:target-fixture
```

The bundled Reader fails directly on all three fixtures before CalDAV
storage. It throws `Sabre\VObject\InvalidDataException` at
`lib/Document.php:214`. The stack goes through
`Document::createProperty → Parser\MimeDir::readProperty → Parser\MimeDir::parseLine`.
The error messages read `Unsupported VALUE parameter for LINK property. You
supplied "UID"`, `Unsupported VALUE parameter for LINK property. You supplied
"XML-REFERENCE"`, and `Unsupported VALUE parameter for RELATED-TO property.
You supplied "UID"`. The corresponding DAV requests return HTTP 500 with the
same exception and message. The server preserves the existing resource and
collection state. [Bundled value map](https://github.com/nextcloud/3rdparty/blob/8d85b94d76506730b13deac503e12ed79234ee22/sabre/vobject/lib/Component/VCalendar.php)
[Bundled parser](https://github.com/nextcloud/3rdparty/blob/8d85b94d76506730b13deac503e12ed79234ee22/sabre/vobject/lib/Document.php)

To reproduce directly independently of DAV, pass the generated CRLF fixture
on standard input to the PHP CLI from inside the pinned image.

```php
require '/var/www/html/3rdparty/autoload.php';
try {
    \Sabre\VObject\Reader::read(stream_get_contents(STDIN));
} catch (\Sabre\VObject\InvalidDataException $e) {
    fwrite(STDERR, get_class($e) . ' ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
```

| Fixture | SHA-256 of CRLF probe body with UID `<ID>-trace` |
| --- | --- |
| J12-link-uid | `4e073b6d948d8485f490de5da598cf8bc85b45fb08ff500ccc3db41437ac6fe3` |
| J12-link-xml | `25de9626bddb663eaae5df5999be0effb6b736af4f9fb4159f94b24a72d5dd73` |
| J12-related-uid | `4c3011fa5f659461dcba55423fd832e7a15b59d8bcf713753cf911cc85d24158` |
