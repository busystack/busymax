import 'dart:convert';

import '../../../core/time/provider_date_time.dart';
import '../../../dav/ical/ical_recurrence.dart';
import '../../../dav/ical/ical_document.dart';
import '../../../dav/ical/ical_semantics.dart';
import '../../../providers/busy_provider.dart';
import 'event_recurrence_codec.dart';
import 'recurrence_rule.dart';

/// Recurrence positions and the exception timing policy of a series edit.
final class SeriesTimingChange {
  SeriesTimingChange._({
    required this.provider,
    required this.originalRule,
    required this.rule,
    required this.originalMasterStart,
    required this.masterStart,
    required this.originalOccurrenceStart,
    required this.desiredStart,
    required this.requiresConfirmation,
    required this.allDay,
    required this.timeZone,
    this.shiftExceptions = false,
    String? savedSignature,
    this.civilToUtc,
    this.utcToCivil,
    this.originalCivilToUtc,
    this.originalTimeZone,
    this.monthDayMapping = const {},
  }) : _savedSignature = savedSignature;

  factory SeriesTimingChange.plan({
    required BusyProvider provider,
    required Object original,
    required DateTime masterStart,
    required DateTime occurrenceStart,
    required DateTime desiredStart,
    required bool allDay,
    required String? originalTimeZone,
    required String? timeZone,
    bool shiftExceptions = false,
    DateTime Function(DateTime)? civilToUtc,
    DateTime Function(DateTime)? utcToCivil,
    DateTime Function(DateTime)? originalCivilToUtc,
  }) {
    final before = _wall(occurrenceStart);
    final after = _wall(desiredStart);
    final master = _wall(masterStart);
    final dateChanged = _date(before) != _date(after);
    final originalRule = EventRecurrenceCodec.decode(
      provider,
      provider == BusyProvider.microsoft
          ? original
          : original is Map
          ? {'rules': original['rules']}
          : original is List
          ? original
                .where(
                  (line) => line.toString().toUpperCase().startsWith('RRULE:'),
                )
                .toList()
          : original,
      baseDate: master,
    );
    if (!originalRule.isSupported && !dateChanged) {
      if (before != after &&
          originalRule.rawRules.any(
            (rule) =>
                RegExp(r'(?:^|;)(?:BYHOUR|BYMINUTE|BYSECOND)=')
                    .hasMatch(rule.toUpperCase()),
          )) {
        throw const SeriesTimingDecisionRequired(
          'The explicit recurrence times need a decision before changing the series time.',
        );
      }
      return SeriesTimingChange._(
        provider: provider,
        originalRule: originalRule,
        rule: originalRule,
        originalMasterStart: master,
        masterStart: master.add(after.difference(before)),
        originalOccurrenceStart: before,
        desiredStart: after,
        requiresConfirmation: false,
        allDay: allDay,
        timeZone: timeZone,
        shiftExceptions: shiftExceptions,
        originalTimeZone: originalTimeZone,
        civilToUtc: civilToUtc,
        utcToCivil: utcToCivil,
      );
    }
    if (!originalRule.isSupported || !originalRule.repeats) {
      throw const SeriesTimingDecisionRequired(
        'This recurrence needs an explicit pattern before its dates can change.',
      );
    }
    var rule = originalRule;
    var adjusted = master.add(after.difference(before));
    var confirm = false;
    var monthDayMapping = <int, int>{};
    if (dateChanged) {
      switch (rule.frequency) {
        case RecurrenceFrequency.none:
        case RecurrenceFrequency.daily:
          break;
        case RecurrenceFrequency.weekly:
          final days = _date(after).difference(_date(before)).inDays;
          String shift(String day) =>
              rfcWeekdays[(rfcWeekdays.indexOf(day) + days) % 7];
          rule = rule.copyWith(
            byDay: rule.byDay.map(shift).toList(),
            // Moving the week boundary as well preserves the phase of an
            // interval > 1 when a weekday set wraps into another week.
            weekStart: rule.interval > 1
                ? shift(rule.weekStart)
                : rule.weekStart,
          );
        case RecurrenceFrequency.monthly:
        case RecurrenceFrequency.yearly:
          final monthShift =
              (after.year - before.year) * 12 + after.month - before.month;
          if (rule.byMonthDay.isNotEmpty) {
            if (rule.byMonthDay.length == 1) {
              final oldDay = rule.byMonthDay.single;
              final last = DateTime.utc(after.year, after.month + 1, 0).day;
              final endRelative = after.day - last - 1;
              final newDay = oldDay < 0 && endRelative == oldDay
                  ? oldDay
                  : after.day;
              rule = rule.copyWith(byMonthDay: [newDay]);
              monthDayMapping = {oldDay: newDay};
              // Different month lengths can add/remove dates, even though the
              // editor changed only one displayed occurrence.
              confirm =
                  oldDay != newDay &&
                  (oldDay.abs() > 28 ||
                      newDay.abs() > 28 ||
                      oldDay.sign != newDay.sign);
            } else {
              final last = DateTime.utc(before.year, before.month + 1, 0).day;
              final selected = rule.byMonthDay.where(
                (day) => (day < 0 ? last + day + 1 : day) == before.day,
              );
              if (selected.length != 1) {
                throw const SeriesTimingDecisionRequired(
                  'Choose which monthly date should change before saving.',
                );
              }
              rule = rule.copyWith(
                byMonthDay: [
                  for (final day in rule.byMonthDay)
                    day == selected.single ? after.day : day,
                ],
              );
              monthDayMapping = {
                for (final day in originalRule.byMonthDay)
                  day: day == selected.single ? after.day : day,
              };
              if (rule.byMonthDay.toSet().length != rule.byMonthDay.length) {
                throw const SeriesTimingDecisionRequired(
                  'Two monthly dates would merge. Choose their recurrence identities explicitly.',
                );
              }
              confirm = true;
            }
          } else {
            final weekday = rfcWeekdays[after.weekday - 1];
            final last = DateTime.utc(after.year, after.month + 1, 0).day;
            final positive = (after.day - 1) ~/ 7 + 1;
            final negative = -((last - after.day) ~/ 7 + 1);
            final oldPosition = rule.bySetPosition!;
            final position = oldPosition < 0 ? negative : positive;
            final supported = EventRecurrenceCodec.limitsFor(provider)
                .ordinalPositions;
            final proposedPosition = supported.contains(position)
                ? position
                : supported.contains(positive)
                ? positive
                : negative;
            if (!supported.contains(proposedPosition)) {
              throw const SeriesTimingDecisionRequired(
                'Choose a recurrence position supported by this calendar.',
              );
            }
            rule = rule.copyWith(
              byDay: [weekday],
              bySetPosition: proposedPosition,
            );
            confirm =
                oldPosition != proposedPosition ||
                originalRule.byDay.length != 1;
          }
          if (rule.frequency == RecurrenceFrequency.yearly) {
            rule = rule.copyWith(
              byMonth: [
                for (final month in rule.byMonth)
                  (month - 1 + monthShift) % 12 + 1,
              ],
            );
            confirm =
                confirm ||
                originalRule.byMonth.length > 1 && monthShift != 0 ||
                (originalRule.byMonth.contains(2) ||
                        rule.byMonth.contains(2)) &&
                    (originalRule.byMonthDay.contains(29) ||
                        rule.byMonthDay.contains(29));
          }
          final month = DateTime.utc(master.year, master.month + monthShift);
          final prototype = DateTime.utc(
            month.year,
            month.month,
            1,
            after.hour,
            after.minute,
            after.second,
          );
          final oldCandidates = _candidates(originalRule, master, 0);
          final oldIndex = oldCandidates.indexOf(master);
          final candidates = _candidates(rule, prototype, 0);
          if (oldIndex < 0) {
            throw const SeriesTimingDecisionRequired(
              'The new pattern cannot identify the first occurrence safely.',
            );
          }
          if (monthDayMapping.isNotEmpty) {
            final selector = _monthDaySelectors(originalRule, master);
            if (selector.length != 1) {
              throw const SeriesTimingDecisionRequired(
                'The first occurrence has an ambiguous monthly identity.',
              );
            }
            final date = _monthDay(
              month.year,
              month.month,
              monthDayMapping[selector.single]!,
            );
            if (date != null) {
              adjusted = DateTime.utc(
                date.year,
                date.month,
                date.day,
                after.hour,
                after.minute,
                after.second,
              );
            } else {
              DateTime? first;
              for (
                var period = 0;
                period < const IcalRecurrenceLimits().maximumPeriods &&
                    first == null;
                period++
              ) {
                first = _candidates(rule, prototype, period).firstOrNull;
              }
              if (first == null) {
                throw const SeriesTimingDecisionRequired(
                  'The revised pattern has no first occurrence within the supported expansion limit.',
                );
              }
              adjusted = first;
            }
            if (before.year == master.year &&
                before.month == master.month &&
                after.isBefore(adjusted)) {
              adjusted = after;
            }
          } else {
            if (oldIndex >= candidates.length) {
              throw const SeriesTimingDecisionRequired(
                'The revised ordinal cannot identify the first occurrence safely.',
              );
            }
            adjusted = candidates[oldIndex];
          }
      }
    }
    final until = rule.untilRaw?.endsWith('Z') == true && utcToCivil != null
        ? _isoDate(utcToCivil(DateTime.parse(rule.untilRaw!)))
        : rule.untilDateFor(timeZone: originalTimeZone);
    if (until != null) {
      if (!allDay && timeZone != null && civilToUtc != null) {
        final day = DateTime.parse(until);
        rule = rule.copyWith(
          untilRaw: _compact(
            civilToUtc(
              DateTime.utc(
                day.year,
                day.month,
                day.day,
                adjusted.hour,
                adjusted.minute,
                adjusted.second,
              ),
            ),
            utc: true,
          ),
        );
      } else {
        rule = rule.withUntilDate(
          until,
          allDay: allDay,
          floating: !allDay && timeZone == null,
          baseDate: adjusted,
          timeZone: timeZone,
        );
      }
    }
    if (!EventRecurrenceCodec.canEncode(provider, rule)) {
      throw const SeriesTimingDecisionRequired(
        'Choose a recurrence pattern supported by this calendar.',
      );
    }
    final result = SeriesTimingChange._(
      provider: provider,
      originalRule: originalRule,
      rule: rule,
      originalMasterStart: master,
      masterStart: adjusted,
      originalOccurrenceStart: before,
      desiredStart: after,
      requiresConfirmation: confirm,
      allDay: allDay,
      timeZone: timeZone,
      shiftExceptions: shiftExceptions,
      originalTimeZone: originalTimeZone,
      civilToUtc: civilToUtc,
      utcToCivil: utcToCivil,
      originalCivilToUtc: originalCivilToUtc,
      monthDayMapping: monthDayMapping,
    );
    if (result.mapOccurrence(before) != after) {
      throw const SeriesTimingDecisionRequired(
        'The edited date cannot be associated with the revised pattern safely.',
      );
    }
    if (dateChanged && !result.containsNewOccurrence(after)) {
      throw const SeriesTimingDecisionRequired(
        'The edited date is outside the series ending condition. Choose its ending condition explicitly.',
      );
    }
    return result;
  }

