// BusyMax keeps its error presentation and provider policies app-owned, but
// uses the shared DAV failure taxonomy at every protocol boundary.
export 'package:busystack_dav/busystack_dav.dart'
    show
        DavErrorKind,
        DavErrorCategory,
        DavErrorDisposition,
        DavException,
        isDavCollectionPendingChangesError,
        classifyDavError,
        parseDavRetryAfter;

/// The remote CalDAV mutation committed; only refreshing local projections failed.
/// Callers must not present this as a failed mutation or invite blind replay.
final class DavRefreshPending implements Exception {
  const DavRefreshPending();
  @override
  String toString() => 'CalDAV change committed; refresh pending';
}
