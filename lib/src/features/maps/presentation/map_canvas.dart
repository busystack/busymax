import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/map_tile_service.dart';
import '../domain/geographic_point.dart';

final class BusyMaxMapController {
  VoidCallback? _zoomIn;
  VoidCallback? _zoomOut;
  VoidCallback? _recenter;

  void zoomIn() => _zoomIn?.call();
  void zoomOut() => _zoomOut?.call();
  void recenter() => _recenter?.call();
}

/// Shared Linux/Windows map canvas. Platform compositions own all surrounding
/// dialog chrome, controls and feedback.
class BusyMaxMapCanvas extends StatefulWidget {
  const BusyMaxMapCanvas({
    super.key,
    required this.point,
    required this.destinationLabel,
    required this.apiKey,
    required this.cache,
    required this.canUseNetwork,
    required this.controller,
    required this.onTileFailure,
    required this.onOpenAttribution,
    required this.brightness,
    required this.markerColor,
  });

  final GeographicPoint point;
  final String destinationLabel;
  final String apiKey;
  final MapCachingProvider cache;
  final Future<bool> Function() canUseNetwork;
  final BusyMaxMapController controller;
  final VoidCallback onTileFailure;
  final Future<void> Function(Uri uri) onOpenAttribution;
  final Brightness brightness;
  final Color markerColor;

  @override
  State<BusyMaxMapCanvas> createState() => _BusyMaxMapCanvasState();
}

class _BusyMaxMapCanvasState extends State<BusyMaxMapCanvas> {
  static const _initialZoom = 15.0;
  late final MapController _mapController;
  late final BusyMaxMapTileProvider _tileProvider;

  LatLng get _destination =>
      LatLng(widget.point.latitude, widget.point.longitude);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tileProvider = BusyMaxMapTileProvider(
      client: MapTileClient(
        http.Client(),
        canUseNetwork: widget.canUseNetwork,
        onFailure: widget.onTileFailure,
      ),
      cache: widget.cache,
    );
    widget.controller._zoomIn = () => _changeZoom(1);
    widget.controller._zoomOut = () => _changeZoom(-1);
    widget.controller._recenter = () =>
        _mapController.move(_destination, _initialZoom);
  }

  void _changeZoom(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(1, 20));
  }

  @override
  void dispose() {
    widget.controller
      .._zoomIn = null
      .._zoomOut = null
      .._recenter = null;
    unawaited(_tileProvider.dispose());
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.brightness == Brightness.dark;
    final style = dark ? 'dark-matter' : 'osm-bright';
    return Semantics(
      label: widget.destinationLabel,
      image: true,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _destination,
          initialZoom: _initialZoom,
          minZoom: 1,
          maxZoom: 20,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://maps.geoapify.com/v1/tile/$style/{z}/{x}/{y}{r}.png?apiKey={apiKey}',
            additionalOptions: {'apiKey': widget.apiKey},
            tileProvider: _tileProvider,
            maxNativeZoom: 20,
            retinaMode: RetinaMode.isHighDensity(context),
            userAgentPackageName: 'org.busystack.busymax',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _destination,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: Semantics(
                  label: widget.destinationLabel,
                  child: Icon(
                    Icons.location_pin,
                    size: 44,
                    color: widget.markerColor,
                  ),
                ),
              ),
            ],
          ),
          RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution(
                'Geoapify',
                prependCopyright: false,
                onTap: () => unawaited(
                  widget.onOpenAttribution(
                    Uri.parse('https://www.geoapify.com/'),
                  ),
                ),
              ),
              TextSourceAttribution(
                'OpenMapTiles',
                onTap: () => unawaited(
                  widget.onOpenAttribution(
                    Uri.parse('https://openmaptiles.org/'),
                  ),
                ),
              ),
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => unawaited(
                  widget.onOpenAttribution(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
