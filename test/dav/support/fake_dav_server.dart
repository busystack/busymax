import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:http/http.dart' as http;

final class FakeDavResource {
  FakeDavResource({
    required this.path,
    required this.body,
    required this.etag,
    this.multistatusStatus,
  });

  final String path;
  String body;
  String etag;
  int? multistatusStatus;
}

final class FakeDavFault {
  const FakeDavFault({
    this.method,
    this.path,
    this.statusCode,
    this.body = '',
    this.headers = const {},
    this.delay = Duration.zero,
    this.dropConnection = false,
  });

  final String? method;
  final String? path;
  final int? statusCode;
  final String body;
  final Map<String, String> headers;
  final Duration delay;
  final bool dropConnection;

  bool matches(HttpRequest request) =>
      (method == null || method == request.method) &&
      (path == null || path == request.uri.path);
}

final class FakeDavRequestRecord {
  const FakeDavRequestRecord({
    required this.method,
    required this.path,
    required this.depth,
    required this.ifMatch,
    required this.ifNoneMatch,
    required this.hasBasicAuthorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? depth;
  final String? ifMatch;
  final String? ifNoneMatch;
  final bool hasBasicAuthorization;
  final String body;
}

/// A loopback-only, stateful DAV origin used by integration tests. It models
/// discovery, inventory, RFC 6578 paging, multiget, conditional writes,
/// server rewriting, ACL changes, and injected protocol/transport failures.
final class FakeDavServer {
  FakeDavServer({this.installationPath = '/nextcloud'});

  final String installationPath;
  HttpServer? _server;
  final List<FakeDavFault> _faults = [];
  final List<http.Client> _clients = [];
  final Map<String, FakeDavResource> resources = {};
  final List<FakeDavRequestRecord> requests = [];
  final Set<String> deletedPaths = {};
  final Set<String> invalidSyncTokens = {'invalid-token'};

  bool redirectWellKnown = true;
  bool collectionReadOnly = false;
  bool collectionRemoved = false;
  bool paginateInitialSync = true;
  bool rewriteMutations = false;
  bool raceNextMutation = false;
  bool dropAfterNextMutation = false;
  String finalSyncToken = 'sync-token-1';
  int _revision = 10;

  String get davRootPath => '$installationPath/remote.php/dav/';
  String get principalPath => '${davRootPath}principals/users/alex/';
  String get calendarHomePath => '${davRootPath}calendars/alex/';
  String get collectionPath => '${calendarHomePath}work/';
  String get eventPath => '${collectionPath}event.ics';
  String get taskPath => '${collectionPath}task.ics';

  Uri get authority {
    final server = _server;
    if (server == null) throw StateError('Fake DAV server is not running.');
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: installationPath,
    );
  }

  Uri uriFor(String path) => authority.replace(path: path);

  DavProviderProfile get profile => DavProviderProfile(
    provider: BusyProvider.nextcloud,
    bootstrapUri: authority,
    calendarEnabled: true,
    tasksEnabled: true,
    allowCollectionMutations: false,
    allowSchedulingMutations: false,
    allowMove: false,
    allowInsecureLoopbackForTesting: true,
  );

  DavBasicCredential get credential =>
      DavBasicCredential(username: 'alex', password: 'app-password');

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    resources
      ..clear()
      ..[eventPath] = FakeDavResource(
        path: eventPath,
        etag: '"event-1"',
        body: _eventBody('Server event'),
      )
      ..[taskPath] = FakeDavResource(
        path: taskPath,
        etag: 'W/"task-1"',
        body: _taskBody('Server task'),
      );
    unawaited(
      server.forEach(_handle).catchError((Object _) {
        // A deliberately dropped test connection can surface at the server
        // listener after the client has already observed the network error.
      }),
    );
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    await server?.close(force: true);
  }

  void enqueueFault(FakeDavFault fault) => _faults.add(fault);

