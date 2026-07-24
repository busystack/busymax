import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../task_providers/task_provider.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import '../data/calendar_repository.dart';
import 'event_description_editor.dart';
import 'event_editor_draft.dart';

Future<EventEditorDialogResult?> showBusyMaxEventEditorDialog(
  BuildContext context, {
  required EventEditorDraft initialDraft,
  required List<CalendarSourceEntity> sources,
  LinuxHeaderBarService? headerBarService,
  bool allowDelete = true,
  Map<String, List<String>> categorySuggestionsByAccount = const {},
}) async {
  return showBusyMaxModalEditorDialog<EventEditorDialogResult>(
    context,
    headerBarService: headerBarService,
    maxWidth: BusyMaxSizes.detailsWidth,
    maxHeight: 720,
    builder: (context) {
      return EventEditor(
        initialDraft: initialDraft,
        sources: sources,
        categorySuggestionsByAccount: categorySuggestionsByAccount,
        headerBarService: headerBarService,
        onCancel: () => Navigator.of(context).pop(),
        onSave: (draft) =>
            Navigator.of(context).pop(EventEditorDialogResult.save(draft)),
        onDelete: allowDelete && initialDraft.eventId != null
            ? (eventId) => Navigator.of(
                context,
              ).pop(EventEditorDialogResult.delete(eventId))
            : null,
      );
    },
  );
}

class EventEditorDialogResult {
  const EventEditorDialogResult._({this.draft, this.deletedEventId});

  factory EventEditorDialogResult.save(EventEditorDraft draft) {
    return EventEditorDialogResult._(draft: draft);
  }

  factory EventEditorDialogResult.delete(String eventId) {
    return EventEditorDialogResult._(deletedEventId: eventId);
  }

