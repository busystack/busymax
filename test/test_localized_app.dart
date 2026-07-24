import 'package:flutter/material.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';

Widget localizedTestApp({
  required Widget child,
  Locale locale = const Locale('en'),
  bool? alwaysUse24HourFormat,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      ...GlobalUbuntuLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: alwaysUse24HourFormat == null
        ? null
        : (context, child) {
            final data = MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat);
            return MediaQuery(data: data, child: child ?? const SizedBox());
          },
    home: child,
  );
}
