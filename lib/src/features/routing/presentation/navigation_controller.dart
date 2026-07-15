import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_policies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

part 'navigation_lifecycle.dart';

class NavigationController extends ChangeNotifier {
  NavigationController(
    this._api,
    this._location,
    this._store,
    this._speech,
    this._wakeLock, {
    required this.destination,
    required this.mode,
    DateTime Function()? now,
    Duration Function(int attempt)? streamRetryDelay,
  }) : _now = now ?? DateTime.now,
       _streamRetryDelay = streamRetryDelay ?? _defaultStreamRetryDelay,
       _headingTracker = NavigationHeadingTracker(mode),
       session = NavigationSession(
         status: NavigationStatus.acquiringPosition,
         destination: destination,
         mode: mode,
         voiceEnabled: true,
       ) {
    _signalPolicy = NavigationSignalPolicy(mode: mode, now: _now);
    _deviationPolicy = RouteDeviationPolicy(mode);
    _speech.setErrorHandler(_handleSpeechError);
  }

  final Place destination;
  final TravelMode mode;
  final GeoplateformeGateway _api;
  final DeviceLocationGateway _location;
  final LocalRouteStore _store;
  final SpeechGateway _speech;
  final WakeLockGateway _wakeLock;
  final DateTime Function() _now;
  final Duration Function(int attempt) _streamRetryDelay;
  final NavigationHeadingTracker _headingTracker;

  NavigationSession session;
  NavigationEngine? _engine;
  final GuidanceAnnouncementPlanner _announcementPlanner =
      GuidanceAnnouncementPlanner();
  late final NavigationSignalPolicy _signalPolicy;
  late final RouteDeviationPolicy _deviationPolicy;
  final ReroutePolicy _reroutePolicy = ReroutePolicy();
  StreamSubscription<NavigationPosition>? _positionSubscription;
  Timer? _signalWatchdog;
  double? _progressMeters;
  DateTime? _lastFixReceivedAt;
  NavigationPosition? _lastAcceptedPosition;
  NavigationPosition? _pendingPosition;
  int _operationGeneration = 0;
  bool _handlingPosition = false;
  bool _foreground = true;
  bool _wantsForeground = true;
  bool _disposed = false;
  bool _recoveringStream = false;
  final _lifecycleTransitions = _LifecycleTransitionQueue();
  int _streamRetryAttempts = 0;
  bool voiceMutationInProgress = false;