  final EventEditorDraft? draft;
  final String? deletedEventId;
}

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.initialDraft,
    required this.sources,
    required this.onCancel,
    required this.onSave,
    this.onDelete,
    this.categorySuggestionsByAccount = const {},
    this.headerBarService,
  });

  final EventEditorDraft initialDraft;
  final List<CalendarSourceEntity> sources;
  final Map<String, List<String>> categorySuggestionsByAccount;
  final VoidCallback onCancel;
  final ValueChanged<EventEditorDraft> onSave;
  final ValueChanged<String>? onDelete;
  final LinuxHeaderBarService? headerBarService;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late EventEditorDraft _draft;
  final _shortcutFocusNode = FocusNode(debugLabel: 'Event editor shortcuts');
  final _guestController = TextEditingController();
  String? _guestError;
  var _addingGuest = false;
  var _addingCategory = false;
  var _confirmingCancel = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    _guestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dirty = _draft != widget.initialDraft;
    CalendarSourceEntity? currentSource;
    for (final source in widget.sources) {
      if (source.id == _draft.sourceId) {
        currentSource = source;
        break;
      }
    }
    final provider = currentSource?.provider ?? TaskProvider.google;
    final title = widget.initialDraft.eventId == null
        ? l10n.newEvent
        : l10n.editEvent;
    final canSave = dirty && _draft.canSave;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(_cancel());
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (canSave) {
            widget.onSave(_draft);
          }
        },
      },
      child: Focus(
        autofocus: true,
        focusNode: _shortcutFocusNode,
        onKeyEvent: _handleEditorKeyEvent,
        child: BusyMaxModalEditorScaffold(
          title: title,
          cancelLabel: l10n.cancel,
          saveLabel: l10n.save,
          onCancel: () => unawaited(_cancel()),
          onSave: canSave ? () => widget.onSave(_draft) : null,
          children: [
            BusyMaxGroupedList(
              filled: true,
              children: [
                YaruListTile.square(
                  hoverColor: busyMaxEditorRowHoverColor(context),
                  title: TextFormField(
                    initialValue: _draft.title,
                    autofocus: true,
                    decoration: _plainEventFieldDecoration(
                      context,
                      labelText: l10n.title,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(title: value);
                      });
                    },
                  ),
                ),
                YaruListTile.square(
                  hoverColor: busyMaxEditorRowHoverColor(context),
                  title: TextFormField(
                    initialValue: _draft.location,
                    decoration: _plainEventFieldDecoration(
                      context,
                      labelText: l10n.location,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(location: value);
                      });
                    },
                  ),
                ),
              ],
            ),
            BusyMaxGroupedList(filled: true, children: [_calendarRow()]),
            BusyMaxGroupedList(
              filled: true,
              children: [
                BusyMaxTimeModeRow(
                  allDay: _draft.allDay,
                  onChanged: _setAllDay,
                ),
              ],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [
                DesktopDateValueRow(
                  label: l10n.startDate,
                  date: _dateString(_draft.start),
                  onChanged: (value) {
                    _setStart(_withDate(_draft.start, value), provider);
                  },
                  emptyLabel: l10n.noneValue,
                ),
                if (!_draft.allDay)
                  DesktopTimeValueRow(
                    label: l10n.startTime,
                    time: _timeString(_draft.start),
                    onChanged: (value) {
                      _setStart(_withTime(_draft.start, value), provider);
                    },
                    emptyLabel: '--:--',
                    allowEmpty: false,
                  ),
              ],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [
                DesktopDateValueRow(
                  label: l10n.endDate,
                  date: _dateString(_draft.end),
                  onChanged: (value) {
                    _setEnd(_withDate(_draft.end, value));
                  },
                  emptyLabel: l10n.noneValue,
                ),
                if (!_draft.allDay)
                  DesktopTimeValueRow(
                    label: l10n.endTime,
                    time: _timeString(_draft.end),
                    onChanged: (value) {
                      _setEnd(_withTime(_draft.end, value));
                    },
                    emptyLabel: '--:--',
                    allowEmpty: false,
                  ),
              ],
            ),
            if (_draft.providerRecurringEventId == null)
              BusyMaxGroupedList(
                filled: true,
                children: [_repeatRow(provider)],
              ),
            BusyMaxGroupedList(
              title: l10n.reminder,
              filled: true,
              children: _reminderRows(provider),
            ),
            BusyMaxGroupedList(
              title: l10n.guests,
              filled: true,
              children: _guestRows(),
            ),
            if (provider == TaskProvider.microsoft)
              BusyMaxGroupedList(
                title: l10n.organizationSection,
                filled: true,
                children: [_categoriesRow()],
              ),
            BusyMaxGroupedList(
              filled: true,
              children: [
                YaruListTile.square(
                  hoverColor: busyMaxEditorRowHoverColor(context),
                  title: EventDescriptionEditor(
                    provider: provider,
                    text: _draft.description,
                    contentType: _draft.descriptionContentType,
                    html: _draft.descriptionHtml,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(
                          description: value.text,
                          descriptionContentType: value.contentType,
                          descriptionHtml: value.html,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [_availabilityRow(provider)],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [_visibilityRow(provider)],
            ),
            if (_draft.eventId != null && widget.onDelete != null)
              const SizedBox(height: BusyMaxSpacing.md),
            if (_draft.eventId != null && widget.onDelete != null)
              BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxActionRow(
                    title: l10n.deleteEvent,
                    titleWidget: Center(
                      child: Text(
                        l10n.deleteEvent,
                        style: _eventEditorProminentActionStyle(
                          context,
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    destructive: true,
                    onTap: _deleteCurrentEvent,
                  ),
                ],
              ),
            const SizedBox(height: BusyMaxSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (_confirmingCancel) {
      return;
    }
    if (_draft == widget.initialDraft) {
      widget.onCancel();
      return;
    }

    _confirmingCancel = true;
    try {
      final discard = await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discard,
        destructive: true,
        headerBarService: widget.headerBarService,
      );
      if (discard && mounted) {
        widget.onCancel();
      }
    } finally {
      _confirmingCancel = false;
    }
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !_canDeleteWithShortcut ||
        _isEditableTextFocused()) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        _deleteCurrentEvent();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _canDeleteWithShortcut {
    return _draft.eventId != null && widget.onDelete != null;
  }

  bool _isEditableTextFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _deleteCurrentEvent() {
    final eventId = _draft.eventId;
    if (eventId != null && widget.onDelete != null) {
      widget.onDelete!(eventId);
    }
  }

  Widget _repeatRow(BusyProvider provider) {
    final l10n = context.l10n;
    final labels = {
      'none': l10n.doesNotRepeat,
      'daily': l10n.repeatDaily,
      'weekly': l10n.repeatWeekly,
      'monthly': l10n.repeatMonthly,
      'yearly': l10n.repeatYearly,
    };
    return BusyMaxComboRow<String>(
      title: l10n.repeat,
      leading: const Icon(Icons.repeat),
      values: labels.keys.toList(),
      selected: _recurrenceType(_draft.recurrence),
      labelFor: (value) => labels[value] ?? l10n.doesNotRepeat,
      onSelected: (value) {
        setState(() {
          _draft = value == 'none'
              ? _draft.copyWith(clearRecurrence: true)
              : _draft.copyWith(
                  recurrence: _recurrenceFor(provider, value, _draft.start),
                );
        });
      },
    );
  }

  Widget _calendarRow() {
    final existingSourceId = widget.initialDraft.eventId == null
        ? null
        : widget.initialDraft.sourceId;
    final sources = existingSourceId == null
        ? widget.sources
        : [
            for (final source in widget.sources)
              if (source.id == existingSourceId) source,
          ];
    if (sources.isEmpty) {
      return BusyMaxActionRow(
        title: context.l10n.calendar,
        leading: const Icon(YaruIcons.calendar),
        subtitle: context.l10n.noCalendarsSynced,
      );
    }
    final selected = sources.any((source) => source.id == _draft.sourceId)
        ? _draft.sourceId
        : sources.first.id;
    return BusyMaxComboRow<String>(
      title: context.l10n.calendar,
      leading: const Icon(YaruIcons.calendar),
      values: [for (final source in sources) source.id],
      selected: selected,
      enabled: existingSourceId == null,
      labelFor: (value) =>
          sources.firstWhere((source) => source.id == value).summary,
      selectorLeadingBuilder: (context, value) {
        final source = sources.firstWhere((source) => source.id == value);
        return _CalendarSourceDot(color: _calendarSourceColor(context, source));
      },
      onSelected: (value) {
        final source = sources.firstWhere((source) => source.id == value);
        final recurrenceType = _recurrenceType(_draft.recurrence);
        final adjustedRecurrence =
            _draft.recurrenceChanged && recurrenceType != 'none'
            ? _recurrenceFor(source.provider, recurrenceType, _draft.start)
            : null;
        setState(() {
          if (source.provider != TaskProvider.microsoft) {
            _addingCategory = false;
          }
          _draft = _draft.copyWith(
            accountId: source.accountId,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            categories: source.provider == TaskProvider.microsoft
                ? _draft.categories
                : const [],
            recurrence: adjustedRecurrence,
          );
        });
      },
    );
  }

  List<Widget> _reminderRows(BusyProvider provider) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = _reminderMinutesList(_draft.reminders);
    final supportsMultiple = provider == TaskProvider.google;
    final canAddReminder =
        minutes.isEmpty ||
        (supportsMultiple &&
            minutes.length < _eventReminderMinuteOptions.length);
    return [
      for (var index = 0; index < minutes.length; index += 1)
        BusyMaxComboRow<int>(
          title: l10n.reminder,
          leading: const Icon(Icons.notifications_outlined),
          values: _reminderValuesFor(minutes[index]),
          selected: minutes[index],
          labelFor: (value) => _reminderLabel(context, value),
          onSelected: (value) {
            _setReminderMinutes(provider, [
              ...minutes.take(index),
              value,
              ...minutes.skip(index + 1),
            ]);
          },
          trailingAction: YaruIconButton(
            tooltip: l10n.removeReminder,
            iconSize: BusyMaxSizes.headerIcon,
            icon: const Icon(YaruIcons.window_close),
            onPressed: () {
              _setReminderMinutes(provider, [
                ...minutes.take(index),
                ...minutes.skip(index + 1),
              ]);
            },
            style: busyMaxHeaderIconButtonStyle(
              foregroundColor: colorScheme.onSurfaceVariant,
              backgroundColor: busyMaxSubtleButtonBackground(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ),
      if (canAddReminder)
        BusyMaxActionRow(
          title: l10n.addReminder,
          titleWidget: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
                const SizedBox(width: BusyMaxSpacing.xs),
                Text(
                  l10n.addReminder,
                  style: _eventEditorProminentActionStyle(context),
                ),
              ],
            ),
          ),
          onTap: () {
            _setReminderMinutes(provider, [
              ...minutes,
              _nextReminderMinute(minutes),
            ]);
          },
        ),
    ];
  }

  List<Widget> _guestRows() {
    final rows = <Widget>[
      for (final attendee in _draft.attendees)
        BusyMaxActionRow(
          title: attendee.email,
          subtitle: attendee.displayName,
          leading: const Icon(Icons.person_outline),
          trailing: YaruIconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            icon: const Icon(YaruIcons.window_close),
            onPressed: () {
              setState(() {
                _draft = _draft.copyWith(
                  attendees: [
                    for (final item in _draft.attendees)
                      if (item != attendee) item,
                  ],
                );
              });
            },
          ),
        ),
    ];
    if (!_addingGuest) {
      rows.add(
        BusyMaxActionRow(
          title: context.l10n.addGuest,
          titleWidget: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
                const SizedBox(width: BusyMaxSpacing.xs),
                Text(
                  context.l10n.addGuest,
                  style: _eventEditorProminentActionStyle(context),
                ),
              ],
            ),
          ),
          onTap: () {
            setState(() {
              _addingGuest = true;
              _guestError = null;
            });
          },
        ),
      );
    } else {
      rows.add(
        YaruListTile.square(
          leading: const Icon(Icons.person_add_alt_outlined),
          hoverColor: busyMaxEditorRowHoverColor(context),
          title: TextField(
            controller: _guestController,
            autofocus: true,
            decoration: _plainEventFieldDecoration(
              context,
              labelText: context.l10n.addGuestEmail,
              errorText: _guestError,
            ),
            onSubmitted: (_) => _addGuest(),
          ),
          trailing: YaruIconButton(
            tooltip: context.l10n.addGuest,
            icon: const Icon(YaruIcons.plus),
            onPressed: _addGuest,
          ),
        ),
      );
    }
    return rows;
  }

  Widget _categoriesRow() {
    final l10n = context.l10n;
    return BusyMaxCategoryEditorRow(
      title: l10n.categories,
      addLabel: l10n.addCategory,
      categories: _draft.categories,
      suggestions:
          widget.categorySuggestionsByAccount[_draft.accountId] ??
          const <String>[],
      adding: _addingCategory,
      inputKey: const Key('event-category-input'),
      onAddPressed: () {
        setState(() {
          _addingCategory = true;
        });
      },
      onSubmitted: _addCategory,
      onCancelAdding: () {
        setState(() {
          _addingCategory = false;
        });
      },
      onDeleted: _removeCategory,
    );
  }

  Widget _availabilityRow(BusyProvider provider) {
    final values = provider == TaskProvider.google
        ? const ['opaque', 'transparent']
        : const ['free', 'tentative', 'busy', 'oof', 'workingElsewhere'];
    final selected = values.contains(_draft.showAs)
        ? _draft.showAs!
        : provider == TaskProvider.google
        ? 'opaque'
        : 'busy';
    return BusyMaxComboRow<String>(
      title: context.l10n.availabilityShowAs,
      leading: const Icon(Icons.work_outline),
      values: values,
      selected: selected,
      labelFor: (value) => _availabilityLabel(context, value),
      onSelected: (value) {
        setState(() {
          _draft = _draft.copyWith(showAs: value);
        });
      },
    );
  }

  Widget _visibilityRow(BusyProvider provider) {
    final values = provider == TaskProvider.google
        ? const ['default', 'public', 'private', 'confidential']
        : const ['normal', 'personal', 'private', 'confidential'];
    final selected = values.contains(_draft.visibilityOrSensitivity)
        ? _draft.visibilityOrSensitivity!
        : values.first;
    return BusyMaxComboRow<String>(
      title: context.l10n.visibility,
      leading: const Icon(Icons.visibility_outlined),
      values: values,
      selected: selected,
      labelFor: (value) => _visibilityLabel(context, value),
      onSelected: (value) {
        setState(() {
          _draft = _draft.copyWith(visibilityOrSensitivity: value);
        });
      },
    );
  }

  void _addGuest() {
    final email = _guestController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _guestError = context.l10n.feedbackInvalidEmail);
      return;
    }
    if (_draft.attendees.any((attendee) => attendee.email == email)) {
      _guestController.clear();
      setState(() {
        _addingGuest = false;
        _guestError = null;
      });
      return;
    }
    _guestController.clear();
    setState(() {
      _addingGuest = false;
      _guestError = null;
      _draft = _draft.copyWith(
        attendees: [
          ..._draft.attendees,
          EventAttendeeDraft(email: email),
        ],
      );
    });
  }

  void _addCategory(String value) {
    final category = value.trim();
    if (category.isEmpty ||
        _draft.categories.any(
          (existing) => existing.toLowerCase() == category.toLowerCase(),
        )) {
      return;
    }
    setState(() {
      _addingCategory = false;
      _draft = _draft.copyWith(categories: [..._draft.categories, category]);
    });
  }

  void _removeCategory(String category) {
    setState(() {
      _draft = _draft.copyWith(
        categories: [
          for (final value in _draft.categories)
            if (value != category) value,
        ],
      );
    });
  }

  void _setAllDay(bool allDay) {
    final start = _draft.start;
    final end = _draft.end;
    setState(() {
      _draft = _draft.copyWith(
        allDay: allDay,
        end: start != null && !_isValidEventEnd(start, end, allDay)
            ? _defaultEndFor(start, allDay)
            : end,
      );
    });
  }

  void _setStart(DateTime start, BusyProvider provider) {
    final end = _draft.end;
    final recurrenceType = _recurrenceType(_draft.recurrence);
    final adjustedRecurrence =
        provider == TaskProvider.microsoft &&
            _draft.recurrenceChanged &&
            recurrenceType != 'none'
        ? _recurrenceFor(provider, recurrenceType, start)
        : null;
    setState(() {
      _draft = _draft.copyWith(
        start: start,
        end: !_isValidEventEnd(start, end, _draft.allDay)
            ? _defaultEndFor(start, _draft.allDay)
            : end,
        recurrence: adjustedRecurrence,
      );
    });
  }

  void _setEnd(DateTime end) {
    final start = _draft.start;
    setState(() {
      _draft = _draft.copyWith(
        end: start != null && !_isValidEventEnd(start, end, _draft.allDay)
            ? _defaultEndFor(start, _draft.allDay)
            : end,
      );
    });
  }

  void _setReminderMinutes(BusyProvider provider, List<int> minutes) {
    final reminders = _remindersFor(provider, minutes);
    setState(() {
      _draft = _draft.copyWith(
        reminders: reminders ?? _disabledRemindersFor(provider),
      );
    });
  }
}

