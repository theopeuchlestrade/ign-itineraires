import 'dart:async';

import 'package:flutter/foundation.dart';
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

  testWidgets('explains repeated map tile failures', (tester) async {
    final originalDebugPrint = debugPrint;
    debugPrint = (_, {wrapWidth}) {};
    addTearDown(() => debugPrint = originalDebugPrint);
    await tester.pumpWidget(
      MaterialApp(
        home: IgnRouteMap(
          start: null,
          destination: null,
          route: null,
          tileProvider: _FailingTileProvider(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Fond de carte indisponible. Le trajet reste utilisable.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    debugPrint = originalDebugPrint;
  });
}

class _FailingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return const _FailingImageProvider();
  }
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('tile unavailable')),
    );
  }
}
