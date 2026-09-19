import 'package:http/http.dart' as http;

/// An HTTP client that can terminate work which has not yet reached
/// [http.Abortable.abortTrigger], such as native connection establishment.
abstract interface class TerminatingHttpClient implements http.Client {
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  });
}
