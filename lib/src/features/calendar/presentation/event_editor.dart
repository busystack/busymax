import 'package:busymax/src/core/auth/authorization_attempt.dart';

import '../domain/event_property_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/app_bootstrap.dart';
import '../../../contacts/busymax_contacts_controller.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_window_close.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../calendar_providers/calendar_mutation.dart';
import '../../../calendar_providers/calendar_provider_capabilities.dart';
import '../../../microsoft_calendar/microsoft_calendar_models.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_projection.dart';

import 'package:busymax/src/providers/busy_provider.dart';

import '../../accounts/data/accounts_repository.dart';
import '../../recurrence/domain/event_recurrence_codec.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import '../../recurrence/presentation/recurrence_editor.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import '../../maps/domain/location_result.dart';
import '../data/calendar_repository.dart';
import '../domain/event_move_policy.dart';
import 'event_description_editor.dart';
import 'event_editor_draft.dart';
import '../domain/event_timing_policy.dart';
import '../domain/google_status_event.dart';
import 'google_status_event_labels.dart';
import 'event_guest_delivery_dialog.dart';
import '../../../dav/presentation/nextcloud_scheduling_dialog.dart';
import 'linux_cloud_availability_dialog.dart';

Future<EventEditorDialogResult?> showBusyMaxEventEditorDialog(
  BuildContext context, {
  required EventEditorDraft initialDraft,
  required List<CalendarSourceEntity> sources,
  required List<AccountEntity> accounts,
  bool allowDelete = true,
  Map<String, List<String>> categorySuggestionsByAccount = const {},
}) async {
  return showBusyMaxModalEditorDialog<EventEditorDialogResult>(
    context,
    maxWidth: BusyMaxSizes.detailsWidth,
    maxHeight: 720,
    builder: (context) {
      return EventEditor(
        initialDraft: initialDraft,
        sources: sources,
        accounts: accounts,
        categorySuggestionsByAccount: categorySuggestionsByAccount,
        onCancel: () => Navigator.of(context).pop(),
        onSave: (draft) => unawaited(
          _completeEventEditorSave(
            context,
            draft: draft,
            initialDraft: initialDraft,
            sources: sources,
            accounts: accounts,
          ),
        ),
        onDelete: allowDelete && initialDraft.eventId != null
            ? (eventId, scope) => unawaited(
                _completeEventEditorDelete(
                  context,
                  eventId: eventId,
                  scope: scope,
                  initialDraft: initialDraft,
                  sources: sources,
                ),
              )
            : null,
      );
    },
  );
}

class EventEditorDialogResult {
  const EventEditorDialogResult._({
    this.draft,
    this.deletedEventId,
    this.deletionScope,
    this.guestUpdatePolicy = CalendarGuestUpdatePolicy.send,
  });

