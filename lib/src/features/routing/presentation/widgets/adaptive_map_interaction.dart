import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

bool get usesMacWebTrackpad =>
    kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

InteractionOptions routeMapInteractionOptions({bool? macWebTrackpad}) {
  final useTrackpad = macWebTrackpad ?? usesMacWebTrackpad;
  var flags = InteractiveFlag.all & ~InteractiveFlag.rotate;
  if (useTrackpad) {
    flags &= ~InteractiveFlag.scrollWheelZoom;
  }
  return InteractionOptions(flags: flags);
}

class AdaptiveMapInteraction extends StatelessWidget {
  const AdaptiveMapInteraction({
    super.key,
    required this.controller,
    required this.child,
    this.onUserInteraction,
  });

  final MapController controller;
  final Widget child;
  final VoidCallback? onUserInteraction;

  @override
  Widget build(BuildContext context) {
    if (!usesMacWebTrackpad) return child;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: child,
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent && event is! PointerScaleEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      if (resolvedEvent is PointerScrollEvent) {
        _pan(resolvedEvent);
      } else if (resolvedEvent is PointerScaleEvent) {
        _zoom(resolvedEvent);
      }
    });
  }

  void _pan(PointerScrollEvent event) {
    if (event.scrollDelta == Offset.zero) return;
    final camera = _camera;
    if (camera == null) return;
    onUserInteraction?.call();
    controller.move(
      camera.center,
      camera.zoom,
      offset: -event.scrollDelta,
      id: 'mac-trackpad-pan',
    );
  }

  void _zoom(PointerScaleEvent event) {
    if (!event.scale.isFinite || event.scale <= 0 || event.scale == 1) return;
    final camera = _camera;
    if (camera == null) return;
    final newZoom = camera.clampZoom(
      camera.zoom + math.log(event.scale) / math.ln2,
    );
    final newCenter = camera.focusedZoomCenter(event.localPosition, newZoom);
    onUserInteraction?.call();
    controller.move(newCenter, newZoom, id: 'mac-trackpad-zoom');
  }

  MapCamera? get _camera {
    try {
      return controller.camera;
    } catch (_) {
      return null;
    }
  }
}
