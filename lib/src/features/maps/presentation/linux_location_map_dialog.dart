import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../application/directions_launcher.dart';
import '../application/location_destination_resolver.dart';
import '../application/location_map_controller.dart';
import '../data/geoapify_client.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';
import 'map_canvas.dart';

Future<void> showLinuxLocationMapDialog(
  BuildContext context,
  WidgetRef ref, {
  required String location,
  required LocationChange locationChange,
  GeographicPoint? nativePoint,
  LocationItemIdentity? identity,
  Future<void> Function(LocationResult result)? onSelection,
  LinuxHeaderBarService? headerBarService,
}) async {
  final cache = await ref.read(mapTileCacheProvider.future);
  if (!context.mounted) return;
  await showBusyMaxModalDialog<void>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (_) => _LinuxLocationMapDialog(
      client: ref.read(geoapifyClientProvider),
      cache: cache,
      canUseNetwork: ref.read(networkConnectivityMonitorProvider).canUseNetwork,
      resolver: LocationDestinationResolver(
        ref.read(locationResolutionRepositoryProvider),
      ),
      location: location,
      locationChange: locationChange,
      nativePoint: nativePoint,
      identity: identity,
      language: Localizations.localeOf(context).toLanguageTag(),
      onSelection: onSelection,
    ),
  );
}

class _LinuxLocationMapDialog extends StatefulWidget {
  const _LinuxLocationMapDialog({
    required this.client,
    required this.cache,
    required this.canUseNetwork,
    required this.resolver,
    required this.location,
    required this.locationChange,
    required this.nativePoint,
    required this.identity,
    required this.language,
    required this.onSelection,
  });

  final GeoapifyClient client;
  final MapCachingProvider cache;
  final Future<bool> Function() canUseNetwork;
  final LocationDestinationResolver resolver;
  final String location;
  final LocationChange locationChange;
  final GeographicPoint? nativePoint;
  final LocationItemIdentity? identity;
  final String language;
  final Future<void> Function(LocationResult result)? onSelection;

  @override
  State<_LinuxLocationMapDialog> createState() =>
      _LinuxLocationMapDialogState();
}

class _LinuxLocationMapDialogState extends State<_LinuxLocationMapDialog> {
  late final LocationMapController _locationController;
  final _mapController = BusyMaxMapController();

  @override
  void initState() {
    super.initState();
    _locationController = LocationMapController(
      client: widget.client,
      resolver: widget.resolver,
      location: widget.location,
      locationChange: widget.locationChange,
      nativePoint: widget.nativePoint,
      identity: widget.identity,
      language: widget.language,
    )..addListener(_changed);
    unawaited(_locationController.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _choose(LocationResult result) async {
    _locationController.choose(result);
    try {
      await widget.onSelection?.call(result);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.mapsRememberFailed)));
    }
  }

  Future<void> _directions() async {
    final destination = _locationController.destination;
    final opened = await launchGoogleMapsDirections(
      location: widget.location.isNotEmpty
          ? widget.location
          : destination?.label ?? '',
      point: destination?.point,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.mapsBrowserFailed)));
    }
  }

  Future<void> _openAttribution(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.mapsBrowserFailed)));
    }
  }

  @override
  void dispose() {
    _locationController
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destination = _locationController.destination;
    final canDirections =
        destination != null || widget.location.trim().isNotEmpty;
    return BusyMaxDialogShell(
      title: l10n.mapsShow,
      maxWidth: 780,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: canDirections ? () => unawaited(_directions()) : null,
          child: Text(l10n.mapsDirections),
        ),
        BusyMaxPushButton.suggested(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
      children: [
        Text(
          '${l10n.mapsDestination}: '
          '${widget.location.trim().isEmpty ? destination?.label ?? '—' : widget.location}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (destination != null &&
            widget.location.trim().isNotEmpty &&
            destination.label != widget.location.trim()) ...[
          const SizedBox(height: BusyMaxSpacing.xs),
          SelectableText(destination.label),
        ],
        const SizedBox(height: BusyMaxSpacing.sm),
        if (_locationController.choices.isNotEmpty)
          BusyMaxGroupedList(
            filled: true,
            children: [
              for (final choice in _locationController.choices)
                BusyMaxActionRow(
                  title: choice.label,
                  subtitle: choice.approximate ? l10n.mapsApproximate : null,
                  leading: const Icon(Icons.place_outlined),
                  onTap: () => unawaited(_choose(choice)),
                ),
            ],
          )
        else if (destination != null && widget.client.configured)
          SizedBox(
            height: 440,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BusyMaxMapCanvas(
                    point: destination.point,
                    destinationLabel: destination.label,
                    apiKey: widget.client.apiKey,
                    cache: widget.cache,
                    canUseNetwork: widget.canUseNetwork,
                    controller: _mapController,
                    onTileFailure: _locationController.reportTileFailure,
                    onOpenAttribution: _openAttribution,
                    brightness: Theme.of(context).brightness,
                    markerColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                PositionedDirectional(
                  top: BusyMaxSpacing.sm,
                  end: BusyMaxSpacing.sm,
                  child: Card(
                    child: Column(
                      children: [
                        YaruIconButton(
                          tooltip: l10n.mapsZoomIn,
                          onPressed: _mapController.zoomIn,
                          icon: const Icon(YaruIcons.plus),
                        ),
                        YaruIconButton(
                          tooltip: l10n.mapsZoomOut,
                          onPressed: _mapController.zoomOut,
                          icon: const Icon(YaruIcons.minus),
                        ),
                        YaruIconButton(
                          tooltip: l10n.mapsRecenter,
                          onPressed: _mapController.recenter,
                          icon: const Icon(Icons.my_location_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.lg),
            child: Text(_statusText(context, _locationController.status)),
          ),
        if (_locationController.tileFailure) ...[
          const SizedBox(height: BusyMaxSpacing.sm),
          Text(l10n.mapsTilesFailed),
        ],
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(l10n.mapsPrivacy, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _statusText(BuildContext context, LocationLookupStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    LocationLookupStatus.loading => l10n.mapsLoading,
    LocationLookupStatus.empty => l10n.mapsEmpty,
    LocationLookupStatus.offline => l10n.mapsOffline,
    LocationLookupStatus.unconfigured => l10n.mapsUnconfigured,
    LocationLookupStatus.rateLimited => l10n.mapsRateLimited,
    LocationLookupStatus.failed => l10n.mapsServiceError,
    LocationLookupStatus.idle ||
    LocationLookupStatus.results => l10n.mapsServiceError,
  };
}
