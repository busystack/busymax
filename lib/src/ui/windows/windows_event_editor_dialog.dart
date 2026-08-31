import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/domain/event_move_policy.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../providers/busy_provider.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_event_reminders.dart';
import 'windows_guest_update_dialog.dart';
import 'windows_recurrence_dialog.dart';
import 'windows_time_zone_dialog.dart';

Future<bool> showWindowsEventEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  String? eventId,
  DateTime? initialStart,
}) async {
  final repository = ref.read(calendarRepositoryProvider);
  final detail = eventId == null
      ? null
      : await repository.loadEventDetail(eventId);
  if (eventId != null && detail == null) return false;
  final originalDraft = detail == null
      ? null
      : EventEditorDraft.fromEventDetail(detail);
  final accounts = await ref
      .read(accountsRepositoryProvider)
      .watchAccounts()
      .first;
  final sources = writableCalendarSources(
    await ref
        .read(calendarRepositoryProvider)
        .watchSourcesForAccounts(accounts.map((account) => account.id).toList())
        .first,
  );
  if (!context.mounted) return false;
  if (sources.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(AppLocalizations.of(context).newEvent),
        content: Text(AppLocalizations.of(context).noCalendarsSynced),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
    return false;
  }

  final title = TextEditingController(text: originalDraft?.title);
  final description = TextEditingController(text: originalDraft?.description);
  final location = TextEditingController(text: originalDraft?.location);
  final guestEmail = TextEditingController();
  final categories = TextEditingController(
    text: originalDraft?.categories.join(', '),
  );
  var selectedSource = sources.firstWhere(
    (source) =>
        source.id == originalDraft?.sourceId &&
        source.accountId == originalDraft?.accountId,
    orElse: () => sources.first,
  );
  final requestedStart = initialStart == null
      ? null
      : DateTime(
          initialStart.year,
          initialStart.month,
          initialStart.day,
          initialStart.hour == 0 && initialStart.minute == 0
              ? 9
              : initialStart.hour,
          initialStart.minute,
        );
  var start =
      originalDraft?.start ??
      requestedStart ??
      DateTime.now().add(const Duration(hours: 1));
  start = DateTime(
    start.year,
    start.month,
    start.day,
    start.hour,
    start.minute,
  );
  var end = originalDraft?.end ?? start.add(const Duration(hours: 1));
  var allDay = originalDraft?.allDay ?? false;
  var selectedTimeZone =
      selectedSource.timeZone ?? ref.read(localTimeZoneProvider) ?? 'Etc/UTC';
  var recurrence = EventRecurrenceCodec.decode(
    selectedSource.provider,
    originalDraft?.recurrence,
    baseDate: start,
  );
  var recurrenceChanged = false;
  var reminderMinutes = decodeWindowsEventReminderMinutes(
    originalDraft?.reminders,
  );
  var remindersChanged = false;
  var attendees = [...?originalDraft?.attendees];
  var attendeesChanged = false;
  var categoriesChanged = false;
  var onlineMeeting =
      originalDraft?.conference != null ||
      (originalDraft?.createConference ?? false);
  var responseRequested = originalDraft?.responseRequested ?? true;
  var hideAttendees = originalDraft?.hideAttendees ?? false;
  var allowNewTimeProposals = originalDraft?.allowNewTimeProposals ?? true;
  var importance = originalDraft?.importance ?? 'normal';
  var showAs = _showAsForProvider(
    originalDraft?.showAs,
    selectedSource.provider,
  );
  var visibility = _visibilityForProvider(
    originalDraft?.visibilityOrSensitivity,
    selectedSource.provider,
  );
  final initialSourceAccountId = selectedSource.accountId;
  final initialSourceId = selectedSource.id;
  final initialTitle = title.text;
  final initialDescription = description.text;
  final initialLocation = location.text;
  final initialCategories = categories.text;
  final initialStartValue = start;
  final initialEndValue = end;
  final initialAllDay = allDay;
  final initialTimeZone = selectedTimeZone;
  final initialOnlineMeeting = onlineMeeting;
  final initialResponseRequested = responseRequested;
  final initialHideAttendees = hideAttendees;
  final initialAllowNewTimeProposals = allowNewTimeProposals;
  final initialImportance = importance;
  final initialShowAs = showAs;
  final initialVisibility = visibility;
  String? guestError;
  var saving = false;
  var saved = false;
  var allowPop = false;
  String? error;
  bool hasPendingEdits() =>
      selectedSource.accountId != initialSourceAccountId ||
      selectedSource.id != initialSourceId ||
      title.text != initialTitle ||
      description.text != initialDescription ||
      location.text != initialLocation ||
      categories.text != initialCategories ||
      start != initialStartValue ||
      end != initialEndValue ||
      allDay != initialAllDay ||
      selectedTimeZone != initialTimeZone ||
      recurrenceChanged ||
      remindersChanged ||
      attendeesChanged ||
      categoriesChanged ||
      onlineMeeting != initialOnlineMeeting ||
      responseRequested != initialResponseRequested ||
      hideAttendees != initialHideAttendees ||
      allowNewTimeProposals != initialAllowNewTimeProposals ||
      importance != initialImportance ||
      showAs != initialShowAs ||
      visibility != initialVisibility;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final validEnd = allDay
            ? DateTime(
                end.year,
                end.month,
                end.day,
              ).isAfter(DateTime(start.year, start.month, start.day))
            : end.isAfter(start);
        void closeDialog() {
          setState(() => allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          });
        }

        return PopScope<void>(
          canPop: allowPop || (!saving && !hasPendingEdits()),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || saving || allowPop) return;
            if (await _confirmDiscardEventChanges(context) && context.mounted) {
              closeDialog();
            }
          },
          child: ContentDialog(
            title: Text(detail == null ? l10n.newEvent : l10n.editEvent),
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoLabel(
                    label: l10n.title,
                    child: TextBox(
                      controller: title,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.calendar,
                    child: ComboBox<CalendarSourceEntity>(
                      isExpanded: true,
                      value: selectedSource,
                      items: [
                        for (final source in sources)
                          ComboBoxItem(
                            value: source,
                            child: Text(source.summary),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (source) {
                              if (source != null) {
                                setState(() {
                                  selectedSource = source;
                                  selectedTimeZone =
                                      source.timeZone ??
                                      ref.read(localTimeZoneProvider) ??
                                      'Etc/UTC';
                                  recurrence = const RecurrenceRule.none();
                                  reminderMinutes = const [];
                                  recurrenceChanged = true;
                                  remindersChanged = true;
                                  showAs = _showAsForProvider(
                                    null,
                                    source.provider,
                                  );
                                  visibility = _visibilityForProvider(
                                    null,
                                    source.provider,
                                  );
                                  importance = 'normal';
                                  onlineMeeting = false;
                                  if (source.provider == BusyProvider.google) {
                                    categories.clear();
                                    categoriesChanged = true;
                                  }
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: allDay,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => allDay = value),
                    content: Text(l10n.allDay),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.startDateTime,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        DatePicker(
                          selected: start,
                          onChanged: saving
                              ? null
                              : (date) => setState(() {
                                  final duration = end.difference(start);
                                  start = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    start.hour,
                                    start.minute,
                                  );
                                  end = start.add(duration);
                                }),
                        ),
                        if (!allDay)
                          TimePicker(
                            selected: start,
                            onChanged: saving
                                ? null
                                : (time) => setState(() {
                                    final duration = end.difference(start);
                                    start = DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                      time.hour,
                                      time.minute,
                                    );
                                    end = start.add(duration);
                                  }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.endDateTime,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        DatePicker(
                          selected: end,
                          onChanged: saving
                              ? null
                              : (date) => setState(() {
                                  end = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    end.hour,
                                    end.minute,
                                  );
                                }),
                        ),
                        if (!allDay)
                          TimePicker(
                            selected: end,
                            onChanged: saving
                                ? null
                                : (time) => setState(() {
                                    end = DateTime(
                                      end.year,
                                      end.month,
                                      end.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.selectTimeZone,
                    child: Button(
                      onPressed: saving
                          ? null
                          : () async {
                              final result = await showWindowsTimeZoneDialog(
                                context,
                                selectedTimeZone: selectedTimeZone,
                              );
                              if (result != null) {
                                setState(() => selectedTimeZone = result);
                              }
                            },
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(selectedTimeZone),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.reminder,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < reminderMinutes.length;
                          index += 1
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ComboBox<int>(
                                    isExpanded: true,
                                    value: reminderMinutes[index],
                                    items: [
                                      for (final minutes
                                          in windowsEventReminderValuesFor(
                                            reminderMinutes[index],
                                          ))
                                        ComboBoxItem(
                                          value: minutes,
                                          child: Text(
                                            _reminderLabel(l10n, minutes),
                                          ),
                                        ),
                                    ],
                                    onChanged: saving
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            setState(() {
                                              reminderMinutes =
                                                  normalizeWindowsEventReminderMinutes(
                                                    [
                                                      ...reminderMinutes.take(
                                                        index,
                                                      ),
                                                      value,
                                                      ...reminderMinutes.skip(
                                                        index + 1,
                                                      ),
                                                    ],
                                                  );
                                              remindersChanged = true;
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    windowsBusyMaxGlyph(BusyMaxGlyph.delete),
                                  ),
                                  onPressed: saving
                                      ? null
                                      : () => setState(() {
                                          reminderMinutes = [
                                            ...reminderMinutes.take(index),
                                            ...reminderMinutes.skip(index + 1),
                                          ];
                                          remindersChanged = true;
                                        }),
                                ),
                              ],
                            ),
                          ),
                        if (reminderMinutes.isEmpty ||
                            (selectedSource.provider !=
                                    BusyProvider.microsoft &&
                                reminderMinutes.length <
                                    windowsEventReminderMinuteOptions.length))
                          Button(
                            onPressed: saving
                                ? null
                                : () => setState(() {
                                    reminderMinutes = [
                                      ...reminderMinutes,
                                      nextWindowsEventReminderMinute(
                                        reminderMinutes,
                                      ),
                                    ];
                                    remindersChanged = true;
                                  }),
                            child: Text(l10n.addReminder),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.repeat,
                    child: Button(
                      onPressed: saving
                          ? null
                          : () async {
                              final result = await showWindowsRecurrenceDialog(
                                context,
                                initial: recurrence,
                                baseDate: start,
                                allDay: allDay,
                                timeZone: selectedTimeZone,
                                providerLabel:
                                    selectedSource.provider.displayName,
                                limits: EventRecurrenceCodec.limitsFor(
                                  selectedSource.provider,
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  recurrence = result;
                                  recurrenceChanged = true;
                                });
                              }
                            },
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _recurrenceLabel(l10n, recurrence.frequency),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.availabilityShowAs,
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: showAs,
                      items: [
                        for (final value in _showAsValues(
                          selectedSource.provider,
                        ))
                          ComboBoxItem(
                            value: value,
                            child: Text(_availabilityLabel(l10n, value)),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) setState(() => showAs = value);
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.visibility,
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: visibility,
                      items: [
                        for (final value in _visibilityValues(
                          selectedSource.provider,
                        ))
                          ComboBoxItem(
                            value: value,
                            child: Text(_visibilityLabel(l10n, value)),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => visibility = value);
                              }
                            },
                    ),
                  ),
                  if (selectedSource.provider == BusyProvider.microsoft) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.importance,
                      child: ComboBox<String>(
                        isExpanded: true,
                        value: importance,
                        items: [
                          ComboBoxItem(
                            value: 'low',
                            child: Text(l10n.importanceLow),
                          ),
                          ComboBoxItem(
                            value: 'normal',
                            child: Text(l10n.importanceNormal),
                          ),
                          ComboBoxItem(
                            value: 'high',
                            child: Text(l10n.importanceHigh),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => importance = value);
                                }
                              },
                      ),
                    ),
                  ],
                  if (selectedSource.provider != BusyProvider.google) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.categories,
                      child: TextBox(
                        controller: categories,
                        enabled: !saving,
                        onChanged: (_) =>
                            setState(() => categoriesChanged = true),
                      ),
                    ),
                  ],
                  if (selectedSource.provider == BusyProvider.google ||
                      selectedSource.provider == BusyProvider.microsoft) ...[
                    const SizedBox(height: 16),
                    ToggleSwitch(
                      checked: onlineMeeting,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => onlineMeeting = value),
                      content: Text(
                        onlineMeeting && originalDraft?.conference != null
                            ? l10n.onlineMeetingAdded
                            : selectedSource.provider == BusyProvider.google
                            ? l10n.addGoogleMeet
                            : l10n.addTeamsMeeting,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.guests,
                      child: Column(
                        children: [
                          for (final attendee in attendees)
                            _WindowsAttendeeRow(
                              attendee: attendee,
                              requiredLabel: l10n.attendeeRequired,
                              optionalLabel: l10n.attendeeOptional,
                              canEdit:
                                  !saving &&
                                  !attendee.self &&
                                  !attendee.organizer &&
                                  (originalDraft?.canManageAttendees ?? true),
                              onOptionalChanged: (optional) => setState(() {
                                attendees = [
                                  for (final item in attendees)
                                    if (identical(item, attendee))
                                      EventAttendeeDraft(
                                        email: item.email,
                                        displayName: item.displayName,
                                        optional: optional,
                                        self: item.self,
                                        organizer: item.organizer,
                                        responseStatus: item.responseStatus,
                                      )
                                    else
                                      item,
                                ];
                                attendeesChanged = true;
                              }),
                              onDelete: () => setState(() {
                                attendees = [
                                  for (final item in attendees)
                                    if (!identical(item, attendee)) item,
                                ];
                                attendeesChanged = true;
                              }),
                            ),
                          if (originalDraft?.canManageAttendees ?? true)
                            _WindowsAddGuestRow(
                              controller: guestEmail,
                              label: l10n.addGuest,
                              enabled: !saving,
                              onChanged: () =>
                                  setState(() => guestError = null),
                              onAdd: () {
                                final email = guestEmail.text.trim();
                                if (!_looksLikeEmail(email)) {
                                  setState(
                                    () =>
                                        guestError = l10n.feedbackInvalidEmail,
                                  );
                                  return;
                                }
                                if (!attendees.any(
                                  (item) =>
                                      item.email.toLowerCase() ==
                                      email.toLowerCase(),
                                )) {
                                  setState(() {
                                    attendees = [
                                      ...attendees,
                                      EventAttendeeDraft(email: email),
                                    ];
                                    attendeesChanged = true;
                                  });
                                }
                                guestEmail.clear();
                              },
                            ),
                          if (guestError != null)
                            InfoBar(
                              title: Text(guestError!),
                              severity: InfoBarSeverity.warning,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: responseRequested,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => responseRequested = value),
                      content: Text(l10n.requestResponses),
                    ),
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: hideAttendees,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => hideAttendees = value),
                      content: Text(l10n.hideGuestList),
                    ),
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: allowNewTimeProposals,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => allowNewTimeProposals = value),
                      content: Text(l10n.allowNewTimeProposals),
                    ),
                  ],
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.location,
                    child: TextBox(controller: location),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.description,
                    child: TextBox(controller: description, maxLines: 4),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(error!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: saving
                    ? null
                    : () async {
                        if (hasPendingEdits() &&
                            !await _confirmDiscardEventChanges(context)) {
                          return;
                        }
                        closeDialog();
                      },
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: saving || title.text.trim().isEmpty || !validEnd
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final effectiveEnd = allDay
                              ? DateTime(end.year, end.month, end.day)
                              : end;
                          final effectiveStart = allDay
                              ? DateTime(start.year, start.month, start.day)
                              : start;
                          final encodedRecurrence =
                              recurrenceChanged && recurrence.repeats
                              ? EventRecurrenceCodec.encode(
                                  selectedSource.provider,
                                  recurrence,
                                  baseDate: start,
                                  allDay: allDay,
                                  timeZone: selectedTimeZone,
                                )
                              : null;
                          var draft =
                              (originalDraft ??
                                      EventEditorDraft.newEvent(
                                        accountId: selectedSource.accountId,
                                        sourceId: selectedSource.id,
                                        providerCalendarId:
                                            selectedSource.providerCalendarId,
                                        start: effectiveStart,
                                        end: effectiveEnd,
                                      ))
                                  .copyWith(
                                    accountId: selectedSource.accountId,
                                    sourceId: selectedSource.id,
                                    providerCalendarId:
                                        selectedSource.providerCalendarId,
                                    title: title.text.trim(),
                                    allDay: allDay,
                                    start: effectiveStart,
                                    end: effectiveEnd,
                                    location: location.text.trim(),
                                    description: description.text.trim(),
                                    startTimeZone: selectedTimeZone,
                                    endTimeZone: selectedTimeZone,
                                    recurrence: recurrenceChanged
                                        ? encodedRecurrence
                                        : null,
                                    recurrenceChanged: recurrenceChanged,
                                    clearRecurrence:
                                        recurrenceChanged &&
                                        !recurrence.repeats,
                                    reminders: remindersChanged
                                        ? encodeWindowsEventReminderPayload(
                                            selectedSource.provider,
                                            reminderMinutes,
                                          )
                                        : null,
                                    remindersChanged: remindersChanged,
                                    attendees: attendeesChanged
                                        ? attendees
                                        : null,
                                    attendeesChanged: attendeesChanged,
                                    importance:
                                        selectedSource.provider ==
                                            BusyProvider.microsoft
                                        ? importance
                                        : null,
                                    showAs: showAs,
                                    visibilityOrSensitivity: visibility,
                                    categories: categoriesChanged
                                        ? _categories(categories.text)
                                        : null,
                                    categoriesChanged: categoriesChanged,
                                    createConference:
                                        onlineMeeting &&
                                        originalDraft?.conference == null,
                                    clearConference: !onlineMeeting,
                                    responseRequested: responseRequested,
                                    hideAttendees: hideAttendees,
                                    allowNewTimeProposals:
                                        allowNewTimeProposals,
                                  );
                          if (originalDraft?.providerRecurringEventId != null) {
                            final scope =
                                await _chooseRecurringEventMutationScope(
                                  dialogContext,
                                  selectedSource.provider,
                                );
                            if (scope == null) {
                              if (dialogContext.mounted) {
                                setState(() => saving = false);
                              }
                              return;
                            }
                            draft = draft.copyWith(
                              recurringMutationScope: scope,
                            );
                          }

                          final moveSource = originalDraft == null
                              ? null
                              : sources.firstWhere(
                                  (source) =>
                                      source.id == originalDraft.sourceId &&
                                      source.accountId ==
                                          originalDraft.accountId,
                                  orElse: () => selectedSource,
                                );
                          final moveStrategy = moveSource == null
                              ? CalendarEventMoveStrategy.none
                              : calendarEventMoveStrategy(
                                  sourceAccountId: moveSource.accountId,
                                  sourceId: moveSource.id,
                                  sourceProviderCalendarId:
                                      moveSource.providerCalendarId,
                                  sourceProvider: moveSource.provider,
                                  sourceDavCollectionId:
                                      moveSource.davCollectionId,
                                  destinationAccountId:
                                      selectedSource.accountId,
                                  destinationId: selectedSource.id,
                                  destinationProviderCalendarId:
                                      selectedSource.providerCalendarId,
                                  destinationProvider: selectedSource.provider,
                                  destinationDavCollectionId:
                                      selectedSource.davCollectionId,
                                  eventType: originalDraft?.eventType,
                                  recurring:
                                      originalDraft?.providerRecurringEventId !=
                                      null,
                                  recurringScope: draft.recurringMutationScope,
                                );
                          if (moveStrategy ==
                              CalendarEventMoveStrategy.copyThenDelete) {
                            if (!dialogContext.mounted) return;
                            final confirmed = await _confirmCopyThenDelete(
                              dialogContext,
                              sourceLabel: _calendarSourceLabel(
                                moveSource!,
                                accounts,
                              ),
                              destinationLabel: _calendarSourceLabel(
                                selectedSource,
                                accounts,
                              ),
                            );
                            if (!confirmed) {
                              if (dialogContext.mounted) {
                                setState(() => saving = false);
                              }
                              return;
                            }
                          }

                          var guestUpdatePolicy =
                              CalendarGuestUpdatePolicy.send;
                          final guestProvider =
                              selectedSource.provider == BusyProvider.google ||
                                  selectedSource.provider ==
                                      BusyProvider.microsoft
                              ? selectedSource.provider
                              : moveSource?.provider;
                          if ((guestProvider == BusyProvider.google ||
                                  guestProvider == BusyProvider.microsoft) &&
                              draft.isOrganizer == true &&
                              _hasExternalGuests(
                                draft.attendees,
                                originalDraft?.attendees ?? const [],
                              )) {
                            if (!dialogContext.mounted) return;
                            final choice = await showWindowsGuestUpdateDialog(
                              dialogContext,
                              provider: guestProvider!,
                              action: WindowsGuestUpdateAction.save,
                            );
                            if (choice == null) {
                              if (dialogContext.mounted) {
                                setState(() => saving = false);
                              }
                              return;
                            }
                            guestUpdatePolicy = choice;
                          }
                          if (detail == null) {
                            await repository.createLocalEvent(
                              draft,
                              guestUpdatePolicy: guestUpdatePolicy,
                            );
                          } else {
                            await repository.updateLocalEvent(
                              draft,
                              guestUpdatePolicy: guestUpdatePolicy,
                            );
                          }
                          saved = true;
                          closeDialog();
                        } on Object catch (_) {
                          setState(() {
                            saving = false;
                            error = l10n.operationFailed;
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(),
                      )
                    : Text(detail == null ? l10n.create : l10n.save),
              ),
            ],
          ),
        );
      },
    ),
  );
  title.dispose();
  description.dispose();
  location.dispose();
  guestEmail.dispose();
  categories.dispose();
  return saved;
}