  Future<void> start() async {
    final operation = ++_operationGeneration;
    final voiceEnabled = await _loadVoicePreference();
    if (!_canContinue(operation)) return;
    _setSession(
      session.copyWith(
        status: NavigationStatus.acquiringPosition,
        voiceEnabled: voiceEnabled,
        speechRetryAvailable: false,
        signalState: NavigationSignalState.acquiring,
        message: null,
      ),
    );
    try {
      final position = await _location.currentPosition(navigationMode: mode);
      if (!_canContinue(operation)) return;
      final issue = _signalPolicy.issueFor(position);
      if (issue != null) {
        _setSession(
          session.copyWith(
            position: position,
            signalState: position.precision == LocationPrecision.reduced
                ? NavigationSignalState.reduced
                : NavigationSignalState.degraded,
          ),
        );
        throw DeviceLocationException(issue);
      }
      _setSession(
        session.copyWith(
          status: NavigationStatus.calculating,
          position: position,
          signalState: NavigationSignalState.reliable,
        ),
      );
      final route = await _api.calculateRoute(
        start: position.asPlace,
        destination: destination,
        mode: mode,
      );
      if (!_canContinue(operation)) return;
      await _activateRoute(
        route,
        position,
        announceInitial: true,
        operation: operation,
      );
    } on DeviceLocationException catch (error) {
      _fail(error.message, recovery: error.recovery);
    } on GeoplateformeException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('Le guidage n’a pas pu démarrer.');
    }
  }

  Future<void> _activateRoute(
    RoutePlan route,
    NavigationPosition position, {
    required bool announceInitial,
    required int operation,
  }) async {
    if (!_canContinue(operation)) return;
    _engine = NavigationEngine(route, mode);
    _headingTracker.reset();
    _progressMeters = null;
    _deviationPolicy.reset();
    _signalPolicy.reset();
    _lastAcceptedPosition = position;
    _lastFixReceivedAt = _now();
    final update = _engine!.update(position);
    _progressMeters = update.progressMeters;
    _setSession(
      session.copyWith(
        status: NavigationStatus.active,
        route: route,
        position: position,
        snappedPosition: update.snappedPosition,
        currentStepIndex: update.currentStepIndex,
        upcomingStepIndex: update.upcomingStepIndex,
        distanceToManeuverMeters: update.distanceToManeuverMeters,
        remainingDistanceMeters: update.remainingDistanceMeters,
        remainingDurationSeconds: update.remainingDurationSeconds,
        distanceFromRouteMeters: update.distanceFromRouteMeters,
        signalState: NavigationSignalState.reliable,
        displayHeadingDegrees: _headingTracker.resolve(
          position,
          routeHeadingDegrees: update.routeHeadingDegrees,
        ),
        message: null,
      ),
    );
    try {
      await _wakeLock.enable();
      if (!_canContinue(operation)) {
        await _wakeLock.disable();
        return;
      }
    } catch (_) {
      _setSession(
        session.copyWith(
          message: 'L’écran pourrait s’éteindre pendant le guidage.',
        ),
      );
    }
    if (announceInitial &&
        session.voiceEnabled &&
        !session.speechRetryAvailable) {
      final instruction = _announcementPlanner.initial(route);
      if (instruction != null) await _speak(instruction);
    }
    if (!_canContinue(operation)) return;
    await _subscribeToPositions(operation);
  }

  Future<void> _subscribeToPositions(int operation) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!_canContinue(operation)) return;
    _positionSubscription = _location
        .watchPositions(mode)
        .listen(
          (position) => _queuePosition(position, operation),
          onError: (_) => unawaited(_handleStreamError(operation)),
        );
    _startSignalWatchdog(operation);
  }

  void _queuePosition(NavigationPosition position, int operation) {
    if (!_canContinue(operation)) return;
    _streamRetryAttempts = 0;
    _lastFixReceivedAt = _now();
    _pendingPosition = position;
    if (!_handlingPosition) {
      unawaited(_drainPositions(operation));
    }
  }

  Future<void> _drainPositions(int operation) async {
    if (_handlingPosition) return;
    _handlingPosition = true;
    try {
      while (_pendingPosition != null && _canContinue(operation)) {
        final position = _pendingPosition!;
        _pendingPosition = null;
        await _handlePosition(position, operation);
      }
    } finally {
      _handlingPosition = false;
    }
  }

  Future<void> _handlePosition(
    NavigationPosition position,
    int operation,
  ) async {
    if (!_canContinue(operation) || session.status != NavigationStatus.active) {
      return;
    }
    final issue = _signalPolicy.issueFor(position);
    if (issue != null) {
      final signalState = _signalPolicy.reject(
        position: position,
        currentSignalState: session.signalState,
      );
      _setSession(session.copyWith(signalState: signalState, message: issue));
      return;
    }
    if (_signalPolicy.needsRecoveryConfirmation(session.signalState)) {
      _setSession(
        session.copyWith(
          signalState: NavigationSignalState.acquiring,
          message: 'Signal GPS retrouvé. Confirmation en cours…',
        ),
      );
      return;
    }
    _signalPolicy.accept();
    final engine = _engine;
    final route = session.route;
    if (engine == null || route == null) return;

    final update = engine.update(
      position,
      previousProgressMeters: _progressMeters,
      previousPosition: _lastAcceptedPosition,
    );
    _progressMeters = update.progressMeters;
    _lastAcceptedPosition = position;

    _deviationPolicy.update(update: update, position: position);

    _setSession(
      session.copyWith(
        status: NavigationStatus.active,
        position: position,
        snappedPosition: update.snappedPosition,
        currentStepIndex: update.currentStepIndex,
        upcomingStepIndex: update.upcomingStepIndex,
        distanceToManeuverMeters: update.distanceToManeuverMeters,
        remainingDistanceMeters: update.remainingDistanceMeters,
        remainingDurationSeconds: update.remainingDurationSeconds,
        distanceFromRouteMeters: update.distanceFromRouteMeters,
        signalState: NavigationSignalState.reliable,
        displayHeadingDegrees: _headingTracker.resolve(
          position,
          routeHeadingDegrees: update.routeHeadingDegrees,
        ),
        message: null,
      ),
    );

    if (_deviationPolicy.hasArrived) {
      await _arrive(operation);
      return;
    }
    if (session.voiceEnabled && !session.speechRetryAvailable) {
      final announcement = _announcementPlanner.next(
        update: update,
        route: route,
        mode: mode,
      );
      if (announcement != null) await _speak(announcement);
    }
    if (!_canContinue(operation)) return;
    if (_deviationPolicy.shouldReroute(position.timestamp)) {
      await _reroute(position, operation: operation);
    }
  }

  Future<void> _reroute(
    NavigationPosition position, {
    required int operation,
    bool force = false,
  }) async {
    if (!_canContinue(operation)) return;
    if (!_reroutePolicy.markAttempt(_now(), force: force)) {
      return;
    }
    _setSession(
      session.copyWith(
        status: NavigationStatus.rerouting,
        message: 'Recalcul de l’itinéraire…',
      ),
    );
    try {
      final route = await _api.calculateRoute(
        start: position.asPlace,
        destination: destination,
        mode: mode,
      );
      if (!_canContinue(operation)) return;
      _announcementPlanner.reset();
      final activationPosition = _pendingPosition ?? position;
      _pendingPosition = null;
      await _activateRoute(
        route,
        activationPosition,
        announceInitial: false,
        operation: operation,
      );
      if (!_canContinue(operation)) return;
      if (session.voiceEnabled && !session.speechRetryAvailable) {
        await _speak('Itinéraire recalculé.');
      }
    } on GeoplateformeException catch (error) {
      _deviationPolicy.clearOffRouteFixes();
      _setSession(
        session.copyWith(
          status: NavigationStatus.active,
          position: position,
          message: '${error.message} L’ancien trajet reste affiché.',
        ),
      );
      await _ensureForegroundServices(operation);
    } catch (_) {
      _deviationPolicy.clearOffRouteFixes();
      _setSession(
        session.copyWith(
          status: NavigationStatus.active,
          position: position,
          message: 'Recalcul impossible. L’ancien trajet reste affiché.',
        ),
      );
      await _ensureForegroundServices(operation);
    }
  }

  Future<void> _ensureForegroundServices(int operation) async {
    if (!_canContinue(operation)) return;
    if (_positionSubscription == null) await _subscribeToPositions(operation);
    try {
      await _wakeLock.enable();
      if (!_canContinue(operation)) await _wakeLock.disable();
    } catch (_) {
      // The guidance remains usable if screen wake lock is unavailable.
    }
  }

  Future<void> pause() {
    if (_disposed || !_wantsForeground) return Future<void>.value();
    _wantsForeground = false;
    _foreground = false;
    _operationGeneration++;
    if (session.status != NavigationStatus.stopped &&
        session.status != NavigationStatus.arrived) {
      _setSession(
        session.copyWith(
          status: NavigationStatus.paused,
          signalState: NavigationSignalState.interrupted,
          message: 'Guidage en pause pendant que l’application est masquée.',
        ),
      );
    }
    return _lifecycleTransitions.add(() async {
      await _stopForegroundTracking();
      await _stopSpeechAndWakeLock();
    });
  }

  Future<void> resume() {
    if (_disposed || _wantsForeground) return Future<void>.value();
    if (session.status == NavigationStatus.stopped ||
        session.status == NavigationStatus.arrived) {
      return Future<void>.value();
    }
    _wantsForeground = true;
    return _lifecycleTransitions.add(() async {
      if (_disposed || !_wantsForeground) return;
      _foreground = true;
      final operation = ++_operationGeneration;
      _setSession(
        session.copyWith(
          status: NavigationStatus.acquiringPosition,
          signalState: NavigationSignalState.acquiring,
          message: 'Reprise du guidage…',
        ),
      );
      try {
        final position = await _location.currentPosition(navigationMode: mode);
        if (!_canContinue(operation)) return;
        final issue = _signalPolicy.issueFor(position);
        if (issue != null) throw DeviceLocationException(issue);
        await _reroute(position, operation: operation, force: true);
      } on DeviceLocationException catch (error) {
        if (_canContinue(operation)) {
          _fail(error.message, recovery: error.recovery);
        }
      }
    });
  }

  Future<void> toggleVoice() async {
    if (voiceMutationInProgress) return;
    voiceMutationInProgress = true;
    final enabled = !session.voiceEnabled;
    _setSession(
      session.copyWith(voiceEnabled: enabled, speechRetryAvailable: false),
    );
    if (enabled) {
      await _repeatCurrentInstruction();
    } else {
      try {
        await _speech.stop();
      } catch (_) {
        // Muting remains effective for subsequent announcements.
      }
    }
    try {
      await _store.saveVoiceEnabled(enabled);
    } catch (_) {
      _setSession(
        session.copyWith(
          message:
              'La voix est modifiée pour cette session, mais la préférence n’a pas pu être enregistrée.',
        ),
      );
    } finally {
      voiceMutationInProgress = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retrySpeech() async {
    if (!session.voiceEnabled) return;
    _setSession(session.copyWith(speechRetryAvailable: false));
    await _repeatCurrentInstruction();
  }

  void setFollowingUser(bool following) {
    _setSession(session.copyWith(followingUser: following));
  }

  Future<void> stop() {
    _wantsForeground = false;
    _foreground = false;
    _operationGeneration++;
    _setSession(session.copyWith(status: NavigationStatus.stopped));
    return _lifecycleTransitions.add(() async {
      await _stopForegroundTracking();
      await _stopSpeechAndWakeLock();
    });
  }

  Future<void> _arrive(int operation) async {
    if (!_canContinue(operation)) return;
    _operationGeneration++;
    await _stopForegroundTracking();
    await _stopSpeechAndWakeLock();
    _setSession(
      session.copyWith(
        status: NavigationStatus.arrived,
        remainingDistanceMeters: 0,
        remainingDurationSeconds: 0,
        message: null,
      ),
    );
    if (session.voiceEnabled && !session.speechRetryAvailable) {
      await _speak('Vous êtes arrivé à destination.');
    }
  }

  void _startSignalWatchdog(int operation) {
    _signalWatchdog?.cancel();
    _signalWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_canContinue(operation)) return;
      final lastFix = _lastFixReceivedAt;
      if (lastFix == null ||
          _now().difference(lastFix) <= const Duration(seconds: 8)) {
        return;
      }
      if (session.signalState == NavigationSignalState.degraded) {
        return;
      }
      _setSession(
        session.copyWith(
          signalState: NavigationSignalState.degraded,
          message:
              'Aucune position GPS fiable depuis huit secondes. Guidage suspendu.',
        ),
      );
    });
  }

  Future<void> _handleStreamError(int operation) async {
    if (!_canContinue(operation) || _recoveringStream) return;
    _recoveringStream = true;
    try {
      _signalWatchdog?.cancel();
      _signalWatchdog = null;
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      if (!_canContinue(operation)) return;
      _setSession(
        session.copyWith(
          signalState: NavigationSignalState.interrupted,
          message: 'Signal GPS interrompu. Nouvelle tentative…',
        ),
      );
      _streamRetryAttempts++;
      await Future<void>.delayed(_streamRetryDelay(_streamRetryAttempts));
      if (_canContinue(operation)) await _subscribeToPositions(operation);
    } finally {
      _recoveringStream = false;
    }
  }

  bool _canContinue(int operation) =>
      !_disposed && _foreground && operation == _operationGeneration;

  Future<bool> _loadVoicePreference() async {
    try {
      return await _store.loadVoiceEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _speech.speak(text);
    } catch (_) {
      _setSession(session.copyWith(speechRetryAvailable: true));
    }
  }

  Future<void> _repeatCurrentInstruction() async {
    final route = session.route;
    if (route == null) return;
    final instruction = _announcementPlanner.replayCurrent(
      stepIndex: session.upcomingStepIndex,
      distanceToManeuverMeters: session.distanceToManeuverMeters,
      remainingDistanceMeters: session.remainingDistanceMeters,
      route: route,
      mode: mode,
    );
    if (instruction != null) await _speak(instruction);
  }

  void _handleSpeechError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('interrupted') ||
        normalized.contains('canceled') ||
        normalized.contains('cancelled')) {
      return;
    }
    _setSession(session.copyWith(speechRetryAvailable: true));
  }

  Future<void> _stopForegroundTracking() async {
    _pendingPosition = null;
    _signalWatchdog?.cancel();
    _signalWatchdog = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _stopSpeechAndWakeLock() async {
    try {
      await _speech.stop();
    } catch (_) {
      // The visual guidance can continue without speech.
    }
    try {
      await _wakeLock.disable();
    } catch (_) {
      // Releasing a non-existent wake lock is harmless.
    }
  }

  Future<bool> openLocationRecovery() async {
    final recovery = session.locationRecovery;
    if (recovery == null) return false;
    return switch (recovery) {
      LocationRecovery.openLocationSettings => _location.openLocationSettings(),
      LocationRecovery.openAppSettings => _location.openAppSettings(),
    };
  }

  void _fail(String message, {LocationRecovery? recovery}) {
    _setSession(
      session.copyWith(
        status: NavigationStatus.error,
        signalState: session.signalState == NavigationSignalState.reduced
            ? NavigationSignalState.reduced
            : NavigationSignalState.interrupted,
        message: message,
        locationRecovery: recovery,
      ),
    );
  }

  void _setSession(NavigationSession value) {
    if (_disposed) return;
    session = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wantsForeground = false;
    _foreground = false;
    _operationGeneration++;
    _signalWatchdog?.cancel();
    _signalWatchdog = null;
    _pendingPosition = null;
    unawaited(_positionSubscription?.cancel());
    unawaited(_stopSpeechAndWakeLock());
    super.dispose();
  }
}

Duration _defaultStreamRetryDelay(int attempt) {
  final exponent = math.min(attempt, 5).toInt();
  final seconds = math.min(30, 1 << exponent).toInt();
  return Duration(seconds: seconds);
}
