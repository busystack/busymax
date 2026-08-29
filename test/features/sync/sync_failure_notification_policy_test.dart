import 'dart:async';
import 'dart:io';

import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/features/sync/sync_failure_notification_policy.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_error.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('sync failure notification policy', () {
    test('suppresses transport failures', () {
      final failures = <Object>[
        const NetworkUnavailableException(),
        const SocketException('Network is unreachable'),
        TimeoutException('Request timed out'),
        http.ClientException(
          'Connection failed',
          Uri.parse('https://example.invalid'),
        ),
      ];

      for (final failure in failures) {
        expect(
          syncFailureNotificationDisposition(failure),
          SyncFailureNotificationDisposition.suppressed,
          reason: failure.runtimeType.toString(),
        );
      }
    });

    test('suppresses retryable provider failures', () {
      final failures = <Object>[
        const TaskRemoteError(
          statusCode: 503,
          code: 'unavailable',
          message: 'Unavailable',
          retryable: true,
        ),
        const GoogleCalendarApiError(
          statusCode: 503,
          code: 'backendError',
          message: 'Unavailable',
        ),
        const MicrosoftCalendarApiError(
          statusCode: 429,
          code: 'TooManyRequests',
          message: 'Slow down',
        ),
        const MicrosoftTodoApiError(
          statusCode: 500,
          code: 'InternalServerError',
          message: 'Unavailable',
        ),
        const OAuthRefreshException(
          'OAuthRefreshFailed',
          'Unavailable',
          statusCode: 503,
        ),
      ];

      for (final failure in failures) {
        expect(
          syncFailureNotificationDisposition(failure),
          SyncFailureNotificationDisposition.suppressed,
          reason: failure.runtimeType.toString(),
        );
      }
    });

    test('suppresses transient DAV failures, including aggregates', () {
      const networkFailure = DavException(
        kind: DavErrorKind.network,
        code: 'DavNetworkFailure',
        safeMessage: 'The DAV server could not be reached.',
      );

      expect(
        syncFailureNotificationDisposition(networkFailure),
        SyncFailureNotificationDisposition.suppressed,
      );
      expect(
        syncFailureNotificationDisposition(
          DavAccountSyncException([networkFailure]),
        ),
        SyncFailureNotificationDisposition.suppressed,
      );
    });

    test('classifies failures that require account action', () {
      final cases =
          <({Object failure, SyncFailureNotificationDisposition expected})>[
            (
              failure: const OAuthException(
                'OAuthMissingToken',
                'No token is available.',
              ),
              expected: SyncFailureNotificationDisposition.reconnectRequired,
            ),
            (
              failure: const OAuthRefreshException(
                'OAuthRefreshFailed',
                'Invalid grant',
                statusCode: 400,
              ),
              expected: SyncFailureNotificationDisposition.reconnectRequired,
            ),
            (
              failure: const TaskRemoteError(
                statusCode: 401,
                message: 'Unauthorized',
              ),
              expected: SyncFailureNotificationDisposition.reconnectRequired,
            ),
            (
              failure: const TaskRemoteError(
                statusCode: 403,
                message: 'Forbidden',
              ),
              expected: SyncFailureNotificationDisposition.permissionChanged,
            ),
            (
              failure: const DavException(
                kind: DavErrorKind.protocol,
                code: 'DavUnsupportedServer',
                safeMessage: 'Unsupported server.',
              ),
              expected: SyncFailureNotificationDisposition.unsupportedProvider,
            ),
          ];

      for (final testCase in cases) {
        expect(
          syncFailureNotificationDisposition(testCase.failure),
          testCase.expected,
          reason: testCase.failure.runtimeType.toString(),
        );
      }
    });

    test('uses the most actionable DAV aggregate failure', () {
      final failure = DavAccountSyncException(const [
        DavException(
          kind: DavErrorKind.network,
          code: 'DavNetworkFailure',
          safeMessage: 'Offline.',
        ),
        DavException(
          kind: DavErrorKind.authentication,
          code: 'DavAuthRejected',
          safeMessage: 'Sign in again.',
        ),
      ]);

      expect(
        syncFailureNotificationDisposition(failure),
        SyncFailureNotificationDisposition.reconnectRequired,
      );
    });

    test('maps unknown failures to a controlled generic message', () {
      expect(
        syncFailureNotificationDisposition(
          StateError('Internal database details'),
        ),
        SyncFailureNotificationDisposition.temporarilyUnavailable,
      );
    });
  });
}
