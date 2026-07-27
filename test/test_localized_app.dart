import 'package:flutter/material.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';

Widget localizedTestApp({
  required Widget child,
  Locale locale = const Locale('en'),
  bool? alwaysUse24HourFormat,
  TextScaler? textScaler,
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
    builder: alwaysUse24HourFormat == null && textScaler == null
        ? null
        : (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final data = mediaQuery.copyWith(
              alwaysUse24HourFormat:
                  alwaysUse24HourFormat ?? mediaQuery.alwaysUse24HourFormat,
              textScaler: textScaler ?? mediaQuery.textScaler,
            );
            return MediaQuery(data: data, child: child ?? const SizedBox());
          },
    home: child,
  );
}