class _WindowsAttendeeRow extends StatelessWidget {
  const _WindowsAttendeeRow({
    required this.attendee,
    required this.requiredLabel,
    required this.optionalLabel,
    required this.canEdit,
    required this.onOptionalChanged,
    required this.onDelete,
  });

  final EventAttendeeDraft attendee;
  final String requiredLabel;
  final String optionalLabel;
  final bool canEdit;
  final ValueChanged<bool> onOptionalChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(attendee.email),
          if (attendee.displayName != null)
            Text(
              attendee.displayName!,
              style: FluentTheme.of(context).typography.caption,
            ),
        ],
      );
      final controls = canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ComboBox<bool>(
                  value: attendee.optional,
                  items: [
                    ComboBoxItem(value: false, child: Text(requiredLabel)),
                    ComboBoxItem(value: true, child: Text(optionalLabel)),
                  ],
                  onChanged: (value) {
                    if (value != null) onOptionalChanged(value);
                  },
                ),
                IconButton(
                  icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
                  onPressed: onDelete,
                ),
              ],
            )
          : Text(attendee.optional ? optionalLabel : requiredLabel);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: controls,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 8),
                  controls,
                ],
              ),
      );
    },
  );
}

class _WindowsAddGuestRow extends StatelessWidget {
  const _WindowsAddGuestRow({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final field = TextBox(
        controller: controller,
        enabled: enabled,
        placeholder: label,
        onChanged: (_) => onChanged(),
        onSubmitted: enabled ? (_) => onAdd() : null,
      );
      final button = Button(
        onPressed: enabled ? onAdd : null,
        child: Text(label),
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 8),
                button,
              ],
            );
    },
  );
}