TextStyle? _eventEditorProminentActionStyle(
  BuildContext context, {
  Color? color,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(color: color, fontWeight: fontWeight);
}

InputDecoration _plainEventFieldDecoration(
  BuildContext context, {
  required String labelText,
  String? errorText,
  bool alignLabelWithHint = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final labelColor = errorText == null
      ? colorScheme.onSurfaceVariant
      : colorScheme.error;
  final labelStyle = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: labelColor);
  return InputDecoration(
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    labelText: labelText,
    labelStyle: labelStyle,
    floatingLabelStyle: labelStyle,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    alignLabelWithHint: alignLabelWithHint,
    errorText: errorText,
  );
}

String? _dateString(DateTime? value) {
  return value == null ? null : encodeDateOnly(value);
}

String? _timeString(DateTime? value) {
  return value == null ? null : encodeTimeOfDay(TimeOfDay.fromDateTime(value));
}

DateTime _withDate(DateTime? current, String date) {
  final parsed = parseDateOnly(date) ?? DateTime.now();
  final time = current == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(current);
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    time.hour,
    time.minute,
  );
}

DateTime _withTime(DateTime? current, String? time) {
  final parsed = parseTimeOfDay(time) ?? const TimeOfDay(hour: 9, minute: 0);
  final date = current ?? DateTime.now();
  return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
}

