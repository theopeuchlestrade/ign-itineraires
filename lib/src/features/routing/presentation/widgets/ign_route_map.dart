import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/adaptive_map_interaction.dart';
import 'package:ign_itineraires/src/network_endpoints.dart';
import 'package:latlong2/latlong.dart';

const ignPlanWmtsUrl =
    'https://${NetworkEndpoints.geoplateformeHost}/wmts'
    '?SERVICE=WMTS'
    '&VERSION=1.0.0'
    '&REQUEST=GetTile'
    '&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2'
    '&STYLE=normal'
    '&FORMAT=image/png'
    '&TILEMATRIXSET=PM'
    '&TILEMATRIX={z}'
    '&TILEROW={y}'
    '&TILECOL={x}';

class IgnRouteMap extends StatefulWidget {
  const IgnRouteMap({
    super.key,
    required this.start,
    required this.destination,
    required this.route,
    this.tileProvider,
    this.mapControllerFactory,
  });

  final Place? start;
  final Place? destination;
  final RoutePlan? route;
  final TileProvider? tileProvider;
  @visibleForTesting
  final MapController Function()? mapControllerFactory;

  @override
  State<IgnRouteMap> createState() => _IgnRouteMapState();
}

class _IgnRouteMapState extends State<IgnRouteMap> {
  static const _paris = LatLng(46.603354, 1.888334);

  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapControllerFactory?.call() ?? MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IgnRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = widget.route != oldWidget.route;
    final pointsChanged =
        widget.start != oldWidget.start ||
        widget.destination != oldWidget.destination;
    if (routeChanged || pointsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitContent());
    }
  }

  void _fitContent() {
    if (!mounted) return;
    final points = widget.route?.points.isNotEmpty == true
        ? widget.route!.points
        : [
            if (widget.start != null) widget.start!.point,
            if (widget.destination != null) widget.destination!.point,
          ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveMapInteraction(
      controller: _mapController,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _paris,
          initialZoom: 5.5,
          minZoom: 3,
          maxZoom: 19,
          interactionOptions: routeMapInteractionOptions(),
        ),
        children: [
          TileLayer(
            urlTemplate: ignPlanWmtsUrl,
            userAgentPackageName: 'fr.ign.itineraires',
            maxNativeZoom: 19,
            tileProvider: widget.tileProvider,
          ),
          if (widget.route != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route!.points,
                  color: colorScheme.primary,
                  strokeWidth: 6,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (widget.start != null)
                Marker(
                  point: widget.start!.point,
                  width: 48,
                  height: 48,
                  child: _MapMarker(
                    color: colorScheme.primary,
                    icon: Icons.trip_origin,
                    tooltip: 'Départ',
                  ),
                ),
              if (widget.destination != null)
                Marker(
                  point: widget.destination!.point,
                  width: 48,
                  height: 48,
                  child: _MapMarker(
                    color: colorScheme.tertiary,
                    icon: Icons.flag,
                    tooltip: 'Arrivée',
                  ),
                ),
            ],
          ),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              const TextSourceAttribution('© IGN – cartes.gouv.fr'),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 28,
            child: FloatingActionButton.small(
              heroTag: 'fit-map',
              tooltip: 'Recentrer la carte',
              onPressed: _fitContent,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