String _recurrenceLabel(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => l10n.repeatNone,
      RecurrenceFrequency.daily => l10n.repeatDaily,
      RecurrenceFrequency.weekly => l10n.repeatWeekly,
      RecurrenceFrequency.monthly => l10n.repeatMonthly,
      RecurrenceFrequency.yearly => l10n.repeatYearly,
    };

String _reminderLabel(AppLocalizations l10n, int minutes) {
  if (minutes == 0) return l10n.reminderAtStart;
  const minutesPerDay = Duration.minutesPerHour * Duration.hoursPerDay;
  if (minutes % minutesPerDay == 0) {
    return l10n.reminderDaysBefore(minutes ~/ minutesPerDay);
  }
  if (minutes % Duration.minutesPerHour == 0) {
    return l10n.reminderHoursBefore(minutes ~/ Duration.minutesPerHour);
  }
  return l10n.reminderMinutesBefore(minutes);
}

List<String> _showAsValues(BusyProvider provider) =>
    provider == BusyProvider.microsoft
    ? const ['free', 'tentative', 'busy', 'oof', 'workingElsewhere']
    : const ['opaque', 'transparent'];

String _showAsForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'free' || 'tentative' || 'busy' || 'oof' || 'workingElsewhere' => value!,
      'transparent' => 'free',
      _ => 'busy',
    };
  }
  return switch (value) {
    'opaque' || 'transparent' => value!,
    'free' => 'transparent',
    _ => 'opaque',
  };
}

