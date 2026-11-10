import 'dart:io';

import 'package:busymax/src/dav/ical/ical_attachments.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/features/schedule/presentation/dav_attachment_save.dart';
import 'package:flutter_test/flutter_test.dart';
// file_selector exposes its official platform test seam separately.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FileSelectorPlatform original;
  late _SaveSelector selector;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'busymax-attach-save-test-',
    );
    original = FileSelectorPlatform.instance;
    selector = _SaveSelector();
    FileSelectorPlatform.instance = selector;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = original;
    await directory.delete(recursive: true);
  });

  test(
    'explicit save writes exact bytes with private mode and removes staging',
    () async {
      final path = '${directory.path}/selected.bin';
      selector.path = path;
      expect(await saveDavInlineAttachment(_attachment()), path);
      expect(await File(path).readAsBytes(), [0, 1, 2, 3]);
      expect(selector.suggestedName, 'café.bin');
      expect(await directory.list().length, 1);
      if (Platform.isLinux || Platform.isMacOS) {
        expect((await File(path).stat()).mode & 0x1ff, 0x180);
      }
    },
  );

  test(
    'confirmed regular-file replacement never leaves a partial destination',
    () async {
      final path = '${directory.path}/existing.bin';
      await File(path).writeAsString('original');
      selector.path = path;
      await saveDavInlineAttachment(_attachment());
      expect(await File(path).readAsBytes(), [0, 1, 2, 3]);
      expect(await directory.list().length, 1);
    },
  );

  test('cancel creates no files and performs no automatic save', () async {
    expect(await saveDavInlineAttachment(_attachment()), isNull);
    expect(await directory.list().isEmpty, isTrue);
  });

  test(
    'malformed content is rejected before showing a filesystem chooser',
    () async {
      selector.path = '${directory.path}/not-created';
      await expectLater(
        saveDavInlineAttachment(_attachment(value: 'AB==')),
        throwsFormatException,
      );
      expect(selector.calls, 0);
      expect(await directory.list().isEmpty, isTrue);
    },
  );

  test(
    'symlink destination cannot overwrite its target and staging is removed',
    () async {
      final originalFile = File('${directory.path}/original');
      await originalFile.writeAsString('untouched');
      final link = Link('${directory.path}/chosen');
      await link.create(originalFile.path);
      selector.path = link.path;
      await expectLater(
        saveDavInlineAttachment(_attachment()),
        throwsA(isA<FileSystemException>()),
      );
      expect(await originalFile.readAsString(), 'untouched');
      expect(await link.target(), originalFile.path);
      expect(await directory.list().length, 2);
    },
  );

  test(
    'directory destination is not replaced and failure removes staging',
    () async {
      final child = await Directory('${directory.path}/chosen').create();
      await File('${child.path}/keep').writeAsString('untouched');
      selector.path = child.path;
      await expectLater(
        saveDavInlineAttachment(_attachment()),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File('${child.path}/keep').readAsString(), 'untouched');
      expect(await directory.list().length, 1);
    },
  );

  for (final name in [
    '../outside',
    r'..\outside',
    '/tmp/outside',
    'CON.txt',
    'line^nbreak',
    'reversed\u202ebin',
    'x' * 256,
    '雪' * 100,
  ]) {
    test('untrusted filename cannot choose paths: $name', () {
      expect(
        davAttachmentFileName(_attachment(name: name)),
        'attachment-1.bin',
      );
    });
  }
}

IcalAttachment _attachment({
  String value = 'AAECAw==',
  String name = 'café.bin',
}) => readIcalAttachments(
  'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:one\r\n'
  'ATTACH;FMTTYPE=application/octet-stream;VALUE=BINARY;ENCODING=BASE64;FILENAME="$name":$value\r\n'
  'END:VEVENT\r\nEND:VCALENDAR\r\n',
  const IcalComponentKey(componentType: 'VEVENT', uid: 'one'),
).single;

class _SaveSelector extends FileSelectorPlatform {
  String? path;
  String? suggestedName;
  int calls = 0;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    calls++;
    suggestedName = options.suggestedName;
    return path == null ? null : FileSaveLocation(path!);
  }
}
