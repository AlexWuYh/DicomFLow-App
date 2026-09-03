import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Pinch / wheel zoom and pan. Scale clamped to 1x–8x. Double-tap toggles 1x / 2x.
class ZoomableStage extends StatefulWidget {
  const ZoomableStage({super.key, required this.child});

  final Widget child;

  @override
  State<ZoomableStage> createState() => ZoomableStageState();
}

class ZoomableStageState extends State<ZoomableStage> {
  final TransformationController _transform = TransformationController();

  double get scale => _transform.value.getMaxScaleOnAxis();

  void reset() {
    _transform.value = Matrix4.identity();
  }

  void zoomTo(double target, {Offset focal = Offset.zero}) {
    final clamped = target.clamp(1.0, 8.0);
    if (clamped <= 1.0) {
      reset();
      return;
    }
    _transform.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(clamped, clamped, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
  }

  void zoomBy(double factor) {
    final next = (scale * factor).clamp(1.0, 8.0);
    if (next <= 1.0) {
      reset();
      return;
    }
    final ratio = next / scale;
    _transform.value = _transform.value.clone()..scaleByDouble(ratio, ratio, 1, 1);
  }

  void zoomIn() => zoomBy(1.25);

  void zoomOut() => zoomBy(0.8);

  void _toggleZoom(TapDownDetails details) {
    if (scale > 1.05) {
      reset();
      return;
    }
    zoomTo(2, focal: details.localPosition);
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final next = (scale * factor).clamp(1.0, 8.0);
    if (next <= 1.0) {
      reset();
      return;
    }
    final ratio = next / scale;
    final focal = event.localPosition;
    final matrix = _transform.value.clone()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    _transform.value = matrix;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onScroll,
      child: GestureDetector(
        onDoubleTapDown: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 8,
          clipBehavior: Clip.hardEdge,
          child: widget.child,
        ),
      ),
    );
  }
}
