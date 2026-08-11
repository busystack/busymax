import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../dav_errors.dart';

const davNamespace = 'DAV:';
const caldavNamespace = 'urn:ietf:params:xml:ns:caldav';
const calendarServerNamespace = 'http://calendarserver.org/ns/';
const appleIcalNamespace = 'http://apple.com/ns/ical/';
const owncloudNamespace = 'http://owncloud.org/ns';
const nextcloudNamespace = 'http://nextcloud.com/ns';

final class DavXmlLimits {
  const DavXmlLimits({
    this.maximumBytes = 8 * 1024 * 1024,
    this.maximumDepth = 64,
    this.maximumElements = 100000,
    this.maximumTextBytes = 4 * 1024 * 1024,
  });

  final int maximumBytes;
  final int maximumDepth;
  final int maximumElements;
  final int maximumTextBytes;
}

final class DavPropertyName {
  const DavPropertyName(this.namespaceUri, this.localName);

  final String? namespaceUri;
  final String localName;

  @override
  bool operator ==(Object other) =>
      other is DavPropertyName &&
      other.namespaceUri == namespaceUri &&
      other.localName == localName;

  @override
  int get hashCode => Object.hash(namespaceUri, localName);

  @override
  String toString() => '{$namespaceUri}$localName';
}

final class DavProperty {
  const DavProperty({required this.name, required this.element});

  final DavPropertyName name;
  final XmlElement element;

  String get text => element.innerText;

  Iterable<XmlElement> get childElements => element.childElements;
}

final class DavPropstat {
  const DavPropstat({
    required this.statusCode,
    required this.reasonPhrase,
    required this.properties,
    required this.errorConditions,
  });

  final int statusCode;
  final String reasonPhrase;
  final List<DavProperty> properties;
  final Set<DavPropertyName> errorConditions;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  DavProperty? property(String namespaceUri, String localName) {
    for (final property in properties) {
      if (property.name == DavPropertyName(namespaceUri, localName)) {
        return property;
      }
    }
    return null;
  }
}

final class DavMultistatusResponse {
  const DavMultistatusResponse({
    required this.href,
    required this.propstats,
    required this.statusCode,
    required this.reasonPhrase,
    required this.errorConditions,
  });

  final String href;
  final List<DavPropstat> propstats;
  final int? statusCode;
  final String? reasonPhrase;
  final Set<DavPropertyName> errorConditions;

  bool get isMissing =>
      statusCode == 404 ||
      (statusCode == null &&
          propstats.isNotEmpty &&
          propstats.every((propstat) => propstat.statusCode == 404));

  DavProperty? successfulProperty(String namespaceUri, String localName) {
    for (final propstat in propstats.where((entry) => entry.isSuccessful)) {
      final property = propstat.property(namespaceUri, localName);
      if (property != null) {
        return property;
      }
    }
    return null;
  }
}

final class DavMultistatus {
  const DavMultistatus({
    required this.responses,
    required this.syncToken,
    required this.errorConditions,
  });

  final List<DavMultistatusResponse> responses;
  final String? syncToken;
  final Set<DavPropertyName> errorConditions;

  bool hasCondition(String namespaceUri, String localName) =>
      errorConditions.contains(DavPropertyName(namespaceUri, localName)) ||
      responses.any(
        (response) =>
            response.errorConditions.contains(
              DavPropertyName(namespaceUri, localName),
            ) ||
            response.propstats.any(
              (propstat) => propstat.errorConditions.contains(
                DavPropertyName(namespaceUri, localName),
              ),
            ),
      );
}

final class DavXmlParser {
  const DavXmlParser({this.limits = const DavXmlLimits()});

  final DavXmlLimits limits;

