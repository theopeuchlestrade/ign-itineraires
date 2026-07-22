part of '../navigation_page.dart';

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({required this.session});

  final NavigationSession session;

  @override
  Widget build(BuildContext context) {
    final step = session.upcomingStep;
    return Card(
      key: const Key('navigation-instruction'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppPalette.card(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                navigationInstructionIcon(step),
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
                    step?.normalizedType == 'arrive'
                        ? 'Continuez vers votre destination'
                        : step?.instruction ?? 'Suivez l’itinéraire',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationControls extends StatelessWidget {
  const _NavigationControls({
    required this.session,
    required this.compact,
    required this.now,
    required this.onRecenter,
    required this.onExternal,
    required this.onStop,
  });

  final NavigationSession session;
  final bool compact;
  final DateTime Function() now;
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
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: compact ? 82 : 104,
                  child: _Metric(
                    label: 'Restant',
                    value: session.formattedRemainingDistance,
                  ),
                ),
                SizedBox(
                  width: compact ? 82 : 104,
                  child: _Metric(
                    label: 'Durée',
                    value: session.formattedRemainingDuration,
                  ),
                ),
                SizedBox(
                  width: compact ? 82 : 104,
                  child: _Metric(
                    label: 'Arrivée',
                    value: _arrivalTime(session.remainingDurationSeconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: session.followingUser ? null : onRecenter,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Recentrer'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Ouvrir dans une autre application',
                  onPressed: onExternal,
                  icon: const Icon(Icons.open_in_new),
                ),
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
    final arrival = now().add(Duration(seconds: remainingSeconds.round()));
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
  const _NavigationMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(liveRegion: true, child: Text(message)),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
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
    this.onRetry,
    this.onRecovery,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback? onExternal;
  final VoidCallback? onRetry;
  final VoidCallback? onRecovery;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Card(
              margin: EdgeInsets.zero,
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
                    Semantics(
                      liveRegion: true,
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 22),
                    if (onRecovery != null)
                      FilledButton.icon(
                        onPressed: onRecovery,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Ouvrir les réglages'),
                      ),
                    if (onRetry != null)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
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
        ),
      ),
    );
  }
}
