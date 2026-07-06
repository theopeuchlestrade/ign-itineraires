import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/app_dependencies.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_controller.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/adaptive_map_interaction.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/ign_route_map.dart';
import 'package:ign_itineraires/src/theme/company_theme.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.destination,
    required this.mode,
    required this.dependencies,
  });

  final Place destination;
  final TravelMode mode;
  final AppDependencies dependencies;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

@visibleForTesting
Widget buildLiveNavigationMapForTest(
  NavigationSession session, {
  TileProvider? tileProvider,
}) {
  return _LiveNavigationMap(
    session: session,
    onFollowingChanged: (_) {},
    tileProvider: tileProvider,
  );
}

class _NavigationPageState extends State<NavigationPage>
    with WidgetsBindingObserver {
  late final NavigationController _controller;
  ExternalNavigationGateway get _launcher =>
      widget.dependencies.externalNavigation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = NavigationController(
      widget.dependencies.geoplateforme,
      widget.dependencies.location,
      widget.dependencies.store,
      widget.dependencies.speech,
      widget.dependencies.wakeLock,
      destination: widget.destination,
      mode: widget.mode,
    );
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final session = _controller.session;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Arrêter le guidage',
              onPressed: _confirmStop,
              icon: const Icon(Icons.close),
            ),
            title: Row(
              children: [
                const CompanyLogoMark(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.status == NavigationStatus.rerouting
                        ? 'Recalcul en cours…'
                        : 'Guidage ${widget.mode.label.toLowerCase()}',
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: session.voiceEnabled
                    ? 'Couper les instructions vocales'
                    : 'Activer les instructions vocales',
                onPressed: _controller.toggleVoice,
                icon: Icon(
                  session.voiceEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _buildBody(session),
        );
      },
    );
  }

  Widget _buildBody(NavigationSession session) {
    if (session.status == NavigationStatus.error) {
      return _NavigationFailure(
        message: session.message ?? 'Le guidage n’a pas pu démarrer.',
        onClose: () => Navigator.pop(context),
        onExternal: session.position == null ? null : _openExternal,
      );
    }
    if (session.route == null || session.position == null) {
      return CompanyBackground(
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    session.status == NavigationStatus.acquiringPosition
                        ? 'Recherche de votre position…'
                        : 'Calcul du trajet depuis votre position…',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _LiveNavigationMap(
            session: session,
            onFollowingChanged: _controller.setFollowingUser,
            tileProvider: widget.dependencies.tileProvider,
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(12),
          child: Column(
            children: [
              _InstructionBanner(session: session),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _GpsSignalBadge(session: session),
              ),
              if (session.message != null) ...[
                const SizedBox(height: 8),
                _NavigationMessage(message: session.message!),
              ],
              const Spacer(),
              _NavigationControls(
                session: session,
                onRecenter: () => _controller.setFollowingUser(true),
                onExternal: _openExternal,
                onStop: _confirmStop,
              ),
            ],
          ),
        ),
        if (session.status == NavigationStatus.arrived)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(28),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flag_circle_rounded,
                          color: CompanyPalette.primary,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Vous êtes arrivé',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.destination.label,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Terminer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmStop() async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrêter le guidage ?'),
        content: const Text(
          'La position ne sera plus suivie et l’écran pourra de nouveau s’éteindre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    if (shouldStop != true || !mounted) return;
    await _controller.stop();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openExternal() async {
    final start = _controller.session.position?.asPlace;
    if (start == null) return;
    final provider = await showModalBottomSheet<NavigationProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Ouvrir dans une autre application')),
            for (final candidate in _launcher.availableProviders)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(candidate.label),
                onTap: () => Navigator.pop(context, candidate),
              ),
          ],
        ),
      ),
    );
    if (provider == null) return;
    await _launcher.launch(
      provider: provider,
      start: start,
      destination: widget.destination,
      mode: widget.mode,
    );
  }
}

class _LiveNavigationMap extends StatefulWidget {
  const _LiveNavigationMap({
    required this.session,
    required this.onFollowingChanged,
    this.tileProvider,
  });

  final NavigationSession session;
  final ValueChanged<bool> onFollowingChanged;
  final TileProvider? tileProvider;

  @override
  State<_LiveNavigationMap> createState() => _LiveNavigationMapState();
}

class _LiveNavigationMapState extends State<_LiveNavigationMap> {
  final MapController _mapController = MapController();
  bool _ready = false;
  late double _mapRotation;

