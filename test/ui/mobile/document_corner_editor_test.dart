import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planner/ui/mobile/document_corner_editor.dart';

void main() {
  testWidgets('zoom and magnifier select the nearest of overlapping handles', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('planner-corner-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final photo = File.fromUri(directory.uri.resolve('photo.png'))
      ..writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 200)));
    final corners = [
      const Point(.49, .49),
      const Point(.51, .49),
      const Point(.51, .51),
      const Point(.49, .51)
    ];
    int? moved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 500,
            child: StatefulBuilder(
              builder: (context, setState) => DocumentCornerEditor(
                file: photo,
                imageSize: const Size(200, 200),
                corners: corners,
                onMoved: (index, point) => setState(() {
                  moved = index;
                  corners[index] = point;
                }),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Ingrandisci il ritaglio'));
    await tester.pump();
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);

    final handle = find.byKey(const ValueKey('scan-corner-0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(-24, -22));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, -10));
    await tester.pump();
    final lens = find.byKey(const ValueKey('scan-magnifier'));
    expect(lens, findsOneWidget);
    expect(moved, 0);
    expect(corners[0].x, lessThan(.49));
    await gesture.up();
    await tester.pump();
    expect(lens, findsNothing);
  });
}
