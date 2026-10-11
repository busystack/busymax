import 'dart:typed_data';

import 'package:busystack_contacts/busystack_contacts.dart';

/// BusyMax policy, independent of the actual OAuth grant or DAV privileges.
/// The delegate remains private; all directory bindings pass through here.
final class ReadOnlyContactsProvider implements ContactsProvider {
  ReadOnlyContactsProvider(this._delegate);

  final ContactsProvider _delegate;

  static ContactSource effectiveSource(ContactSource source) {
    final capabilities = source.capabilities;
    if (!capabilities.create &&
        !capabilities.update &&
        !capabilities.delete &&
        !capabilities.photoWrite &&
        !source.canRename &&
        !source.canRemove) {
      return source;
    }
    return ContactSource.fromJson({
      ...source.toJson(),
      'capabilities': {
        ...capabilities.toJson(),
        'create': false,
        'update': false,
        'delete': false,
        'photoWrite': false,
      },
      'rename': false,
      'remove': false,
    });
  }

  Never _reject() => throw const ContactsException(
    ContactsFailure.permission,
    'busymax-contacts-read-only',
  );

  @override
  String get accountId => _delegate.accountId;
  @override
  ContactProviderKind get kind => _delegate.kind;

  @override
  Future<List<ContactSource>> discover(
    ContactsCancellationToken cancellation,
  ) async =>
      (await _delegate.discover(cancellation))
          .map(effectiveSource)
          .toList(growable: false);

  @override
  Future<ContactsPage> page(
    ContactSource source, {
    String? cursor,
    String? page,
    required ContactsCancellationToken cancellation,
  }) => _delegate.page(
    source,
    cursor: cursor,
    page: page,
    cancellation: cancellation,
  );

  @override
  Future<ContactRecord> get(
    ContactSource source,
    ContactIdentity identity,
    ContactsCancellationToken cancellation,
  ) => _delegate.get(source, identity, cancellation);

  @override
  Future<Uint8List?> photo(
    ContactSource source,
    ContactRecord record,
    ContactsCancellationToken cancellation,
  ) => _delegate.photo(source, record, cancellation);

  @override
  Future<ContactRecord?> findCreated(
    ContactSource source,
    ContactMutation mutation,
    ContactsCancellationToken cancellation,
  ) => _delegate.findCreated(source, mutation, cancellation);

  @override
  Future<ContactRecord> create(
    ContactSource source,
    ContactPatch patch,
    String mutationId,
    ContactsCancellationToken cancellation, {
    String? fullVcard,
  }) async => _reject();

  @override
  Future<ContactRecord> update(
    ContactSource source,
    ContactRecord base,
    ContactPatch patch,
    ContactsCancellationToken cancellation,
  ) async => _reject();

  @override
  Future<void> delete(
    ContactSource source,
    ContactRecord base,
    ContactsCancellationToken cancellation,
  ) async => _reject();

  @override
  Future<ContactRecord> setPhoto(
    ContactSource source,
    ContactRecord base,
    Uint8List? bytes,
    String mediaType,
    ContactsCancellationToken cancellation,
  ) async => _reject();

  @override
  Future<ContactActionResult> action(
    ContactProviderAction action,
    ContactsCancellationToken cancellation,
  ) async => _reject();

  @override
  ContactProviderAction decodeAction(Map<String, dynamic> json) =>
      _delegate.decodeAction(json);

  @override
  void close() => _delegate.close();
}