  final BusyProvider provider;
  final RecurrenceRule originalRule;
  final RecurrenceRule rule;
  final DateTime originalMasterStart;
  final DateTime masterStart;
  final DateTime originalOccurrenceStart;
  final DateTime desiredStart;
  final bool requiresConfirmation;
  final bool allDay;

  /// Cloud pointer rescheduling retains its delta-based exception behavior.
  /// Ordinary editor saves preserve an individually rescheduled interval.
  final bool shiftExceptions;
  final String? timeZone;
  final String? originalTimeZone;
  final DateTime Function(DateTime)? civilToUtc;
  final DateTime Function(DateTime)? utcToCivil;
  final DateTime Function(DateTime)? originalCivilToUtc;
  final Map<int, int> monthDayMapping;
  final String? _savedSignature;

  Map<String, Object?> toJson() => {
    'provider': provider.storageValue,
    'beforeRule': originalRule.isSupported ? originalRule.toRrule() : null,
    'afterRule': rule.isSupported ? rule.toRrule() : null,
    'beforeStart': originalMasterStart.toIso8601String(),
    'afterStart': masterStart.toIso8601String(),
    'occurrenceStart': originalOccurrenceStart.toIso8601String(),
    'desiredStart': desiredStart.toIso8601String(),
    'allDay': allDay,
    'shiftExceptions': shiftExceptions,
    'timeZone': timeZone,
    'originalTimeZone': originalTimeZone,
    'confirmation': requiresConfirmation,
    'signature': signature,
    'monthDayMapping': {
      for (final entry in monthDayMapping.entries) '${entry.key}': entry.value,
    },
    if (!originalRule.isSupported)
      'opaque': {
        'rules': originalRule.rawRules,
        'dates': originalRule.recurrenceDates,
        'excludedDates': originalRule.exceptionDates,
      },
  };

