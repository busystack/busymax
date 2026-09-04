import 'dart:convert';

import 'package:crypto/crypto.dart';

const calendarEventGoogleCreateIdKey = '_googleCreateEventId';
const calendarEventMicrosoftTransactionIdKey = '_microsoftTransactionId';

/// Google event IDs accept lowercase base32hex characters. A SHA-256 digest
/// uses only the permitted 0-9 and a-f subset and remains stable across retries.
String googleCalendarCreateEventId(String operationId) {
  return sha256
      .convert(utf8.encode('busymax:event-create:$operationId'))
      .toString();
}

/// Pending cloud operations use UUIDs, which are suitable Graph transaction
/// identifiers and are already persisted before the request is sent.
String microsoftCalendarCreateTransactionId(String operationId) => operationId;