DateTime _defaultEndFor(DateTime start, bool allDay) {
  if (!allDay) {
    return start.add(const Duration(hours: 1));
  }
  return start.isUtc
      ? DateTime.utc(
          start.year,
          start.month,
          start.day + 1,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        )
      : DateTime(
          start.year,
          start.month,
          start.day + 1,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        );
}

bool _isValidEventEnd(DateTime start, DateTime? end, bool allDay) {
  if (end == null) {
    return false;
  }
  if (!allDay) {
    return end.isAfter(start);
  }
  return _calendarDate(end).isAfter(_calendarDate(start));
}

DateTime _calendarDate(DateTime value) {
  return DateTime.utc(value.year, value.month, value.day);
}

String _recurrenceType(Object? recurrence) {
  if (recurrence is List && recurrence.isNotEmpty) {
    final value = recurrence.first.toString().toUpperCase();
    if (value.contains('FREQ=DAILY')) return 'daily';
    if (value.contains('FREQ=WEEKLY')) return 'weekly';
    if (value.contains('FREQ=MONTHLY')) return 'monthly';
    if (value.contains('FREQ=YEARLY')) return 'yearly';
  }
  if (recurrence is Map) {
    final pattern = recurrence['pattern'];
    if (pattern is Map) {
      final type = pattern['type']?.toString();
      return switch (type) {
        'daily' => 'daily',
        'weekly' => 'weekly',
        'absoluteMonthly' => 'monthly',
        'absoluteYearly' => 'yearly',
        _ => 'none',
      };
    }
  }
  return 'none';
}