  factory SeriesTimingChange.fromJson(Map<String, Object?> json) {
    final before = DateTime.parse(json['beforeStart'] as String);
    final after = DateTime.parse(json['afterStart'] as String);
    return SeriesTimingChange._(
      provider: BusyProviderCodec.requireStorageValue(
        json['provider'] as String,
      ),
      originalRule: json['opaque'] is Map
          ? const RecurrenceRule.unsupported()
          : RecurrenceRule.fromIcalendar(
              rules: [json['beforeRule'] as String],
              baseDate: before,
            ),
      rule: json['opaque'] is Map
          ? const RecurrenceRule.unsupported()
          : RecurrenceRule.fromIcalendar(
              rules: [json['afterRule'] as String],
              baseDate: after,
            ),
      originalMasterStart: before,
      masterStart: after,
      originalOccurrenceStart: DateTime.parse(
        json['occurrenceStart'] as String,
      ),
      desiredStart: DateTime.parse(json['desiredStart'] as String),
      requiresConfirmation: json['confirmation'] == true,
      allDay: json['allDay'] == true,
      shiftExceptions: json['shiftExceptions'] == true,
      timeZone: json['timeZone'] as String?,
      originalTimeZone: json['originalTimeZone'] as String?,
      savedSignature: json['signature'] as String?,
      monthDayMapping: {
        for (final entry in (json['monthDayMapping'] as Map).entries)
          int.parse(entry.key as String): entry.value as int,
      },
    );
  }

