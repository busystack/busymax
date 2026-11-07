import 'package:flutter_test/flutter_test.dart';

import 'caldav_qa_targets.dart';

void main() {
  test('qualification defaults retain every pinned mandatory target', () {
    expect(selectCalDavQaTargets('').keys, [
      'Radicale 3.9.0',
      'Baikal 0.13.0',
      'BusyStack 0.1.0',
    ]);
  });
  test('an explicit partial native run retains endpoint semantics', () {
    final targets = selectCalDavQaTargets('radicale,baikal');
    expect(targets.keys, ['Radicale 3.9.0', 'Baikal 0.13.0']);
    expect(
      calDavQaSupportsMixed(Uri.parse('https://localhost:18448/dav/')),
      isFalse,
    );
    expect(calDavQaSupportsMixed(Uri.parse(targets.values.first)), isTrue);
  });
  test(
    'unrecognized selections fail rather than silently skipping coverage',
    () {
      expect(
        () => selectCalDavQaTargets('radicale,unrecognized'),
        throwsArgumentError,
      );
      expect(() => selectCalDavQaTargets(','), throwsArgumentError);
    },
  );
}