Object _recurrenceFor(BusyProvider provider, String type, DateTime? start) {
  final freq = switch (type) {
    'daily' => 'DAILY',
    'weekly' => 'WEEKLY',
    'monthly' => 'MONTHLY',
    'yearly' => 'YEARLY',
    _ => 'DAILY',
  };
  if (provider == TaskProvider.google) {
    return ['RRULE:FREQ=$freq;INTERVAL=1'];
  }
  final recurrenceStart = start ?? DateTime.now();
  final patternType = switch (type) {
    'daily' => 'daily',
    'weekly' => 'weekly',
    'monthly' => 'absoluteMonthly',
    'yearly' => 'absoluteYearly',
    _ => 'daily',
  };
  return {
    'pattern': {
      'type': patternType,
      'interval': 1,
      if (type == 'weekly') ...{
        'daysOfWeek': [_microsoftDayOfWeek(recurrenceStart.weekday)],
        'firstDayOfWeek': 'sunday',
      },
      if (type == 'monthly') 'dayOfMonth': recurrenceStart.day,
      if (type == 'yearly') ...{
        'dayOfMonth': recurrenceStart.day,
        'month': recurrenceStart.month,
      },
    },
    'range': {'type': 'noEnd', 'startDate': encodeDateOnly(recurrenceStart)},
  };
}

