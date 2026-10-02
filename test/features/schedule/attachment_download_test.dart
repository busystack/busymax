import 'package:busymax/src/features/schedule/presentation/attachment_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider filenames cannot select paths or control output', () {
    expect(safeAttachmentFileName(' Agenda.pdf '), 'Agenda.pdf');
    for (final value in [
      '',
      '.',
      '..',
      '../secret',
      r'..\secret',
      'report?.pdf',
      'report:part.pdf',
      'report.',
      'CON.txt',
      'lpt1',
      'line\nbreak',
      String.fromCharCodes(List.filled(256, 97)),
    ]) {
      expect(safeAttachmentFileName(value), isNull, reason: value);
    }
  });
}
