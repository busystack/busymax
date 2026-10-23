import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/db/app_database.dart';

/// Disposable DAV resources with real mutation effects and ETag enforcement.
class StatefulTaskDavRemote implements DavMutationRemoteClient {
  StatefulTaskDavRemote(Iterable<DavObject> objects)
    : resources = {
        for (final object in objects)
          object.hrefKey: (raw: object.rawIcsBody, etag: object.etag!),
      };

  final Map<String, ({String raw, String etag})> resources;
  var puts = 0;
  var deletes = 0;
  var moves = 0;
  var _revision = 0;

  static const _stale = DavConditionalResponse(
    status: DavConditionalStatus.preconditionFailed,
    statusCode: 412,
    etag: null,
  );
  static const _missing = DavConditionalResponse(
    status: DavConditionalStatus.missing,
    statusCode: 404,
    etag: null,
  );

  @override
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  }) async {
    final current = resources[uri.path];
    if (ifNoneMatch
        ? current != null
        : current == null || current.etag != ifMatch) {
      return _stale;
    }
    final etag = '"qa-${++_revision}"';
    resources[uri.path] = (raw: rawIcs, etag: etag);
    puts++;
    return DavConditionalResponse(
      status: DavConditionalStatus.success,
      statusCode: 204,
      etag: etag,
    );
  }

  @override
  Future<DavConditionalResponse> conditionalDelete({
    required Uri uri,
    required String ifMatch,
    required String correlationId,
  }) async {
    final current = resources[uri.path];
    if (current == null) return _missing;
    if (current.etag != ifMatch) return _stale;
    resources.remove(uri.path);
    deletes++;
    return const DavConditionalResponse(
      status: DavConditionalStatus.success,
      statusCode: 204,
      etag: null,
    );
  }

  @override
  Future<DavConditionalResponse> conditionalMove({
    required Uri sourceUri,
    required Uri destinationUri,
    required String ifMatch,
    required String correlationId,
  }) async {
    final current = resources[sourceUri.path];
    if (current == null) return _missing;
    if (current.etag != ifMatch || resources.containsKey(destinationUri.path)) {
      return _stale;
    }
    resources.remove(sourceUri.path);
    final etag = '"qa-${++_revision}"';
    resources[destinationUri.path] = (raw: current.raw, etag: etag);
    moves++;
    return DavConditionalResponse(
      status: DavConditionalStatus.success,
      statusCode: 201,
      etag: etag,
    );
  }

  @override
  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  }) async {
    final current = resources[hrefKey];
    return current == null
        ? DavFetchedMember.missing(hrefKey: hrefKey, requestUri: uri)
        : DavFetchedMember.live(
            hrefKey: hrefKey,
            requestUri: uri,
            etag: current.etag,
            contentType: 'text/calendar',
            rawIcsBody: current.raw,
          );
  }
}
