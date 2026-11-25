import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

List<Point<double>>? detectDocumentCorners(img.Image photo) {
  final longest = max(photo.width, photo.height);
  final sample = longest <= 220
      ? photo
      : img.copyResize(photo,
          width: photo.width >= photo.height ? 220 : null,
          height: photo.height > photo.width ? 220 : null,
          interpolation: img.Interpolation.average);
  final w = sample.width, h = sample.height;
  if (min(w, h) < 24) return null;
  final values = Uint8List(w * h);
  final border = <int>[], center = <int>[];
  for (final pixel in sample) {
    final x = pixel.x, y = pixel.y;
    final value = (sample.numChannels < 3 ? pixel.r : pixel.luminance).round();
    values[y * w + x] = value;
    if (x < 3 || y < 3 || x >= w - 3 || y >= h - 3) border.add(value);
    if (x > w * .35 && x < w * .65 && y > h * .35 && y < h * .65) {
      center.add(value);
    }
  }
  border.sort();
  center.sort();
  final outside = border[border.length ~/ 2];
  final inside = center[center.length ~/ 2];
  if ((inside - outside).abs() < 30) return null;
  final threshold = (inside + outside) / 2;
  final mask = Uint8List(values.length);
  for (var i = 0; i < values.length; i++) {
    if ((inside > outside && values[i] > threshold) ||
        (inside < outside && values[i] < threshold)) {
      mask[i] = 1;
    }
  }

  final queue = Int32List(mask.length);
  List<Point<int>>? edge;
  var largest = 0;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 0) continue;
    var head = 0, tail = 0;
    void enqueue(int index) {
      if (mask[index] == 0) return;
      queue[tail++] = index;
      mask[index] = 0;
    }

    enqueue(i);
    while (head < tail) {
      final k = queue[head++];
      final x = k % w, y = k ~/ w;
      if (x > 0) enqueue(k - 1);
      if (x < w - 1) enqueue(k + 1);
      if (y > 0) enqueue(k - w);
      if (y < h - 1) enqueue(k + w);
    }
    if (tail <= largest) continue;
    largest = tail;
    final left = List.filled(h, w), right = List.filled(h, -1);
    for (var n = 0; n < tail; n++) {
      final x = queue[n] % w, y = queue[n] ~/ w;
      left[y] = min(left[y], x);
      right[y] = max(right[y], x);
    }
    edge = [
      for (var y = 0; y < h; y++)
        if (right[y] >= 0) ...[Point(left[y], y), Point(right[y], y)],
    ];
  }
  if (edge == null ||
      largest < mask.length * .16 ||
      largest > mask.length * .92) {
    return null;
  }

  final hull = _hull(edge);
  if (hull.length < 4) return null;
  final area = _area(hull);
  while (hull.length > 4) {
    var index = 0;
    var smallest = double.infinity;
    for (var i = 0; i < hull.length; i++) {
      final size = _turn(hull[(i + hull.length - 1) % hull.length], hull[i],
              hull[(i + 1) % hull.length])
          .abs();
      if (size < smallest) {
        smallest = size.toDouble();
        index = i;
      }
    }
    hull.removeAt(index);
  }
  final quadArea = _area(hull);
  if (quadArea < area * .83 || largest < area * .72) return null;
  final scores = hull.map((p) => p.x / w + p.y / h).toList();
  final start = scores.indexOf(scores.reduce(min));
  return [
    for (var i = 0; i < 4; i++)
      Point(
          hull[(start + i) % 4].x / (w - 1), hull[(start + i) % 4].y / (h - 1)),
  ];
}

int _turn(Point<int> a, Point<int> b, Point<int> c) =>
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

double _area(List<Point<int>> points) {
  var sum = 0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

List<Point<int>> _hull(List<Point<int>> points) {
  points.sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
  List<Point<int>> half(Iterable<Point<int>> ordered) {
    final result = <Point<int>>[];
    for (final point in ordered) {
      while (result.length > 1 &&
          _turn(result[result.length - 2], result.last, point) <= 0) {
        result.removeLast();
      }
      result.add(point);
    }
    return result..removeLast();
  }

  return [...half(points), ...half(points.reversed)];
}