String _microsoftDayOfWeek(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    DateTime.sunday => 'sunday',
    _ => throw ArgumentError.value(weekday, 'weekday'),
  };
}

const _eventReminderMinuteOptions = [5, 10, 30, 60, 1440];

List<int> _reminderMinutesList(Object? reminders) {
  if (reminders is! Map) {
    return const [];
  }
  final map = reminders.cast<String, Object?>();
  final minutes = map['reminderMinutesBeforeStart'];
  if (minutes is int) {
    return _normalizedReminderMinutes([minutes]);
  }
  final overrides = map['overrides'];
  if (overrides is List) {
    final values = <int>[];
    for (final override in overrides) {
      if (override is Map && override['minutes'] is int) {
        values.add(override['minutes'] as int);
      }
    }
    return _normalizedReminderMinutes(values);
  }
  return const [];
}

Object? _remindersFor(BusyProvider provider, List<int> minutes) {
  final normalized = _normalizedReminderMinutes(minutes);
  if (normalized.isEmpty) {
    return null;
  }
  if (provider == TaskProvider.google) {
    return {
      'useDefault': false,
      'overrides': [
        for (final minutes in normalized)
          {'method': 'popup', 'minutes': minutes},
      ],
    };
  }
  return {'isReminderOn': true, 'reminderMinutesBeforeStart': normalized.first};
}