  String get signature =>
      _savedSignature ??
      jsonEncode([
        provider.storageValue,
        originalRule.isSupported
            ? originalRule.toRrule()
            : originalRule.rawRules,
        rule.isSupported ? rule.toRrule() : rule.rawRules,
        originalMasterStart.toIso8601String(),
        masterStart.toIso8601String(),
        originalOccurrenceStart.toIso8601String(),
        desiredStart.toIso8601String(),
        allDay,
        if (shiftExceptions) 'shiftExceptions',
        timeZone,
        [
          for (final entry in monthDayMapping.entries) [entry.key, entry.value],
        ],
      ]);

  /// Resolve timing separately from the presence of non-timing overrides.
  /// [baselineStart] and [baselineEnd] are authoritative values in the series
  /// zone; [start] and [end] can include pending local edits. Both projection
  /// and replay use this decision, and replay persists its resolved payload.
  ({DateTime start, DateTime end, bool preserved})? occurrenceTiming({
    required DateTime originalStart,
    required DateTime start,
    required DateTime end,
    required DateTime? baselineStart,
    required DateTime? baselineEnd,
    required Duration? masterDuration,
    required Duration endDelta,
    bool pendingTimingEdit = false,
    bool startChanged = true,
    bool endChanged = true,
  }) {
    final rescheduled =
        pendingTimingEdit ||
        baselineStart != null &&
            (_wall(baselineStart) != _wall(originalStart) ||
                baselineEnd != null &&
                    masterDuration != null &&
                    baselineEnd.difference(baselineStart) != masterDuration);
    if (rescheduled && !shiftExceptions) {
      return (start: start, end: end, preserved: true);
    }
    final startDelta = desiredStart.difference(originalOccurrenceStart);
    final mapped = !startChanged
        ? start
        : rescheduled
        ? start.add(startDelta)
        : mapOccurrence(start);
    if (mapped == null) return null;
    return (
      start: mapped,
      end: !endChanged
          ? end
          : rescheduled
          ? end.add(endDelta)
          : mapped.add(end.difference(start) + endDelta - startDelta),
      preserved: false,
    );
  }

  Object encode(Object original) {
    if (!rule.isSupported) return original;
    final encoded = EventRecurrenceCodec.encode(
      provider,
      rule,
      baseDate: masterStart,
      allDay: allDay,
      timeZone: timeZone,
      original: original,
    )!;
    if (provider != BusyProvider.google) return encoded;
    return [
      for (final line in encoded as List)
        if (!line.toString().toUpperCase().startsWith('EXDATE'))
          line
        else
          ...mapExclusions(
            IcalDocument.parse(
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:exclusion\r\n$line\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
            ).root.components.single.firstProperty('EXDATE')!,
          ).map((property) => property.serializeLogicalLine()),
    ];
  }

