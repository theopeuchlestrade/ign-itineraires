import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/ign_route_map.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('disposes its map controller when removed', (tester) async {
    late MapController controller;
    final streamDone = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: IgnRouteMap(
          start: null,
          destination: null,
          route: null,
          tileProvider: TransparentTileProvider(),
          mapControllerFactory: () {
            controller = MapController();
            controller.mapEventStream.listen(
              (_) {},
              onDone: streamDone.complete,
            );
            return controller;
          },
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(streamDone.isCompleted, isTrue);
  });
}