Object _disabledRemindersFor(BusyProvider provider) {
  if (provider == TaskProvider.google) {
    return {'useDefault': false, 'overrides': const []};
  }
  return {'isReminderOn': false};
}

List<int> _normalizedReminderMinutes(Iterable<int> minutes) {
  final result = <int>[];
  for (final value in minutes) {
    if (value <= 0 || result.contains(value)) {
      continue;
    }
    result.add(value);
  }
  return result;
}

List<int> _reminderValuesFor(int selected) {
  if (_eventReminderMinuteOptions.contains(selected)) {
    return _eventReminderMinuteOptions;
  }
  return [..._eventReminderMinuteOptions, selected];
}

int _nextReminderMinute(List<int> existing) {
  for (final minutes in _eventReminderMinuteOptions) {
    if (!existing.contains(minutes)) {
      return minutes;
    }
  }
  return _eventReminderMinuteOptions.first;
}

String _reminderLabel(BuildContext context, int minutes) {
  final l10n = context.l10n;
  const minutesPerDay = Duration.minutesPerHour * Duration.hoursPerDay;
  if (minutes % minutesPerDay == 0) {
    return l10n.reminderDaysBefore(minutes ~/ minutesPerDay);
  }
  if (minutes % Duration.minutesPerHour == 0) {
    return l10n.reminderHoursBefore(minutes ~/ Duration.minutesPerHour);
  }
  return l10n.reminderMinutesBefore(minutes);
}

String _availabilityLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  return switch (value) {
    'opaque' || 'busy' => l10n.busy,
    'transparent' || 'free' => l10n.availabilityFree,
    'tentative' => l10n.availabilityTentative,
    'oof' => l10n.availabilityOutOfOffice,
    'workingElsewhere' => l10n.availabilityWorkingElsewhere,
    _ => value,
  };
}

String _visibilityLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  return switch (value) {
    'default' => l10n.visibilityDefault,
    'public' => l10n.visibilityPublic,
    'private' => l10n.visibilityPrivate,
    'confidential' => l10n.visibilityConfidential,
    'normal' => l10n.sensitivityNormal,
    'personal' => l10n.sensitivityPersonal,
    _ => value,
  };
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

class _CalendarSourceDot extends StatelessWidget {
  const _CalendarSourceDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 10),
    );
  }
}

Color _calendarSourceColor(BuildContext context, CalendarSourceEntity source) {
  return _colorFromHex(
        calendarSourceBackgroundColorHex(
          provider: source.provider,
          backgroundColor: source.backgroundColor,
          colorId: source.colorId,
        ),
      ) ??
      ScheduleProjection.deterministicSourceColor(
        source.id,
        Theme.of(context).colorScheme.brightness,
      );
}

Color? _colorFromHex(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) {
    return null;
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xff000000 | parsed);
}