String _availabilityLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'opaque' || 'busy' => l10n.busy,
      'transparent' || 'free' => l10n.availabilityFree,
      'tentative' => l10n.availabilityTentative,
      'oof' => l10n.availabilityOutOfOffice,
      'workingElsewhere' => l10n.availabilityWorkingElsewhere,
      _ => value,
    };

List<String> _visibilityValues(BusyProvider provider) =>
    provider == BusyProvider.microsoft
    ? const ['normal', 'personal', 'private', 'confidential']
    : const ['default', 'public', 'private', 'confidential'];

String _visibilityForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'normal' || 'personal' || 'private' || 'confidential' => value!,
      _ => 'normal',
    };
  }
  return switch (value) {
    'default' || 'public' || 'private' || 'confidential' => value!,
    'personal' => 'private',
    _ => 'default',
  };
}

String _visibilityLabel(AppLocalizations l10n, String value) => switch (value) {
  'default' => l10n.visibilityDefault,
  'public' => l10n.visibilityPublic,
  'private' => l10n.visibilityPrivate,
  'confidential' => l10n.visibilityConfidential,
  'normal' => l10n.sensitivityNormal,
  'personal' => l10n.sensitivityPersonal,
  _ => value,
};

List<String> _categories(String value) => value
    .split(',')
    .map((category) => category.trim())
    .where((category) => category.isNotEmpty)
    .toSet()
    .toList(growable: false);

