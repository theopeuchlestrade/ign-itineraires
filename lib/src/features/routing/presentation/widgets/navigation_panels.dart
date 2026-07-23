part of '../navigation_page.dart';

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({required this.session});

  final NavigationSession session;

  @override
  Widget build(BuildContext context) {
    final step = session.upcomingStep;
    final instruction =
        step?.normalizedType == 'arrive' && session.remainingDistanceMeters > 80
        ? 'Continuez vers votre destination'
        : step?.instruction ?? 'Suivez l’itinéraire';
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${session.formattedDistanceToManeuver}, $instruction',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ManeuverVisual(step: step),
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
                      instruction,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManeuverVisual extends StatelessWidget {
  const _ManeuverVisual({required this.step});

  final RouteStep? step;

  @override
  Widget build(BuildContext context) {
    final currentStep = step;
    final ordinal = currentStep?.exitOrdinal;
    final isNumberedRoundabout =
        currentStep != null && currentStep.isRoundabout && ordinal != null;
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppPalette.card(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(19),
      ),
      child: isNumberedRoundabout
          ? Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _RoundaboutExitPainter(
                    exitAngleDegrees: roundaboutExitAngleDegrees(currentStep),
                    color: Colors.white,
                  ),
                ),
                Center(
                  child: Text(
                    ordinal,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            )
          : Icon(
              navigationInstructionIcon(currentStep),
              color: Colors.white,
              size: 34,
            ),
    );
  }
}

class _RoundaboutExitPainter extends CustomPainter {
  const _RoundaboutExitPainter({
    required this.exitAngleDegrees,
    required this.color,
  });

  final double exitAngleDegrees;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortestSide * 0.24;
    final edgeDistance = shortestSide / 2 - 6;
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final exitPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5.5;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawLine(
      center + Offset(0, radius),
      Offset(center.dx, size.height - 5),
      basePaint,
    );

    final radians = exitAngleDegrees * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final branchStart = center + direction * radius;
    final branchEnd = center + direction * edgeDistance;
    canvas.drawLine(branchStart, branchEnd, exitPaint);

    final perpendicular = Offset(-direction.dy, direction.dx);
    final arrowBase = branchEnd - direction * 7;
    final arrow = Path()
      ..moveTo(branchEnd.dx, branchEnd.dy)
      ..lineTo(
        arrowBase.dx + perpendicular.dx * 4,
        arrowBase.dy + perpendicular.dy * 4,
      )
      ..moveTo(branchEnd.dx, branchEnd.dy)
      ..lineTo(
        arrowBase.dx - perpendicular.dx * 4,
        arrowBase.dy - perpendicular.dy * 4,
      );
    canvas.drawPath(arrow, exitPaint);
  }

  @override
  bool shouldRepaint(covariant _RoundaboutExitPainter oldDelegate) {
    return oldDelegate.exitAngleDegrees != exitAngleDegrees ||
        oldDelegate.color != color;
  }
}

class _NavigationControls extends StatelessWidget {
  const _NavigationControls({
    required this.session,
    required this.compact,
    required this.now,
    required this.onExternal,
    required this.onStop,
  });

  final NavigationSession session;
  final bool compact;
  final DateTime Function() now;
  final VoidCallback onExternal;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final stackButtons =
                    constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.8;
                final buttons = <Widget>[
                  Tooltip(
                    message: 'Ouvrir dans une autre application',
                    child: OutlinedButton.icon(
                      key: const ValueKey('navigation-external-button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: onExternal,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Autre GPS'),
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('navigation-stop-button'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Arrêter'),
                  ),
                ];
                if (stackButtons) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons.first,
                      const SizedBox(height: 8),
                      buttons.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: buttons.first),
                    const SizedBox(width: 8),
                    Expanded(child: buttons.last),
                  ],
                );
              },
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
