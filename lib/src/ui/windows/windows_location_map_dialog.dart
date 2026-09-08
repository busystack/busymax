import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/maps/application/directions_launcher.dart';
import '../../features/maps/application/location_destination_resolver.dart';
import '../../features/maps/application/location_map_controller.dart';
import '../../features/maps/data/geoapify_client.dart';
import '../../features/maps/domain/geographic_point.dart';
import '../../features/maps/domain/location_result.dart';
import '../../features/maps/presentation/map_canvas.dart';

Future<void> showWindowsLocationMapDialog(
  BuildContext context,
  WidgetRef ref, {
  required String location,
  required LocationChange locationChange,
  GeographicPoint? nativePoint,
  LocationItemIdentity? identity,
  Future<void> Function(LocationResult result)? onSelection,
}) async {
  final cache = await ref.read(mapTileCacheProvider.future);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WindowsLocationMapDialog(
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

class _WindowsLocationMapDialog extends StatefulWidget {
  const _WindowsLocationMapDialog({
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
  State<_WindowsLocationMapDialog> createState() =>
      _WindowsLocationMapDialogState();
}

class _WindowsLocationMapDialogState extends State<_WindowsLocationMapDialog> {
  late final LocationMapController _locationController;
  final _mapController = BusyMaxMapController();
  var _browserFailed = false;
  var _rememberFailed = false;

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
      if (mounted) setState(() => _rememberFailed = true);
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
    if (!opened && mounted) setState(() => _browserFailed = true);
  }

  Future<void> _openAttribution(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (!opened && mounted) setState(() => _browserFailed = true);
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
    final l10n = AppLocalizations.of(context);
    final theme = FluentTheme.of(context);
    final destination = _locationController.destination;
    final canDirections =
        destination != null || widget.location.trim().isNotEmpty;
    return ContentDialog(
      title: Text(l10n.mapsShow),
      constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
      content: SizedBox(
        width: 720,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              '${l10n.mapsDestination}: '
              '${widget.location.trim().isEmpty ? destination?.label ?? '—' : widget.location}',
            ),
            if (destination != null &&
                widget.location.trim().isNotEmpty &&
                destination.label != widget.location.trim())
              SelectableText(destination.label),
            const SizedBox(height: 8),
            Expanded(
              child: _locationController.choices.isNotEmpty
                  ? ListView(
                      children: [
                        for (final choice in _locationController.choices)
                          ListTile.selectable(
                            title: Text(choice.label),
                            subtitle: choice.approximate
                                ? Text(l10n.mapsApproximate)
                                : null,
                            leading: const Icon(FluentIcons.map_pin),
                            onPressed: () => unawaited(_choose(choice)),
                          ),
                      ],
                    )
                  : destination != null && widget.client.configured
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: BusyMaxMapCanvas(
                            point: destination.point,
                            destinationLabel: destination.label,
                            apiKey: widget.client.apiKey,
                            cache: widget.cache,
                            canUseNetwork: widget.canUseNetwork,
                            controller: _mapController,
                            onTileFailure:
                                _locationController.reportTileFailure,
                            onOpenAttribution: _openAttribution,
                            brightness: theme.brightness,
                            markerColor: theme.accentColor,
                          ),
                        ),
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: Acrylic(
                            child: Column(
                              children: [
                                Tooltip(
                                  message: l10n.mapsZoomIn,
                                  child: IconButton(
                                    icon: const Icon(FluentIcons.add),
                                    onPressed: _mapController.zoomIn,
                                  ),
                                ),
                                Tooltip(
                                  message: l10n.mapsZoomOut,
                                  child: IconButton(
                                    icon: const Icon(FluentIcons.remove),
                                    onPressed: _mapController.zoomOut,
                                  ),
                                ),
                                Tooltip(
                                  message: l10n.mapsRecenter,
                                  child: IconButton(
                                    icon: const Icon(
                                      FluentIcons.location_circle,
                                    ),
                                    onPressed: _mapController.recenter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        _statusText(l10n, _locationController.status),
                      ),
                    ),
            ),
            if (_locationController.tileFailure)
              InfoBar(
                title: Text(l10n.mapsTilesFailed),
                severity: InfoBarSeverity.warning,
              ),
            if (_browserFailed)
              InfoBar(
                title: Text(l10n.mapsBrowserFailed),
                severity: InfoBarSeverity.error,
              ),
            if (_rememberFailed)
              InfoBar(
                title: Text(l10n.mapsRememberFailed),
                severity: InfoBarSeverity.error,
              ),
            const SizedBox(height: 8),
            Text(l10n.mapsPrivacy, style: theme.typography.caption),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: canDirections ? () => unawaited(_directions()) : null,
          child: Text(l10n.mapsDirections),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

String _statusText(AppLocalizations l10n, LocationLookupStatus status) =>
    switch (status) {
      LocationLookupStatus.loading => l10n.mapsLoading,
      LocationLookupStatus.empty => l10n.mapsEmpty,
      LocationLookupStatus.offline => l10n.mapsOffline,
      LocationLookupStatus.unconfigured => l10n.mapsUnconfigured,
      LocationLookupStatus.rateLimited => l10n.mapsRateLimited,
      LocationLookupStatus.failed => l10n.mapsServiceError,
      LocationLookupStatus.idle ||
      LocationLookupStatus.results => l10n.mapsServiceError,
    };
