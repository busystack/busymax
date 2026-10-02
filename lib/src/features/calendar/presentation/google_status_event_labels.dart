import '../../../../l10n/generated/app_localizations.dart';

String googleEventTypeLabel(AppLocalizations l10n, String? type) =>
    switch (type) {
      'focusTime' => l10n.googleFocusTime,
      'outOfOffice' => l10n.googleOutOfOffice,
      'workingLocation' => l10n.googleWorkingLocation,
      _ => l10n.googleRegularEvent,
    };

String googleAutoDeclineLabel(AppLocalizations l10n, String mode) =>
    switch (mode) {
      'declineAllConflictingInvitations' => l10n.googleDeclineAll,
      'declineOnlyNewConflictingInvitations' => l10n.googleDeclineNew,
      _ => l10n.googleDeclineNone,
    };

String googleWorkingLocationLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'officeLocation' => l10n.googleWorkAtOffice,
      'customLocation' => l10n.googleWorkAtCustomLocation,
      _ => l10n.googleWorkAtHome,
    };

List<String> googleStatusDetailLines(
  AppLocalizations l10n,
  String? eventType,
  Map<String, Object?> properties,
) {
  if (eventType != 'focusTime' &&
      eventType != 'outOfOffice' &&
      eventType != 'workingLocation') {
    return const [];
  }
  final lines = <String>[googleEventTypeLabel(l10n, eventType)];
  if (eventType == 'workingLocation') {
    final type = properties['type']?.toString() ?? 'homeOffice';
    final detail = properties[type];
    final label = detail is Map ? detail['label']?.toString() : null;
    lines.add(
      label == null || label.trim().isEmpty
          ? googleWorkingLocationLabel(l10n, type)
          : '${googleWorkingLocationLabel(l10n, type)} · $label',
    );
  } else {
    if (properties['autoDeclineMode'] case final mode? when mode is String) {
      lines.add(
        '${l10n.googleDeclineInvitations}: '
        '${googleAutoDeclineLabel(l10n, mode)}',
      );
    }
    final chat = properties['chatStatus'];
    if (eventType == 'focusTime' && chat is String) {
      lines.add(
        '${l10n.googleChatStatus}: '
        '${chat == 'doNotDisturb' ? l10n.googleChatDoNotDisturb : l10n.googleChatAvailable}',
      );
    }
    if (properties['declineMessage'] case final message?
        when message is String && message.trim().isNotEmpty) {
      lines.add('${l10n.googleDeclineMessage}: $message');
    }
  }
  return lines;
}
