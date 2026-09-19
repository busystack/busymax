import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final source = image.decodePng(
    File('assets/branding/busymax-logo.png').readAsBytesSync(),
  );
  if (source == null) throw StateError('BusyMax logo is not a valid PNG.');
  const sizes = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    final directory = Directory('android/app/src/main/res/mipmap-${entry.key}')
      ..createSync(recursive: true);
    final icon = image.copyResize(
      source,
      width: entry.value,
      height: entry.value,
      interpolation: image.Interpolation.cubic,
    );
    final foreground = image.Image(
      width: entry.value,
      height: entry.value,
      numChannels: 4,
    );
    final inset = image.copyResize(
      source,
      width: (entry.value * .72).round(),
      height: (entry.value * .72).round(),
      interpolation: image.Interpolation.cubic,
    );
    image.compositeImage(
      foreground,
      inset,
      dstX: (entry.value - inset.width) ~/ 2,
      dstY: (entry.value - inset.height) ~/ 2,
    );
    File(
      '${directory.path}/ic_launcher.png',
    ).writeAsBytesSync(image.encodePng(icon));
    File(
      '${directory.path}/ic_launcher_round.png',
    ).writeAsBytesSync(image.encodePng(icon));
    File(
      '${directory.path}/ic_launcher_foreground.png',
    ).writeAsBytesSync(image.encodePng(foreground));
  }
}
