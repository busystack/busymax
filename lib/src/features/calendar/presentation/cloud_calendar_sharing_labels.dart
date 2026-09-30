import 'package:busymax/l10n/generated/app_localizations.dart';

String calendarSharingRoleLabel(AppLocalizations l10n, String role) =>
    switch (role) {
      'freeBusyReader' || 'freeBusyRead' => l10n.calendarShareFreeBusy,
      'limitedRead' => l10n.calendarShareLimitedRead,
      'reader' || 'read' => l10n.calendarShareRead,
      'writer' || 'write' => l10n.calendarShareWrite,
      'writerWithoutPrivateAccess' => l10n.calendarShareWriteWithoutPrivate,
      'owner' => l10n.calendarShareOwner,
      _ => role,
    };