  Set<DavPropertyName> parseDavError(Uint8List bytes, {String? correlationId}) {
    final document = _parseDocument(bytes, correlationId);
    final root = document.rootElement;
    if (!_matches(root, davNamespace, 'error')) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlExpectedError',
        'The DAV server returned an invalid error document.',
        correlationId,
      );
    }
    return Set.unmodifiable({
      for (final child in root.childElements)
        DavPropertyName(child.name.namespaceUri, child.name.local),
    });
  }

  DavMultistatus parseMultistatus(Uint8List bytes, {String? correlationId}) {
    final document = _parseDocument(bytes, correlationId);
    final root = document.rootElement;
    if (!_matches(root, davNamespace, 'multistatus')) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlExpectedMultistatus',
        'The DAV server response was not a DAV multistatus document.',
        correlationId,
      );
    }

    final responses = <DavMultistatusResponse>[];
    for (final response in _direct(root, davNamespace, 'response')) {
      responses.add(_parseResponse(response, correlationId));
    }
    final syncToken = _firstDirect(
      root,
      davNamespace,
      'sync-token',
    )?.innerText.trim();
    return DavMultistatus(
      responses: List.unmodifiable(responses),
      syncToken: syncToken == null || syncToken.isEmpty ? null : syncToken,
      errorConditions: _parseErrorConditions(root),
    );
  }

  XmlDocument _parseDocument(Uint8List bytes, String? correlationId) {
    if (bytes.length > limits.maximumBytes) {
      throw _error(
        DavErrorKind.responseTooLarge,
        'DavXmlResponseTooLarge',
        'The DAV XML response exceeded the configured size limit.',
        correlationId,
      );
    }
    final source = _decodeUtf8(bytes, correlationId);
    if (RegExp(
      r'<!\s*(DOCTYPE|ENTITY)\b',
      caseSensitive: false,
    ).hasMatch(source)) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlDtdForbidden',
        'DAV XML must not contain DTD or entity declarations.',
        correlationId,
      );
    }

    late final XmlDocument document;
    try {
      document = XmlDocument.parse(source);
    } on Object {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlMalformed',
        'The DAV server returned malformed XML.',
        correlationId,
      );
    }
    _enforceTreeLimits(document, correlationId);
    return document;
  }

  DavMultistatusResponse _parseResponse(
    XmlElement element,
    String? correlationId,
  ) {
    final href = _firstDirect(element, davNamespace, 'href')?.innerText.trim();
    if (href == null || href.isEmpty) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlResponseMissingHref',
        'A DAV multistatus response did not contain an HREF.',
        correlationId,
      );
    }
    final propstats = <DavPropstat>[];
    for (final propstat in _direct(element, davNamespace, 'propstat')) {
      propstats.add(_parsePropstat(propstat, correlationId));
    }
    final statusText = _firstDirect(element, davNamespace, 'status')?.innerText;
    final status = statusText == null
        ? null
        : _parseStatus(statusText, correlationId);
    if (status == null && propstats.isEmpty) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlResponseMissingStatus',
        'A DAV multistatus response contained no status information.',
        correlationId,
      );
    }
    return DavMultistatusResponse(
      href: href,
      propstats: List.unmodifiable(propstats),
      statusCode: status?.code,
      reasonPhrase: status?.reason,
      errorConditions: _parseErrorConditions(element),
    );
  }

  DavPropstat _parsePropstat(XmlElement element, String? correlationId) {
    final statusText = _firstDirect(element, davNamespace, 'status')?.innerText;
    if (statusText == null) {
      throw _error(
        DavErrorKind.malformedStatus,
        'DavXmlPropstatMissingStatus',
        'A DAV property status did not contain an HTTP status line.',
        correlationId,
      );
    }
    final status = _parseStatus(statusText, correlationId);
    final prop = _firstDirect(element, davNamespace, 'prop');
    if (prop == null) {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlPropstatMissingProp',
        'A DAV property status did not contain a property container.',
        correlationId,
      );
    }
    final properties = [
      for (final child in prop.childElements)
        DavProperty(
          name: DavPropertyName(child.name.namespaceUri, child.name.local),
          element: child,
        ),
    ];
    return DavPropstat(
      statusCode: status.code,
      reasonPhrase: status.reason,
      properties: List.unmodifiable(properties),
      errorConditions: _parseErrorConditions(element),
    );
  }

  ({int code, String reason}) _parseStatus(
    String source,
    String? correlationId,
  ) {
    final match = RegExp(
      r'^HTTP/1[.][01] ([1-5][0-9]{2})(?: ([^\r\n]*))?$',
    ).firstMatch(source.trim());
    if (match == null) {
      throw _error(
        DavErrorKind.malformedStatus,
        'DavMalformedHttpStatusLine',
        'The DAV server returned a malformed HTTP status line.',
        correlationId,
      );
    }
    return (
      code: int.parse(match.group(1)!),
      reason: match.group(2)?.trim() ?? '',
    );
  }

  Set<DavPropertyName> _parseErrorConditions(XmlElement container) {
    final result = <DavPropertyName>{};
    for (final error in _direct(container, davNamespace, 'error')) {
      for (final child in error.childElements) {
        result.add(DavPropertyName(child.name.namespaceUri, child.name.local));
      }
    }
    return Set.unmodifiable(result);
  }

  void _enforceTreeLimits(XmlDocument document, String? correlationId) {
    var elementCount = 0;
    var textBytes = 0;
    void visit(XmlNode node, int depth) {
      if (depth > limits.maximumDepth) {
        throw _error(
          DavErrorKind.malformedXml,
          'DavXmlDepthLimitExceeded',
          'The DAV XML response exceeded the nesting limit.',
          correlationId,
        );
      }
      if (node is XmlElement) {
        elementCount += 1;
        if (elementCount > limits.maximumElements) {
          throw _error(
            DavErrorKind.malformedXml,
            'DavXmlElementLimitExceeded',
            'The DAV XML response contained too many elements.',
            correlationId,
          );
        }
      } else if (node is XmlText) {
        textBytes += utf8.encode(node.value).length;
        if (textBytes > limits.maximumTextBytes) {
          throw _error(
            DavErrorKind.malformedXml,
            'DavXmlTextLimitExceeded',
            'The DAV XML response contained too much text.',
            correlationId,
          );
        }
      }
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    visit(document, 0);
  }

  String _decodeUtf8(Uint8List bytes, String? correlationId) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw _error(
        DavErrorKind.malformedXml,
        'DavXmlInvalidUtf8',
        'The DAV server returned XML that is not valid UTF-8.',
        correlationId,
      );
    }
  }

  DavException _error(
    DavErrorKind kind,
    String code,
    String safeMessage,
    String? correlationId,
  ) => DavException(
    kind: kind,
    code: code,
    safeMessage: safeMessage,
    correlationId: correlationId,
  );
}

Iterable<XmlElement> _direct(
  XmlElement parent,
  String namespaceUri,
  String localName,
) => parent.childElements.where(
  (element) => _matches(element, namespaceUri, localName),
);

XmlElement? _firstDirect(
  XmlElement parent,
  String namespaceUri,
  String localName,
) {
  for (final element in parent.childElements) {
    if (_matches(element, namespaceUri, localName)) {
      return element;
    }
  }
  return null;
}

bool _matches(XmlElement element, String namespaceUri, String localName) =>
    element.name.namespaceUri == namespaceUri &&
    element.name.local == localName;
