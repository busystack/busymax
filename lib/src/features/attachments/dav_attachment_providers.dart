import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../dav/ical/ical_attachments.dart';
import '../../dav/ical/ical_document.dart';

typedef DavTaskAttachmentTarget = ({
  String accountId,
  String taskListId,
  String taskId,
});

final davEventAttachmentsProvider = StreamProvider.autoDispose
    .family<List<IcalAttachment>, String>((ref, id) {
      final db = ref.watch(databaseProvider);
      final repository = ref.watch(calendarRepositoryProvider);
      return (db.select(db.calendarEvents)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .asyncMap((event) async {
            if (event == null || event.isDeleted || event.icalUid == null) {
              return const <IcalAttachment>[];
            }
            final raw = await repository.nativeEventExport(event.id);
            return raw == null
                ? const <IcalAttachment>[]
                : readIcalAttachments(
                    raw,
                    IcalComponentKey(
                      componentType: 'VEVENT',
                      uid: event.icalUid!,
                      recurrenceIdKey: event.recurrenceIdKey,
                    ),
                    occurrenceKey: event.occurrenceKey,
                  );
          });
    });

final davTaskAttachmentsProvider = StreamProvider.autoDispose
    .family<List<IcalAttachment>, DavTaskAttachmentTarget>((ref, target) {
      final db = ref.watch(databaseProvider);
      final repository = ref.watch(
        tasksRepositoryForAccountProvider(target.accountId),
      );
      return (db.select(db.tasks)..where(
            (row) =>
                row.id.equals(target.taskId) &
                row.accountId.equals(target.accountId) &
                row.taskListId.equals(target.taskListId),
          ))
          .watchSingleOrNull()
          .asyncMap((task) async {
            if (task == null || task.deleted == true || task.icalUid == null) {
              return const <IcalAttachment>[];
            }
            final raw = await repository.nativeTaskExport(
              task.taskListId,
              task.id,
            );
            return raw == null
                ? const <IcalAttachment>[]
                : readIcalAttachments(
                    raw,
                    IcalComponentKey(
                      componentType: 'VTODO',
                      uid: task.icalUid!,
                      recurrenceIdKey: task.recurrenceIdKey,
                    ),
                  );
          });
    });
