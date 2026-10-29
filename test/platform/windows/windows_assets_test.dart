import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('Windows icons contain all committed resolutions', () {
    for (final path in const [
      'windows/runner/resources/app_icon.ico',
      'assets/windows/busymax_tray.ico',
      'assets/windows/busymax_tray_offline.ico',
    ]) {
      final decoder = image.IcoDecoder();
      final info = decoder.startDecode(File(path).readAsBytesSync());
      expect(info, isNotNull, reason: path);
      expect(info!.numFrames, 9, reason: path);
      expect(
        {
          for (var index = 0; index < info.numFrames; index++)
            decoder.decodeFrame(index)!.width,
        },
        {16, 20, 24, 32, 40, 48, 64, 128, 256},
        reason: path,
      );
    }
  });

  test('MSIX assets match the packaged files and have transparent padding', () {
    const logicalSizes = {
      'StoreLogo.png': 50,
      'Square44x44Logo.png': 44,
      'Square150x150Logo.png': 150,
      'FileAssociationLogo.png': 44,
    };
    expect(
      Directory('windows/runner/resources/msix')
          .listSync()
          .map((entry) => entry.uri.pathSegments.last)
          .toSet(),
      logicalSizes.keys.toSet(),
    );
    for (final MapEntry(key: name, value: size) in logicalSizes.entries) {
      final path = 'windows/runner/resources/msix/$name';
      final asset = image.decodePng(File(path).readAsBytesSync());
      expect(asset, isNotNull, reason: path);
      expect(asset!.width, size, reason: path);
      expect(asset.height, size, reason: path);
      expect(asset.getPixel(0, 0).a, 0, reason: '$path needs safe padding');
    }
  });
}