  List<IcalProperty> mapExclusions(
    IcalProperty source, {
    DateTime Function(IcalTemporalValue)? asCivil,
  }) {
    final result = <IcalProperty>[];
    for (final token in source.rawValue.split(',')) {
      final property = source.deepCopy()..rawValue = token;
      final temporal = parseIcalTemporal(property)!;
      final before =
          asCivil?.call(temporal) ??
          switch (temporal.kind) {
            IcalTemporalKind.date ||
            IcalTemporalKind.floatingDateTime => temporal.localValue,
            IcalTemporalKind.utcDateTime => providerInstantInTimeZone(
              temporal.localValue,
              originalTimeZone ?? timeZone,
            ),
            IcalTemporalKind.tzidDateTime => providerInstantInTimeZone(
              providerWallTimeToInstant(
                temporal.localValue,
                temporal.timeZoneId,
              ),
              originalTimeZone ?? timeZone,
            ),
          };
      if (originalRule.isSupported &&
          !containsNewOccurrence(
            before,
            recurrence: originalRule.copyWith(count: null, untilRaw: null),
            startingAt: originalMasterStart,
          )) {
        if (_date(originalOccurrenceStart) != _date(desiredStart)) {
          throw const SeriesTimingDecisionRequired(
            'An exclusion outside the regular pattern needs an explicit recurrence decision.',
          );
        }
        result.add(property);
        continue;
      }
      final mapped = mapOccurrence(before);
      if (mapped == null || !containsNewOccurrence(mapped)) {
        throw const SeriesTimingDecisionRequired(
          'A cancellation cannot be associated with the revised pattern safely.',
        );
      }
      final utc = temporal.kind == IcalTemporalKind.utcDateTime && !allDay;
      final value = utc
          ? (civilToUtc ?? (wall) => providerWallTimeToInstant(wall, timeZone))(
              mapped,
            )
          : mapped;
      result.add(
        IcalProperty(
          group: source.group,
          name: source.name,
          parameters: [
            ...source.parameters.where(
              (parameter) =>
                  parameter.name != 'VALUE' && parameter.name != 'TZID',
            ),
            if (allDay)
              const IcalParameter(
                name: 'VALUE',
                values: ['DATE'],
                wasQuoted: false,
              ),
            if (!allDay && !utc && timeZone != null)
              IcalParameter(name: 'TZID', values: [timeZone!], wasQuoted: true),
          ],
          rawValue: allDay
              ? _compact(value).substring(0, 8)
              : _compact(value, utc: utc),
          originalPhysicalLines: const [],
          isDirty: true,
        ),
      );
    }
    return result;
  }

  DateTime? mapOccurrence(DateTime original) {
    final value = _wall(original);
    final anchor = originalMasterStart;
    if (!originalRule.isSupported ||
        originalRule.frequency == RecurrenceFrequency.daily ||
        originalRule.frequency == RecurrenceFrequency.weekly) {
      return value.add(masterStart.difference(anchor));
    }
    if (monthDayMapping.isNotEmpty) {
      final selectors = _monthDaySelectors(originalRule, value);
      if (selectors.length != 1) return null;
      final months =
          (desiredStart.year - originalOccurrenceStart.year) * 12 +
          desiredStart.month -
          originalOccurrenceStart.month;
      final targetMonth = DateTime.utc(value.year, value.month + months);
      final target = _monthDay(
        targetMonth.year,
        targetMonth.month,
        monthDayMapping[selectors.single]!,
      );
      if (target == null) return null;
      return DateTime.utc(
        target.year,
        target.month,
        target.day,
        masterStart.hour,
        masterStart.minute,
        masterStart.second,
      );
    }
    final units = originalRule.frequency == RecurrenceFrequency.monthly
        ? (value.year - anchor.year) * 12 + value.month - anchor.month
        : value.year - anchor.year;
    if (units < 0 || units % originalRule.interval != 0) return null;
    final period = units ~/ originalRule.interval;
    final oldCandidates = _candidates(originalRule, anchor, period);
    final index = oldCandidates.indexOf(value);
    final candidates = _candidates(rule, masterStart, period);
    if (index < 0 || index >= candidates.length) return null;
    // With multiple selectors, a changed ordering or a disappearing date
    // cannot establish which exception belongs to which new occurrence.
    if (oldCandidates.length != candidates.length &&
        originalRule.byMonthDay.length > 1) {
      return null;
    }
    return candidates[index];
  }

