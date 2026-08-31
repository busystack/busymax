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

  test(
    'MSIX visual assets have every declared scale and transparent padding',
    () {
      const logicalSizes = {
        'StoreLogo': 50,
        'Square44x44Logo': 44,
        'Square150x150Logo': 150,
        'FileAssociation': 44,
      };
      const scales = [100, 125, 150, 200, 400];
      for (final MapEntry(key: name, value: logicalSize)
          in logicalSizes.entries) {
        for (final scale in scales) {
          final path = 'windows/runner/resources/msix/$name.scale-$scale.png';
          final asset = image.decodePng(File(path).readAsBytesSync());
          expect(asset, isNotNull, reason: path);
          final expectedSize = (logicalSize * scale / 100).round();
          expect(asset!.width, expectedSize, reason: path);
          expect(asset.height, expectedSize, reason: path);
          expect(asset.getPixel(0, 0).a, 0, reason: '$path needs safe padding');
        }
      }
    },
  );
}
