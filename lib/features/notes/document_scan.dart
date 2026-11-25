import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'document_detection.dart';

const defaultDocumentCorners = [
  Point(.06, .06),
  Point(.94, .06),
  Point(.94, .94),
  Point(.06, .94),
];

typedef PreparedScan = ({int width, int height, List<Point<double>>? corners});

bool validDocumentCorners(List<Point<double>> corners) {
  if (corners.length != 4 ||
      corners.any((p) =>
          !p.x.isFinite ||
          !p.y.isFinite ||
          p.x < 0 ||
          p.x > 1 ||
          p.y < 0 ||
          p.y > 1)) {
    return false;
  }
  // Check clockwise convexity and leave room for an accidental crossed edge.
  return List.generate(4, (i) {
    final a = corners[(i + 1) % 4] - corners[i];
    final b = corners[(i + 2) % 4] - corners[(i + 1) % 4];
    return a.x * b.y - a.y * b.x;
  }).every((cross) => cross > .00001);
}

img.Image _readPhoto(String path) {
  final file = File(path);
  if (file.lengthSync() > 18 * 1024 * 1024) {
    throw const FormatException('La foto supera 18 MB.');
  }
  final bytes = file.readAsBytesSync();
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw const FormatException('Foto non leggibile o troppo grande.');
  }
  final image = decoder!.decodeFrame(0);
  if (image == null) throw const FormatException('Foto non leggibile.');
  return img.bakeOrientation(image);
}

PreparedScan prepareScanPhoto(String source, String target) {
  var photo = _readPhoto(source);
  final longest = max(photo.width, photo.height);
  if (longest > 2200) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 2200 : null,
      height: photo.height > photo.width ? 2200 : null,
      interpolation: img.Interpolation.average,
    );
  }
  // The corner editor and exporter use the same oriented pixels.
  photo.exif.clear();
  File(target).writeAsBytesSync(img.encodeJpg(photo, quality: 93));
  final corners = detectDocumentCorners(photo);
  return (
    width: photo.width,
    height: photo.height,
    corners: corners != null && validDocumentCorners(corners) ? corners : null,
  );
}

void renderDocumentScan(
  String source,
  String target,
  List<Point<double>> corners,
  bool monochrome,
) {
  if (!validDocumentCorners(corners)) {
    throw const FormatException('Sistema i quattro angoli del documento.');
  }
  final photo = _readPhoto(source);
  final p = corners
      .map((p) => Point(p.x * (photo.width - 1), p.y * (photo.height - 1)))
      .toList();
  final width = max(p[0].distanceTo(p[1]), p[3].distanceTo(p[2]));
  final height = max(p[0].distanceTo(p[3]), p[1].distanceTo(p[2]));
  final scale = min(1.0, 1900 / max(width, height));
  final scan = img.Image(
      width: max(2, (width * scale).round()),
      height: max(2, (height * scale).round()));

  // Homography from the unit rectangle to the four selected image corners.
  final a = p[1] - p[2], b = p[3] - p[2], c = p[0] - p[1] + p[2] - p[3];
  final determinant = a.x * b.y - b.x * a.y;
  final g = (c.x * b.y - b.x * c.y) / determinant;
  final h = (a.x * c.y - c.x * a.y) / determinant;
  final uAxis = p[1] * (1 + g) - p[0], vAxis = p[3] * (1 + h) - p[0];
  for (final pixel in scan) {
    final u = pixel.x / (scan.width - 1), v = pixel.y / (scan.height - 1);
    final denominator = 1 + g * u + h * v;
    final x = (p[0].x + uAxis.x * u + vAxis.x * v) / denominator;
    final y = (p[0].y + uAxis.y * u + vAxis.y * v) / denominator;
    pixel.set(photo.getPixelInterpolate(x, y,
        interpolation: img.Interpolation.linear));
  }
  final output =
      monochrome ? _blackAndWhite(scan) : img.adjustColor(scan, contrast: 1.15);
  File(target)
      .writeAsBytesSync(img.encodeJpg(output, quality: monochrome ? 92 : 87));
}

img.Image _blackAndWhite(img.Image scan) {
  final w = scan.width, h = scan.height;
  final stride = w + 1;
  final sums = Uint32List(stride * (h + 1));
  final levels = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    var row = 0;
    for (var x = 0; x < w; x++) {
      final pixel = scan.getPixel(x, y);
      final value = (scan.numChannels < 3 ? pixel.r : pixel.luminance).round();
      levels[y * w + x] = value;
      row += value;
      sums[(y + 1) * stride + x + 1] = sums[y * stride + x + 1] + row;
    }
  }
  final result = img.Image(width: w, height: h);
  final radius = (min(w, h) ~/ 22).clamp(4, 64);
  for (final pixel in result) {
    final x = pixel.x, y = pixel.y;
    final left = max(0, x - radius), right = min(w, x + radius + 1);
    final top = max(0, y - radius), bottom = min(h, y + radius + 1);
    final sum = sums[bottom * stride + right] -
        sums[top * stride + right] -
        sums[bottom * stride + left] +
        sums[top * stride + left];
    final mean = sum / ((right - left) * (bottom - top));
    final threshold = (mean - 17).clamp(68, 215);
    final value = levels[y * w + x] < threshold ? 0 : 255;
    pixel.setRgb(value, value, value);
  }
  return result;
}

void renderMonochromeGuide(String source, String target) {
  final photo = _readPhoto(source);
  final side = max(photo.width, photo.height);
  final guide = side <= 1200
      ? photo
      : img.copyResize(
          photo,
          width: photo.width >= photo.height ? 1200 : null,
          height: photo.height > photo.width ? 1200 : null,
          interpolation: img.Interpolation.average,
        );
  File(target)
      .writeAsBytesSync(img.encodeJpg(_blackAndWhite(guide), quality: 88));
}
