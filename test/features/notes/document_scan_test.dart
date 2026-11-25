import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planner/features/notes/document_scan.dart';
import 'package:planner/features/notes/document_detection.dart';

void main() {
  test('accetta un ritaglio che occupa meno del 2% di ciascun lato', () {
    expect(
      validDocumentCorners(const [
        Point(.742, .632),
        Point(.759, .632),
        Point(.759, .649),
        Point(.742, .649),
      ]),
      isTrue,
    );
  });

  test('rifiuta bordi incrociati e angoli fuori dalla foto', () {
    expect(validDocumentCorners(defaultDocumentCorners), isTrue);
    expect(
        validDocumentCorners([
          const Point(.1, .1),
          const Point(.9, .9),
          const Point(.9, .1),
          const Point(.1, .9),
        ]),
        isFalse);
    expect(
        validDocumentCorners([
          const Point(-.1, .1),
          ...defaultDocumentCorners.skip(1),
        ]),
        isFalse);
  });

  test(
      'ritaglia la foto, raddrizza la prospettiva e rende bianco il foglio colorato',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('document-scan-test-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File.fromUri(directory.uri.resolve('raw.png'));
    final oriented = File.fromUri(directory.uri.resolve('oriented.jpg'));
    final corrected = File.fromUri(directory.uri.resolve('corrected.jpg'));
    final photo = img.Image(width: 300, height: 300);
    img.fill(photo, color: img.ColorRgb8(245, 25, 25));
    img.fillRect(photo,
        x1: 59, y1: 33, x2: 247, y2: 267, color: img.ColorRgb8(195, 174, 125));
    img.fillRect(photo,
        x1: 135, y1: 120, x2: 165, y2: 160, color: img.ColorRgb8(20, 20, 20));
    await source.writeAsBytes(img.encodePng(photo));
    final prepared = prepareScanPhoto(source.path, oriented.path);
    expect(prepared.width, 300);
    expect(prepared.height, 300);
    renderDocumentScan(
        oriented.path,
        corrected.path,
        const [
          Point(.24, .16),
          Point(.76, .14),
          Point(.79, .86),
          Point(.21, .81),
        ],
        true);
    final result = img.decodeJpg(await corrected.readAsBytes())!;
    expect(result.width, lessThan(photo.width));
    expect(result.height, greaterThan(result.width));
    final corner = result.getPixel(5, 5);
    expect(corner.r, greaterThan(248));
    expect(corner.r, corner.g);
    expect(corner.g, corner.b);
    final center = result.getPixel(result.width ~/ 2, result.height ~/ 2);
    expect(center.r, lessThan(12));
    final guide = File.fromUri(directory.uri.resolve('guide.jpg'));
    renderMonochromeGuide(oriented.path, guide.path);
    final guideImage = img.decodeJpg(await guide.readAsBytes())!;
    expect((guideImage.width, guideImage.height), (300, 300));
    final paper = guideImage.getPixel(105, 80);
    expect([paper.r, paper.g, paper.b], everyElement(greaterThan(248)));
  });

  test('rileva i bordi di un foglio inclinato in prospettiva', () {
    final photo = img.Image(width: 480, height: 640);
    img.fill(photo, color: img.ColorRgb8(40, 46, 60));
    const quad = [
      Point(.18, .14),
      Point(.84, .23),
      Point(.74, .88),
      Point(.13, .77),
    ];
    img.fillPolygon(photo,
        vertices: [
          for (final v in quad) img.Point(v.x * 479, v.y * 639),
        ],
        color: img.ColorRgb8(239, 234, 215));
    img.fillRect(photo,
        x1: 150, y1: 290, x2: 305, y2: 302, color: img.ColorRgb8(25, 25, 25));
    final corners = detectDocumentCorners(photo)!;
    expect(validDocumentCorners(corners), isTrue);
    for (var i = 0; i < 4; i++) {
      expect(corners[i].distanceTo(quad[i]), lessThan(.045));
    }
  });

  test('lascia il ritaglio manuale su foto uniformi e sagome tonde', () {
    final photo = img.Image(width: 200, height: 270);
    img.fill(photo, color: img.ColorRgb8(55, 55, 55));
    expect(detectDocumentCorners(photo), isNull);
    img.fillCircle(photo,
        x: 100, y: 135, radius: 80, color: img.ColorRgb8(235, 235, 235));
    expect(detectDocumentCorners(photo), isNull);
  });
}