  factory EventEditorDialogResult.save(
    EventEditorDraft draft, {
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) {
    return EventEditorDialogResult._(
      draft: draft,
      guestUpdatePolicy: guestUpdatePolicy,
    );
  }

  factory EventEditorDialogResult.delete(
    String eventId, {
    RecurringEventMutationScope? scope,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) {
    return EventEditorDialogResult._(
      deletedEventId: eventId,
      deletionScope: scope,
      guestUpdatePolicy: guestUpdatePolicy,
    );
  }

  final EventEditorDraft? draft;
  final String? deletedEventId;
  final RecurringEventMutationScope? deletionScope;
  final CalendarGuestUpdatePolicy guestUpdatePolicy;
}

Future<void> _completeEventEditorSave(
  BuildContext context, {
  required EventEditorDraft draft,
  required EventEditorDraft initialDraft,
  required List<CalendarSourceEntity> sources,
  required List<AccountEntity> accounts,
}) async {
  final move = _eventMoveContext(
    initialDraft: initialDraft,
    draft: draft,
    sources: sources,
  );
  if (move != null &&
      move.strategy == CalendarEventMoveStrategy.copyThenDelete) {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.copyEventAndDeleteOriginal,
      message: context.l10n.copyEventMoveWarning(
        _calendarMoveLabel(move.source, accounts),
        _calendarMoveLabel(move.destination, accounts),
      ),
      confirmLabel: context.l10n.copyAndDelete,
    );
    if (!confirmed || !context.mounted) return;
  }
  var guestUpdatePolicy = CalendarGuestUpdatePolicy.send;
  final provider = _guestDeliveryProvider(move, draft, sources);
  if (provider != null &&
      draft.isOrganizer == true &&
      _hasExternalGuests(draft.attendees, initialDraft.attendees)) {
    final choice = await showCalendarGuestDeliveryDialog(
      context,
      provider: provider,
      action: CalendarGuestDeliveryAction.save,
    );
    if (choice == null) return;
    guestUpdatePolicy = choice;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop(
    EventEditorDialogResult.save(draft, guestUpdatePolicy: guestUpdatePolicy),
  );
}

BusyProvider? _guestDeliveryProvider(
  _EventMoveContext? move,
  EventEditorDraft draft,
  List<CalendarSourceEntity> sources,
) {
  final destination = _providerForDraft(draft, sources);
  if (destination == BusyProvider.google ||
      destination == BusyProvider.microsoft ||
      destination == BusyProvider.nextcloud) {
    return destination;
  }
  final source = move?.source.provider;
  return source == BusyProvider.google || source == BusyProvider.microsoft
      ? source
      : null;
}

_EventMoveContext? _eventMoveContext({
  required EventEditorDraft initialDraft,
  required EventEditorDraft draft,
  required List<CalendarSourceEntity> sources,
}) {
  if (initialDraft.eventId == null) return null;
  CalendarSourceEntity? source;
  CalendarSourceEntity? destination;
  for (final candidate in sources) {
    if (candidate.id == initialDraft.sourceId) source = candidate;
    if (candidate.id == draft.sourceId) destination = candidate;
  }
  if (source == null || destination == null) return null;
  final strategy = calendarEventMoveStrategy(
    sourceAccountId: source.accountId,
    sourceId: source.id,
    sourceProviderCalendarId: source.providerCalendarId,
    sourceProvider: source.provider,
    sourceDavCollectionId: source.davCollectionId,
    destinationAccountId: destination.accountId,
    destinationId: destination.id,
    destinationProviderCalendarId: destination.providerCalendarId,
    destinationProvider: destination.provider,
    destinationDavCollectionId: destination.davCollectionId,
    eventType: initialDraft.eventType,
    recurring: initialDraft.providerRecurringEventId != null,
    recurringScope: draft.recurringMutationScope,
  );
  if (strategy == CalendarEventMoveStrategy.none) return null;
  return _EventMoveContext(
    source: source,
    destination: destination,
    strategy: strategy,
  );
}

String _calendarMoveLabel(
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

class _EventMoveContext {
  const _EventMoveContext({
    required this.source,
    required this.destination,
    required this.strategy,
  });

  final CalendarSourceEntity source;
  final CalendarSourceEntity destination;
  final CalendarEventMoveStrategy strategy;
}

Future<void> _completeEventEditorDelete(
  BuildContext context, {
  required String eventId,
  required RecurringEventMutationScope? scope,
  required EventEditorDraft initialDraft,
  required List<CalendarSourceEntity> sources,
}) async {
  var guestUpdatePolicy = CalendarGuestUpdatePolicy.send;
  final provider = _providerForDraft(initialDraft, sources);
  if (provider != null &&
      initialDraft.isOrganizer == true &&
      _hasExternalGuests(initialDraft.attendees)) {
    final choice = await showCalendarGuestDeliveryDialog(
      context,
      provider: provider,
      action: CalendarGuestDeliveryAction.delete,
    );
    if (choice == null) return;
    guestUpdatePolicy = choice;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop(
    EventEditorDialogResult.delete(
      eventId,
      scope: scope,
      guestUpdatePolicy: guestUpdatePolicy,
    ),
  );
}

BusyProvider? _providerForDraft(
  EventEditorDraft draft,
  List<CalendarSourceEntity> sources,
) {
  for (final source in sources) {
    if (source.id == draft.sourceId) return source.provider;
  }
  return null;
}

bool _hasExternalGuests(
  List<EventAttendeeDraft> attendees, [
  List<EventAttendeeDraft> previous = const [],
]) {
  return [
    ...attendees,
    ...previous,
  ].any((attendee) => !attendee.self && !attendee.organizer);
}

typedef EventEditorDeleteCallback = void Function(
  String eventId,
  RecurringEventMutationScope? scope,
);

class EventEditor extends ConsumerStatefulWidget {
  const EventEditor({
    super.key,
    required this.initialDraft,
    required this.sources,
    required this.onCancel,
    required this.onSave,
    this.accounts = const [],
    this.onDelete,
    this.categorySuggestionsByAccount = const {},
  });

  final EventEditorDraft initialDraft;
  final List<CalendarSourceEntity> sources;
  final List<AccountEntity> accounts;
  final Map<String, List<String>> categorySuggestionsByAccount;
  final VoidCallback onCancel;
  final ValueChanged<EventEditorDraft> onSave;
  final EventEditorDeleteCallback? onDelete;

  @override
  ConsumerState<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<EventEditor> {
  AuthorizationCancellation? _consentCancellation;

  late EventEditorDraft _draft;
  final _shortcutFocusNode = FocusNode(debugLabel: 'Event editor shortcuts');
  final _guestController = TextEditingController();
  String? _guestError;
  List<BusyMaxContactSuggestion> _guestSuggestions = const [];
  int _guestSuggestionGeneration = 0;
  StreamSubscription<void>? _contactsChanges;
  var _addingGuest = false;
  var _addingCategory = false;
  var _confirmingCancel = false;
  var _startTimeValid = true;
  var _endTimeValid = true;

  List<CalendarSourceEntity> get _selectableSources {
    if (widget.initialDraft.eventId == null) {
      return widget.sources;
    }
    return [
      for (final source in widget.sources)
        if (!source.pendingCreate || source.id == widget.initialDraft.sourceId)
          source,
    ];
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
  }

  @override
  void dispose() {
    _consentCancellation?.cancel();
    _guestSuggestionGeneration++;
    unawaited(_contactsChanges?.cancel());
    _shortcutFocusNode.dispose();
    _guestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxWindowCloseGuard(
      onCloseRequested: _confirmWindowClose,
      child: _buildEditor(context),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final l10n = context.l10n;
    final dirty = _hasUnsavedChanges;
    final title = widget.initialDraft.eventId == null
        ? l10n.newEvent
        : l10n.editEvent;
    CalendarSourceEntity? currentSource;
    for (final source in _selectableSources) {
      if (source.id == _draft.sourceId) {
        currentSource = source;
        break;
      }
    }
    if (currentSource == null) {
      return BusyMaxModalEditorScaffold(
        title: title,
        cancelLabel: l10n.cancel,
        saveLabel: l10n.save,
        onCancel: widget.onCancel,
        onSave: null,
        children: [
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.calendar,
                subtitle: l10n.noCalendarsSynced,
                leading: const Icon(YaruIcons.calendar),
                enabled: false,
              ),
            ],
          ),
        ],
      );
    }
    final provider = currentSource.provider;
    final schedulingReadOnly =
        provider == BusyProvider.appleICloud ||
        (provider == BusyProvider.nextcloud &&
            currentSource.davEffectivePermissions['canInvite'] != true);
    final recurringOccurrence = _draft.providerRecurringEventId != null;
    final timeFieldsValid = _draft.allDay || (_startTimeValid && _endTimeValid);
    final recurringScopeValid =
        !recurringOccurrence ||
        (_draft.recurringMutationScope != null &&
            _supportsRecurringScope(
              currentSource,
              _draft.recurringMutationScope!,
            ));
    final canSave =
        dirty && _draft.canSave && timeFieldsValid && recurringScopeValid;
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
                  title: TextFormField(
                    initialValue: _draft.title,
                    autofocus: true,
                    decoration: busyMaxGroupedTextFieldDecoration(
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
                  title: TextFormField(
                    key: const ValueKey('event-location-field'),
                    initialValue: _draft.location ?? '',
                    decoration: busyMaxGroupedTextFieldDecoration(
                      context,
                      labelText: l10n.location,
                    ),
                    onChanged: (value) {
                      final original = widget.initialDraft.location ?? '';
                      setState(() {
                        _draft = _draft.copyWith(
                          location: value,
                          locationChange: value == original
                              ? const LocationChange.unchanged()
                              : const LocationChange.clear(),
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [_accountRow(), _calendarRow()],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [
                BusyMaxTimeModeRow(
                  allDay: _draft.allDay,
                  onChanged: (value) => _setAllDay(value, provider),
                ),
              ],
            ),
            BusyMaxGroupedList(
              title: l10n.startDateTime,
              filled: true,
              children: [
                DesktopDateValueRow(
                  label: l10n.startDate,
                  date: _dateString(_draft.start),
                  onChanged: (value) {
                    _setStart(_withDate(_draft.start, value), provider);
                  },
                ),
                if (!_draft.allDay)
                  DesktopTimeValueRow(
                    label: l10n.startTime,
                    time: _timeString(_draft.start),
                    onChanged: (value) {
                      _setStart(_withTime(_draft.start, value), provider);
                    },
                    timeZone: _draft.startTimeZone,
                    onTimeZoneChanged: (value) {
                      _setStartTimeZone(value, provider);
                    },
                    allowEmpty: false,
                    onValidityChanged: (valid) {
                      if (_startTimeValid != valid) {
                        setState(() => _startTimeValid = valid);
                      }
                    },
                  ),
              ],
            ),
            BusyMaxGroupedList(
              title: l10n.endDateTime,
              filled: true,
              children: [
                DesktopDateValueRow(
                  label: l10n.endDate,
                  date: _dateString(_draft.end),
                  onChanged: (value) {
                    _setEnd(_withDate(_draft.end, value));
                  },
                ),
                if (!_draft.allDay)
                  DesktopTimeValueRow(
                    label: l10n.endTime,
                    time: _timeString(_draft.end),
                    onChanged: (value) {
                      _setEnd(_withTime(_draft.end, value));
                    },
                    timeZone: _draft.endTimeZone,
                    onTimeZoneChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(endTimeZone: value);
                      });
                    },
                    allowEmpty: false,
                    onValidityChanged: (valid) {
                      if (_endTimeValid != valid) {
                        setState(() => _endTimeValid = valid);
                      }
                    },
                  ),
              ],
            ),
            BusyMaxGroupedList(
              filled: true,
              children: [
                YaruListTile.square(
                  title: EventDescriptionEditor(
                    provider: provider,
                    text: _draft.editableDescription,
                    contentType: _draft.descriptionContentType,
                    html: _draft.editableDescriptionHtml,
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
            if (recurringOccurrence)
              BusyMaxGroupedList(
                title: l10n.recurringEventScope,
                filled: true,
                children: _recurringScopeRows(provider),
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
            if (!schedulingReadOnly || _draft.attendees.isNotEmpty)
              BusyMaxGroupedList(
                title: l10n.guests,
                filled: true,
                children: _guestRows(
                  readOnly: schedulingReadOnly || !_draft.canManageAttendees,
                ),
              ),
            if (provider == BusyProvider.nextcloud &&
                currentSource.davCollectionId != null &&
                currentSource.davEffectivePermissions['canQueryFreeBusy'] ==
                    true &&
                _draft.attendees.isNotEmpty)
              BusyMaxPushButton.standard(
                onPressed: () => showLinuxNextcloudSchedulingDialog(
                  context,
                  accountId: currentSource!.accountId,
                  collectionId: currentSource.davCollectionId!,
                  draft: _draft,
                ),
                child: Text(l10n.nextcloudGuestAvailability),
              ),
            if ((provider == BusyProvider.google ||
                    (provider == BusyProvider.microsoft &&
                        microsoftAvailabilityAccountType(
                              widget.accounts
                                  .where(
                                    (account) =>
                                        account.id == currentSource!.accountId,
                                  )
                                  .firstOrNull
                                  ?.tenantId,
                            ) ==
                            MicrosoftAvailabilityAccountType.workSchool)) &&
                _draft.attendees.any(
                  (attendee) => !attendee.self && !attendee.organizer,
                ))
              BusyMaxPushButton.standard(
                onPressed: () => showLinuxCloudAvailabilityDialog(
                  context,
                  draft: _draft,
                  calendarTimeZone: currentSource?.timeZone,
                ),
                child: Text(l10n.nextcloudGuestAvailability),
              ),
            YaruExpandable(
              header: Text(l10n.organizationSection),
              expandIconSemanticLabel: l10n.organizationSection,
              isExpanded:
                  _draft.categories.isNotEmpty ||
                  _draft.eventLabelId != null ||
                  _draft.conference != null ||
                  _draft.createConference ||
                  (_draft.importance != null &&
                      _draft.importance != 'normal') ||
                  (_draft.showAs != null &&
                      !const ['opaque', 'busy'].contains(_draft.showAs)) ||
                  (_draft.visibilityOrSensitivity != null &&
                      !const [
                        'default',
                        'normal',
                        'public',
                      ].contains(_draft.visibilityOrSensitivity)),
              child: Column(
                children: [
                  if ((provider == BusyProvider.google ||
                          provider == BusyProvider.microsoft) &&
                      _draft.isOrganizer != false)
                    BusyMaxGroupedList(
                      title: l10n.meetingSection,
                      filled: true,
                      children: _meetingRows(provider, currentSource),
                    ),
                  if (provider == BusyProvider.microsoft ||
                      provider == BusyProvider.nextcloud ||
                      schedulingReadOnly)
                    BusyMaxGroupedList(
                      title: l10n.organizationSection,
                      filled: true,
                      children: [
                        _categoriesRow(),
                        if (provider == BusyProvider.microsoft)
                          _importanceRow(),
                      ],
                    ),
                  if (provider == BusyProvider.google)
                    if (currentSource.primaryCalendar ||
                        googleStatusEventTypes.contains(_draft.eventType))
                      BusyMaxGroupedList(
                        title: l10n.googleEventType,
                        filled: true,
                        children: _googleStatusRows(),
                      ),
                  if (provider == BusyProvider.google)
                    BusyMaxGroupedList(
                      title: l10n.eventLabel,
                      filled: true,
                      children: [_googleLabelRow(currentSource)],
                    ),
                  BusyMaxGroupedList(
                    filled: true,
                    children: [_availabilityRow(provider)],
                  ),
                  BusyMaxGroupedList(
                    filled: true,
                    children: [_visibilityRow(provider)],
                  ),
                ],
              ),
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
                    onTap:
                        recurringOccurrence &&
                            _draft.recurringMutationScope == null
                        ? null
                        : _deleteCurrentEvent,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (await _confirmWindowClose() && mounted) {
      widget.onCancel();
    }
  }

  Future<bool> _confirmWindowClose() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    if (_confirmingCancel) {
      return false;
    }

    _confirmingCancel = true;
    try {
      return await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discardChangesAction,
        destructive: true,
      );
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
    return _draft.eventId != null &&
        widget.onDelete != null &&
        (!_requiresRecurringScope || _draft.recurringMutationScope != null);
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
      widget.onDelete!(eventId, _draft.recurringMutationScope);
    }
  }

  bool get _requiresRecurringScope {
    return _draft.providerRecurringEventId != null;
  }

  List<Widget> _recurringScopeRows(BusyProvider provider) {
    final l10n = context.l10n;
    final source = _sourceForId(_draft.sourceId);
    final supportsFollowing =
        source != null &&
        _supportsRecurringScope(
          source,
          RecurringEventMutationScope.thisAndFuture,
        );
    final supportsEntire =
        source != null &&
        _supportsRecurringScope(
          source,
          RecurringEventMutationScope.entireSeries,
        );
    final moving = _isMovingTo(source);
    return [
      BusyMaxActionRow(
        title: l10n.singleOccurrence,
        subtitle: l10n.chooseRecurringEventScope,
        leading: Icon(
          _draft.recurringMutationScope ==
                  RecurringEventMutationScope.singleOccurrence
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        onTap: () => setState(() {
          _draft = _draft.copyWith(
            recurringMutationScope:
                RecurringEventMutationScope.singleOccurrence,
          );
        }),
      ),
      BusyMaxActionRow(
        title: l10n.thisAndFollowingEvents,
        subtitle: supportsFollowing
            ? null
            : moving
            ? l10n.thisAndFutureMoveUnavailable
            : l10n.thisAndFutureUnavailable,
        leading: Icon(
          _draft.recurringMutationScope ==
                  RecurringEventMutationScope.thisAndFuture
              ? Icons.radio_button_checked
              : supportsFollowing
              ? Icons.radio_button_unchecked
              : Icons.update_disabled_outlined,
        ),
        enabled: supportsFollowing,
        onTap: supportsFollowing
            ? () => setState(() {
                _draft = _draft.copyWith(
                  recurringMutationScope:
                      RecurringEventMutationScope.thisAndFuture,
                );
              })
            : null,
      ),
      BusyMaxActionRow(
        title: l10n.entireSeries,
        subtitle: supportsEntire ? null : l10n.entireSeriesMoveUnavailable,
        leading: Icon(
          _draft.recurringMutationScope ==
                  RecurringEventMutationScope.entireSeries
              ? Icons.radio_button_checked
              : supportsEntire
              ? Icons.radio_button_unchecked
              : Icons.update_disabled_outlined,
        ),
        enabled: supportsEntire,
        onTap: supportsEntire
            ? () => setState(() {
                _draft = _draft.copyWith(
                  recurringMutationScope:
                      RecurringEventMutationScope.entireSeries,
                );
              })
            : null,
      ),
    ];
  }

  Widget _repeatRow(BusyProvider provider) {
    final l10n = context.l10n;
    final recurrence = EventRecurrenceCodec.decode(
      provider,
      _draft.recurrence,
      baseDate: _draft.start,
    );
    if (!recurrence.isSupported) {
      return BusyMaxActionRow(
        title: l10n.repeat,
        subtitle: l10n.unsupportedRecurrencePreserved,
        leading: const Icon(Icons.repeat),
        enabled: false,
      );
    }
    return BusyMaxActionRow(
      title: l10n.repeat,
      leading: const Icon(Icons.repeat),
      subtitle: recurrenceRuleSummary(
        context,
        recurrence,
        timeZone: _draft.startTimeZone,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(_editRecurrence(provider, recurrence)),
    );
  }

  Future<void> _editRecurrence(
    BusyProvider provider,
    RecurrenceRule initial,
  ) async {
    final baseDate = _draft.start ?? DateTime.now();
    final result = await showRecurrenceEditorDialog(
      context,
      initial: initial,
      allDay: _draft.allDay,
      floating: _isFloatingDavTime(
        provider,
        allDay: _draft.allDay,
        timeZone: _draft.startTimeZone,
      ),
      baseDate: baseDate,
      minimumDate: baseDate,
      timeZone: _draft.startTimeZone,
      limits: EventRecurrenceCodec.limitsFor(provider),
      useNativeDatePicker: false,
    );
    if (result == null || !mounted) return;
    if (!result.repeats) {
      setState(() => _draft = _draft.copyWith(clearRecurrence: true));
      return;
    }
    final encoded = EventRecurrenceCodec.encode(
      provider,
      result,
      baseDate: baseDate,
      allDay: _draft.allDay,
      timeZone: _draft.startTimeZone,
      original: _draft.recurrence,
    );
    setState(() => _draft = _draft.copyWith(recurrence: encoded));
  }

  Widget _accountRow() {
    final accountIds =
        <String>{for (final source in _selectableSources) source.accountId}
            .toList()
          ..sort((first, second) {
            final labelOrder = _accountLabel(first)
                .toLowerCase()
                .compareTo(_accountLabel(second).toLowerCase());
            return labelOrder != 0 ? labelOrder : first.compareTo(second);
          });
    final selected = accountIds.contains(_draft.accountId)
        ? _draft.accountId
        : accountIds.first;
    return BusyMaxComboRow<String>(
      title: context.l10n.account,
      leading: const Icon(YaruIcons.user),
      values: accountIds,
      selected: selected,
      enabled: accountIds.length > 1,
      labelFor: _accountLabel,
      onSelected: _selectAccount,
    );
  }

  Widget _calendarRow() {
    final sources = [
      for (final source in _selectableSources)
        if (source.accountId == _draft.accountId) source,
    ]..sort(_compareCalendarSources);
    if (sources.isEmpty) {
      return BusyMaxActionRow(
        title: context.l10n.calendar,
        leading: const Icon(YaruIcons.calendar),
        subtitle: context.l10n.noCalendarsSynced,
      );
    }
    final selected = sources.any((source) => source.id == _draft.sourceId)
        ? _draft.sourceId
        : _preferredCalendarSource(sources).id;
    final sourcesById = {for (final source in sources) source.id: source};
    return BusyMaxComboRow<String>(
      title: context.l10n.calendar,
      leading: const Icon(YaruIcons.calendar),
      values: [for (final source in sources) source.id],
      selected: selected,
      enabled: sources.length > 1,
      labelFor: (value) => sourcesById[value]!.summary,
      selectorLeadingBuilder: (context, value) {
        final source = sourcesById[value]!;
        return _CalendarSourceDot(color: _calendarSourceColor(context, source));
      },
      onSelected: (value) => _selectCalendarSource(sourcesById[value]!),
    );
  }

  int _compareCalendarSources(
    CalendarSourceEntity first,
    CalendarSourceEntity second,
  ) {
    final summaryOrder = first.summary.toLowerCase().compareTo(
      second.summary.toLowerCase(),
    );
    if (summaryOrder != 0) return summaryOrder;
    return first.id.compareTo(second.id);
  }

  String _accountLabel(String accountId) {
    for (final candidate in widget.accounts) {
      if (candidate.id == accountId) {
        return candidate.selectorLabel;
      }
    }
    for (final source in _selectableSources) {
      if (source.accountId == accountId) return source.provider.displayName;
    }
    return context.l10n.account;
  }

  void _selectAccount(String accountId) {
    if (accountId == _draft.accountId) return;
    final sources = [
      for (final source in _selectableSources)
        if (source.accountId == accountId) source,
    ]..sort(_compareCalendarSources);
    if (sources.isEmpty) return;
    _selectCalendarSource(_preferredCalendarSource(sources));
  }

  CalendarSourceEntity _preferredCalendarSource(
    List<CalendarSourceEntity> sources,
  ) {
    for (final source in sources) {
      if (source.primaryCalendar) return source;
    }
    return sources.first;
  }

  void _selectCalendarSource(CalendarSourceEntity source) {
    if (googleStatusEventTypes.contains(_draft.eventType) &&
        (source.provider != BusyProvider.google || !source.primaryCalendar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.googleStatusPrimaryOnly)),
      );
      return;
    }
    final currentProvider = _providerForDraft(_draft, _selectableSources);
    Object? adjustedRecurrence;
    var clearRecurrence = false;
    if (_draft.recurrence != null &&
        currentProvider != null &&
        currentProvider != source.provider) {
      final rule = EventRecurrenceCodec.decode(
        currentProvider,
        _draft.recurrence,
        baseDate: _draft.start,
      );
      final canConvert =
          rule.isSupported &&
          (!rule.repeats ||
              EventRecurrenceCodec.canEncode(source.provider, rule));
      if (!canConvert) {
        if (_draft.providerRecurringEventId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.recurrenceUnsupportedByProvider(
                  source.provider.displayName,
                ),
              ),
            ),
          );
          return;
        }
      } else if (!rule.repeats) {
        clearRecurrence = true;
      } else {
        adjustedRecurrence = EventRecurrenceCodec.encode(
          source.provider,
          rule,
          baseDate: _draft.start ?? DateTime.now(),
          allDay: _draft.allDay,
          timeZone: _draft.startTimeZone,
        );
      }
    }
    final providerChanged =
        currentProvider != null && currentProvider != source.provider;
    final reminderMinutes = _reminderMinutesList(_draft.reminders);
    final adjustedReminders = providerChanged
        ? _remindersFor(source.provider, reminderMinutes) ??
              _disabledRemindersFor(source.provider)
        : _draft.reminders;
    final adjustedShowAs = providerChanged
        ? eventShowAsForProvider(_draft.showAs, source.provider)
        : _draft.showAs;
    final adjustedVisibility = providerChanged
        ? eventVisibilityForProvider(
            _draft.visibilityOrSensitivity,
            source.provider,
          )
        : _draft.visibilityOrSensitivity;
    var updated = _draft.copyWith(
      accountId: source.accountId,
      sourceId: source.id,
      providerCalendarId: source.providerCalendarId,
      reminders: providerChanged ? adjustedReminders : null,
      showAs: adjustedShowAs,
      visibilityOrSensitivity: adjustedVisibility,
      categories: source.provider != BusyProvider.google
          ? _draft.categories
          : const [],
      recurrence: adjustedRecurrence,
      clearRecurrence: clearRecurrence,
      clearImportance: source.provider != BusyProvider.microsoft,
      clearColorId: _draft.accountId != source.accountId || providerChanged,
      clearEventLabelId: _draft.sourceId != source.id,
      eventLabelChanged: _draft.sourceId == source.id
          ? _draft.eventLabelChanged
          : true,
    );
    final scope = updated.recurringMutationScope;
    if (scope != null && !_supportsRecurringScopeFor(updated, source, scope)) {
      updated = updated.copyWith(clearRecurringMutationScope: true);
    }
    setState(() {
      if (source.provider == BusyProvider.google) {
        _addingCategory = false;
      }
      _guestSuggestionGeneration++;
      _guestSuggestions = const [];
      _draft = updated;
    });
  }

  CalendarSourceEntity? _sourceForId(String sourceId) {
    for (final source in _selectableSources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }

  bool _isMovingTo(CalendarSourceEntity? destination) {
    if (destination == null || widget.initialDraft.eventId == null) {
      return false;
    }
    return destination.id != widget.initialDraft.sourceId ||
        destination.accountId != widget.initialDraft.accountId ||
        destination.providerCalendarId !=
            widget.initialDraft.providerCalendarId;
  }

  bool _supportsRecurringScope(
    CalendarSourceEntity destination,
    RecurringEventMutationScope scope,
  ) => _supportsRecurringScopeFor(_draft, destination, scope);

  bool _supportsRecurringScopeFor(
    EventEditorDraft draft,
    CalendarSourceEntity destination,
    RecurringEventMutationScope scope,
  ) {
    if (!_isMovingTo(destination)) {
      return scope != RecurringEventMutationScope.thisAndFuture ||
          (draft.originalDetail == null
              ? supportsThisAndFollowingEventMutation(destination.provider)
              : eventSupportsThisAndFollowing(draft.originalDetail!));
    }
    if (scope == RecurringEventMutationScope.singleOccurrence) return true;
    if (scope == RecurringEventMutationScope.thisAndFuture) return false;
    final move = _eventMoveContext(
      initialDraft: widget.initialDraft,
      draft: draft.copyWith(recurringMutationScope: scope),
      sources: _selectableSources,
    );
    if (move == null ||
        move.strategy != CalendarEventMoveStrategy.copyThenDelete) {
      return true;
    }
    final rule = EventRecurrenceCodec.decode(
      destination.provider,
      draft.recurrence,
      baseDate: draft.start,
    );
    return rule.isSupported && rule.repeats;
  }

  List<Widget> _reminderRows(BusyProvider provider) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = _reminderMinutesList(_draft.reminders);
    final supportsMultiple = provider != BusyProvider.microsoft;
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
          trailingAction: BusyMaxHeaderIconButton(
            tooltip: l10n.removeReminder,
            iconSize: BusyMaxSizes.headerIcon,
            icon: const Icon(YaruIcons.window_close),
            onPressed: () {
              _setReminderMinutes(provider, [
                ...minutes.take(index),
                ...minutes.skip(index + 1),
              ]);
            },
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxSubtleButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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

  List<Widget> _guestRows({required bool readOnly}) {
    final rows = <Widget>[
      for (final attendee in _draft.attendees)
        if (readOnly || attendee.self || attendee.organizer)
          BusyMaxActionRow(
            title: attendee.email,
            subtitle: attendee.displayName,
            leading: const Icon(Icons.person_outline),
          )
        else
          BusyMaxComboRow<bool>(
            title: attendee.email,
            subtitle: attendee.displayName,
            leading: const Icon(Icons.person_outline),
            values: const [false, true],
            selected: attendee.optional,
            labelFor: (optional) => optional
                ? context.l10n.attendeeOptional
                : context.l10n.attendeeRequired,
            onSelected: (optional) => _setAttendeeOptional(attendee, optional),
            trailingAction: YaruIconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(YaruIcons.window_close),
              onPressed: () => _removeAttendee(attendee),
            ),
          ),
    ];
    if (readOnly) return rows;
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
          trailing: YaruIconButton(
            tooltip: context.l10n.addGuest,
            icon: const Icon(YaruIcons.plus),
            onPressed: _addGuest,
          ),
          title: TextField(
            controller: _guestController,
            autofocus: true,
            decoration: busyMaxGroupedTextFieldDecoration(
              context,
              labelText: context.l10n.addGuestEmail,
              errorText: _guestError,
            ),
            onChanged: _loadGuestSuggestions,
            onSubmitted: (_) => _addGuest(),
          ),
        ),
      );
      rows.addAll([
        for (final suggestion in _guestSuggestions)
          BusyMaxActionRow(
            key: ValueKey('guest-contact-${suggestion.email}'),
            title: suggestion.displayName.isEmpty
                ? suggestion.email
                : suggestion.displayName,
            subtitle: suggestion.displayName.isEmpty ? null : suggestion.email,
            leading: const Icon(Icons.person_outline),
            onTap: () => _addSuggestedGuest(suggestion),
          ),
      ]);
    }
    return rows;
  }

  List<Widget> _meetingRows(
    BusyProvider provider,
    CalendarSourceEntity source,
  ) {
    final rows = <Widget>[];
    final hasConference = _draft.conference != null;
    final canCreateConference = switch (provider) {
      BusyProvider.google => source.allowedConferenceSolutions.contains(
        'hangoutsMeet',
      ),
      BusyProvider.microsoft => source.allowedConferenceSolutions.contains(
        'teamsForBusiness',
      ),
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => false,
    };
    if (hasConference || canCreateConference) {
      rows.add(
        BusyMaxSwitchRow(
          title: provider == BusyProvider.google
              ? context.l10n.addGoogleMeet
              : context.l10n.addTeamsMeeting,
          subtitle: hasConference ? context.l10n.onlineMeetingAdded : null,
          leading: const Icon(Icons.video_call_outlined),
          value: hasConference || _draft.createConference,
          enabled: !hasConference,
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(createConference: value);
            });
          },
        ),
      );
    }
    if (provider == BusyProvider.microsoft) {
      rows.add(
        BusyMaxSwitchRow(
          title: context.l10n.requestResponses,
          subtitle: context.l10n.requestResponsesDescription,
          leading: const Icon(Icons.how_to_reg_outlined),
          value: _draft.responseRequested ?? true,
          onChanged: (value) => setState(() {
            _draft = _draft.copyWith(responseRequested: value);
          }),
        ),
      );
    }
    rows.add(
      BusyMaxSwitchRow(
        title: context.l10n.hideGuestList,
        subtitle: context.l10n.hideGuestListDescription,
        leading: const Icon(Icons.visibility_off_outlined),
        value: _draft.hideAttendees ?? false,
        onChanged: (value) => setState(() {
          _draft = _draft.copyWith(hideAttendees: value);
        }),
      ),
    );
    if (provider == BusyProvider.microsoft) {
      rows.add(
        BusyMaxSwitchRow(
          title: context.l10n.allowNewTimeProposals,
          subtitle: context.l10n.allowNewTimeProposalsDescription,
          leading: const Icon(Icons.more_time_outlined),
          value: _draft.allowNewTimeProposals ?? true,
          onChanged: (value) => setState(() {
            _draft = _draft.copyWith(allowNewTimeProposals: value);
          }),
        ),
      );
    }
    return rows;
  }

  Widget _importanceRow() {
    const values = ['low', 'normal', 'high'];
    final selected = values.contains(_draft.importance)
        ? _draft.importance!
        : 'normal';
    return BusyMaxComboRow<String>(
      title: context.l10n.importance,
      leading: const Icon(Icons.priority_high),
      values: values,
      selected: selected,
      labelFor: (value) => switch (value) {
        'low' => context.l10n.importanceLow,
        'high' => context.l10n.importanceHigh,
        _ => context.l10n.importanceNormal,
      },
      onSelected: (value) => setState(() {
        _draft = _draft.copyWith(importance: value);
      }),
    );
  }

  void _setAttendeeOptional(EventAttendeeDraft attendee, bool optional) {
    setState(() {
      _draft = _draft.copyWith(
        attendees: [
          for (final item in _draft.attendees)
            if (item == attendee) item.withOptional(optional) else item,
        ],
      );
    });
  }

  void _removeAttendee(EventAttendeeDraft attendee) {
    setState(() {
      _draft = _draft.copyWith(
        attendees: [
          for (final item in _draft.attendees)
            if (item != attendee) item,
        ],
      );
    });
  }

  List<Widget> _googleStatusRows() {
    final l10n = context.l10n;
    final type = _draft.eventType ?? 'default';
    final values = <String>['default', ...googleStatusEventTypes];
    final rows = <Widget>[
      BusyMaxComboRow<String>(
        title: l10n.googleEventType,
        leading: const Icon(Icons.event_note_outlined),
        values: values,
        selected: values.contains(type) ? type : 'default',
        labelFor: (value) => googleEventTypeLabel(l10n, value),
        enabled: _draft.eventId == null,
        onSelected: (value) => setState(() {
          final start = _draft.start;
          _draft = _draft.copyWith(
            eventType: value,
            googleStatusProperties: defaultGoogleStatusProperties(value),
            showAs: value == 'workingLocation' ? 'transparent' : 'opaque',
            visibilityOrSensitivity: value == 'workingLocation'
                ? 'public'
                : 'default',
            allDay: value == 'workingLocation' ? _draft.allDay : false,
            end: value == 'workingLocation' && _draft.allDay && start != null
                ? DateTime(start.year, start.month, start.day + 1)
                : _draft.end,
          );
        }),
      ),
    ];
    if (!googleStatusEventTypes.contains(type)) return rows;
    final properties = _draft.googleStatusProperties;
    if (type == 'focusTime' || type == 'outOfOffice') {
      const modes = [
        'declineNone',
        'declineOnlyNewConflictingInvitations',
        'declineAllConflictingInvitations',
      ];
      final mode = properties['autoDeclineMode']?.toString() ?? 'declineNone';
      rows.add(
        BusyMaxComboRow<String>(
          title: l10n.googleDeclineInvitations,
          values: modes,
          selected: modes.contains(mode) ? mode : modes.first,
          labelFor: (value) => googleAutoDeclineLabel(l10n, value),
          onSelected: (value) => setState(
            () => _draft = _draft.copyWith(
              googleStatusProperties: {...properties, 'autoDeclineMode': value},
            ),
          ),
        ),
      );
      if (type == 'focusTime') {
        rows.add(
          BusyMaxComboRow<String>(
            title: l10n.googleChatStatus,
            values: const ['available', 'doNotDisturb'],
            selected: properties['chatStatus'] == 'doNotDisturb'
                ? 'doNotDisturb'
                : 'available',
            labelFor: (value) => value == 'doNotDisturb'
                ? l10n.googleChatDoNotDisturb
                : l10n.googleChatAvailable,
            onSelected: (value) => setState(
              () => _draft = _draft.copyWith(
                googleStatusProperties: {...properties, 'chatStatus': value},
              ),
            ),
          ),
        );
      }
      rows.add(
        TextFormField(
          key: ValueKey('google-status-message-$type'),
          initialValue: properties['declineMessage']?.toString() ?? '',
          decoration: InputDecoration(labelText: l10n.googleDeclineMessage),
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              googleStatusProperties: {...properties, 'declineMessage': value},
            ),
          ),
        ),
      );
      return rows;
    }
    final locationType = properties['type']?.toString() ?? 'homeOffice';
    const locations = ['homeOffice', 'officeLocation', 'customLocation'];
    rows.add(
      BusyMaxComboRow<String>(
        title: l10n.googleWorkingLocation,
        values: locations,
        selected: locations.contains(locationType)
            ? locationType
            : locations.first,
        labelFor: (value) => googleWorkingLocationLabel(l10n, value),
        onSelected: (value) => setState(() {
          final next = {...properties}
            ..remove('homeOffice')
            ..remove('officeLocation')
            ..remove('customLocation');
          next['type'] = value;
          next[value] = value == 'homeOffice'
              ? <String, Object?>{}
              : (properties[value] is Map
                    ? Map<String, Object?>.from(properties[value] as Map)
                    : <String, Object?>{});
          _draft = _draft.copyWith(googleStatusProperties: next);
        }),
      ),
    );
    if (locationType != 'homeOffice') {
      final detail = properties[locationType] is Map
          ? Map<String, Object?>.from(properties[locationType] as Map)
          : <String, Object?>{};
      rows.add(
        TextFormField(
          key: ValueKey('google-status-location-$locationType'),
          initialValue: detail['label']?.toString() ?? '',
          decoration: InputDecoration(labelText: l10n.googleWorkLocationLabel),
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              googleStatusProperties: {
                ...properties,
                locationType: {...detail, 'label': value},
              },
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _categoriesRow() {
    final l10n = context.l10n;
    final isMicrosoft =
        _providerForDraft(_draft, widget.sources) == BusyProvider.microsoft;
    var hasProviderScope = false;
    if (isMicrosoft) {
      try {
        ProviderScope.containerOf(context, listen: false);
        hasProviderScope = true;
      } on StateError {
        // Optional account metadata is absent in standalone editor previews.
      }
    }
    final categoryLookup = isMicrosoft && hasProviderScope
        ? ref.watch(microsoftMasterCategoriesProvider(_draft.accountId))
        : null;
    final masterCategories = categoryLookup?.valueOrNull;
    return Column(
      children: [
        BusyMaxCategoryEditorRow(
          title: l10n.categories,
          addLabel: l10n.addCategory,
          categories: _draft.categories,
          suggestions:
              masterCategories
                  ?.map((category) => category.displayName)
                  .toList() ??
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
        ),
        if (masterCategories != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in masterCategories)
                BusyMaxPushButton.standard(
                  onPressed: () =>
                      _draft.categories.contains(category.displayName)
                      ? _removeCategory(category.displayName)
                      : _addCategory(category.displayName),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (microsoftCategorySwatchArgb(category.color)
                          case final color?) ...[
                        Container(width: 12, height: 12, color: Color(color)),
                        const SizedBox(width: 6),
                      ],
                      Text(category.displayName),
                      if (_draft.categories.contains(category.displayName)) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check, size: 16),
                      ],
                    ],
                  ),
                ),
            ],
          )
        else if (isMicrosoft && categoryLookup?.hasError == true)
          BusyMaxPushButton.standard(
            onPressed: () async {
              _consentCancellation?.cancel();
              final consent = AuthorizationCancellation();
              _consentCancellation = consent;
              try {
                try {
                  await ref
                      .read(microsoftCategoryAuthorizationProvider)
                      ?.authorizeCategoryAccess(
                        _draft.accountId,
                        cancellation: consent,
                      );
                  if (!mounted || consent.isCancelled) return;
                  if (mounted) {
                    ref.invalidate(
                      microsoftMasterCategoriesProvider(_draft.accountId),
                    );
                  }
                } on Object {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.outlookCategoriesUnavailable),
                      ),
                    );
                  }
                }
              } finally {
                consent.cancel();
                if (identical(_consentCancellation, consent)) {
                  _consentCancellation = null;
                }
              }
            },
            child: Text(l10n.loadOutlookCategories),
          ),
      ],
    );
  }

  Widget _googleLabelRow(CalendarSourceEntity source) {
    // The editor can also be embedded without an application scope (for
    // example, a standalone preview). Metadata is optional; editing the
    // event itself must remain available in that composition.
    try {
      ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return BusyMaxActionRow(
        title: context.l10n.eventLabel,
        subtitle: _draft.eventLabelId ?? context.l10n.noneValue,
      );
    }
    final labels = ref.watch(
      googleEventLabelsForCalendarProvider((
        accountId: source.accountId,
        calendarId: source.providerCalendarId,
      )),
    );
    final current = _draft.eventLabelId;
    return labels.when(
      loading: () => BusyMaxActionRow(
        title: context.l10n.eventLabel,
        subtitle: current ?? context.l10n.noneValue,
        onTap: null,
      ),
      error: (_, _) => BusyMaxActionRow(
        title: context.l10n.eventLabel,
        subtitle: current ?? context.l10n.noneValue,
        onTap: () => ref.invalidate(
          googleEventLabelsForCalendarProvider((
            accountId: source.accountId,
            calendarId: source.providerCalendarId,
          )),
        ),
      ),
      data: (available) {
        final byId = {for (final label in available) label.id: label};
        final values = <String>[
          '',
          ...byId.keys,
          if (current != null && !byId.containsKey(current)) current,
        ];
        return BusyMaxComboRow<String>(
          title: context.l10n.eventLabel,
          leading: Icon(
            Icons.label_outline,
            color: byId[current] == null
                ? null
                : Color(
                    0xff000000 |
                        int.parse(
                          byId[current]!.backgroundColor.substring(1),
                          radix: 16,
                        ),
                  ),
          ),
          values: values,
          selected: current ?? '',
          labelFor: (id) => id.isEmpty
              ? context.l10n.noneValue
              : byId[id]?.name ?? context.l10n.unknownEventLabel(id),
          onSelected: (id) => setState(() {
            _draft = id.isEmpty
                ? _draft.copyWith(clearEventLabelId: true)
                : _draft.copyWith(eventLabelId: id);
          }),
        );
      },
    );
  }

  Widget _availabilityRow(BusyProvider provider) {
    final statusType = provider == BusyProvider.google
        ? _draft.eventType
        : null;
    final values = statusType == 'workingLocation'
        ? const ['transparent']
        : statusType == 'focusTime' || statusType == 'outOfOffice'
        ? const ['opaque']
        : provider != BusyProvider.microsoft
        ? const ['opaque', 'transparent']
        : const ['free', 'tentative', 'busy', 'oof', 'workingElsewhere'];
    final selected = values.contains(_draft.showAs)
        ? _draft.showAs!
        : provider != BusyProvider.microsoft
        ? 'opaque'
        : 'busy';
    return BusyMaxComboRow<String>(
      title: context.l10n.availabilityShowAs,
      leading: const Icon(Icons.work_outline),
      values: values,
      selected: selected,
      labelFor: (value) => _availabilityLabel(context, value),
      enabled: values.length > 1,
      onSelected: (value) {
        setState(() {
          _draft = _draft.copyWith(showAs: value);
        });
      },
    );
  }

  Widget _visibilityRow(BusyProvider provider) {
    final values =
        provider == BusyProvider.google && _draft.eventType == 'workingLocation'
        ? const ['public']
        : provider != BusyProvider.microsoft
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
      enabled: values.length > 1,
      onSelected: (value) {
        setState(() {
          _draft = _draft.copyWith(visibilityOrSensitivity: value);
        });
      },
    );
  }

  void _addGuest() {
    _guestSuggestionGeneration++;
    _guestSuggestions = const [];
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

  Future<void> _loadGuestSuggestions(String query) async {
    final generation = ++_guestSuggestionGeneration;
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    if (query.trim().isEmpty) {
      setState(() => _guestSuggestions = const []);
      return;
    }
    try {
      _contactsChanges ??= ref
          .read(busyMaxContactsControllerProvider)
          .changes
          .listen((_) {
            _guestSuggestionGeneration++;
            if (mounted) setState(() => _guestSuggestions = const []);
          });
      final suggestions = await ref
          .read(busyMaxContactsControllerProvider)
          .suggestAttendees(
            query,
            busyMaxAccountId: accountId,
            excludedAddresses: {
              for (final attendee in _draft.attendees) attendee.email,
            },
          );
      if (!mounted ||
          generation != _guestSuggestionGeneration ||
          _draft.accountId != accountId ||
          _draft.sourceId != sourceId ||
          _guestController.text.trim() != query.trim()) {
        return;
      }
      setState(() => _guestSuggestions = suggestions);
    } on Object {
      // Manual attendee entry remains available when contacts are unavailable.
      if (!mounted ||
          generation != _guestSuggestionGeneration ||
          _draft.accountId != accountId ||
          _draft.sourceId != sourceId ||
          _guestController.text.trim() != query.trim()) {
        return;
      }
      setState(() => _guestSuggestions = const []);
    }
  }

  Future<void> _addSuggestedGuest(BusyMaxContactSuggestion suggestion) async {
    if (!_draft.canManageAttendees || !_guestSuggestions.contains(suggestion)) {
      return;
    }
    final generation = _guestSuggestionGeneration;
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    try {
      if (!await ref
          .read(busyMaxContactsControllerProvider)
          .suggestionEligible(suggestion, busyMaxAccountId: accountId)) {
        return;
      }
    } on Object {
      return;
    }
    if (!mounted ||
        generation != _guestSuggestionGeneration ||
        _draft.accountId != accountId ||
        _draft.sourceId != sourceId ||
        !_draft.canManageAttendees ||
        !_guestSuggestions.contains(suggestion)) {
      return;
    }
    _guestSuggestionGeneration++;
    final duplicate = _draft.attendees.any(
      (attendee) =>
          attendee.email.toLowerCase() == suggestion.email.toLowerCase(),
    );
    _guestController.clear();
    setState(() {
      _guestSuggestions = const [];
      _addingGuest = false;
      _guestError = null;
      if (!duplicate) {
        _draft = _draft.copyWith(
          attendees: [
            ..._draft.attendees,
            EventAttendeeDraft(
              email: suggestion.email,
              displayName: suggestion.displayName.isEmpty
                  ? null
                  : suggestion.displayName,
            ),
          ],
        );
      }
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

  void _setAllDay(bool allDay, BusyProvider provider) {
    final start = _draft.start;
    final end = _draft.end;
    final adjustedRecurrence = start == null
        ? null
        : _recurrenceForScheduleChange(
            provider,
            baseDate: start,
            allDay: allDay,
            timeZone: _draft.startTimeZone,
          );
    setState(() {
      _startTimeValid = true;
      _endTimeValid = true;
      _draft = _draft.copyWith(
        allDay: allDay,
        end: start != null && !_isValidEventEnd(start, end, allDay)
            ? _defaultEndFor(start, allDay)
            : end,
        recurrence: adjustedRecurrence,
      );
    });
  }

  bool get _hasUnsavedChanges {
    final hasInvalidVisibleTime =
        !_draft.allDay && (!_startTimeValid || !_endTimeValid);
    final contentDraft = _draft.copyWith(clearRecurringMutationScope: true);
    final initialContent = widget.initialDraft.copyWith(
      clearRecurringMutationScope: true,
    );
    return contentDraft != initialContent || hasInvalidVisibleTime;
  }

  void _setStart(DateTime start, BusyProvider provider) {
    final end = _draft.end;
    final adjustedRecurrence = _recurrenceForScheduleChange(
      provider,
      baseDate: start,
      allDay: _draft.allDay,
      timeZone: _draft.startTimeZone,
    );
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

  void _setStartTimeZone(String timeZone, BusyProvider provider) {
    final start = _draft.start;
    final adjustedRecurrence = start == null
        ? null
        : _recurrenceForScheduleChange(
            provider,
            baseDate: start,
            allDay: _draft.allDay,
            timeZone: timeZone,
          );
    setState(() {
      _draft = _draft.copyWith(
        startTimeZone: timeZone,
        recurrence: adjustedRecurrence,
      );
    });
  }

  Object? _recurrenceForScheduleChange(
    BusyProvider provider, {
    required DateTime baseDate,
    required bool allDay,
    required String? timeZone,
  }) {
    if (_draft.providerRecurringEventId != null || _draft.recurrence == null) {
      return null;
    }
    var rule = EventRecurrenceCodec.decode(
      provider,
      _draft.recurrence,
      baseDate: _draft.start,
    );
    if (!rule.isSupported || !rule.repeats) return null;
    final untilDate = rule.untilDateFor(timeZone: _draft.startTimeZone);
    if (untilDate != null) {
      rule = rule.withUntilDate(
        untilDate,
        allDay: allDay,
        floating: _isFloatingDavTime(
          provider,
          allDay: allDay,
          timeZone: timeZone,
        ),
        baseDate: baseDate,
        timeZone: timeZone,
      );
    }
    if (!EventRecurrenceCodec.canEncode(provider, rule)) return null;
    return EventRecurrenceCodec.encode(
      provider,
      rule,
      baseDate: baseDate,
      allDay: allDay,
      timeZone: timeZone,
      original: _draft.recurrence,
    );
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
  return Theme.of(context).textTheme.labelLarge
      ?.copyWith(color: color, fontWeight: fontWeight);
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
  final davMinutes = map['minutes'];
  if (davMinutes is List) {
    return _normalizedReminderMinutes(davMinutes.whereType<int>());
  }
  return const [];
}

Object? _remindersFor(BusyProvider provider, List<int> minutes) {
  final normalized = _normalizedReminderMinutes(minutes);
  if (normalized.isEmpty) {
    return null;
  }
  if (provider != BusyProvider.microsoft) {
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
  if (provider != BusyProvider.microsoft) {
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

bool _isFloatingDavTime(
  BusyProvider provider, {
  required bool allDay,
  required String? timeZone,
}) {
  return !allDay &&
      (timeZone?.trim().isEmpty ?? true) &&
      (provider == BusyProvider.appleICloud ||
          provider == BusyProvider.nextcloud);
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
