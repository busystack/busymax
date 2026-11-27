import 'package:flutter/foundation.dart';

import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';
import 'nextcloud_sharing_service.dart';
import '../ical/dav_native_export.dart';

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
  Map<DavPropertyName, NextcloudCollectionValidation> fieldErrors = {};
  bool _disposed = false;
  int _searchGeneration = 0;
  bool searching = false;
  bool _searchFailed = false;
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
          ? (nextcloudPropertyNames(loaded.collection.properties[name])
                    .contains('{$caldavNamespace}transparent')
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
    fieldErrors.remove(name);
    _notify();
  }

  Future<void> save() => _run(() async {
    final changes = {
      for (final entry in values.entries)
        if (_baseline[entry.key] != entry.value) entry.key: entry.value,
    };
    fieldErrors = Map.of(validateNextcloudCollectionChanges(changes));
    if (fieldErrors.isNotEmpty) {
      throw NextcloudCollectionValidationException(fieldErrors);
    }
    final result = await service.collections.update(collectionId, changes);
    refreshPending = result == NextcloudMutationOutcome.refreshPending;
    _baseline
      ..clear()
      ..addAll(values);
  });
  Future<void> search(String query) async {
    final term = query.trim();
    if (_disposed || busy || term.isEmpty) return;
    final generation = ++_searchGeneration;
    searching = true;
    _searchFailed = false;
    recipients = const [];
    failed = false;
    error = null;
    _notify();
    try {
      final found = await service.search(term);
      if (!_disposed && generation == _searchGeneration) recipients = found;
    } on Object catch (failure) {
      if (!_disposed && generation == _searchGeneration) {
        _searchFailed = true;
        failed = true;
        error = failure;
      }
    } finally {
      if (!_disposed && generation == _searchGeneration) {
        searching = false;
        _notify();
      }
    }
  }

  void clearSearch() {
    _searchGeneration++;
    searching = false;
    if (_searchFailed) {
      _searchFailed = false;
      failed = false;
      error = null;
    }
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
  Future<void> exportTo(Future<void> Function(DavCollectionExport) save) =>
      _run(() async {
        final snapshot = await DavNativeExportService(
          service.collections.database,
        ).collectionForReview(service.collections.accountId, collectionId);
        if (!_disposed) await save(snapshot);
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
    if (searching) clearSearch();
    _searchFailed = false;
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
