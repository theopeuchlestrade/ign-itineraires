import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/adaptive_map_interaction.dart';

void main() {
  test('Mac web trackpad pans instead of triggering wheel zoom', () {
    final options = routeMapInteractionOptions(macWebTrackpad: true);

    expect(InteractiveFlag.hasScrollWheelZoom(options.flags), isFalse);
    expect(InteractiveFlag.hasPinchZoom(options.flags), isTrue);
    expect(InteractiveFlag.hasDrag(options.flags), isTrue);
    expect(InteractiveFlag.hasRotate(options.flags), isFalse);
  });

  test('other platforms keep wheel zoom without accidental rotation', () {
    final options = routeMapInteractionOptions(macWebTrackpad: false);

    expect(InteractiveFlag.hasScrollWheelZoom(options.flags), isTrue);
    expect(InteractiveFlag.hasRotate(options.flags), isFalse);
  });
}
