part of '../routing_page.dart';

class _PlannerPanel extends StatelessWidget {
  const _PlannerPanel({
    required this.controller,
    required this.onStartNavigation,
    required this.onLaunchExternal,
    required this.onShowPrivacy,
    required this.onOpenLegalNotice,
  });

  final RoutingController controller;
  final VoidCallback onStartNavigation;
  final VoidCallback onLaunchExternal;
  final VoidCallback onShowPrivacy;
  final VoidCallback onOpenLegalNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'IGN ITINÉRAIRES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text('Préparer le trajet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Calcul d’itinéraire via les services publics cartes.gouv.fr.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          AddressSearchField(
            label: 'Départ',
            icon: Icons.trip_origin,
            value: controller.start,
            search: controller.search,
            onChanged: controller.setStart,
            locating: controller.locating,
            onUseCurrentLocation: controller.useCurrentLocation,
          ),
          Semantics(
            button: true,
            label: 'Inverser le départ et l’arrivée',
            excludeSemantics: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Inverser le départ et l’arrivée',
                onPressed:
                    controller.start == null && controller.destination == null
                    ? null
                    : controller.swapEndpoints,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
          ),
          AddressSearchField(
            label: 'Arrivée',
            icon: Icons.flag_outlined,
            value: controller.destination,
            search: controller.search,
            onChanged: controller.setDestination,
          ),
          const SizedBox(height: 18),
          SegmentedButton<TravelMode>(
            segments: const [
              ButtonSegment(
                value: TravelMode.car,
                icon: Icon(Icons.directions_car),
                label: Text('Voiture'),
              ),
              ButtonSegment(
                value: TravelMode.pedestrian,
                icon: Icon(Icons.directions_walk),
                label: Text('À pied'),
              ),
            ],
            selected: {controller.mode},
            onSelectionChanged: (selection) {
              controller.setMode(selection.first);
            },
          ),
          const SizedBox(height: 18),
          AppPrimaryButton(
            onPressed: controller.canCalculate ? controller.calculate : null,
            loading: controller.calculating,
            label: controller.calculating
                ? 'Calcul en cours…'
                : 'Calculer l’itinéraire',
          ),
          if (controller.message != null) ...[
            const SizedBox(height: 12),
            _InlineMessage(
              message: controller.message!,
              error: controller.messageIsError,
              actionLabel: controller.locationRecovery != null
                  ? 'Ouvrir les réglages'
                  : controller.routeRetryAvailable
                  ? controller.routeRetryLabel
                  : null,
              action: controller.locationRecovery != null
                  ? controller.recoverLocation
                  : controller.canRetryRoute
                  ? controller.calculate
                  : null,
            ),
          ],
          if (controller.route != null) ...[
            const SizedBox(height: 20),
            _RouteSummary(
              route: controller.route!,
              favorite: controller.destinationIsFavorite,
              onToggleFavorite: controller.favoriteMutationInProgress
                  ? null
                  : controller.toggleDestinationFavorite,
              onStartNavigation: onStartNavigation,
              onLaunchExternal: onLaunchExternal,
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sans compte ni suivi publicitaire. Les données utiles '
                      'au trajet sont envoyées directement à la Géoplateforme.',
                    ),
                    TextButton(
                      onPressed: onShowPrivacy,
                      child: const Text('Données et confidentialité'),
                    ),
                    TextButton(
                      onPressed: onOpenLegalNotice,
                      child: const Text('Mentions légales'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Projet open source non officiel · sans affiliation avec l’IGN',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.route,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onStartNavigation,
    required this.onLaunchExternal,
  });

  final RoutePlan route;
  final bool favorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onStartNavigation;
  final VoidCallback onLaunchExternal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${route.formattedDuration} · ${route.formattedDistance}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: favorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  onPressed: onToggleFavorite,
                  icon: Icon(favorite ? Icons.star : Icons.star_outline),
                ),
              ],
            ),
            if (route.resourceVersion.isNotEmpty)
              Text(
                'Réseau IGN ${route.resourceVersion}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onStartNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Démarrer le guidage'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onLaunchExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ouvrir dans une autre application'),
            ),
            const SizedBox(height: 8),
            Text(
              'Le guidage intégré recalcule le départ depuis votre position GPS.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (route.steps.isNotEmpty) ...[
              const Divider(height: 28),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('Feuille de route (${route.steps.length})'),
                children: [
                  for (var index = 0; index < route.steps.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(route.steps[index].instruction),
                      subtitle: route.steps[index].distanceMeters > 0
                          ? Text(
                              _formatStepDistance(
                                route.steps[index].distanceMeters,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatStepDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.error,
    this.actionLabel,
    this.action,
  });

  final String message;
  final bool error;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = error ? colors.errorContainer : colors.secondaryContainer;
    final onColor = error
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              color: onColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(message, style: TextStyle(color: onColor)),
                  ),
                  if (actionLabel != null)
                    TextButton(onPressed: action, child: Text(actionLabel!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(text),
        ],
      ),
    );
  }
}