  bool containsOriginalOccurrence(DateTime value) => containsNewOccurrence(
    value,
    recurrence: originalRule,
    startingAt: originalMasterStart,
    resolveUtc:
        originalCivilToUtc ??
        (wall) => providerWallTimeToInstant(wall, originalTimeZone),
  );

  RecurrenceRule previewRule({required bool following, bool original = false}) {
    final value = original ? originalRule : rule;
    final count = originalRule.count;
    if (!following || count == null) return value;
    var preceding = 0;
    for (
      var period = 0;
      period < const IcalRecurrenceLimits().maximumPeriods;
      period++
    ) {
      for (final candidate in _candidates(
        originalRule,
        originalMasterStart,
        period,
      )) {
        if (candidate.isBefore(originalMasterStart)) continue;
        if (!candidate.isBefore(originalOccurrenceStart)) {
          return value.copyWith(count: count - preceding);
        }
        preceding++;
        if (preceding >= count) {
          throw const SeriesTimingDecisionRequired(
            'The edited occurrence is outside the original count.',
          );
        }
      }
    }
    throw const SeriesTimingDecisionRequired(
      'The edited occurrence exceeds the supported recurrence expansion limit.',
    );
  }

  bool removesOrdinaryOccurrence(
    DateTime value, {
    RecurrenceRule? recurrence,
    DateTime? startingAt,
  }) {
    final mapped = mapOccurrence(value);
    if (mapped != null) {
      return !containsNewOccurrence(
        mapped,
        recurrence: recurrence,
        startingAt: startingAt,
      );
    }
    return monthDayMapping.isNotEmpty &&
        _monthDaySelectors(originalRule, value).length == 1;
  }

  /// RANGE=THISANDFUTURE can express one civil timing difference. Verify the
  /// whole finite schedule, or the Gregorian selector cycle for an unlimited
  /// rule, before retaining a ranged exception under a new pattern.
  bool preservesFollowingOverride() {
    if (timeZone != originalTimeZone) return false;
    if (!rule.isSupported || !originalRule.isSupported) {
      return _date(masterStart) == _date(originalMasterStart);
    }
    final delta = masterStart.difference(originalMasterStart);
    if (originalRule.count != null || originalRule.untilRaw != null) {
      final old = _ruleOccurrences(
        originalRule,
        originalMasterStart,
        originalCivilToUtc ??
            (wall) => providerWallTimeToInstant(wall, originalTimeZone),
      ).iterator;
      final revised = _ruleOccurrences(
        rule,
        masterStart,
        civilToUtc ?? (wall) => providerWallTimeToInstant(wall, timeZone),
      ).iterator;
      while (old.moveNext()) {
        if (!revised.moveNext() || old.current.add(delta) != revised.current) {
          return false;
        }
      }
      return true;
    }
    if (rule.frequency == RecurrenceFrequency.daily ||
        rule.frequency == RecurrenceFrequency.weekly) {
      return true;
    }
    final periods = rule.frequency == RecurrenceFrequency.monthly ? 4800 : 400;
    for (var period = 0; period < periods; period++) {
      final old = _candidates(originalRule, originalMasterStart, period)
          .where((date) => !date.isBefore(originalMasterStart))
          .map((date) => date.add(delta))
          .toList();
      final revised = _candidates(
        rule,
        masterStart,
        period,
      ).where((date) => !date.isBefore(masterStart)).toList();
      if (old.length != revised.length) return false;
      for (var index = 0; index < old.length; index++) {
        if (old[index] != revised[index]) return false;
      }
    }
    return true;
  }

  ({DateTime? previous, DateTime? next}) adjacentNewOccurrences(
    DateTime value,
  ) {
    DateTime? previous;
    for (final occurrence in _ruleOccurrences(
      rule,
      masterStart,
      civilToUtc ?? (wall) => providerWallTimeToInstant(wall, timeZone),
    )) {
      if (occurrence.isAfter(value)) {
        return (previous: previous, next: occurrence);
      }
      if (occurrence.isBefore(value)) previous = occurrence;
    }
    return (previous: previous, next: null);
  }

