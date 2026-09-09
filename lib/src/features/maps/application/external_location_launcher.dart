import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/geographic_point.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

const _linuxExternalUriChannel = MethodChannel(
  'io.busystack.busymax/external_uri_launcher',
);

Future<bool> _launchLinuxExternalUri(
  Uri uri, {
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  if (mode != LaunchMode.externalApplication) return false;
  return await _linuxExternalUriChannel.invokeMethod<bool>(
        'launch',
        uri.toString(),
      ) ??
      false;
}

enum ExternalLocationPlatform { linux, windows }

enum ExternalLocationLaunchResult {
  opened,
  noDestination,
  browserUrlTooLong,
  failed,
}

enum ExternalLocationDestinationKind { link, coordinates, text }

final class ExternalLocationDestination {
  const ExternalLocationDestination._({
    required this.kind,
    this.link,
    this.point,
    this.text,
  });

  const ExternalLocationDestination.link(Uri link)
    : this._(kind: ExternalLocationDestinationKind.link, link: link);

  const ExternalLocationDestination.coordinates(GeographicPoint point)
    : this._(kind: ExternalLocationDestinationKind.coordinates, point: point);

  const ExternalLocationDestination.text(String text)
    : this._(kind: ExternalLocationDestinationKind.text, text: text);

  final ExternalLocationDestinationKind kind;
  final Uri? link;
  final GeographicPoint? point;
  final String? text;

  String get searchQuery => switch (kind) {
    ExternalLocationDestinationKind.coordinates => point!.directionsValue,
    ExternalLocationDestinationKind.text => text!,
    ExternalLocationDestinationKind.link => throw StateError(
      'A direct link is not a map-search query.',
    ),
  };
}

final class ExternalLocationLauncher {
  const ExternalLocationLauncher({
    this.launcher = launchUrl,
    this.linuxLauncher = _launchLinuxExternalUri,
    this.platform = currentExternalLocationPlatform,
  });

  static const googleMapsUrlLimit = 2048;

  final ExternalUriLauncher launcher;
  final ExternalUriLauncher linuxLauncher;
  final ExternalLocationPlatform Function() platform;

  Future<ExternalLocationLaunchResult> open(
    ExternalLocationDestination? destination,
  ) async {
    if (destination == null) {
      return ExternalLocationLaunchResult.noDestination;
    }
    if (destination.kind == ExternalLocationDestinationKind.link) {
      final link = destination.link!;
      if (completeHttpLocationUri(link.toString()) == null) {
        return ExternalLocationLaunchResult.noDestination;
      }
      return await _launch(
            link,
            useLinuxLauncher: platform() == ExternalLocationPlatform.linux,
          )
          ? ExternalLocationLaunchResult.opened
          : ExternalLocationLaunchResult.failed;
    }

    final currentPlatform = platform();
    if (currentPlatform == ExternalLocationPlatform.linux) {
      final nativeUri = linuxLocationUri(destination);
      if (await _launch(nativeUri, useLinuxLauncher: true)) {
        return ExternalLocationLaunchResult.opened;
      }
    }

    final browserUri = googleMapsSearchUri(destination.searchQuery);
    if (browserUri.toString().length > googleMapsUrlLimit) {
      return ExternalLocationLaunchResult.browserUrlTooLong;
    }
    return await _launch(
          browserUri,
          useLinuxLauncher: currentPlatform == ExternalLocationPlatform.linux,
        )
        ? ExternalLocationLaunchResult.opened
        : ExternalLocationLaunchResult.failed;
  }

  Future<bool> _launch(Uri uri, {required bool useLinuxLauncher}) async {
    try {
      return await (useLinuxLauncher ? linuxLauncher : launcher)(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}

ExternalLocationPlatform currentExternalLocationPlatform() => Platform.isLinux
    ? ExternalLocationPlatform.linux
    : ExternalLocationPlatform.windows;

Uri linuxLocationUri(ExternalLocationDestination destination) {
  return switch (destination.kind) {
    ExternalLocationDestinationKind.coordinates => Uri(
      scheme: 'geo',
      path: destination.point!.directionsValue,
    ),
    ExternalLocationDestinationKind.text => Uri.parse(
      'maps:q=${Uri.encodeComponent(destination.text!)}',
    ),
    ExternalLocationDestinationKind.link => throw ArgumentError.value(
      destination,
      'destination',
      'Direct links do not have a generated native maps URI.',
    ),
  };
}

Uri googleMapsSearchUri(String query) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});

Uri? completeHttpLocationUri(String location) {
  final value = location.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}
