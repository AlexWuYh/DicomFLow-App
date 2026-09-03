import 'dart:math' as math;
import 'dart:typed_data';

/// Port of DicomFlow `engine/window.py` (tag → filename W/L → min-max, MONOCHROME1).
class WindowResult {
  const WindowResult({
    required this.rgb,
    required this.width,
    required this.height,
  });

  /// Tight RGB888 buffer, even width/height for H.264.
  final Uint8List rgb;
  final int width;
  final int height;
}

final _filenameWindow = RegExp(r'[Ww](\d+)[Ll](-?\d+)');

(double, double)? windowFromFilename(String path) {
  final match = _filenameWindow.firstMatch(path);
  if (match == null) return null;
  final ww = double.parse(match.group(1)!);
  final wc = double.parse(match.group(2)!);
  return (wc, ww);
}

Uint8List applyWindowToPixels({
  required List<int> stored,
  required double slope,
  required double intercept,
  double? windowCenter,
  double? windowWidth,
  required bool monochrome1,
}) {
  final n = stored.length;
  final scaled = Float64List(n);
  var pmin = double.infinity;
  var pmax = -double.infinity;
  for (var i = 0; i < n; i++) {
    final v = stored[i] * slope + intercept;
    scaled[i] = v;
    if (v < pmin) pmin = v;
    if (v > pmax) pmax = v;
  }

  final double lower;
  final double upper;
  if (windowCenter != null && windowWidth != null) {
    lower = windowCenter - windowWidth / 2.0;
    upper = windowCenter + windowWidth / 2.0;
  } else {
    lower = pmin;
    upper = pmax;
  }

  final out = Uint8List(n);
  final span = upper - lower;
  if (span <= 0) {
    return out;
  }
  for (var i = 0; i < n; i++) {
    var v = scaled[i];
    if (v < lower) v = lower;
    if (v > upper) v = upper;
    var u8 = ((v - lower) / span * 255.0).round();
    if (u8 < 0) u8 = 0;
    if (u8 > 255) u8 = 255;
    if (monochrome1) u8 = 255 - u8;
    out[i] = u8;
  }
  return out;
}

WindowResult toRgbEven({
  required Uint8List grayOrRgb,
  required int width,
  required int height,
  required int samplesPerPixel,
}) {
  final evenW = width + (width % 2);
  final evenH = height + (height % 2);
  final rgb = Uint8List(evenW * evenH * 3);

  if (samplesPerPixel >= 3) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final src = (y * width + x) * samplesPerPixel;
        final dst = (y * evenW + x) * 3;
        rgb[dst] = grayOrRgb[src];
        rgb[dst + 1] = grayOrRgb[src + 1];
        rgb[dst + 2] = grayOrRgb[src + 2];
      }
    }
  } else {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final g = grayOrRgb[y * width + x];
        final dst = (y * evenW + x) * 3;
        rgb[dst] = g;
        rgb[dst + 1] = g;
        rgb[dst + 2] = g;
      }
    }
  }
  return WindowResult(rgb: rgb, width: evenW, height: evenH);
}

WindowResult resizeRgb(WindowResult src, int newW, int newH) {
  if (newW == src.width && newH == src.height) return src;
  final out = Uint8List(newW * newH * 3);
  for (var y = 0; y < newH; y++) {
    final sy = ((y * src.height) / newH).floor().clamp(0, src.height - 1);
    for (var x = 0; x < newW; x++) {
      final sx = ((x * src.width) / newW).floor().clamp(0, src.width - 1);
      final si = (sy * src.width + sx) * 3;
      final di = (y * newW + x) * 3;
      out[di] = src.rgb[si];
      out[di + 1] = src.rgb[si + 1];
      out[di + 2] = src.rgb[si + 2];
    }
  }
  return WindowResult(rgb: out, width: newW, height: newH);
}

WindowResult blackFrame(int width, int height) {
  return WindowResult(
    rgb: Uint8List(width * height * 3),
    width: width,
    height: height,
  );
}

/// Scale to fit [tw]x[th] and letterbox with black. Used for merge.
WindowResult fitPad(WindowResult src, int tw, int th) {
  if (src.width == tw && src.height == th) return src;
  final scale = math.min(tw / src.width, th / src.height);
  var nw = math.max(2, (src.width * scale).round());
  var nh = math.max(2, (src.height * scale).round());
  if (nw % 2 != 0) nw += 1;
  if (nh % 2 != 0) nh += 1;
  if (nw > tw) nw = tw;
  if (nh > th) nh = th;
  final scaled = resizeRgb(src, nw, nh);
  if (nw == tw && nh == th) return scaled;
  final out = Uint8List(tw * th * 3);
  final ox = ((tw - nw) / 2).floor();
  final oy = ((th - nh) / 2).floor();
  for (var y = 0; y < nh; y++) {
    final di = ((oy + y) * tw + ox) * 3;
    final si = y * nw * 3;
    out.setRange(di, di + nw * 3, scaled.rgb, si);
  }
  return WindowResult(rgb: out, width: tw, height: th);
}

(int, int) scaledSize({
  required int width,
  required int height,
  required double scale,
  int? maxSide,
}) {
  var w = math.max(2, (width * scale).round());
  var h = math.max(2, (height * scale).round());
  if (maxSide != null) {
    final longest = math.max(w, h);
    if (longest > maxSide) {
      final ratio = maxSide / longest;
      w = math.max(2, (w * ratio).round());
      h = math.max(2, (h * ratio).round());
    }
  }
  if (w % 2 != 0) w += 1;
  if (h % 2 != 0) h += 1;
  return (w, h);
}
