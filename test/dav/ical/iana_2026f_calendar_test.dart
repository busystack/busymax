import 'package:busymax/src/core/time/iana_time_zone_data.dart';
import 'package:busymax/src/core/time/tz_continuations_2026f.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_projection_mutations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const affected2026Zones = {
  'America/Vancouver': -7,
  'America/Edmonton': -6,
  'America/Winnipeg': -5,
  'America/Inuvik': -6,
  'Africa/Casablanca': 0,
  'Africa/El_Aaiun': 0,
  'America/Havana': -4,
};

void main() {
  test('transition and continuation data identify the same IANA release', () {
    expect(ianaTimeZoneVersion, '2026f');
    expect(tzContinuationVersion, ianaTimeZoneVersion);
  });
  for (final entry in affected2026Zones.entries) {
    final zone = entry.key, offset = entry.value;
    test(
      '$zone creates, uploads, edits and expands with the 2026f offset',
      () async {
        final object = buildDavEventObject(
          DavEventMutationInput(
            title: 'Current IANA',
            allDay: false,
            start: providerCivilDateTime(DateTime.utc(2026, 10, 31, 9)),
            end: providerCivilDateTime(DateTime.utc(2026, 10, 31, 10)),
            startTimeZone: zone,
          ),
        );
        final key = IcalComponentKey(componentType: 'VEVENT', uid: object.uid);
        final raw = DavMutationPatch(
          target: key,
          scope: DavMutationScope.recurrenceMaster,
          operations: [DavPatchOperation.setRaw('RRULE', 'FREQ=DAILY;COUNT=4')],
        ).applyTo(object.rawIcs, nowUtc: DateTime.utc(2026, 10, 30));
        String? stored;
        var puts = 0;
        final client = MockClient((request) async {
          if (request.method == 'PUT') {
            puts++;
            stored = request.body;
            expect(stored, contains('TZID:$zone'));
            return http.Response('', 201, headers: {'etag': '"$puts"'});
          }
          expect(request.method, 'GET');
          return http.Response(
            stored ?? '',
            stored == null ? 404 : 200,
            headers: {'etag': '"$puts"', 'content-type': 'text/calendar'},
          );
        });
        addTearDown(client.close);
        final authority = Uri.parse('https://example.test/');
        final service = DavConditionalMutationService(
          remoteClient: DavMutationHttpClient(
            transport: DavHttpTransport(
              client: client,
              profile: davProviderProfile(
                BusyProvider.caldav,
                caldavServer: authority,
              ),
              accountAuthority: authority,
            ),
            accountId: 'account',
            collectionId: 'collection',
            credential: DavBasicCredential(username: 'alice', password: 'test'),
          ),
        );
        const writable = CollectionCapabilities(
          canWriteContent: true,
          canAddMembers: true,
          supportsEvents: true,
        );
        final created = await service.create(
          collectionUri: authority.resolve('calendar/'),
          object: DavNewObject(
            uid: object.uid,
            initialMemberName: object.initialMemberName,
            rawIcs: raw,
            componentType: 'VEVENT',
          ),
          capabilities: writable,
          correlationId: 'iana-create',
        );
        expect(created.outcome, DavMutationOutcome.succeeded);
        final canonical = created.canonicalObject!;
        final edited = await service.update(
          hrefKey: canonical.hrefKey,
          uri: canonical.requestUri,
          baselineEtag: canonical.etag!,
          baselineRawIcs: canonical.rawIcsBody!,
          patch: DavMutationPatch(
            target: key,
            scope: DavMutationScope.recurrenceMaster,
            operations: [DavPatchOperation.setText('SUMMARY', 'Updated')],
          ),
          capabilities: writable,
          correlationId: 'iana-edit',
        );
        expect(edited.outcome, DavMutationOutcome.succeeded);
        expect(puts, 2);
        final semantic = IcalSemanticDocument.parse(
          edited.canonicalObject!.rawIcsBody!,
        );
        final resolver = IcalTimeZoneResolver.fromDocument(semantic);
        final occurrences = IcalRecurrenceExpander().expand(
          semantic,
          rangeStartUtc: DateTime.utc(2026, 10, 31),
          rangeEndUtc: DateTime.utc(2026, 11, 4),
        );
        expect(occurrences, hasLength(4));
        for (var i = 0; i < occurrences.length; i++) {
          expect(
            resolver.toUtc(occurrences[i].start),
            DateTime.utc(2026, 10, 31 + i, 9 - offset),
          );
        }
        expect(
          providerDateTimeAsUtcInstant('2026-11-02T09:00:00', zone),
          DateTime.utc(2026, 11, 2, 9 - offset),
        );
      },
    );
  }
}
