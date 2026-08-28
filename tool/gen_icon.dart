// Generates launcher-icon source assets from assets/logo.jpeg.
// Run with: dart run tool/gen_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodeJpg(File('assets/logo.jpeg').readAsBytesSync());
  if (source == null) {
    stderr.writeln('Unable to decode assets/logo.jpeg');
    exitCode = 1;
    return;
  }

  const size = 1024;
  final square = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );

  File('assets/app_icon.png').writeAsBytesSync(img.encodePng(square));

  // Adaptive icons crop to the inner ~66%, so inset the logo on a transparent
  // canvas to keep it clear of the mask.
  const inset = 620;
  final foreground = img.Image(width: size, height: size, numChannels: 4);
  img.compositeImage(
    foreground,
    img.copyResize(
      source,
      width: inset,
      height: inset,
      interpolation: img.Interpolation.cubic,
    ),
    dstX: (size - inset) ~/ 2,
    dstY: (size - inset) ~/ 2,
  );

  File('assets/app_icon_foreground.png').writeAsBytesSync(
    img.encodePng(foreground),
  );

  stdout.writeln('Wrote assets/app_icon.png and assets/app_icon_foreground.png');
}