bool _looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

bool _hasExternalGuests(
  List<EventAttendeeDraft> attendees, [
  List<EventAttendeeDraft> previous = const [],
]) => [
  ...attendees,
  ...previous,
].any((attendee) => !attendee.self && !attendee.organizer);

Future<bool> _confirmDiscardEventChanges(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ContentDialog(
          title: Text(l10n.discardChanges),
          content: const SizedBox.shrink(),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;
}

Future<RecurringEventMutationScope?> _chooseRecurringEventMutationScope(
  BuildContext context,
  BusyProvider provider,
) {
  final l10n = AppLocalizations.of(context);
  final supportsFollowing = supportsThisAndFollowingEventMutation(provider);
  return showDialog<RecurringEventMutationScope>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ContentDialog(
      title: Text(l10n.recurringEventScope),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chooseRecurringEventScope),
          const SizedBox(height: 12),
          Button(
            onPressed: () => Navigator.pop(
              dialogContext,
              RecurringEventMutationScope.singleOccurrence,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.singleOccurrence),
            ),
          ),
          const SizedBox(height: 8),
          Button(
            onPressed: supportsFollowing
                ? () => Navigator.pop(
                    dialogContext,
                    RecurringEventMutationScope.thisAndFuture,
                  )
                : null,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                supportsFollowing
                    ? l10n.thisAndFollowingEvents
                    : '${l10n.thisAndFollowingEvents}\n'
                          '${l10n.thisAndFutureUnavailable}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Button(
            onPressed: () => Navigator.pop(
              dialogContext,
              RecurringEventMutationScope.entireSeries,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.entireSeries),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

Future<bool> _confirmCopyThenDelete(
  BuildContext context, {
  required String sourceLabel,
  required String destinationLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ContentDialog(
          title: Text(l10n.copyEventAndDeleteOriginal),
          content: Text(
            l10n.copyEventMoveWarning(sourceLabel, destinationLabel),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.copyAndDelete),
            ),
          ],
        ),
      ) ??
      false;
}

String _calendarSourceLabel(
  CalendarSourceEntity source,
  List<AccountEntity> accounts,
) {
  for (final account in accounts) {
    if (account.id == source.accountId) {
      return '${account.selectorLabel} · ${source.summary}';
    }
  }
  return '${source.provider.displayName} · ${source.summary}';
}
