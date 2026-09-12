typedef CollectionIdReplacement =
    Future<void> Function(String oldId, String newId);

/// Local preference failures must never retry an already-created collection.
Future<void> notifyCollectionIdReplacement(
  CollectionIdReplacement? callback,
  String oldId,
  String newId,
) async {
  if (oldId == newId) return;
  try {
    await callback?.call(oldId, newId);
  } on Object {
    // The database transaction and remote creation have already succeeded.
  }
}
