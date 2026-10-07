import 'package:busymax/src/schedule/event_attachment_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects only safe provider-supplied attachment URLs', () {
    final links = eventAttachmentLinks(const [
      {
        'fileUrl': 'https://drive.example/file',
        'title': 'Agenda',
        'mimeType': 'application/pdf',
      },
      {'fileUrl': 'https://drive.example/file', 'title': 'Duplicate'},
      'https://cloud.example/documents/notes.txt',
      'javascript:alert(1)',
      'https://user:password@cloud.example/secret',
      'data:text/plain;base64,YQ==',
    ]);
    expect(links.map((link) => link.name), ['Agenda', 'notes.txt']);
    expect(links.first.mimeType, 'application/pdf');
    expect(links.last.url, 'https://cloud.example/documents/notes.txt');
  });
}
