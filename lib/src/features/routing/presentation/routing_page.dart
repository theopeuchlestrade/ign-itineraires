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
import 'package:ign_itineraires/src/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/routing_panels.dart';

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
                AppLogoMark(size: largeText ? 30 : 36),
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
    if (kIsWeb) {
      try {
        // WebKit only authorizes later speech after a synthesis request made
        // directly from a user gesture. The web driver performs that silent
        // activation here, before GPS and routing await network responses.
        await widget.dependencies.speech.initialize();
      } catch (_) {
        // Navigation remains usable and exposes a retry if synthesis fails.
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          destination: destination,
          mode: _controller.mode,
          dependencies: widget.dependencies,
          initialStart: _controller.start,
          initialRoute: _controller.route,
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
                onChanged: _controller.historyMutationInProgress
                    ? null
                    : _controller.setHistoryEnabled,
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
                    onPressed: _controller.historyMutationInProgress
                        ? null
                        : _controller.clearRecents,
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
        : NetworkEndpoints.officialLegalNoticeUri;
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
