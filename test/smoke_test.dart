import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';

void main() {
  testWidgets('missing OAuth client ID screen is shown', (tester) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          buildConfigProvider.overrideWithValue(
            const BuildConfig(
              googleOAuthClientId: '',
              googleOAuthClientSecret: '',
              apiBaseUrl: 'https://tasks.googleapis.com',
              oauthAuthorizationEndpoint:
                  'https://accounts.google.com/o/oauth2/v2/auth',
              oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
              oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
            ),
          ),
        ],
        child: const BusyMaxApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set Up BusyMax'), findsNothing);
    expect(find.text('Connect accounts'), findsOneWidget);
    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Add Microsoft account'), findsOneWidget);
    expect(find.textContaining('GOOGLE_OAUTH_CLIENT_ID'), findsOneWidget);
    expect(
      find.text(
        'Connect Google and Microsoft accounts to sync calendars and tasks.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('Add all Google and Microsoft accounts'),
      findsNothing,
    );
    expect(find.text('Accounts'), findsNothing);
    expect(find.textContaining('sync task.'), findsNothing);
  });
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> json = <String, Object?>{};

  @override
  Future<Map<String, Object?>> load() async {
    return Map<String, Object?>.from(json);
  }

  @override
  Future<void> save(Map<String, Object?> json) async {
    this.json = Map<String, Object?>.from(json);
  }
}
