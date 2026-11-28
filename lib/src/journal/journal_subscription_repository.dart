import 'package:drift/drift.dart';

import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';
import '../db/app_database.dart';
import 'journal_component.dart';

final class JournalSubscriptionEntry {
  const JournalSubscriptionEntry(this.source, this.subscription, this.journal);

  final CalendarSource source;
  final WebCalSubscription subscription;
  final JournalComponent journal;

  String resource() {
    final uid = journal.component.firstProperty('UID')?.rawValue;
    final document = IcalDocument.parse(subscription.snapshotIcsBody);
    document.root.children.removeWhere(
      (node) =>
          node is IcalComponent &&
          node.name != 'VTIMEZONE' &&
          (node.name != 'VJOURNAL' ||
              node.firstProperty('UID')?.rawValue != uid),
    );
    document.root.structurallyDirty = true;
    return document.serialize();
  }
}

/// Projects journal notes from the existing, sanitized WebCal snapshot. The
/// subscription fetch and its calendar-source visibility remain authoritative.
Future<List<JournalSubscriptionEntry>> listJournalSubscriptions(
  AppDatabase database, {
  Set<String>? sourceIds,
}) async {
  final subscriptions = database.webCalSubscriptions;
  final sources = database.calendarSources;
  final query = database.select(subscriptions).join([
    innerJoin(sources, sources.id.equalsExp(subscriptions.calendarSourceId)),
  ])..where(sources.selected & sources.hidden.not() & sources.isDeleted.not());
  if (sourceIds != null) query.where(sources.id.isIn(sourceIds));
  final entries = <JournalSubscriptionEntry>[];
  for (final row in await query.get()) {
    final subscription = row.readTable(subscriptions);
    final source = row.readTable(sources);
    for (final journal in _parseJournals(subscription.snapshotIcsBody)) {
      entries.add(JournalSubscriptionEntry(source, subscription, journal));
    }
  }
  return entries;
}

List<JournalComponent> _parseJournals(String calendar) {
  try {
    return [
      for (final component in IcalDocument.parse(calendar).calendarComponents)
        if (component.name == 'VJOURNAL')
          // A malformed temporal value must not hide other entries in the feed.
          if (_canRead(component)) JournalComponent(component),
    ];
  } on DavException {
    return const [];
  }
}

bool _canRead(IcalComponent component) {
  try {
    parseIcalTemporal(component.firstProperty('DTSTART'));
    return true;
  } on DavException {
    return false;
  }
}
