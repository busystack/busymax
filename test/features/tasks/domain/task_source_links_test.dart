import 'package:busymax/src/features/tasks/domain/task_source_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google supplied links are deduplicated and unsafe links omitted', () {
    final links = googleTaskSourceLinks(
      assignmentInfoJson:
          '{"surfaceType":"DOCUMENT","linkToTask":"https://docs.google.com/document/d/example"}',
      linksJson:
          '[{"description":"Document","link":"https://docs.google.com/document/d/example"},{"type":"generic","link":"https://example.test/source"},{"type":"email","link":"javascript:alert(1)"}]',
      webViewLink: 'https://tasks.google.com/task/example',
    );
    expect(links.map((link) => link.url), [
      'https://docs.google.com/document/d/example',
      'https://example.test/source',
      'https://tasks.google.com/task/example',
    ]);
    expect(links[1].label, 'generic');
  });

  test('malformed source metadata leaves the valid task page available', () {
    final links = googleTaskSourceLinks(
      assignmentInfoJson: '{broken',
      linksJson: '{broken',
      webViewLink: 'https://tasks.google.com/task/example',
    );
    expect(links.single.url, 'https://tasks.google.com/task/example');
  });
}
