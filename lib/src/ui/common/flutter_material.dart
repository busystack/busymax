import 'package:flutter_localizations/flutter_localizations.dart';

// Yaru and the calendar package use the SDK Material types in their APIs.
// Keep their widgets, theme data and localization delegates on the same types.
// ignore: deprecated_member_use
export 'package:flutter/material.dart';

const flutterMaterialLocalizationsDelegate =
    // ignore: deprecated_member_use
    GlobalMaterialLocalizations.delegate;

const flutterCupertinoLocalizationsDelegate =
    // ignore: deprecated_member_use
    GlobalCupertinoLocalizations.delegate;
