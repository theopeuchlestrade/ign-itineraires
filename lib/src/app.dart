import 'package:flutter/material.dart';
import 'package:ign_itineraires/src/app_dependencies.dart';
import 'package:ign_itineraires/src/features/routing/presentation/routing_page.dart';
import 'package:ign_itineraires/src/theme/company_theme.dart';

class IgnItinerairesApp extends StatefulWidget {
  IgnItinerairesApp({super.key, AppDependencies? dependencies})
    : dependencies = dependencies ?? AppDependencies.production(),
      ownsDependencies = dependencies == null;

  final AppDependencies dependencies;
  final bool ownsDependencies;

  @override
  State<IgnItinerairesApp> createState() => _IgnItinerairesAppState();
}

class _IgnItinerairesAppState extends State<IgnItinerairesApp> {
  @override
  void dispose() {
    if (widget.ownsDependencies) widget.dependencies.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGN Itinéraires',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildCompanyTheme(Brightness.light),
      darkTheme: buildCompanyTheme(Brightness.dark),
      home: RoutingPage(dependencies: widget.dependencies),
    );
  }
}
