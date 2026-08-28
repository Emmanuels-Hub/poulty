// Generates launcher-icon source assets from assets/logo.jpeg.
//
// The logo is a dark silhouette on a white field, which needs two different
// treatments:
//   * app_icon.png            - the mark centred on an opaque white tile.
//   * app_icon_foreground.png - the mark alone on transparency, scaled to the
//                               inner safe zone so Android's adaptive mask
//                               cannot clip it.
//
// Run with: dart run tool/gen_icon.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Output canvas size for both icons.
const _canvas = 1024;

/// flutter_launcher_icons wraps the foreground in its own 16% inset, so the
/// mark is drawn near full-bleed here. 0.92 * 0.68 lands it at ~62% of the
/// adaptive canvas, just inside the ~66% safe zone the mask guarantees.
const _foregroundExtent = 940;

/// Padding for the plain tile is cosmetic only, so it can run wider.
const _tileExtent = 760;

/// Luminance at or above this is treated as background (fully transparent).
const _whiteCutoff = 236;

/// Luminance at or below this is treated as solid mark (fully opaque).
const _markCutoff = 200;

void main() {
  final file = File('assets/logo.jpeg');
  if (!file.existsSync()) {
    stderr.writeln('assets/logo.jpeg not found');
    exitCode = 1;
    return;
  }

  final source = img.decodeJpg(file.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Unable to decode assets/logo.jpeg');
    exitCode = 1;
    return;
  }

  final cutout = _removeWhiteBackground(source);
  final mark = _trimToContent(cutout);
  if (mark == null) {
    stderr.writeln('Logo appears to be blank after background removal');
    exitCode = 1;
    return;
  }

  File(
    'assets/app_icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(_center(mark, _foregroundExtent)));

  // The plain tile needs an opaque background: iOS rejects alpha, and the
  // silhouette would otherwise vanish against a dark launcher.
  final tile = _center(mark, _tileExtent);
  final onWhite = img.Image(width: _canvas, height: _canvas, numChannels: 4);
  img.fill(onWhite, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(onWhite, tile);
  File('assets/app_icon.png').writeAsBytesSync(img.encodePng(onWhite));

  stdout.writeln(
    'Wrote assets/app_icon.png and assets/app_icon_foreground.png '
    '(mark ${mark.width}x${mark.height})',
  );
}

/// Maps the white field to transparency, ramping through the anti-aliased
/// edge so the silhouette keeps smooth borders instead of jagged ones.
img.Image _removeWhiteBackground(img.Image source) {
  final out = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final luminance = img.getLuminance(pixel);

      int alpha;
      if (luminance >= _whiteCutoff) {
        alpha = 0;
      } else if (luminance <= _markCutoff) {
        alpha = 255;
      } else {
        final t = (_whiteCutoff - luminance) / (_whiteCutoff - _markCutoff);
        alpha = (t * 255).round().clamp(0, 255);
      }

      out.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        alpha,
      );
    }
  }

  return out;
}

/// Crops to the bounding box of everything meaningfully opaque, so the mark
/// fills its allotted space rather than inheriting the logo's own margins.
img.Image? _trimToContent(img.Image source) {
  var minX = source.width;
  var minY = source.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a <= 8) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < minX || maxY < minY) return null;

  return img.copyCrop(
    source,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// Scales [mark] to fit a square of [extent] without distorting it, then
/// centres it on a transparent canvas.
img.Image _center(img.Image mark, int extent) {
  final scale = extent / math.max(mark.width, mark.height);
  final width = math.max(1, (mark.width * scale).round());
  final height = math.max(1, (mark.height * scale).round());

  final resized = img.copyResize(
    mark,
    width: width,
    height: height,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: _canvas, height: _canvas, numChannels: 4);
  img.compositeImage(
    canvas,
    resized,
    dstX: (_canvas - width) ~/ 2,
    dstY: (_canvas - height) ~/ 2,
  );
  return canvas;
}
