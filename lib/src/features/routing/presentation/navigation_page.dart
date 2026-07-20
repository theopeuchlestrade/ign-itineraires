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
import 'package:ign_itineraires/src/theme/app_theme.dart';

part 'widgets/navigation_panels.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.destination,
    required this.mode,
    required this.dependencies,
    this.now,
  });

  final Place destination;
  final TravelMode mode;
  final AppDependencies dependencies;
  final DateTime Function()? now;

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

@visibleForTesting
bool shouldUpdateNavigationCamera(
  NavigationSession previous,
  NavigationSession current,
) {
  return current.followingUser &&
      current.snappedPosition != null &&
      (current.snappedPosition != previous.snappedPosition ||
          current.displayHeadingDegrees != previous.displayHeadingDegrees ||
          !previous.followingUser);
}

@visibleForTesting
double navigationMarkerRotationDegrees({
  required bool followingUser,
  required double headingDegrees,
  required double mapRotationDegrees,
}) {
  return followingUser ? 0 : headingDegrees - mapRotationDegrees;
}

@visibleForTesting
IconData navigationInstructionIcon(RouteStep? step) {
  if (step == null) return Icons.navigation_rounded;
  if (step.normalizedType == 'arrive') return Icons.flag_rounded;
  if (step.isRoundabout) return Icons.roundabout_right_rounded;
  if (step.normalizedType == 'merge') return Icons.merge_rounded;
  if (step.normalizedType == 'fork') {
    return step.modifier.contains('left')
        ? Icons.fork_left_rounded
        : Icons.fork_right_rounded;
  }
  if (step.normalizedType == 'ramp' ||
      step.normalizedType == 'on ramp' ||
      step.normalizedType == 'off ramp') {
    return step.modifier.contains('left')
        ? Icons.ramp_left_rounded
        : Icons.ramp_right_rounded;
  }
  return switch (step.modifier) {
    'slight left' => Icons.turn_slight_left_rounded,
    'slight right' => Icons.turn_slight_right_rounded,
    'sharp left' => Icons.turn_sharp_left_rounded,
    'sharp right' => Icons.turn_sharp_right_rounded,
    'left' => Icons.turn_left_rounded,
    'right' => Icons.turn_right_rounded,
    'uturn' => Icons.u_turn_left_rounded,
    _ => Icons.straight_rounded,
  };
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
                const AppLogoMark(size: 32),
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
                onPressed: _controller.voiceMutationInProgress
                    ? null
                    : _controller.toggleVoice,
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
        onRetry: session.locationRecovery == null
            ? () => unawaited(_controller.start())
            : null,
        onRecovery: session.locationRecovery == null
            ? null
            : _openLocationSettings,
      );
    }
    if (session.route == null || session.position == null) {
      return AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight < 600 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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
                          if (session.speechRetryAvailable) ...[
                            const SizedBox(height: 8),
                            _NavigationMessage(
                              message:
                                  'La voix n’a pas démarré ; le guidage visuel continue.',
                              actionLabel: 'Réessayer la voix',
                              onAction: _controller.retrySpeech,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NavigationControls(
                    session: session,
                    compact: compact,
                    now: widget.now ?? DateTime.now,
                    onRecenter: () => _controller.setFollowingUser(true),
                    onExternal: _openExternal,
                    onStop: _confirmStop,
                  ),
                ],
              );
            },
          ),
        ),
        if (session.status == NavigationStatus.arrived)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flag_circle_rounded,
                              color: AppPalette.primary,
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
    final opened = await _launcher.launch(
      provider: provider,
      start: start,
      destination: widget.destination,
      mode: widget.mode,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le guidage.')),
      );
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = await _controller.openLocationRecovery();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir les réglages.')),
      );
    }
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
        shouldUpdateNavigationCamera(oldWidget.session, widget.session)) {
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
                color: AppPalette.primary,
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
                color: AppPalette.primary.withValues(alpha: 0.12),
                borderColor: AppPalette.primary.withValues(alpha: 0.45),
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
                  color: AppPalette.accent,
                  size: 44,
                ),
              ),
              Marker(
                point: position,
                width: 54,
                height: 54,
                child: Transform.rotate(
                  angle:
                      navigationMarkerRotationDegrees(
                        followingUser: session.followingUser,
                        headingDegrees: session.displayHeadingDegrees,
                        mapRotationDegrees: _mapRotation,
                      ) *
                      math.pi /
                      180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppPalette.button(Theme.of(context).brightness),
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
              const TextSourceAttribution('© IGN – cartes.gouv.fr'),
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
