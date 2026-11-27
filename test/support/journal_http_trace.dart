import 'dart:collection';

import 'package:http/http.dart' as http;

/// Keeps only methods, statuses and elapsed times for a failed journal check.
final class JournalHttpTrace {
  final _recent = Queue<String>();

  Future<http.StreamedResponse> send(
    http.Client client,
    http.BaseRequest request,
  ) async {
    final timer = Stopwatch()..start();
    _add('${request.method} dispatched');
    try {
      final response = await client.send(request);
      _add(
        '${request.method} ${response.statusCode} '
        'after ${timer.elapsedMilliseconds}ms',
      );
      return response;
    } on Object catch (error) {
      _add(
        '${request.method} ${error.runtimeType} '
        'after ${timer.elapsedMilliseconds}ms',
      );
      rethrow;
    }
  }

  @override
  String toString() => _recent.join(', ');

  void clear() => _recent.clear();

  void _add(String outcome) {
    if (_recent.length == 20) _recent.removeFirst();
    _recent.add(outcome);
  }
}
