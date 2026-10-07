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
