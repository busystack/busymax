import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

Stream<Object?> systemAccentChangeEvents() {
  if (defaultTargetPlatform != TargetPlatform.linux) {
    return const Stream<Object?>.empty();
  }
  return _gnomeAccentChangeEvents();
}

Stream<Object?> _gnomeAccentChangeEvents() async* {
  Process? process;
  try {
    process = await Process.start('gsettings', const [
      'monitor',
      'org.gnome.desktop.interface',
      'accent-color',
    ]);
  } on Object {
    return;
  }

  unawaited(process.stderr.drain<void>());
  try {
    await for (final _
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      yield Object();
    }
  } finally {
    process.kill();
  }
}
