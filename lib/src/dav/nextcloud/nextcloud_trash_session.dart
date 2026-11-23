import 'package:flutter/foundation.dart';

import '../http/dav_http_transport.dart';
import 'nextcloud_dav_context.dart';
import 'nextcloud_trash_service.dart';

/// Coordinates a single trash listing, its optional previews and mutations.
final class NextcloudTrashSession extends ChangeNotifier {
  NextcloudTrashSession(this._service);

  final NextcloudTrashService _service;
  final _cancellation = DavCancellationToken();
  final _loadingDetails = <Uri>{};
  int _listingEpoch = 0;
  bool _disposed = false;
  bool _mutating = false;
  NextcloudTrashListing? listing;
  bool busy = false;
  bool refreshPending = false;
  bool _listingStale = true;
  Future<NextcloudMutationOutcome>? _accountRefresh;
  Object? error;

  bool get canMutate => !busy && !_listingStale && !refreshPending;

  bool loadingDetails(Uri href) => _loadingDetails.contains(href);

  @override
  void dispose() {
    _disposed = true;
    _cancellation.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (_mutating || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    await _reload(retryAccountRefresh: true);
  }

  Future<void> mutate(
    NextcloudTrashItem item, {
    required bool permanent,
  }) async {
    if (!canMutate || _disposed) return;
    busy = true;
    _mutating = true;
    error = null;
    _listingEpoch++;
    notifyListeners();
    try {
      final result = permanent
          ? await _service.permanentlyDelete(item)
          : await _service.restore(item);
      if (_disposed) return;
      // Block actions against the previous listing until its replacement loads.
      _listingStale = true;
      refreshPending = result == NextcloudMutationOutcome.refreshPending;
      if (!refreshPending) {
        _mutating = false;
        await _reload();
        return;
      }
    } on Object catch (failure) {
      error = failure;
    }
    _mutating = false;
    if (_disposed) return;
    busy = false;
    notifyListeners();
  }

  Future<void> _reload({bool retryAccountRefresh = false}) async {
    final epoch = ++_listingEpoch;
    try {
      final result = await _service.list(cancellationToken: _cancellation);
      if (_disposed || _listingEpoch != epoch) return;
      listing = result;
      _listingStale = false;
    } on Object catch (failure) {
      if (_disposed || _listingEpoch != epoch) return;
      _listingStale = true;
      error = failure;
    }
    if (retryAccountRefresh && refreshPending) {
      notifyListeners();
      await _retryAccountRefresh();
    }
    if (_disposed || _listingEpoch != epoch) return;
    busy = false;
    notifyListeners();
    if (error != null) return;

    final previews = listing!.items.where((item) => item.canPreview).take(5);
    for (final item in previews) {
      if (_disposed || _listingEpoch != epoch || busy) break;
      await details(item, automatic: true);
    }
  }

  Future<void> _retryAccountRefresh() async {
    final refresh = _accountRefresh ??= _service.refreshAccount();
    final outcome = await refresh;
    if (!identical(_accountRefresh, refresh)) return;
    _accountRefresh = null;
    if (!_disposed) {
      refreshPending = outcome == NextcloudMutationOutcome.refreshPending;
    }
  }

  Future<void> details(
    NextcloudTrashItem item, {
    bool automatic = false,
  }) async {
    final current = listing;
    if (busy ||
        _disposed ||
        current == null ||
        !_loadingDetails.add(item.href)) {
      return;
    }
    final epoch = _listingEpoch;
    notifyListeners();
    try {
      final detailed = await _service.details(
        item,
        cancellationToken: _cancellation,
      );
      if (_disposed || _listingEpoch != epoch) return;
      listing = NextcloudTrashListing(
        List.unmodifiable(
          listing!.items.map((row) => row.href == item.href ? detailed : row),
        ),
        current.retentionSeconds,
      );
    } on Object catch (failure) {
      if (!automatic && !_disposed && _listingEpoch == epoch) error = failure;
    } finally {
      _loadingDetails.remove(item.href);
      if (!_disposed) notifyListeners();
    }
  }
}