  DavHttpTransport transport({
    DavTransportLimits limits = const DavTransportLimits(),
    DavDelay? delay,
  }) {
    final client = http.Client();
    _clients.add(client);
    return DavHttpTransport(
      client: client,
      profile: profile,
      accountAuthority: authority,
      limits: limits,
      delay: delay ?? (_) async {},
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    requests.add(
      FakeDavRequestRecord(
        method: request.method,
        path: request.uri.path,
        depth: request.headers.value('depth'),
        ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
        ifNoneMatch: request.headers.value(HttpHeaders.ifNoneMatchHeader),
        hasBasicAuthorization:
            request.headers
                .value(HttpHeaders.authorizationHeader)
                ?.startsWith('Basic ') ==
            true,
        body: body,
      ),
    );

    final faultIndex = _faults.indexWhere((fault) => fault.matches(request));
    if (faultIndex >= 0) {
      final fault = _faults.removeAt(faultIndex);
      if (fault.delay > Duration.zero) await Future<void>.delayed(fault.delay);
      if (fault.dropConnection) {
        await _drop(request);
        return;
      }
      await _respond(
        request,
        fault.statusCode ?? HttpStatus.internalServerError,
        fault.body,
        headers: fault.headers,
      );
      return;
    }

    if (!requests.last.hasBasicAuthorization) {
      await _respond(request, HttpStatus.unauthorized, '');
      return;
    }
    final path = request.uri.path;
    if (path == '$installationPath/.well-known/caldav') {
      if (redirectWellKnown) {
        await _respond(
          request,
          HttpStatus.movedPermanently,
          '',
          headers: {'location': uriFor(davRootPath).toString()},
        );
      } else {
        await _options(request);
      }
      return;
    }
    if (request.method == 'OPTIONS' && path == davRootPath) {
      await _options(request);
      return;
    }
    if (request.method == 'PROPFIND' && path == davRootPath) {
      await _xml(request, HttpStatus.multiStatus, _principalResponse());
      return;
    }
    if (request.method == 'PROPFIND' && path == principalPath) {
      await _xml(request, HttpStatus.multiStatus, _homeResponse());
      return;
    }
    if (request.method == 'PROPFIND' && path == calendarHomePath) {
      await _xml(request, HttpStatus.multiStatus, _inventoryResponse());
      return;
    }
    if (path == collectionPath && collectionRemoved) {
      await _respond(request, HttpStatus.notFound, '');
      return;
    }
    if (request.method == 'PROPFIND' && path == collectionPath) {
      await _xml(request, HttpStatus.multiStatus, _memberInventoryResponse());
      return;
    }
    if (request.method == 'REPORT' && path == collectionPath) {
      if (body.contains('sync-collection')) {
        await _syncCollection(request, body);
      } else if (body.contains('calendar-multiget')) {
        await _calendarMultiget(request, body);
      } else {
        await _respond(request, HttpStatus.badRequest, '');
      }
      return;
    }
    if (request.method == 'GET') {
      await _getResource(request, path);
      return;
    }
    if (request.method == 'PUT') {
      await _putResource(request, path, body);
      return;
    }
    if (request.method == 'DELETE') {
      await _deleteResource(request, path);
      return;
    }
    await _respond(request, HttpStatus.notFound, '');
  }

  Future<void> _options(HttpRequest request) => _respond(
    request,
    HttpStatus.ok,
    '',
    headers: {
      'dav': '1, 3, calendar-access, sync-collection',
      'allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
    },
  );

  Future<void> _syncCollection(HttpRequest request, String body) async {
    final token = _syncToken(body);
    if (invalidSyncTokens.contains(token)) {
      await _xml(
        request,
        HttpStatus.forbidden,
        '<d:error xmlns:d="DAV:"><d:valid-sync-token/></d:error>',
      );
      return;
    }
    final live = resources.values
        .where((resource) => resource.multistatusStatus != 404)
        .toList(growable: false);
    if (token.isEmpty && paginateInitialSync && live.length > 1) {
      await _xml(
        request,
        HttpStatus.insufficientStorage,
        _syncResponse(
          token: 'intermediate-token',
          live: [live.first],
          deleted: const [],
        ),
      );
      return;
    }
    final page = token == 'intermediate-token'
        ? live.skip(1).toList(growable: false)
        : token.isEmpty
        ? live
        : const <FakeDavResource>[];
    await _xml(
      request,
      HttpStatus.multiStatus,
      _syncResponse(
        token: token == finalSyncToken
            ? '$finalSyncToken-next'
            : finalSyncToken,
        live: page,
        deleted: deletedPaths,
      ),
    );
  }

  Future<void> _calendarMultiget(HttpRequest request, String body) async {
    final requested = RegExp(
      r'<(?:[A-Za-z0-9_-]+:)?href[^>]*>(.*?)</(?:[A-Za-z0-9_-]+:)?href>',
      dotAll: true,
    ).allMatches(body).map((match) => _xmlDecode(match.group(1)!)).toSet();
    final responses = <String>[];
    for (final path in requested) {
      final resource = resources[path];
      if (resource == null || deletedPaths.contains(path)) {
        responses.add(_statusResponse(path, HttpStatus.notFound));
      } else if (resource.multistatusStatus case final status?) {
        responses.add(_statusResponse(path, status));
      } else {
        responses.add(_resourceResponse(resource, includeBody: true));
      }
    }
    await _xml(request, HttpStatus.multiStatus, _multistatus(responses));
  }

  Future<void> _getResource(HttpRequest request, String path) async {
    final resource = resources[path];
    if (resource == null || deletedPaths.contains(path)) {
      await _respond(request, HttpStatus.notFound, '');
      return;
    }
    await _respond(
      request,
      HttpStatus.ok,
      resource.body,
      headers: {
        'etag': resource.etag,
        'content-type': 'text/calendar; charset=utf-8',
      },
    );
  }

  Future<void> _putResource(
    HttpRequest request,
    String path,
    String body,
  ) async {
    if (collectionReadOnly) {
      await _respond(request, HttpStatus.forbidden, '');
      return;
    }
    var current = resources[path];
    if (raceNextMutation && current != null) {
      raceNextMutation = false;
      current.etag = '"race-${_revision += 1}"';
    }
    final ifNoneMatch = request.headers.value(HttpHeaders.ifNoneMatchHeader);
    final ifMatch = request.headers.value(HttpHeaders.ifMatchHeader);
    if (ifNoneMatch == '*' && current != null) {
      await _respond(request, HttpStatus.preconditionFailed, '');
      return;
    }
    if (ifMatch != null && (current == null || current.etag != ifMatch)) {
      await _respond(request, HttpStatus.preconditionFailed, '');
      return;
    }
    final canonical = rewriteMutations ? _rewrite(body) : body;
    final created = current == null;
    current ??= FakeDavResource(path: path, body: canonical, etag: '');
    current
      ..body = canonical
      ..etag = '"revision-${_revision += 1}"';
    resources[path] = current;
    deletedPaths.remove(path);
    if (dropAfterNextMutation) {
      dropAfterNextMutation = false;
      await _drop(request);
      return;
    }
    await _respond(
      request,
      created ? HttpStatus.created : HttpStatus.noContent,
      '',
      headers: {'etag': current.etag},
    );
  }

  Future<void> _deleteResource(HttpRequest request, String path) async {
    if (collectionReadOnly) {
      await _respond(request, HttpStatus.forbidden, '');
      return;
    }
    var current = resources[path];
    if (raceNextMutation && current != null) {
      raceNextMutation = false;
      current.etag = '"race-${_revision += 1}"';
    }
    final ifMatch = request.headers.value(HttpHeaders.ifMatchHeader);
    if (current == null || deletedPaths.contains(path)) {
      await _respond(request, HttpStatus.notFound, '');
      return;
    }
    if (ifMatch == null || current.etag != ifMatch) {
      await _respond(request, HttpStatus.preconditionFailed, '');
      return;
    }
    resources.remove(path);
    deletedPaths.add(path);
    if (dropAfterNextMutation) {
      dropAfterNextMutation = false;
      await _drop(request);
      return;
    }
    await _respond(request, HttpStatus.noContent, '');
  }

  String _principalResponse() => _multistatus([
    '''<d:response><d:href>${_xmlEscape(davRootPath)}</d:href>
<d:propstat><d:prop><d:current-user-principal><d:href>${_xmlEscape(principalPath)}</d:href></d:current-user-principal></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''',
  ]);

  String _homeResponse() => _multistatus([
    '''<d:response><d:href>${_xmlEscape(principalPath)}</d:href><d:propstat><d:prop>
<c:calendar-home-set><d:href>${_xmlEscape(calendarHomePath)}</d:href></c:calendar-home-set>
<c:calendar-user-address-set><d:href>mailto:alex@example.test</d:href></c:calendar-user-address-set>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''',
  ]);

  String _inventoryResponse() {
    final responses = <String>[
      '''<d:response><d:href>${_xmlEscape(calendarHomePath)}</d:href><d:propstat><d:prop>
<d:resourcetype><d:collection/></d:resourcetype></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''',
    ];
    if (!collectionRemoved) {
      final privileges = collectionReadOnly
          ? '<d:privilege><d:read/></d:privilege>'
          : '''<d:privilege><d:read/></d:privilege>
<d:privilege><d:write-content/></d:privilege><d:privilege><d:bind/></d:privilege>
<d:privilege><d:unbind/></d:privilege>''';
      responses.add(
        '''<d:response><d:href>${_xmlEscape(collectionPath)}</d:href><d:propstat><d:prop>
<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
<d:displayname>Work &amp; Tasks</d:displayname>
<d:current-user-privilege-set>$privileges</d:current-user-privilege-set>
<d:supported-report-set>
<d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report>
<d:supported-report><d:report><c:calendar-multiget/></d:report></d:supported-report>
<d:supported-report><d:report><c:calendar-query/></d:report></d:supported-report>
</d:supported-report-set>
<d:sync-token>${_xmlEscape(finalSyncToken)}</d:sync-token>
<c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>
<c:supported-calendar-data><c:calendar-data content-type="text/calendar" version="2.0"/></c:supported-calendar-data>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''',
      );
    }
    return _multistatus(responses);
  }

  String _memberInventoryResponse() => _multistatus([
    '''<d:response><d:href>${_xmlEscape(collectionPath)}</d:href><d:propstat><d:prop>
<d:resourcetype><d:collection/></d:resourcetype></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''',
    for (final resource in resources.values)
      if (!deletedPaths.contains(resource.path))
        _resourceOrStatusResponse(resource, includeBody: false),
  ]);

  String _syncResponse({
    required String token,
    required Iterable<FakeDavResource> live,
    required Iterable<String> deleted,
  }) => _multistatus([
    for (final resource in live)
      _resourceOrStatusResponse(resource, includeBody: false),
    for (final path in deleted) _statusResponse(path, HttpStatus.notFound),
  ], syncToken: token);

  String _resourceResponse(
    FakeDavResource resource, {
    required bool includeBody,
  }) =>
      '''<d:response><d:href>${_xmlEscape(resource.path)}</d:href><d:propstat><d:prop>
<d:getetag>${_xmlEscape(resource.etag)}</d:getetag>
${includeBody ? '<c:calendar-data content-type="text/calendar">${_xmlEscape(resource.body)}</c:calendar-data>' : ''}
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''';

  String _resourceOrStatusResponse(
    FakeDavResource resource, {
    required bool includeBody,
  }) {
    final status = resource.multistatusStatus;
    return status == null
        ? _resourceResponse(resource, includeBody: includeBody)
        : _statusResponse(resource.path, status);
  }

  String _statusResponse(String path, int status) =>
      '<d:response><d:href>${_xmlEscape(path)}</d:href>'
      '<d:status>HTTP/1.1 $status ${_reason(status)}</d:status></d:response>';

  String _multistatus(Iterable<String> responses, {String? syncToken}) =>
      '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
${responses.join('\n')}
${syncToken == null ? '' : '<d:sync-token>${_xmlEscape(syncToken)}</d:sync-token>'}
</d:multistatus>''';

  String _syncToken(String body) {
    final match = RegExp(
      r'<(?:[A-Za-z0-9_-]+:)?sync-token[^>]*>(.*?)</(?:[A-Za-z0-9_-]+:)?sync-token>',
      dotAll: true,
    ).firstMatch(body);
    return match == null ? '' : _xmlDecode(match.group(1)!).trim();
  }

  String _rewrite(String body) {
    if (body.contains('X-SERVER-REWRITE:canonical')) return body;
    for (final end in const ['END:VEVENT', 'END:VTODO']) {
      if (body.contains(end)) {
        return body.replaceFirst(end, 'X-SERVER-REWRITE:canonical\r\n$end');
      }
    }
    return body;
  }

  Future<void> _xml(HttpRequest request, int status, String body) => _respond(
    request,
    status,
    body,
    headers: {'content-type': 'application/xml; charset=utf-8'},
  );

  Future<void> _respond(
    HttpRequest request,
    int status,
    String body, {
    Map<String, String> headers = const {},
  }) async {
    request.response.statusCode = status;
    headers.forEach(request.response.headers.set);
    if (body.isNotEmpty) request.response.add(utf8.encode(body));
    await request.response.close();
  }

  Future<void> _drop(HttpRequest request) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.destroy();
  }
}

String _xmlEscape(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);

String _xmlDecode(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String _reason(int status) => switch (status) {
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  409 => 'Conflict',
  412 => 'Precondition Failed',
  423 => 'Locked',
  429 => 'Too Many Requests',
  500 => 'Internal Server Error',
  503 => 'Service Unavailable',
  507 => 'Insufficient Storage',
  _ => 'Status',
};

String _eventBody(String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Fake DAV//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260809T090000Z\r
DTEND:20260809T100000Z\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _taskBody(String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Fake DAV//EN\r
BEGIN:VTODO\r
UID:task@example.test\r
DTSTAMP:20260808T120000Z\r
DUE:20260809T120000Z\r
SUMMARY:$summary\r
END:VTODO\r
END:VCALENDAR\r
''';
