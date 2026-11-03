import 'dart:convert';

import '../../db/app_database.dart';
import '../dav_errors.dart';

/// Operation-specific feedback, separate from the account's pull outcome.
final class DavCollectionCreationFailure {
  DavCollectionCreationFailure.fromStored(
    this.operation, {
    DavException? currentError,
  }) : error =
           currentError ??
           DavException(
             kind:
                 DavErrorKind.values
                     .where((kind) => kind.name == operation.lastErrorKind)
                     .firstOrNull ??
                 DavErrorKind.conflict,
             code: operation.lastErrorCode ?? 'DavCollectionNameConflict',
             statusCode: operation.lastErrorStatus,
             correlationId: operation.id,
             safeMessage: 'The collection creation did not complete.',
           );

  final DavCollectionCreation operation;
  final DavException error;

  bool get pending =>
      operation.state == 'prepared' || operation.state == 'dispatched';

  bool get taskList {
    try {
      final components = jsonDecode(operation.componentsJson);
      return components is List &&
          components.length == 1 &&
          components.single == 'VTODO';
    } on FormatException {
      return false;
    }
  }
}
