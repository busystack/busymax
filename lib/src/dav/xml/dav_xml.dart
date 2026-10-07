// The shared parser owns bounded XML decoding, DTD/entity rejection, DAV
// status parsing, and namespace-aware multistatus/property mechanics.
export 'package:busystack_dav/busystack_dav.dart'
    show
        davNamespace,
        caldavNamespace,
        calendarServerNamespace,
        appleIcalNamespace,
        owncloudNamespace,
        nextcloudNamespace,
        DavXmlLimits,
        DavPropertyName,
        DavProperty,
        DavPropstat,
        DavMultistatusResponse,
        DavMultistatus,
        DavXmlParser;
