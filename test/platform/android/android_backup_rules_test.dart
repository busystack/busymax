import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  for (final rules in [
    ('backup_rules.xml', 'full-backup-content'),
    ('data_extraction_rules.xml', 'cloud-backup'),
    ('data_extraction_rules.xml', 'device-transfer'),
  ]) {
    test(
      '${rules.$1} ${rules.$2} excludes private support files and SQLite sidecars',
      () {
        final xml = XmlDocument.parse(
          File('android/app/src/main/res/xml/${rules.$1}').readAsStringSync(),
        );
        final section = xml.findAllElements(rules.$2).single;
        bool excluded(String domain, String path) =>
            section.findElements('exclude').any((rule) {
              if (rule.getAttribute('domain') != domain) return false;
              final root = rule.getAttribute('path')!;
              return root == '.' || root == path || path.startsWith('$root/');
            });
        // path_provider_android returns getFilesDir() for application support;
        // BusyMax opens busymax.sqlite there, outside Android's database domain.
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          expect(
            excluded('file', 'busymax.sqlite$suffix'),
            isTrue,
            reason: suffix,
          );
        }
        expect(excluded('database', 'plugin.db'), isTrue);
        expect(excluded('sharedpref', 'settings.xml'), isTrue);
        expect(excluded('root', 'flutter_secure_storage'), isTrue);
      },
    );
  }
}
