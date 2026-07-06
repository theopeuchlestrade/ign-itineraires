import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/app_dependencies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:ign_itineraires/src/features/routing/presentation/routing_controller.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/address_search_field.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/ign_route_map.dart';
import 'package:ign_itineraires/src/network_endpoints.dart';
import 'package:ign_itineraires/src/theme/company_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  late final RoutingController _controller;
  ExternalNavigationGateway get _navigationLauncher =>
      widget.dependencies.externalNavigation;

  @override
  void initState() {
    super.initState();
    _controller = RoutingController(
      widget.dependencies.geoplateforme,
      widget.dependencies.location,
      widget.dependencies.store,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                CompanyLogoMark(size: largeText ? 30 : 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IGN Itinéraires',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Favoris',
                onPressed: _showFavorites,
                icon: Badge(
                  isLabelVisible: _controller.favorites.isNotEmpty,
                  label: Text('${_controller.favorites.length}'),
                  child: const Icon(Icons.star_outline),
                ),
              ),
              IconButton(
                tooltip: 'Trajets récents',
                onPressed: _showRecents,
                icon: const Icon(Icons.history),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final map = IgnRouteMap(
                start: _controller.start,
                destination: _controller.destination,
                route: _controller.route,
                tileProvider: widget.dependencies.tileProvider,
              );
              final planner = _PlannerPanel(
                controller: _controller,
                onStartNavigation: _startIntegratedNavigation,
                onLaunchExternal: _chooseNavigationProvider,
                onShowPrivacy: _showPrivacy,
                onOpenLegalNotice: _openLegalNotice,
              );

              if (desktop) {
                return Row(
                  children: [
                    Expanded(child: map),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 430, child: planner),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(flex: 5, child: map),
                  const Divider(height: 1),
                  Expanded(flex: 6, child: planner),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startIntegratedNavigation() async {
    final destination = _controller.destination;
    if (destination == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          destination: destination,
          mode: _controller.mode,
          dependencies: widget.dependencies,
        ),
      ),
    );
  }

  Future<void> _chooseNavigationProvider() async {
    final start = _controller.start;
    final destination = _controller.destination;
    if (start == null || destination == null) return;

    final provider = await showModalBottomSheet<NavigationProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Ouvrir le guidage externe'),
              subtitle: Text(
                'L’application choisie recalculera éventuellement le trajet.',
              ),
            ),
            for (final candidate in _navigationLauncher.availableProviders)
              ListTile(
                leading: Icon(switch (candidate) {
                  NavigationProvider.google => Icons.map_outlined,
                  NavigationProvider.apple => Icons.navigation_outlined,
                  NavigationProvider.system => Icons.open_in_new,
                }),
                title: Text(candidate.label),
                onTap: () => Navigator.pop(context, candidate),
              ),
          ],
        ),
      ),
    );
    if (provider == null) return;
    final opened = await _navigationLauncher.launch(
      provider: provider,
      start: start,
      destination: destination,
      mode: _controller.mode,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le guidage.')),
      );
    }
  }

  Future<void> _showFavorites() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _controller.favorites.isEmpty
            ? const _EmptySavedState(
                icon: Icons.star_outline,
                text: 'Aucune destination favorite',
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text('Destinations favorites'),
                    leading: Icon(Icons.star),
                  ),
                  for (final place in _controller.favorites)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.label),
                      onTap: () {
                        _controller.setDestination(place);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _showRecents() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('Mémoriser les trajets récents'),
                subtitle: const Text(
                  'Désactivé par défaut. Les dix derniers trajets restent '
                  'uniquement sur cet appareil.',
                ),
                value: _controller.historyEnabled,
                onChanged: _controller.setHistoryEnabled,
              ),
              if (!_controller.historyEnabled)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Text(
                    'Aucun historique n’est enregistré. Les anciens trajets '
                    'locaux sont supprimés lorsque cette option est désactivée.',
                  ),
                )
              else if (_controller.recents.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Text('Aucun trajet récent'),
                )
              else ...[
                for (final recent in _controller.recents)
                  ListTile(
                    leading: Icon(
                      recent.mode == TravelMode.car
                          ? Icons.directions_car
                          : Icons.directions_walk,
                    ),
                    title: Text(recent.destination.label),
                    subtitle: Text(
                      '${recent.mode.label} · ${_formatRecentDistance(recent.distanceMeters)}',
                    ),
                    onTap: () {
                      _controller.restoreRecent(recent);
                      Navigator.pop(context);
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: OutlinedButton.icon(
                    onPressed: _controller.clearRecents,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Effacer l’historique'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacy() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Données et confidentialité'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aucun compte, publicité ou outil d’analyse n’est utilisé. '
                'L’hébergement officiel conserve uniquement les journaux '
                'techniques décrits dans la politique de confidentialité.',
              ),
              SizedBox(height: 12),
              Text(
                'Les recherches d’adresses, les points de départ et d’arrivée '
                'et les tuiles visibles sont envoyés directement aux services '
                'publics de la Géoplateforme (data.geopf.fr).',
              ),
              SizedBox(height: 12),
              Text(
                'Le suivi GPS reste traité sur l’appareil. Une position est '
                'renvoyée à la Géoplateforme uniquement au démarrage ou lors '
                'du recalcul d’un trajet.',
              ),
              SizedBox(height: 12),
              Text(
                'Les favoris, la voix et l’historique facultatif sont stockés '
                'localement. Une application GPS externe ne reçoit le trajet '
                'que si vous choisissez explicitement de l’ouvrir.',
              ),
              SizedBox(height: 16),
              Text(
                'Projet open source non officiel, sans affiliation avec '
                'l’IGN ou l’administration française.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openLegalNotice,
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Mentions légales'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegalNotice() async {
    final uri = kIsWeb
        ? Uri.base.resolve('legal.html')
        : Uri.https(NetworkEndpoints.officialMapHost, '/legal.html');
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  String _formatRecentDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

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
    return CompanyBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'IGN ITINÉRAIRES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: CompanyPalette.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text('Préparer le trajet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Calcul souverain fondé sur les données routières de l’IGN.',
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
          const SizedBox(height: 14),
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
          CompanyGradientButton(
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
            ),
          ],
          if (controller.route != null) ...[
            const SizedBox(height: 20),
            _RouteSummary(
              route: controller.route!,
              favorite: controller.destinationIsFavorite,
              onToggleFavorite: controller.toggleDestinationFavorite,
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
  final VoidCallback onToggleFavorite;
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
  const _InlineMessage({required this.message, required this.error});

  final String message;
  final bool error;

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
              child: Text(message, style: TextStyle(color: onColor)),
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
