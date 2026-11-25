import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class DocumentCornerEditor extends StatefulWidget {
  const DocumentCornerEditor({
    super.key,
    required this.file,
    required this.imageSize,
    required this.corners,
    required this.onMoved,
  });

  final File file;
  final Size imageSize;
  final List<math.Point<double>> corners;
  final void Function(int, math.Point<double>) onMoved;

  @override
  State<DocumentCornerEditor> createState() => _DocumentCornerEditorState();
}

class _DocumentCornerEditorState extends State<DocumentCornerEditor> {
  final _transform = TransformationController();
  final _viewport = GlobalKey();
  int? _active;
  Offset _grab = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Offset _scene(Offset globalPosition) {
    final viewport = _viewport.currentContext!.findRenderObject()! as RenderBox;
    return _transform.toScene(viewport.globalToLocal(globalPosition));
  }

  Offset _corner(int index, Rect photo) {
    final corner = widget.corners[index];
    return photo.topLeft +
        Offset(corner.x * photo.width, corner.y * photo.height);
  }

  int _closestCorner(Offset point, Rect photo) {
    var closest = 0;
    for (var i = 1; i < widget.corners.length; i++) {
      if ((_corner(i, photo) - point).distanceSquared <
          (_corner(closest, photo) - point).distanceSquared) {
        closest = i;
      }
    }
    return closest;
  }

  void _zoom(double factor, Size viewport, Rect photo) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 8.0);
    if (next == 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    final center = widget.corners.fold<Offset>(
                Offset.zero,
                (sum, p) =>
                    sum + Offset(p.x * photo.width, p.y * photo.height)) /
            4 +
        photo.topLeft;
    final offset = viewport.center(Offset.zero) - center * next;
    final x = offset.dx.clamp(viewport.width * (1 - next), 0.0);
    final y = offset.dy.clamp(viewport.height * (1 - next), 0.0);
    _transform.value = Matrix4.diagonal3Values(next, next, 1)
      ..setTranslationRaw(x, y, 0);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, limits) {
        final viewport = limits.biggest;
        final available = Size(
          math.max(1.0, viewport.width - 48),
          math.max(1.0, viewport.height - 48),
        );
        final fitted = applyBoxFit(BoxFit.contain, widget.imageSize, available)
            .destination;
        final photo = Rect.fromCenter(
          center: viewport.center(Offset.zero),
          width: fitted.width,
          height: fitted.height,
        );
        final color = Theme.of(context).colorScheme.primary;
        final active = _active;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                key: _viewport,
                transformationController: _transform,
                minScale: 1,
                maxScale: 8,
                child: AnimatedBuilder(
                  animation: _transform,
                  builder: (context, _) {
                    final zoom = _transform.value.getMaxScaleOnAxis();
                    final target = 48 / zoom;
                    return SizedBox.fromSize(
                      size: viewport,
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: photo,
                            child: Image.file(widget.file, fit: BoxFit.fill),
                          ),
                          Positioned.fromRect(
                            rect: photo,
                            child: IgnorePointer(
                                child: CustomPaint(
                              painter:
                                  _Outline([...widget.corners], color, zoom),
                            )),
                          ),
                          for (var i = 0; i < 4; i++)
                            Positioned(
                              left: _corner(i, photo).dx - target / 2,
                              top: _corner(i, photo).dy - target / 2,
                              child: GestureDetector(
                                key: ValueKey('scan-corner-$i'),
                                behavior: HitTestBehavior.opaque,
                                dragStartBehavior: DragStartBehavior.down,
                                onPanStart: (details) {
                                  final touch = _scene(details.globalPosition);
                                  final corner = _closestCorner(touch, photo);
                                  _grab = _corner(corner, photo) - touch;
                                  setState(() => _active = corner);
                                },
                                onPanUpdate: (details) {
                                  final corner = _active;
                                  if (corner == null) return;
                                  final point = _scene(details.globalPosition) +
                                      _grab -
                                      photo.topLeft;
                                  widget.onMoved(
                                      corner,
                                      math.Point(
                                        (point.dx / photo.width)
                                            .clamp(0.0, 1.0),
                                        (point.dy / photo.height)
                                            .clamp(0.0, 1.0),
                                      ));
                                },
                                onPanEnd: (_) => setState(() => _active = null),
                                onPanCancel: () =>
                                    setState(() => _active = null),
                                child: SizedBox.square(
                                  dimension: target,
                                  child: Center(
                                      child: CircleAvatar(
                                    radius: 8 / zoom,
                                    backgroundColor: color,
                                  )),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (active == null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Material(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Riduci zoom',
                      onPressed: () => _zoom(.5, viewport, photo),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: 'Ingrandisci il ritaglio',
                      onPressed: () => _zoom(2, viewport, photo),
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                ),
              )
            else
              Align(
                alignment: widget.corners[active].x < .5
                    ? Alignment.topRight
                    : Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IgnorePointer(
                      child: _CornerMagnifier(
                    file: widget.file,
                    size: fitted,
                    point: widget.corners[active],
                    color: color,
                  )),
                ),
              ),
          ],
        );
      });
}

class _CornerMagnifier extends StatelessWidget {
  const _CornerMagnifier(
      {required this.file,
      required this.size,
      required this.point,
      required this.color});
  final File file;
  final Size size;
  final math.Point<double> point;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const diameter = 112.0;
    const zoom = 4.0;
    return ClipOval(
      key: const ValueKey('scan-magnifier'),
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(
          children: [
            ColoredBox(color: Theme.of(context).colorScheme.surface),
            Positioned(
              left: diameter / 2 - point.x * size.width * zoom,
              top: diameter / 2 - point.y * size.height * zoom,
              width: size.width * zoom,
              height: size.height * zoom,
              child: Image.file(file, fit: BoxFit.fill),
            ),
            Center(child: Icon(Icons.add, size: 26, color: color)),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ))),
          ],
        ),
      ),
    );
  }
}

class _Outline extends CustomPainter {
  _Outline(this.points, this.color, this.zoom);
  final List<math.Point<double>> points;
  final Color color;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addPolygon([
        for (final point in points)
          Offset(point.x * size.width, point.y * size.height),
      ], true);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(outline, Offset.zero);
    canvas.drawPath(outside, Paint()..color = Colors.black45);
    canvas.drawPath(
        outline,
        Paint()
          ..color = color
          ..strokeWidth = 2 / zoom
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_Outline oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.zoom != zoom ||
      !listEquals(oldDelegate.points, points);
}
