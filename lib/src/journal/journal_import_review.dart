import '../dav/ical/dav_native_import.dart';

/// Holds reviewed input and its local outcomes while the journal route closes
/// and reopens. Queue IDs associate a later provider outcome with the input.
final class JournalImportReview {
  JournalImportReview(this.preview);

  final NextcloudNativeImportPreview preview;
  String? destinationId;
  final _results =
      <(String componentType, String uid), (String, NativeImportItemResult)>{};

  List<NativeImportItemResult> get results => [
    ...preview.rejected,
    for (final (_, result) in _results.values) result,
  ];

  NextcloudNativeImportPreview remaining(String destination) =>
      NextcloudNativeImportPreview(
        preview.resources.where((resource) {
          final outcome = _results[(resource.componentType, resource.uid)];
          return outcome == null ||
              (outcome.$2.status != NativeImportItemStatus.queued &&
                  (outcome.$1 != destination ||
                      outcome.$2.status != NativeImportItemStatus.duplicate));
        }).toList(),
        const [],
        preview.schedulingMethod,
      );

  void remember(String destination, Iterable<NativeImportItemResult> outcomes) {
    destinationId = destination;
    for (final outcome in outcomes) {
      _results[(outcome.componentType, outcome.uid)] = (destination, outcome);
    }
  }
}
