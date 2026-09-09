// Lightweight LTTB implementation and compute wrapper for isolates
// Exposes a top-level function `computeDownsampleSerialized` suitable for
// `compute()` which accepts a Map with keys: 'values' (List<double>) and
// 'maxPoints' (int).

import 'dart:math';

List<List<double>> _toPoints(List values) {
  final pts = <List<double>>[];
  for (var i = 0; i < values.length; i++) {
    final y = (values[i] is num) ? (values[i] as num).toDouble() : double.tryParse(values[i].toString()) ?? 0.0;
    pts.add([i.toDouble(), y]);
  }
  return pts;
}

// LTTB algorithm
List<List<double>> lttb(List<List<double>> data, int threshold) {
  final dataLength = data.length;
  if (threshold >= dataLength || threshold == 0) return data;

  final sampled = <List<double>>[];
  final bucketSize = (dataLength - 2) / (threshold - 2);

  int a = 0;
  sampled.add(data[a]); // always add the first

  for (var i = 0; i < threshold - 2; i++) {
    final start = (1 + (i * bucketSize)).floor();
    final end = (1 + ((i + 1) * bucketSize)).floor();
    final bucket = data.sublist(start, end.clamp(0, dataLength));

    final avgX = bucket.fold(0.0, (p, c) => p + c[0]) / max(1, bucket.length);
    final avgY = bucket.fold(0.0, (p, c) => p + c[1]) / max(1, bucket.length);

    final rangeStart = ( (1 + (i * bucketSize)).floor() );
    final rangeEnd = ( (1 + ((i + 1) * bucketSize)).floor() );
    final range = data.sublist(rangeStart, rangeEnd.clamp(0, dataLength));

    double maxArea = -1.0;
    List<double>? nextA;

    for (final point in range) {
      final area = ( (data[a][0] - avgX) * (point[1] - data[a][1]) - (data[a][0] - point[0]) * (avgY - data[a][1]) ).abs() / 2.0;
      if (area > maxArea) {
        maxArea = area;
        nextA = point;
      }
    }

    if (nextA != null) {
      sampled.add(nextA);
      a = data.indexOf(nextA);
    }
  }

  sampled.add(data.last); // always add last
  return sampled;
}

// compute() wrapper
Future<List<Map<String, double>>> computeDownsampleSerialized(Map args) async {
  final values = (args['values'] as List).cast<dynamic>();
  final maxPoints = args['maxPoints'] as int? ?? 500;
  final pts = _toPoints(values);
  final down = lttb(pts, maxPoints);
  return down.map((p) => {'x': p[0], 'y': p[1]}).toList();
}