  @override
  void initState() {
    super.initState();
    _mapRotation = widget.session.displayHeadingDegrees;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LiveNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        widget.session.followingUser &&
        widget.session.snappedPosition != null &&
        (widget.session.snappedPosition != oldWidget.session.snappedPosition ||
            !oldWidget.session.followingUser)) {
      _follow();
    }
  }

  void _follow() {
    final position = widget.session.snappedPosition;
    if (position == null) return;
    final heading = widget.session.displayHeadingDegrees;
    _mapController.moveAndRotate(position, 17, heading);
  }

  void _overview() {
    final points = widget.session.route?.points;
    if (points == null || points.isEmpty) return;
    widget.onFollowingChanged(false);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final route = session.route!;
    final position = session.snappedPosition ?? session.position!.point;
    return AdaptiveMapInteraction(
      controller: _mapController,
      onUserInteraction: () => widget.onFollowingChanged(false),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: position,
          initialZoom: 17,
          initialRotation: session.displayHeadingDegrees,
          minZoom: 3,
          maxZoom: 19,
          interactionOptions: routeMapInteractionOptions(),
          onMapReady: () {
            _ready = true;
            _follow();
          },
          onMapEvent: (event) {
            if ((_mapRotation - event.camera.rotation).abs() > 0.01 &&
                mounted) {
              setState(() => _mapRotation = event.camera.rotation);
            }
            if (event.source != MapEventSource.mapController &&
                event.source != MapEventSource.fitCamera &&
                event.source != MapEventSource.nonRotatedSizeChange) {
              widget.onFollowingChanged(false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: ignPlanWmtsUrl,
            userAgentPackageName: 'fr.ign.itineraires',
            maxNativeZoom: 19,
            tileProvider: widget.tileProvider,
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.points,
                color: CompanyPalette.primary,
                strokeWidth: 7,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: position,
                radius: session.position!.accuracyMeters,
                useRadiusInMeter: true,
                color: CompanyPalette.primary.withValues(alpha: 0.12),
                borderColor: CompanyPalette.primary.withValues(alpha: 0.45),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
          MarkerLayer(
            rotate: true,
            markers: [
              Marker(
                point: route.points.last,
                width: 48,
                height: 48,
                child: const Icon(
                  Icons.flag_circle_rounded,
                  color: CompanyPalette.accent,
                  size: 44,
                ),
              ),
              Marker(
                point: position,
                width: 54,
                height: 54,
                child: Transform.rotate(
                  angle:
                      (session.displayHeadingDegrees - _mapRotation) *
                      math.pi /
                      180,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: CompanyPalette.buttonGradient(
                        Theme.of(context).brightness,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 10),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              TextSourceAttribution('© IGN – cartes.gouv.fr', onTap: () {}),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 190,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'navigation-overview',
                  tooltip: 'Voir tout le trajet',
                  onPressed: _overview,
                  child: const Icon(Icons.route),
                ),
                const SizedBox(height: 8),
                if (!session.followingUser)
                  FloatingActionButton.small(
                    heroTag: 'navigation-recenter',
                    tooltip: 'Recentrer sur ma position',
                    onPressed: () {
                      widget.onFollowingChanged(true);
                      _follow();
                    },
                    child: const Icon(Icons.my_location),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({required this.session});

  final NavigationSession session;

  @override
  Widget build(BuildContext context) {
    final step = session.upcomingStep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: CompanyPalette.cardGradient(
                  Theme.of(context).brightness,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                _instructionIcon(step),
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.formattedDistanceToManeuver,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    step?.type == 'arrive' &&
                            session.remainingDistanceMeters > 80
                        ? 'Continuez vers votre destination'
                        : step?.instruction ?? 'Suivez l’itinéraire',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _instructionIcon(RouteStep? step) {
    if (step == null) return Icons.navigation_rounded;
    if (step.type == 'arrive') return Icons.flag_rounded;
    return switch (step.modifier) {
      'left' || 'slight left' || 'sharp left' => Icons.turn_left_rounded,
      'right' || 'slight right' || 'sharp right' => Icons.turn_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => Icons.straight_rounded,
    };
  }
}

class _NavigationControls extends StatelessWidget {
  const _NavigationControls({
    required this.session,
    required this.onRecenter,
    required this.onExternal,
    required this.onStop,
  });

  final NavigationSession session;
  final VoidCallback onRecenter;
  final VoidCallback onExternal;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Restant',
                    value: session.formattedRemainingDistance,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Durée',
                    value: session.formattedRemainingDuration,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Arrivée',
                    value: _arrivalTime(session.remainingDurationSeconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: session.followingUser ? null : onRecenter,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Recentrer'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Ouvrir dans une autre application',
                  onPressed: onExternal,
                  icon: const Icon(Icons.open_in_new),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Arrêter',
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _arrivalTime(double remainingSeconds) {
    final arrival = DateTime.now().add(
      Duration(seconds: remainingSeconds.round()),
    );
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GpsSignalBadge extends StatelessWidget {
  const _GpsSignalBadge({required this.session});

  final NavigationSession session;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (session.signalState) {
      NavigationSignalState.reliable => (
        'GPS fiable · ±${session.position?.accuracyMeters.round() ?? 0} m',
        Icons.gps_fixed,
        Colors.green,
      ),
      NavigationSignalState.acquiring => (
        'Acquisition GPS',
        Icons.gps_not_fixed,
        Colors.orange,
      ),
      NavigationSignalState.reduced => (
        'Position approximative',
        Icons.location_disabled,
        Colors.red,
      ),
      NavigationSignalState.degraded => (
        'GPS dégradé',
        Icons.gps_off,
        Colors.orange,
      ),
      NavigationSignalState.interrupted => (
        'GPS interrompu',
        Icons.gps_off,
        Colors.red,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _NavigationMessage extends StatelessWidget {
  const _NavigationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _NavigationFailure extends StatelessWidget {
  const _NavigationFailure({
    required this.message,
    required this.onClose,
    this.onExternal,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback? onExternal;

  @override
  Widget build(BuildContext context) {
    return CompanyBackground(
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Guidage indisponible',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 22),
                if (onExternal != null)
                  OutlinedButton.icon(
                    onPressed: onExternal,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir dans une autre app'),
                  ),
                TextButton(onPressed: onClose, child: const Text('Retour')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
