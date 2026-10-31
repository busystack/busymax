import 'package:http/http.dart' as http;
import 'package:busystack_dav/busystack_dav.dart' as shared;

/// An HTTP client that can terminate work which has not yet reached
/// [http.Abortable.abortTrigger], such as native connection establishment.
abstract interface class TerminatingHttpClient
    implements shared.TerminatingHttpClient {
  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  });
}
