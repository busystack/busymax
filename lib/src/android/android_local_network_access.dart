import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:busystack_dav/busystack_dav.dart' as dav;

import '../l10n/l10n.dart';

bool isAndroidLocalNetworkHost(String host) {
  var value = host.trim().toLowerCase();
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }
  value = value.split('%').first;
  if (value.isEmpty) return false;
  if (value == 'localhost') return false;
  if (value.endsWith('.local') ||
      value.endsWith('.lan') ||
      value.endsWith('.home') ||
      value.endsWith('.internal')) {
    return true;
  }
  final address = InternetAddress.tryParse(value);
  if (address == null) return !value.contains('.');
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
        (bytes[0] >= 224 && bytes[0] <= 239) ||
        value == '255.255.255.255' ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31);
  }
  final loopback = bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1;
  final uniqueLocal = (bytes[0] & 0xfe) == 0xfc;
  final linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
  return !loopback && (uniqueLocal || linkLocal || bytes[0] == 0xff);
}

typedef AndroidHostLookup = Future<List<InternetAddress>> Function(String host);

/// Resolves ordinary DNS names before deciding whether Android's contextual
/// local-network permission is required. DNS failure is left to onboarding so
/// it can surface the real connectivity error without an irrelevant prompt.
Future<bool> requiresAndroidLocalNetworkAccess(
  String host, {
  AndroidHostLookup lookup = InternetAddress.lookup,
  Future<bool?> Function(String)? routeCheck,
}) async {
  if (routeCheck != null) {
    try {
      if (await routeCheck(host) case final known?) return known;
    } on PlatformException {
      /* Retain the documented conservative fallback. */
    } on MissingPluginException {
      /* Tests and unavailable bridge. */
    }
  }
  if (isAndroidLocalNetworkHost(host)) return true;
  var value = host.trim();
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }
  if (value.isEmpty || InternetAddress.tryParse(value) != null) return false;
  try {
    final addresses = await lookup(value);
    return addresses.any(
      (address) => isAndroidLocalNetworkHost(address.address),
    );
  } on Object {
    return false;
  }
}

Future<bool> androidServerRequiresLocalNetworkAccess(Uri server) =>
    requiresAndroidLocalNetworkAccess(
      server.host,
      routeCheck: BusyMaxAndroidPlatform.instance.requiresLocalNetworkAccess,
    );

/// Called by transports, including headless engines. Never opens permission UI.
Future<void> requireAndroidContactsServerAccess(Uri server) async {
  if (await androidServerRequiresLocalNetworkAccess(server) &&
      !await BusyMaxAndroidPlatform.instance.hasLocalNetworkAccess()) {
    throw const AndroidContactsLocalNetworkPermissionException();
  }
}

Future<bool> ensureAndroidLocalNetworkAccess(
  BuildContext context,
  String server, {
  bool review = false,
}) async {
  final uri = Uri.tryParse(server);
  if (!review &&
      (uri == null || !await androidServerRequiresLocalNetworkAccess(uri))) {
    return true;
  }
  final platform = BusyMaxAndroidPlatform.instance;
  try {
    if (await platform.hasLocalNetworkAccess()) return true;
    if (!context.mounted) return false;
    if (await platform.requestLocalNetworkAccess()) return true;
  } on PlatformException {
    /* Show the established app-settings recovery action. */
  }
  if (!context.mounted) return false;
  final settings = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(context.l10n.localNetworkAccessRequired),
      content: Text(context.l10n.localNetworkAccessRecovery),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(context.l10n.settings),
        ),
      ],
    ),
  );
  if (settings == true) await platform.openAppSettings();
  return false;
}

final class AndroidContactsLocalNetworkPermissionException
    extends dav.DavException
    implements dav.DavRequestNotDispatchedException {
  const AndroidContactsLocalNetworkPermissionException()
    : super(
        kind: dav.DavErrorKind.authorization,
        code: 'android-local-network-required',
        safeMessage:
            'Allow local network access in Android settings, then retry.',
      );
}
