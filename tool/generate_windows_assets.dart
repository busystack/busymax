import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final sourceFile = File('assets/branding/busymax-logo.png');
  final source = image.decodePng(sourceFile.readAsBytesSync());
  if (source == null || source.width < 512 || source.height < 512) {
    stderr.writeln('BusyMax source logo must be a 512x512 or larger PNG.');
    exitCode = 1;
    return;
  }

  final runnerResources = Directory('windows/runner/resources')
    ..createSync(recursive: true);
  final packageAssets = Directory('${runnerResources.path}/msix')
    ..createSync(recursive: true);
  final flutterAssets = Directory('assets/windows')
    ..createSync(recursive: true);
  final iconSource = _withTransparentPadding(source, fractionPerSide: 0.06);
  final packageSource = _withTransparentPadding(source, fractionPerSide: 0.10);

  final ico = _encodeIco(iconSource);
  File('${runnerResources.path}/app_icon.ico').writeAsBytesSync(ico);
  File('${flutterAssets.path}/busymax_tray.ico').writeAsBytesSync(ico);
  File(
    '${flutterAssets.path}/busymax_tray_offline.ico',
  ).writeAsBytesSync(_encodeIco(_offlineVariant(iconSource)));

  _writeScaleSet(packageAssets, packageSource, 'Square44x44Logo', const {
    100: 44,
    125: 55,
    150: 66,
    200: 88,
    400: 176,
  });
  _writePng(packageAssets, packageSource, 'Square44x44Logo.png', 44);
  _writeScaleSet(packageAssets, packageSource, 'Square150x150Logo', const {
    100: 150,
    125: 188,
    150: 225,
    200: 300,
    400: 600,
  });
  _writePng(packageAssets, packageSource, 'Square150x150Logo.png', 150);
  _writeScaleSet(packageAssets, packageSource, 'StoreLogo', const {
    100: 50,
    125: 63,
    150: 75,
    200: 100,
    400: 200,
  });
  _writePng(packageAssets, packageSource, 'StoreLogo.png', 50);
  _writePng(packageAssets, packageSource, 'FileAssociation.png', 44);
  _writePng(packageAssets, packageSource, 'FileAssociationLogo.png', 44);
  _writeScaleSet(packageAssets, packageSource, 'FileAssociation', const {
    100: 44,
    125: 55,
    150: 66,
    200: 88,
    400: 176,
  });
  stdout.writeln('Generated BusyMax Windows assets from ${sourceFile.path}.');
}

void _writeScaleSet(
  Directory directory,
  image.Image source,
  String name,
  Map<int, int> sizes,
) {
  for (final MapEntry(key: scale, value: size) in sizes.entries) {
    _writePng(directory, source, '$name.scale-$scale.png', size);
  }
}

void _writePng(Directory directory, image.Image source, String name, int size) {
  File(
    '${directory.path}/$name',
  ).writeAsBytesSync(image.encodePng(_resize(source, size), level: 9));
}

image.Image _resize(image.Image source, int size) => image.copyResize(
  source,
  width: size,
  height: size,
  interpolation: image.Interpolation.cubic,
);

image.Image _withTransparentPadding(
  image.Image source, {
  required double fractionPerSide,
}) {
  final canvasSize = source.width > source.height
      ? source.width
      : source.height;
  final contentSize = (canvasSize * (1 - 2 * fractionPerSide)).round();
  final content = image.copyResize(
    source,
    width: contentSize,
    height: contentSize,
    interpolation: image.Interpolation.cubic,
  );
  final canvas = image.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  image.compositeImage(
    canvas,
    content,
    dstX: (canvasSize - contentSize) ~/ 2,
    dstY: (canvasSize - contentSize) ~/ 2,
  );
  return canvas;
}

List<int> _encodeIco(image.Image source) {
  final frames = <image.Image>[
    for (final size in const [256, 128, 64, 48, 40, 32, 24, 20, 16])
      _resize(source, size),
  ];
  final icon = frames.first;
  for (final frame in frames.skip(1)) {
    icon.addFrame(frame);
  }
  return image.encodeIco(icon);
}

image.Image _offlineVariant(image.Image source) {
  final offline = image.grayscale(source.clone());
  final unit = offline.width / 512;
  int scaled(double value) => (value * unit).round();
  final center = scaled(396);
  image.fillCircle(
    offline,
    x: center,
    y: center,
    radius: scaled(56),
    color: image.ColorRgb8(250, 250, 250),
    antialias: true,
  );
  image.fillCircle(
    offline,
    x: center,
    y: center,
    radius: scaled(47),
    color: image.ColorRgb8(39, 39, 42),
    antialias: true,
  );
  image.drawLine(
    offline,
    x1: scaled(358),
    y1: scaled(358),
    x2: scaled(434),
    y2: scaled(434),
    color: image.ColorRgb8(250, 250, 250),
    thickness: scaled(11),
    antialias: true,
  );
  return offline;
}
