import 'dart:convert';

import '../dav/dav_errors.dart';
import '../dav/ical/dav_native_import.dart';
import '../db/app_database.dart';
import 'journal_repository.dart';

/// Retains the reviewed input independently of the queued resources.
final class JournalImportReview {
  JournalImportReview(this.preview, List<int> sourceBytes)
    : sourceBytes = List.unmodifiable(sourceBytes);

  static const draftId = 'import-review';

  final NextcloudNativeImportPreview preview;
  final List<int> sourceBytes;
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

  String encode() => jsonEncode({
    'format': 'busymax-journal-import-review',
    'version': 1,
    'sourceBase64': base64Encode(sourceBytes),
    'method': preview.schedulingMethod,
    'destination': destinationId,
    'resources': [
      for (final resource in preview.resources)
        [resource.uid, resource.componentType, resource.rawIcs],
    ],
    'rejected': preview.rejected.map(_encodeOutcome).toList(),
    'outcomes': [
      for (final (destination, outcome) in _results.values)
        [destination, _encodeOutcome(outcome)],
    ],
  });

  static JournalImportReview decode(String content) {
    final state = jsonDecode(content) as Map<String, Object?>;
    if (state['format'] != 'busymax-journal-import-review' ||
        state['version'] != 1) {
      throw const FormatException('Unrecognized journal import review format.');
    }
    final review = JournalImportReview(
      NextcloudNativeImportPreview(
        [
          for (final row in (state['resources'] as List).cast<List>())
            NativeImportResource(
              row[0] as String,
              row[1] as String,
              row[2] as String,
            ),
        ],
        (state['rejected'] as List).cast<List>().map(_decodeOutcome).toList(),
        state['method'] as String?,
      ),
      base64Decode(state['sourceBase64'] as String),
    );
    for (final row in (state['outcomes'] as List).cast<List>()) {
      review.remember(row[0] as String, [_decodeOutcome(row[1] as List)]);
    }
    return review..destinationId = state['destination'] as String?;
  }

  static List<String?> _encodeOutcome(NativeImportItemResult item) => [
    item.uid,
    item.componentType,
    item.status.name,
    item.code,
    item.safeMessage,
    item.operationId,
  ];

  static NativeImportItemResult _decodeOutcome(List row) =>
      NativeImportItemResult(
        row[0] as String,
        row[1] as String,
        NativeImportItemStatus.values.byName(row[2] as String),
        row[3] as String?,
        row[4] as String?,
        row[5] as String?,
      );
}

final class JournalImportReviewRepository {
  JournalImportReviewRepository(this.journals);

  final JournalRepository journals;

  Stream<JournalImportReview?> watch() => journals
      .watchDraft(JournalImportReview.draftId)
      .map(
        (draft) => draft == null
            ? null
            : JournalImportReview.decode(draft.contentJson),
      );

  Future<void> begin(DavCollection source, JournalImportReview review) =>
      journals.database.transaction(() async {
        if (await journals.readDraft(JournalImportReview.draftId) != null) {
          throw _reviewChanged;
        }
        await _save(source.id, review..destinationId = source.id);
      });

  Future<void> selectDestination(
    JournalImportReview expected,
    DavCollection destination,
  ) => _update(expected, (latest) async {
    await _save(destination.id, latest..destinationId = destination.id);
  });

  Future<void> queue(JournalImportReview expected, DavCollection source) =>
      _update(expected, (latest) async {
        final results = await DavNativeImportService(journals.database).import(
          accountId: source.accountId,
          collectionId: source.id,
          preview: latest.remaining(source.id),
        );
        latest.remember(source.id, results);
        // Commit operation IDs and queued mutations together so a restart
        // never retries siblings whose successful outcomes were already saved.
        await _save(source.id, latest);
      });

  Future<void> discard(JournalImportReview expected) => _update(
    expected,
    (_) => journals.discardDraft(JournalImportReview.draftId),
  );

  Future<void> _save(String collection, JournalImportReview review) =>
      journals.saveDraft(
        id: JournalImportReview.draftId,
        collectionId: collection,
        baselineDigest: null,
        contentJson: review.encode(),
      );

  Future<void> _update(
    JournalImportReview expected,
    Future<void> Function(JournalImportReview) change,
  ) => journals.database.transaction(() async {
    final draft = await journals.readDraft(JournalImportReview.draftId);
    if (draft?.contentJson != expected.encode()) throw _reviewChanged;
    await change(JournalImportReview.decode(draft!.contentJson));
  });

  static const _reviewChanged = DavException(
    kind: DavErrorKind.conflict,
    code: 'DavJournalImportReviewChanged',
    safeMessage:
        'The saved import review changed. Reopen it before continuing.',
  );
}
