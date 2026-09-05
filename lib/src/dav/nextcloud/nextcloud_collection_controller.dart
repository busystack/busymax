import 'package:flutter/foundation.dart';

import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';
import 'nextcloud_sharing_service.dart';

/// Shared presentation state. Network requests start from explicit actions,
/// never widget builds; disposal prevents stale completion from reviving UI.
final class NextcloudCollectionController extends ChangeNotifier {
  NextcloudCollectionController(this.service, this.collectionId);
  final NextcloudSharingService service;
  final String collectionId;
  NextcloudSharingState? state;
  List<NextcloudShareRecipient> recipients = const [];
  bool busy = false;
  bool failed = false;
  bool refreshPending = false;
  Object? error;
  bool _disposed = false;
  int _searchGeneration = 0;
  final values = <DavPropertyName, String>{};
  final _baseline = <DavPropertyName, String>{};
  bool get dirty => !mapEquals(values, _baseline);

  Future<void> load() => _run(() async {
    final loaded = await service.load(collectionId);
    if (_disposed) return;
    state = loaded;
    refreshPending = false;
    values.clear();
    for (final name in nextcloudWritableProperties) {
      values[name] = name.localName == 'schedule-calendar-transp'
          ? (nextcloudPropertyNames(
                  loaded.collection.properties[name],
                ).contains('{$caldavNamespace}transparent')
                ? 'transparent'
                : 'opaque')
          : loaded.collection.properties[name]?.text.trim() ?? '';
    }
    _baseline
      ..clear()
      ..addAll(values);
  });
  void change(DavPropertyName name, String value) {
    values[name] = value;
    _notify();
  }

  Future<void> save() => _run(() async {
    final result = await service.collections.update(collectionId, {
      for (final entry in values.entries)
        if (_baseline[entry.key] != entry.value) entry.key: entry.value,
    });
    refreshPending = result == NextcloudMutationOutcome.refreshPending;
    _baseline
      ..clear()
      ..addAll(values);
  });
  Future<void> search(String query) async {
    final generation = ++_searchGeneration;
    await _run(() async {
      final found = await service.search(query);
      if (!_disposed && generation == _searchGeneration) recipients = found;
    });
  }

  void clearSearch() {
    _searchGeneration++;
    recipients = const [];
    _notify();
  }

  Future<void> share(NextcloudShareRecipient recipient, bool? writable) =>
      _run(() async {
        final result = await service.changeShare(
          collectionId,
          recipient,
          writable: writable,
        );
        refreshPending = result == NextcloudMutationOutcome.refreshPending;
        await _refreshAfterCommit();
        if (!_disposed) clearSearch();
      });
  Future<void> publish(bool published) => _run(() async {
    final result = await service.setPublished(collectionId, published);
    refreshPending = result == NextcloudMutationOutcome.refreshPending;
    await _refreshAfterCommit();
  });
  Future<void> _refreshAfterCommit() async {
    try {
      final loaded = await service.load(collectionId);
      if (!_disposed) state = loaded;
    } on Object {
      // The write has already succeeded. Never offer it again as a failed save.
      refreshPending = true;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    failed = false;
    error = null;
    _notify();
    try {
      await action();
    } on Object catch (caught) {
      failed = true;
      error = caught;
    }
    if (!_disposed) {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchGeneration++;
    super.dispose();
  }
}
