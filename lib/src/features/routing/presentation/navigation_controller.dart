import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

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
  }) : _now = now ?? DateTime.now,
       session = NavigationSession(
         status: NavigationStatus.acquiringPosition,
         destination: destination,
         mode: mode,
         voiceEnabled: true,
       ) {
    _signalPolicy = _NavigationSignalPolicy(mode: mode, now: _now);
    _deviationPolicy = _RouteDeviationPolicy(mode);
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

  NavigationSession session;
  NavigationEngine? _engine;
  final GuidanceAnnouncementPlanner _announcementPlanner =
      GuidanceAnnouncementPlanner();
  late final _NavigationSignalPolicy _signalPolicy;
  late final _RouteDeviationPolicy _deviationPolicy;
  final _ReroutePolicy _reroutePolicy = _ReroutePolicy();
  StreamSubscription<NavigationPosition>? _positionSubscription;
  Timer? _signalWatchdog;
  double? _progressMeters;
  DateTime? _lastFixReceivedAt;
  NavigationPosition? _lastAcceptedPosition;
  NavigationPosition? _pendingPosition;
  int _operationGeneration = 0;
  bool _handlingPosition = false;
  bool _foreground = true;
  bool _disposed = false;

  Future<void> start() async {
    final operation = ++_operationGeneration;
    final voiceEnabled = await _loadVoicePreference();
    if (!_canContinue(operation)) return;
    _setSession(
      session.copyWith(
        status: NavigationStatus.acquiringPosition,
        voiceEnabled: voiceEnabled,
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
      _fail(error.message);
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
        displayHeadingDegrees: _displayHeading(position, update),
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
    if (announceInitial && session.voiceEnabled) {
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
        displayHeadingDegrees: _displayHeading(position, update),
        message: null,
      ),
    );

    if (_deviationPolicy.hasArrived) {
      await _arrive(operation);
      return;
    }
    if (session.voiceEnabled) {
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
      if (session.voiceEnabled) await _speak('Itinéraire recalculé.');
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

  Future<void> pause() async {
    if (_disposed || !_foreground) return;
    _foreground = false;
    _operationGeneration++;
    await _stopForegroundTracking();
    await _stopSpeechAndWakeLock();
    if (_disposed ||
        session.status == NavigationStatus.stopped ||
        session.status == NavigationStatus.arrived) {
      return;
    }
    _setSession(
      session.copyWith(
        status: NavigationStatus.paused,
        signalState: NavigationSignalState.interrupted,
        message: 'Guidage en pause pendant que l’application est masquée.',
      ),
    );
  }

  Future<void> resume() async {
    if (session.status != NavigationStatus.paused) return;
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
      _fail(error.message);
    }
  }

  Future<void> toggleVoice() async {
    final enabled = !session.voiceEnabled;
    _setSession(session.copyWith(voiceEnabled: enabled));
    await _store.saveVoiceEnabled(enabled);
    if (!enabled) {
      await _speech.stop();
      return;
    }
    final instruction = session.upcomingStep?.instruction;
    if (instruction != null) await _speak(instruction);
  }

  void setFollowingUser(bool following) {
    _setSession(session.copyWith(followingUser: following));
  }

  Future<void> stop() async {
    _foreground = false;
    _operationGeneration++;
    await _stopForegroundTracking();
    await _stopSpeechAndWakeLock();
    _setSession(session.copyWith(status: NavigationStatus.stopped));
  }

  Future<void> _arrive(int operation) async {
    if (!_canContinue(operation)) return;
    _operationGeneration++;
    await _stopForegroundTracking();
    await _wakeLock.disable();
    _setSession(
      session.copyWith(
        status: NavigationStatus.arrived,
        remainingDistanceMeters: 0,
        remainingDurationSeconds: 0,
        message: null,
      ),
    );
    if (session.voiceEnabled) await _speak('Vous êtes arrivé à destination.');
  }

  double _displayHeading(NavigationPosition position, GuidanceUpdate update) {
    return position.hasReliableHeading
        ? position.headingDegrees
        : update.routeHeadingDegrees;
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
    if (!_canContinue(operation)) return;
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
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_canContinue(operation)) await _subscribeToPositions(operation);
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
      _setSession(
        session.copyWith(
          message: 'La voix n’est pas disponible ; le guidage visuel continue.',
        ),
      );
    }
  }

  void _handleSpeechError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('interrupted') ||
        normalized.contains('canceled') ||
        normalized.contains('cancelled')) {
      return;
    }
    _setSession(
      session.copyWith(
        voiceEnabled: false,
        message: 'La voix n’est pas disponible ; le guidage visuel continue.',
      ),
    );
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

  void _fail(String message) {
    _setSession(
      session.copyWith(
        status: NavigationStatus.error,
        signalState: session.signalState == NavigationSignalState.reduced
            ? NavigationSignalState.reduced
            : NavigationSignalState.interrupted,
        message: message,
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

class _NavigationSignalPolicy {
  _NavigationSignalPolicy({required this.mode, required this.now});

  final TravelMode mode;
  final DateTime Function() now;
  int _rejectedFixes = 0;
  int _recoveryFixes = 0;

  String? issueFor(NavigationPosition position) {
    if (position.precision == LocationPrecision.reduced) {
      return 'Localisation approximative activée. Autorisez la position précise '
          'dans les réglages ou utilisez une application GPS externe.';
    }
    if (position.isMocked && !kDebugMode) {
      return 'Une position simulée a été détectée. Le guidage est suspendu.';
    }
    final age = now().difference(position.timestamp);
    if (age > const Duration(seconds: 5) || age < const Duration(seconds: -2)) {
      return 'La position GPS reçue est trop ancienne. Recherche d’un signal récent…';
    }
    final maximumAccuracy = mode == TravelMode.pedestrian ? 25.0 : 35.0;
    if (!position.accuracyMeters.isFinite ||
        position.accuracyMeters > maximumAccuracy) {
      return 'Précision GPS insuffisante '
          '(${position.accuracyMeters.round()} m). Guidage suspendu.';
    }
    return null;
  }

  NavigationSignalState reject({
    required NavigationPosition position,
    required NavigationSignalState currentSignalState,
  }) {
    _rejectedFixes++;
    _recoveryFixes = 0;
    if (position.precision == LocationPrecision.reduced) {
      return NavigationSignalState.reduced;
    }
    return _rejectedFixes >= 3
        ? NavigationSignalState.degraded
        : currentSignalState;
  }

  bool needsRecoveryConfirmation(NavigationSignalState signalState) {
    if (signalState != NavigationSignalState.degraded &&
        signalState != NavigationSignalState.interrupted &&
        signalState != NavigationSignalState.reduced) {
      return false;
    }
    _recoveryFixes++;
    return _recoveryFixes < 2;
  }

  void accept() {
    _rejectedFixes = 0;
    _recoveryFixes = 0;
  }

  void reset() {
    _rejectedFixes = 0;
    _recoveryFixes = 0;
  }
}

class _RouteDeviationPolicy {
  _RouteDeviationPolicy(this.mode);

  final TravelMode mode;
  int _offRouteFixes = 0;
  int _reverseDirectionFixes = 0;
  int _arrivalFixes = 0;
  DateTime? _offRouteSince;

  bool get hasArrived => _arrivalFixes >= 2;

  void update({
    required GuidanceUpdate update,
    required NavigationPosition position,
  }) {
    final offRouteThreshold = mode == TravelMode.pedestrian ? 15.0 : 25.0;
    final certainlyOffRoute =
        update.distanceFromRouteMeters - position.accuracyMeters >
        offRouteThreshold;
    if (certainlyOffRoute) {
      _offRouteFixes++;
      _offRouteSince ??= position.timestamp;
    } else {
      _offRouteFixes = 0;
      _offRouteSince = null;
    }
    _reverseDirectionFixes = update.reverseDirection
        ? _reverseDirectionFixes + 1
        : 0;
    _arrivalFixes = update.arrived && position.accuracyMeters <= 20
        ? _arrivalFixes + 1
        : 0;
  }

  bool shouldReroute(DateTime timestamp) {
    final offRouteSince = _offRouteSince;
    final offRouteLongEnough =
        offRouteSince != null &&
        timestamp.difference(offRouteSince) >= const Duration(seconds: 4);
    return (_offRouteFixes >= 3 && offRouteLongEnough) ||
        _reverseDirectionFixes >= 3;
  }

  void clearOffRouteFixes() {
    _offRouteFixes = 0;
  }

  void reset() {
    _offRouteFixes = 0;
    _reverseDirectionFixes = 0;
    _arrivalFixes = 0;
    _offRouteSince = null;
  }
}

class _ReroutePolicy {
  DateTime? _lastRerouteAt;

  bool markAttempt(DateTime now, {required bool force}) {
    if (!force &&
        _lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 20)) {
      return false;
    }
    _lastRerouteAt = now;
    return true;
  }
}