  bool containsNewOccurrence(
    DateTime candidate, {
    RecurrenceRule? recurrence,
    DateTime? startingAt,
    DateTime Function(DateTime)? resolveUtc,
  }) {
    final pattern = recurrence ?? rule;
    final anchor = startingAt ?? masterStart;
    if (!pattern.isSupported) return true;
    final value = _wall(candidate);
    if (value.isBefore(anchor)) return false;
    final until = pattern.untilRaw;
    if (until != null) {
      final limit = DateTime.parse(until);
      if (until.length == 8) {
        if (_date(value).isAfter(_date(limit))) return false;
      } else if ((until.endsWith('Z')
              ? (resolveUtc ??
                    civilToUtc ??
                    (wall) => providerWallTimeToInstant(wall, timeZone))(value)
              : value)
          .isAfter(until.endsWith('Z') ? limit : _wall(limit))) {
        return false;
      }
    }
    final units = switch (pattern.frequency) {
      RecurrenceFrequency.none => 0,
      RecurrenceFrequency.daily => _date(
        value,
      ).difference(_date(anchor)).inDays,
      RecurrenceFrequency.weekly =>
        _week(
              value,
              pattern.weekStart,
            ).difference(_week(anchor, pattern.weekStart)).inDays ~/
            7,
      RecurrenceFrequency.monthly =>
        (value.year - anchor.year) * 12 + value.month - anchor.month,
      RecurrenceFrequency.yearly => value.year - anchor.year,
    };
    if (units < 0 || units % pattern.interval != 0) return false;
    final period = units ~/ pattern.interval;
    if (!_candidates(pattern, anchor, period).contains(value)) return false;
    final count = pattern.count;
    if (count == null) return true;
    var generated = 0;
    for (var current = 0; current <= period; current++) {
      for (final occurrence in _candidates(pattern, anchor, current)) {
        if (occurrence.isBefore(anchor)) continue;
        generated++;
        if (generated > count) return false;
        if (occurrence == value) return true;
      }
    }
    return false;
  }
}

final class SeriesTimingDecisionRequired implements Exception {
  const SeriesTimingDecisionRequired(this.message);
  final String message;
  @override
  String toString() => message;
}

final class SeriesTimingConfirmationRequired implements Exception {
  const SeriesTimingConfirmationRequired(this.change);
  final SeriesTimingChange change;
}

List<DateTime> _candidates(RecurrenceRule rule, DateTime anchor, int period) =>
    IcalRecurrenceExpander().rulePeriodCandidates(
      recurrenceRule: rule.toRrule(),
      anchor: anchor,
      period: period,
    );

DateTime _wall(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);
DateTime _date(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
DateTime _week(DateTime value, String weekStart) => _date(value).subtract(
  Duration(days: (value.weekday - rfcWeekdays.indexOf(weekStart) - 1) % 7),
);
String _isoDate(DateTime value) => value.toIso8601String().substring(0, 10);
String _compact(DateTime value, {bool utc = false}) =>
    '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}T'
    '${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}${utc ? 'Z' : ''}';
List<int> _monthDaySelectors(RecurrenceRule rule, DateTime date) => [
  for (final day in rule.byMonthDay)
    if (_monthDay(date.year, date.month, day)?.day == date.day) day,
];
DateTime? _monthDay(int year, int month, int selector) {
  final last = DateTime.utc(year, month + 1, 0).day;
  final day = selector > 0 ? selector : last + selector + 1;
  return day < 1 || day > last ? null : DateTime.utc(year, month, day);
}

Iterable<DateTime> _ruleOccurrences(
  RecurrenceRule rule,
  DateTime anchor,
  DateTime Function(DateTime) toUtc,
) sync* {
  var generated = 0;
  final until = rule.untilRaw == null ? null : DateTime.parse(rule.untilRaw!);
  for (
    var period = 0;
    period < const IcalRecurrenceLimits().maximumPeriods;
    period++
  ) {
    for (final candidate in _candidates(rule, anchor, period)) {
      if (candidate.isBefore(anchor)) continue;
      if (until != null &&
          (rule.untilRaw!.length == 8
              ? _date(candidate).isAfter(_date(until))
              : (rule.untilRaw!.endsWith('Z') ? toUtc(candidate) : candidate)
                    .isAfter(
                      rule.untilRaw!.endsWith('Z') ? until : _wall(until),
                    ))) {
        return;
      }
      yield candidate;
      generated++;
      if (rule.count != null && generated >= rule.count!) return;
    }
  }
  throw const SeriesTimingDecisionRequired(
    'The recurrence exceeds the supported expansion limit.',
  );
}
