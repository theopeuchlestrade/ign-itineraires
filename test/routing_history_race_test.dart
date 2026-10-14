import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/routing_controller.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

class _DelayedStore extends MemoryRouteStore {
  Completer<void>? saveRecentsGate;
  int saveRecentsCalls = 0;

  @override
  Future<void> saveRecents(List<RecentRoute> value) async {
    saveRecentsCalls++;
    await saveRecentsGate?.future;
    await super.saveRecents(value);
  }
}

void main() {
  late _DelayedStore store;
  late TestAppHarness harness;
  late RoutingController controller;

  setUp(() async {
    store = _DelayedStore();
    harness = TestAppHarness(store: store);
    controller = RoutingController(harness.api, harness.location, store);
    controller.setStart(parisStart);
    controller.setDestination(parisDestination);
    await controller.setHistoryEnabled(true);
  });

  tearDown(() async {
    controller.dispose();
    await harness.dispose();
  });

  for (final disable in [false, true]) {
    for (final fails in [false, true]) {
      test(
        '${disable ? 'disabling' : 'clearing'} history follows an in-flight ${fails ? 'failed' : 'successful'} write',
        () async {
          final gate = Completer<void>();
          store.saveRecentsGate = gate;
          if (fails) {
            store.saveRecentsError = const LocalStoreException('Write failed');
          }
          final calculation = controller.calculate();
          await Future<void>.delayed(Duration.zero);
          expect(store.saveRecentsCalls, 1);

          final deletion = disable
              ? controller.setHistoryEnabled(false)
              : controller.clearRecents();
          await Future<void>.delayed(Duration.zero);
          expect(controller.historyMutationInProgress, isTrue);
          expect(store.clearRecentsCalls, 0);
          gate.complete();
          await Future.wait([calculation, deletion]);

          expect(store.clearRecentsCalls, 1);
          expect(controller.recents, isEmpty);
          expect(store.recents, isEmpty);
          expect(controller.historyEnabled, !disable);
          expect(store.historyEnabled, !disable);
          expect(controller.historyMutationInProgress, isFalse);
          expect(controller.message, isNull);
        },
      );
    }

    test(
      '${disable ? 'disabling' : 'clearing'} history invalidates a pending route response',
      () async {
        final pending = Completer<RoutePlan>();
        harness.api.pendingRoute = pending;
        final calculation = controller.calculate();
        if (disable) {
          await controller.setHistoryEnabled(false);
        } else {
          await controller.clearRecents();
        }
        pending.complete(urbanRoute);
        await calculation;

        expect(controller.route, urbanRoute);
        expect(controller.recents, isEmpty);
        expect(store.recents, isEmpty);
        expect(store.saveRecentsCalls, 0);
      },
    );
  }

  test('serialized writes preserve two different completed routes', () async {
    final gate = Completer<void>();
    store.saveRecentsGate = gate;
    final first = controller.calculate();
    await Future<void>.delayed(Duration.zero);
    controller.setDestination(reunionDestination);
    final second = controller.calculate();
    await Future<void>.delayed(Duration.zero);
    expect(store.saveRecentsCalls, 1);
    gate.complete();
    await Future.wait([first, second]);

    expect(controller.recents.map((route) => route.destination), [
      reunionDestination,
      parisDestination,
    ]);
    expect(store.recents, hasLength(2));
  });

  test('history can save again after a failed queued write', () async {
    store.saveRecentsError = const LocalStoreException('Write failed');
    await controller.calculate();
    expect(controller.recents, isEmpty);
    store.saveRecentsError = null;
    await controller.calculate();
    expect(controller.recents, hasLength(1));
    expect(store.recents, hasLength(1));
  });
}
