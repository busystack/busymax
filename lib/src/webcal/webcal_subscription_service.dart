import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/secrets/secret_store.dart';
import '../dav/dav_errors.dart';
import '../db/app_database.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/notifications/notification_schedule_service.dart';
import '../ical/ical_event_projection.dart';
import '../ical/ical_ingestion.dart';
import '../providers/busy_provider.dart';
import 'webcal_http_client.dart';
import 'webcal_uri.dart';

const webCalParserVersion = 1;
const webCalProjectionVersion = 2;

enum WebCalRefreshMode { automatic, hourly, sixHours, daily }

extension WebCalRefreshModeStorage on WebCalRefreshMode {
  String get storageValue => switch (this) {
    WebCalRefreshMode.automatic => 'automatic',
    WebCalRefreshMode.hourly => 'hourly',
    WebCalRefreshMode.sixHours => 'six_hours',
    WebCalRefreshMode.daily => 'daily',
  };

  static WebCalRefreshMode parse(String value) => switch (value) {
    'hourly' => WebCalRefreshMode.hourly,
    'six_hours' => WebCalRefreshMode.sixHours,
    'daily' => WebCalRefreshMode.daily,
    _ => WebCalRefreshMode.automatic,
  };
}

final class WebCalSubscriptionEntity {
  const WebCalSubscriptionEntity({
    required this.id,
    required this.accountId,
    required this.calendarSourceId,
    required this.name,
    required this.color,
    required this.safeOrigin,
    required this.refreshMode,
    required this.nextRefreshAtUtc,
    required this.lastSuccessfulSyncAtUtc,
    required this.lastFailureCode,
    required this.lastFailureHttpStatus,
    required this.consecutiveFailureCount,
  });

  final String id;
  final String accountId;
  final String calendarSourceId;
  final String name;
  final String? color;
  final String safeOrigin;
  final WebCalRefreshMode refreshMode;
  final DateTime nextRefreshAtUtc;
  final DateTime? lastSuccessfulSyncAtUtc;
  final String? lastFailureCode;
  final int? lastFailureHttpStatus;
  final int consecutiveFailureCount;
}

final class WebCalSubscriptionException implements Exception {
  const WebCalSubscriptionException(this.code, {this.httpStatus});

  final String code;
  final int? httpStatus;

  @override
  String toString() => 'WebCalSubscriptionException($code)';
}

final class WebCalSubscriptionService {
  WebCalSubscriptionService({
    required AppDatabase database,
    required SecretStore secretStore,
    required WebCalHttpTransport httpTransport,
    NotificationScheduleService? notificationScheduleService,
    Future<void> Function()? onNotificationScheduleChanged,
    DateTime Function()? nowUtc,
    String Function()? idFactory,
    IcalEventProjector? eventProjector,
  }) : _database = database,
       _secretStore = secretStore,
       _httpTransport = httpTransport,
       _notificationScheduleService =
           notificationScheduleService ??
           NotificationScheduleService(database: database),
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _idFactory = idFactory ?? const Uuid().v4,
       _eventProjector = eventProjector ?? IcalEventProjector();

  final AppDatabase _database;
  final SecretStore _secretStore;
  final WebCalHttpTransport _httpTransport;
  final NotificationScheduleService _notificationScheduleService;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final DateTime Function() _nowUtc;
  final String Function() _idFactory;
  final IcalEventProjector _eventProjector;
  final Map<String, Future<void>> _operationTails = {};

  Stream<List<WebCalSubscriptionEntity>> watchSubscriptions() {
    final query = _database.select(_database.webCalSubscriptions).join([
      innerJoin(
        _database.calendarSources,
        _database.calendarSources.id.equalsExp(
          _database.webCalSubscriptions.calendarSourceId,
        ),
      ),
    ])..orderBy([OrderingTerm.asc(_database.calendarSources.summary)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          _entity(
            row.readTable(_database.webCalSubscriptions),
            row.readTable(_database.calendarSources),
          ),
      ],
    );
  }

  Future<List<WebCalSubscriptionEntity>> listSubscriptions() async {
    final rows = await (_database.select(_database.webCalSubscriptions).join([
      innerJoin(
        _database.calendarSources,
        _database.calendarSources.id.equalsExp(
          _database.webCalSubscriptions.calendarSourceId,
        ),
      ),
    ])..orderBy([OrderingTerm.asc(_database.calendarSources.summary)])).get();
    return [
      for (final row in rows)
        _entity(
          row.readTable(_database.webCalSubscriptions),
          row.readTable(_database.calendarSources),
        ),
    ];
  }

  Future<String> addSubscription({
    required String subscriptionUrl,
    String? localName,
    String? color,
    WebCalRefreshMode refreshMode = WebCalRefreshMode.automatic,
  }) async {
    final normalized = normalizeWebCalUri(subscriptionUrl);
    final duplicate =
        await (_database.select(_database.webCalSubscriptions)..where(
              (row) => row.feedFingerprint.equals(normalized.fingerprint),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      throw const WebCalSubscriptionException('WebCalDuplicateSubscription');
    }
    final response = await _httpTransport.get(normalized.uri);
    final candidate = _prepareAcceptedResponse(
      response,
      secretValues: {
        normalized.credentialUri,
        normalized.uri.toString(),
        response.finalUri.toString(),
      },
    );
    final subscriptionId = _idFactory();
    final accountId = 'webcal-account-$subscriptionId';
    final sourceId = 'webcal-calendar-$subscriptionId';
    final name = _subscriptionName(localName);
    final now = _nowUtc();
    final targetFingerprint = webCalUriFingerprint(response.finalUri);
    final secret = WebCalSecretRecord(
      normalizedSubscriptionUri: normalized.credentialUri,
      validatorTargetUri: response.finalUri,
    );
    await _secretStore.saveCredential(accountId, secret);
    try {
      await _database.transaction(() async {
        await _database
            .into(_database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: accountId,
                provider: BusyProvider.webCal.storageValue,
                authority: normalized.safeOrigin.toString(),
                providerAccountId: normalized.fingerprint,
                credentialKind: CredentialKind.webCalSubscription.storageValue,
                displayName: Value(name),
                email: const Value(null),
                tenantId: const Value(null),
                authState: const Value(accountAuthStateSignedIn),
                calendarsEnabled: const Value(true),
                tasksEnabled: const Value(false),
                grantedScopes: const Value(''),
                createdAtUtc: now.toIso8601String(),
                updatedAtUtc: now.toIso8601String(),
                lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
              ),
            );
        await _database
            .into(_database.calendarSources)
            .insert(
              CalendarSourcesCompanion.insert(
                id: sourceId,
                accountId: accountId,
                provider: BusyProvider.webCal.storageValue,
                providerCalendarId: subscriptionId,
                summary: name,
                primaryCalendar: const Value(false),
                selected: const Value(true),
                hidden: const Value(false),
                readOnly: const Value(true),
                backgroundColor: Value(_normalizedColor(color)),
                accessRole: const Value('reader'),
                rawJson: Value(jsonEncode(const {'transport': 'webcal'})),
                createdAtLocal: now.millisecondsSinceEpoch,
                updatedAtLocal: now.millisecondsSinceEpoch,
              ),
            );
        await _database
            .into(_database.webCalSubscriptions)
            .insert(
              WebCalSubscriptionsCompanion.insert(
                id: subscriptionId,
                accountId: accountId,
                calendarSourceId: sourceId,
                feedFingerprint: normalized.fingerprint,
                safeOrigin: normalized.safeOrigin.toString(),
                validatorTargetFingerprint: Value(targetFingerprint),
                etag: Value(response.etag),
                lastModified: Value(response.lastModified),
                contentType: Value(response.contentType),
                snapshotIcsBody: candidate.snapshot,
                rawBodyHash: candidate.rawBodyHash,
                semanticHash: candidate.semanticHash,
                refreshMode: refreshMode.storageValue,
                serverRefreshIntervalSeconds: Value(
                  candidate.ingestion.serverRefreshIntervalSeconds,
                ),
                nextRefreshAtUtc: _nextRefresh(
                  now,
                  mode: refreshMode,
                  serverSeconds:
                      candidate.ingestion.serverRefreshIntervalSeconds,
                  subscriptionId: subscriptionId,
                ).toIso8601String(),
                lastCheckedAtUtc: Value(now.toIso8601String()),
                lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
                lastChangedAtUtc: Value(now.toIso8601String()),
                parserVersion: const Value(webCalParserVersion),
                projectionVersion: const Value(webCalProjectionVersion),
                projectionRangeStartUtc: Value(
                  candidate.projectionRangeStartUtc.toIso8601String(),
                ),
                projectionRangeEndUtc: Value(
                  candidate.projectionRangeEndUtc.toIso8601String(),
                ),
                createdAtUtc: now.toIso8601String(),
                updatedAtUtc: now.toIso8601String(),
              ),
            );
        await _replaceEvents(
          subscriptionId: subscriptionId,
          accountId: accountId,
          sourceId: sourceId,
          color: _normalizedColor(color),
          projections: candidate.projections,
          now: now,
        );
      });
    } on Object {
      await _secretStore.deleteCredential(accountId);
      rethrow;
    }
    await _rebuildNotifications(accountId);
    return subscriptionId;
  }

  Future<void> refreshSubscription(
    String subscriptionId, {
    bool force = false,
  }) => _serializeSubscriptionOperation(
    subscriptionId,
    () => _refreshSubscription(subscriptionId, force: force),
  );

  Future<void> _serializeSubscriptionOperation(
    String subscriptionId,
    Future<void> Function() operation,
  ) {
    final previous = _operationTails[subscriptionId] ?? Future.value();
    final next = previous.catchError((Object _) {}).then((_) => operation());
    _operationTails[subscriptionId] = next;
    return next.whenComplete(() {
      if (identical(_operationTails[subscriptionId], next)) {
        _operationTails.remove(subscriptionId);
      }
    });
  }

  Future<void> refreshAccount(String accountId, {required bool force}) async {
    final subscription = await (_database.select(
      _database.webCalSubscriptions,
    )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();
    if (subscription == null) return;
    await refreshSubscription(subscription.id, force: force);
  }

  Future<void> _refreshSubscription(
    String subscriptionId, {
    required bool force,
  }) async {
    final subscription = await (_database.select(
      _database.webCalSubscriptions,
    )..where((row) => row.id.equals(subscriptionId))).getSingleOrNull();
    if (subscription == null) return;
    final now = _nowUtc();
    final due = DateTime.tryParse(subscription.nextRefreshAtUtc)?.toUtc();
    if (!force && due != null && due.isAfter(now)) return;
    final secret = await _secretStore.readCredential(subscription.accountId);
    if (secret is! WebCalSecretRecord) {
      await _recordFailure(
        subscription,
        const WebCalSubscriptionException('WebCalSecretUnavailable'),
      );
      return;
    }
    final target = secret.validatorTargetUri;
    final subscriptionUri = Uri.parse(secret.normalizedSubscriptionUri);
    final targetFingerprint = target == null
        ? null
        : webCalUriFingerprint(target);
    final validatorsBound =
        target != null &&
        targetFingerprint == subscription.validatorTargetFingerprint;
    try {
      final response = await _httpTransport.get(
        subscriptionUri,
        validators: validatorsBound
            ? WebCalHttpValidators(
                etag: subscription.etag,
                lastModified: subscription.lastModified,
              )
            : const WebCalHttpValidators(),
        validatorTarget: validatorsBound ? target : null,
      );
      if (response.statusCode == 304) {
        if (!response.conditionalRequestSent ||
            !validatorsBound ||
            response.finalUri != target ||
            subscription.snapshotIcsBody.isEmpty) {
          throw const WebCalSubscriptionException('WebCalInvalidNotModified');
        }
        final cachedProjection = _prepareCachedProjectionForRefresh(
          subscription,
          now,
        );
        final source = cachedProjection == null
            ? null
            : await (_database.select(_database.calendarSources)..where(
                    (row) => row.id.equals(subscription.calendarSourceId),
                  ))
                  .getSingle();
        await _database.transaction(() async {
          if (cachedProjection != null) {
            await _replaceEvents(
              subscriptionId: subscription.id,
              accountId: subscription.accountId,
              sourceId: subscription.calendarSourceId,
              color: source!.backgroundColor,
              projections: cachedProjection.projections,
              now: now,
            );
          }
          await (_database.update(
            _database.webCalSubscriptions,
          )..where((row) => row.id.equals(subscription.id))).write(
            WebCalSubscriptionsCompanion(
              etag: Value(response.etag ?? subscription.etag),
              lastModified: Value(
                response.lastModified ?? subscription.lastModified,
              ),
              lastCheckedAtUtc: Value(now.toIso8601String()),
              lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
              consecutiveFailureCount: const Value(0),
              lastFailureCode: const Value(null),
              lastFailureHttpStatus: const Value(null),
              parserVersion: cachedProjection == null
                  ? const Value.absent()
                  : const Value(webCalParserVersion),
              projectionVersion: cachedProjection == null
                  ? const Value.absent()
                  : const Value(webCalProjectionVersion),
              projectionRangeStartUtc: cachedProjection == null
                  ? const Value.absent()
                  : Value(cachedProjection.rangeStartUtc.toIso8601String()),
              projectionRangeEndUtc: cachedProjection == null
                  ? const Value.absent()
                  : Value(cachedProjection.rangeEndUtc.toIso8601String()),
              nextRefreshAtUtc: Value(
                _nextRefresh(
                  now,
                  mode: WebCalRefreshModeStorage.parse(
                    subscription.refreshMode,
                  ),
                  serverSeconds: subscription.serverRefreshIntervalSeconds,
                  subscriptionId: subscription.id,
                ).toIso8601String(),
              ),
              updatedAtUtc: Value(now.toIso8601String()),
            ),
          );
          await (_database.update(
            _database.accounts,
          )..where((row) => row.id.equals(subscription.accountId))).write(
            AccountsCompanion(
              lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
              updatedAtUtc: Value(now.toIso8601String()),
            ),
          );
        });
        if (cachedProjection != null) {
          await _rebuildNotifications(subscription.accountId);
        }
        return;
      }
      final candidate = _prepareAcceptedResponse(
        response,
        secretValues: {
          secret.normalizedSubscriptionUri,
          subscriptionUri.toString(),
          response.finalUri.toString(),
        },
      );
      final source =
          await (_database.select(_database.calendarSources)
                ..where((row) => row.id.equals(subscription.calendarSourceId)))
              .getSingle();
      final nextSecret = secret.copyWithValidatorTarget(response.finalUri);
      await _secretStore.saveCredential(subscription.accountId, nextSecret);
      try {
        await _database.transaction(() async {
          await _replaceEvents(
            subscriptionId: subscription.id,
            accountId: subscription.accountId,
            sourceId: subscription.calendarSourceId,
            color: source.backgroundColor,
            projections: candidate.projections,
            now: now,
          );
          await (_database.update(
            _database.webCalSubscriptions,
          )..where((row) => row.id.equals(subscription.id))).write(
            WebCalSubscriptionsCompanion(
              validatorTargetFingerprint: Value(
                webCalUriFingerprint(response.finalUri),
              ),
              etag: Value(response.etag),
              lastModified: Value(response.lastModified),
              contentType: Value(response.contentType),
              snapshotIcsBody: Value(candidate.snapshot),
              rawBodyHash: Value(candidate.rawBodyHash),
              semanticHash: Value(candidate.semanticHash),
              serverRefreshIntervalSeconds: Value(
                candidate.ingestion.serverRefreshIntervalSeconds,
              ),
              lastCheckedAtUtc: Value(now.toIso8601String()),
              lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
              lastChangedAtUtc: Value(
                candidate.semanticHash == subscription.semanticHash
                    ? subscription.lastChangedAtUtc
                    : now.toIso8601String(),
              ),
              consecutiveFailureCount: const Value(0),
              lastFailureCode: const Value(null),
              lastFailureHttpStatus: const Value(null),
              generation: Value(subscription.generation + 1),
              parserVersion: const Value(webCalParserVersion),
              projectionVersion: const Value(webCalProjectionVersion),
              projectionRangeStartUtc: Value(
                candidate.projectionRangeStartUtc.toIso8601String(),
              ),
              projectionRangeEndUtc: Value(
                candidate.projectionRangeEndUtc.toIso8601String(),
              ),
              nextRefreshAtUtc: Value(
                _nextRefresh(
                  now,
                  mode: WebCalRefreshModeStorage.parse(
                    subscription.refreshMode,
                  ),
                  serverSeconds:
                      candidate.ingestion.serverRefreshIntervalSeconds,
                  subscriptionId: subscription.id,
                ).toIso8601String(),
              ),
              updatedAtUtc: Value(now.toIso8601String()),
            ),
          );
          await (_database.update(
            _database.accounts,
          )..where((row) => row.id.equals(subscription.accountId))).write(
            AccountsCompanion(
              authState: const Value(accountAuthStateSignedIn),
              lastSuccessfulSyncAtUtc: Value(now.toIso8601String()),
              updatedAtUtc: Value(now.toIso8601String()),
            ),
          );
        });
      } on Object {
        await _secretStore.saveCredential(subscription.accountId, secret);
        rethrow;
      }
      await _rebuildNotifications(subscription.accountId);
    } on Object catch (error) {
      await _recordFailure(subscription, error);
      rethrow;
    }
  }

  Future<void> renameSubscription(String subscriptionId, String name) {
    final trimmed = _subscriptionName(name);
    return _serializeSubscriptionOperation(
      subscriptionId,
      () => _renameSubscription(subscriptionId, trimmed),
    );
  }

  Future<void> _renameSubscription(
    String subscriptionId,
    String trimmed,
  ) async {
    final subscription = await _subscription(subscriptionId);
    final now = _nowUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.accounts,
      )..where((row) => row.id.equals(subscription.accountId))).write(
        AccountsCompanion(
          displayName: Value(trimmed),
          updatedAtUtc: Value(now.toIso8601String()),
        ),
      );
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(subscription.calendarSourceId))).write(
        CalendarSourcesCompanion(
          summary: Value(trimmed),
          updatedAtLocal: Value(now.millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<void> changeSubscriptionColor(String subscriptionId, String? color) {
    final normalized = _normalizedColor(color);
    return _serializeSubscriptionOperation(
      subscriptionId,
      () => _changeSubscriptionColor(subscriptionId, normalized),
    );
  }

  Future<void> _changeSubscriptionColor(
    String subscriptionId,
    String? normalized,
  ) async {
    final subscription = await _subscription(subscriptionId);
    final now = _nowUtc().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(subscription.calendarSourceId))).write(
        CalendarSourcesCompanion(
          backgroundColor: Value(normalized),
          updatedAtLocal: Value(now),
        ),
      );
      await (_database.update(_database.calendarEvents)..where(
            (row) => row.calendarSourceId.equals(subscription.calendarSourceId),
          ))
          .write(
            CalendarEventsCompanion(
              colorHex: Value(normalized),
              updatedAtLocal: Value(now),
            ),
          );
    });
  }

  Future<void> changeRefreshMode(
    String subscriptionId,
    WebCalRefreshMode mode,
  ) => _serializeSubscriptionOperation(
    subscriptionId,
    () => _changeRefreshMode(subscriptionId, mode),
  );

  Future<void> _changeRefreshMode(
    String subscriptionId,
    WebCalRefreshMode mode,
  ) async {
    final subscription = await _subscription(subscriptionId);
    final now = _nowUtc();
    await (_database.update(
      _database.webCalSubscriptions,
    )..where((row) => row.id.equals(subscription.id))).write(
      WebCalSubscriptionsCompanion(
        refreshMode: Value(mode.storageValue),
        nextRefreshAtUtc: Value(
          _nextRefresh(
            now,
            mode: mode,
            serverSeconds: subscription.serverRefreshIntervalSeconds,
            subscriptionId: subscription.id,
          ).toIso8601String(),
        ),
        updatedAtUtc: Value(now.toIso8601String()),
      ),
    );
  }

  Future<void> unsubscribe(String subscriptionId) =>
      _serializeSubscriptionOperation(
        subscriptionId,
        () => _unsubscribe(subscriptionId),
      );

  Future<void> _unsubscribe(String subscriptionId) async {
    final subscription = await _subscription(subscriptionId);
    final secret = await _secretStore.readCredential(subscription.accountId);
    await _secretStore.deleteCredential(subscription.accountId);
    try {
      await _database.transaction(() async {
        await (_database.delete(
          _database.accounts,
        )..where((row) => row.id.equals(subscription.accountId))).go();
      });
    } on Object {
      if (secret != null) {
        await _secretStore.saveCredential(subscription.accountId, secret);
      }
      rethrow;
    }
    await _onNotificationScheduleChanged?.call();
  }

  Future<WebCalSubscription> _subscription(String id) async {
    final value = await (_database.select(
      _database.webCalSubscriptions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (value == null) {
      throw const WebCalSubscriptionException('WebCalSubscriptionNotFound');
    }
    return value;
  }

  Future<void> ensureProjectionCoverage({
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) async {
    final requestedStart = rangeStartUtc.toUtc();
    final requestedEnd = rangeEndUtc.toUtc();
    if (!requestedEnd.isAfter(requestedStart)) return;
    final subscriptions = await _database
        .select(_database.webCalSubscriptions)
        .get();
    for (final subscription in subscriptions) {
      if (!_projectionCoverageRequired(
        subscription,
        requestedStart: requestedStart,
        requestedEnd: requestedEnd,
      )) {
        continue;
      }
      await _serializeSubscriptionOperation(
        subscription.id,
        () => _ensureProjectionCoverage(
          subscription.id,
          requestedStart: requestedStart,
          requestedEnd: requestedEnd,
        ),
      );
    }
  }

  Future<void> _ensureProjectionCoverage(
    String subscriptionId, {
    required DateTime requestedStart,
    required DateTime requestedEnd,
  }) async {
    final subscription = await (_database.select(
      _database.webCalSubscriptions,
    )..where((row) => row.id.equals(subscriptionId))).getSingleOrNull();
    if (subscription == null ||
        !_projectionCoverageRequired(
          subscription,
          requestedStart: requestedStart,
          requestedEnd: requestedEnd,
        )) {
      return;
    }
    final range = _projectionRange(
      _nowUtc(),
      requestedStart: requestedStart,
      requestedEnd: requestedEnd,
    );
    final projection = _prepareCachedProjection(
      subscription.snapshotIcsBody,
      range: range,
    );
    final source =
        await (_database.select(_database.calendarSources)
              ..where((row) => row.id.equals(subscription.calendarSourceId)))
            .getSingleOrNull();
    if (source == null) return;
    final now = _nowUtc();
    await _database.transaction(() async {
      await _replaceEvents(
        subscriptionId: subscription.id,
        accountId: subscription.accountId,
        sourceId: subscription.calendarSourceId,
        color: source.backgroundColor,
        projections: projection.projections,
        now: now,
      );
      await (_database.update(
        _database.webCalSubscriptions,
      )..where((row) => row.id.equals(subscription.id))).write(
        WebCalSubscriptionsCompanion(
          parserVersion: const Value(webCalParserVersion),
          projectionVersion: const Value(webCalProjectionVersion),
          projectionRangeStartUtc: Value(
            projection.rangeStartUtc.toIso8601String(),
          ),
          projectionRangeEndUtc: Value(
            projection.rangeEndUtc.toIso8601String(),
          ),
          updatedAtUtc: Value(now.toIso8601String()),
        ),
      );
    });
    await _rebuildNotifications(subscription.accountId);
  }

  _PreparedProjection? _prepareCachedProjectionForRefresh(
    WebCalSubscription subscription,
    DateTime now,
  ) {
    final minimumFuture = DateTime.utc(now.year + 1, now.month, now.day);
    if (!_projectionCoverageRequired(
      subscription,
      requestedStart: now,
      requestedEnd: minimumFuture,
      includePadding: false,
    )) {
      return null;
    }
    return _prepareCachedProjection(
      subscription.snapshotIcsBody,
      range: _projectionRange(now),
    );
  }

  bool _projectionCoverageRequired(
    WebCalSubscription subscription, {
    required DateTime requestedStart,
    required DateTime requestedEnd,
    bool includePadding = true,
  }) {
    if (subscription.parserVersion != webCalParserVersion ||
        subscription.projectionVersion != webCalProjectionVersion) {
      return true;
    }
    final storedStart = DateTime.tryParse(
      subscription.projectionRangeStartUtc ?? '',
    )?.toUtc();
    final storedEnd = DateTime.tryParse(
      subscription.projectionRangeEndUtc ?? '',
    )?.toUtc();
    if (storedStart == null || storedEnd == null) return true;
    final requiredStart = includePadding
        ? requestedStart.subtract(const Duration(days: 30))
        : requestedStart;
    final requiredEnd = includePadding
        ? requestedEnd.add(const Duration(days: 90))
        : requestedEnd;
    return storedStart.isAfter(requiredStart) ||
        storedEnd.isBefore(requiredEnd);
  }

  _PreparedProjection _prepareCachedProjection(
    String snapshot, {
    required ({DateTime start, DateTime end}) range,
  }) {
    final ingestion = IcalIngestion.parseString(
      snapshot,
      policy: IcalIngestionPolicy.webCal,
    );
    final projections = <ProjectedIcalEvent>[];
    try {
      for (final set in ingestion.recurrenceSets) {
        projections.addAll(
          _eventProjector.project(
            set,
            rangeStartUtc: range.start,
            rangeEndUtc: range.end,
            transport: 'webcal',
          ),
        );
      }
    } on DavException catch (error) {
      throw WebCalSubscriptionException(error.code);
    }
    return _PreparedProjection(
      ingestion: ingestion,
      projections: projections,
      rangeStartUtc: range.start,
      rangeEndUtc: range.end,
    );
  }

  _PreparedCandidate _prepareAcceptedResponse(
    WebCalHttpResponse response, {
    required Iterable<String> secretValues,
  }) {
    if (response.finalUri.scheme != 'https' ||
        response.finalUri.host.isEmpty ||
        response.finalUri.userInfo.isNotEmpty ||
        response.finalUri.hasFragment) {
      throw const WebCalSubscriptionException('WebCalUnsafeResponseTarget');
    }
    if (response.statusCode != 200 || response.body == null) {
      throw WebCalSubscriptionException(
        'WebCalHttpStatus',
        httpStatus: response.statusCode,
      );
    }
    final contentType = response.contentType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType == 'text/html' ||
        contentType == 'application/json' ||
        (contentType != null &&
            contentType.isNotEmpty &&
            contentType != 'text/calendar' &&
            contentType != 'text/plain' &&
            contentType != 'application/octet-stream')) {
      throw const WebCalSubscriptionException('WebCalContentTypeRejected');
    }
    final body = response.body!;
    final leading = utf8
        .decode(
          body.take(math.min(body.length, 64)).toList(),
          allowMalformed: true,
        )
        .trimLeft()
        .toLowerCase();
    if (leading.startsWith('<!doctype html') ||
        leading.startsWith('<html') ||
        leading.startsWith('{') ||
        leading.startsWith('[')) {
      throw const WebCalSubscriptionException('WebCalContentRejected');
    }
    final originalIngestion = IcalIngestion.parseBytes(
      body,
      policy: IcalIngestionPolicy.webCal,
    );
    final snapshot = sanitizedCanonicalSnapshot(
      originalIngestion.document,
      secretValues: secretValues,
    );
    final projection = _prepareCachedProjection(
      snapshot,
      range: _projectionRange(_nowUtc()),
    );
    return _PreparedCandidate(
      ingestion: projection.ingestion,
      projections: projection.projections,
      snapshot: snapshot,
      rawBodyHash: sha256.convert(body).toString(),
      semanticHash: sha256.convert(utf8.encode(snapshot)).toString(),
      projectionRangeStartUtc: projection.rangeStartUtc,
      projectionRangeEndUtc: projection.rangeEndUtc,
    );
  }

  Future<void> _replaceEvents({
    required String subscriptionId,
    required String accountId,
    required String sourceId,
    required String? color,
    required List<ProjectedIcalEvent> projections,
    required DateTime now,
  }) async {
    await (_database.delete(
      _database.calendarEvents,
    )..where((row) => row.calendarSourceId.equals(sourceId))).go();
    final timestamp = now.millisecondsSinceEpoch;
    for (final projected in projections) {
      final itemId = _stableId(
        'webcal-item',
        '$subscriptionId\u0000${projected.uid}',
      );
      final eventId = _stableId(
        'webcal-event',
        '$itemId\u0000${_webCalOccurrenceIdentity(projected)}',
      );
      await _database
          .into(_database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: eventId,
              accountId: accountId,
              calendarSourceId: sourceId,
              provider: BusyProvider.webCal.storageValue,
              providerCalendarId: subscriptionId,
              providerEventId: itemId,
              icalUid: Value(projected.uid),
              recurrenceIdKey: Value(projected.recurrenceIdKey),
              occurrenceKey: Value(projected.occurrenceKey),
              projectionVersion: const Value(webCalProjectionVersion),
              providerRecurringEventId: Value(
                projected.recurring ? itemId : null,
              ),
              providerOriginalStartKey: Value(projected.occurrenceKey),
              status: Value(projected.status),
              title: projected.title,
              description: Value(projected.description),
              location: Value(projected.location),
              allDay: Value(projected.allDay),
              startDate: Value(projected.startDate),
              startDateTime: Value(projected.startDateTime),
              startTimeZone: Value(projected.startTimeZone),
              endDate: Value(projected.endDate),
              endDateTime: Value(projected.endDateTime),
              endTimeZone: Value(projected.endTimeZone),
              recurrenceJson: Value(projected.recurrenceJson),
              remindersJson: Value(projected.remindersJson),
              attendeesJson: Value(projected.attendeesJson),
              categoriesJson: Value(projected.categoriesJson),
              organizerJson: Value(projected.organizerJson),
              colorHex: Value(color),
              visibility: Value(projected.visibility),
              transparencyOrShowAs: Value(projected.transparency),
              webLink: Value(projected.webLink),
              attachmentsJson: Value(projected.attachmentsJson),
              isCancelled: Value(projected.cancelled),
              isDeleted: const Value(false),
              rawJson: Value(projected.rawJson),
              createdAtLocal: timestamp,
              updatedAtLocal: timestamp,
              syncStatus: const Value('synced'),
              baselineRawJson: Value(projected.rawJson),
            ),
          );
    }
  }

  Future<void> _recordFailure(
    WebCalSubscription subscription,
    Object error,
  ) async {
    final now = _nowUtc();
    final failures = subscription.consecutiveFailureCount + 1;
    final code = switch (error) {
      WebCalHttpException(:final code) => code,
      WebCalSubscriptionException(:final code) => code,
      IcalIngestionException(:final code) => code,
      _ => 'WebCalRefreshFailed',
    };
    final status = switch (error) {
      WebCalHttpException(:final httpStatus) => httpStatus,
      WebCalSubscriptionException(:final httpStatus) => httpStatus,
      _ => null,
    };
    await (_database.update(
      _database.webCalSubscriptions,
    )..where((row) => row.id.equals(subscription.id))).write(
      WebCalSubscriptionsCompanion(
        lastCheckedAtUtc: Value(now.toIso8601String()),
        consecutiveFailureCount: Value(failures),
        lastFailureCode: Value(code),
        lastFailureHttpStatus: Value(status),
        nextRefreshAtUtc: Value(
          now.add(_failureBackoff(failures)).toIso8601String(),
        ),
        updatedAtUtc: Value(now.toIso8601String()),
      ),
    );
  }

  Future<void> _rebuildNotifications(String accountId) async {
    await _notificationScheduleService.rebuildUpcomingEventNotifications(
      accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }
}

WebCalSubscriptionEntity _entity(
  WebCalSubscription subscription,
  CalendarSource source,
) => WebCalSubscriptionEntity(
  id: subscription.id,
  accountId: subscription.accountId,
  calendarSourceId: subscription.calendarSourceId,
  name: source.summary,
  color: source.backgroundColor,
  safeOrigin: subscription.safeOrigin,
  refreshMode: WebCalRefreshModeStorage.parse(subscription.refreshMode),
  nextRefreshAtUtc: DateTime.parse(subscription.nextRefreshAtUtc).toUtc(),
  lastSuccessfulSyncAtUtc: DateTime.tryParse(
    subscription.lastSuccessfulSyncAtUtc ?? '',
  )?.toUtc(),
  lastFailureCode: subscription.lastFailureCode,
  lastFailureHttpStatus: subscription.lastFailureHttpStatus,
  consecutiveFailureCount: subscription.consecutiveFailureCount,
);

final class _PreparedCandidate {
  const _PreparedCandidate({
    required this.ingestion,
    required this.projections,
    required this.snapshot,
    required this.rawBodyHash,
    required this.semanticHash,
    required this.projectionRangeStartUtc,
    required this.projectionRangeEndUtc,
  });

  final IcalIngestionResult ingestion;
  final List<ProjectedIcalEvent> projections;
  final String snapshot;
  final String rawBodyHash;
  final String semanticHash;
  final DateTime projectionRangeStartUtc;
  final DateTime projectionRangeEndUtc;
}

final class _PreparedProjection {
  const _PreparedProjection({
    required this.ingestion,
    required this.projections,
    required this.rangeStartUtc,
    required this.rangeEndUtc,
  });

  final IcalIngestionResult ingestion;
  final List<ProjectedIcalEvent> projections;
  final DateTime rangeStartUtc;
  final DateTime rangeEndUtc;
}

({DateTime start, DateTime end}) _projectionRange(
  DateTime now, {
  DateTime? requestedStart,
  DateTime? requestedEnd,
}) {
  final utc = now.toUtc();
  final baseStart = DateTime.utc(utc.year - 1, utc.month, utc.day);
  final baseEnd = DateTime.utc(utc.year + 3, utc.month, utc.day);
  final paddedStart = requestedStart?.toUtc().subtract(
    const Duration(days: 30),
  );
  final paddedEnd = requestedEnd?.toUtc().add(const Duration(days: 90));
  return (
    start: paddedStart != null && paddedStart.isBefore(baseStart)
        ? paddedStart
        : baseStart,
    end: paddedEnd != null && paddedEnd.isAfter(baseEnd) ? paddedEnd : baseEnd,
  );
}

String _subscriptionName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Calendar subscription';
  if (trimmed.length > 200) {
    throw const WebCalSubscriptionException('WebCalNameTooLong');
  }
  return trimmed;
}

String? _normalizedColor(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(trimmed)) {
    throw const WebCalSubscriptionException('WebCalColorInvalid');
  }
  return trimmed.toUpperCase();
}

String _stableId(String prefix, String source) =>
    '$prefix-${sha256.convert(utf8.encode(source))}';

String _webCalOccurrenceIdentity(ProjectedIcalEvent event) =>
    event.recurring ? event.occurrenceKey : 'master';

DateTime _nextRefresh(
  DateTime now, {
  required WebCalRefreshMode mode,
  required int? serverSeconds,
  required String subscriptionId,
}) {
  final selected = switch (mode) {
    WebCalRefreshMode.automatic ||
    WebCalRefreshMode.sixHours => const Duration(hours: 6),
    WebCalRefreshMode.hourly => const Duration(hours: 1),
    WebCalRefreshMode.daily => const Duration(days: 1),
  };
  final server = serverSeconds == null
      ? Duration.zero
      : Duration(seconds: serverSeconds);
  final effective = [
    const Duration(hours: 1),
    selected,
    server,
  ].reduce((left, right) => left > right ? left : right);
  final seed = sha256.convert(utf8.encode(subscriptionId)).bytes.first;
  final jitterSeconds = (effective.inSeconds * (seed / 255) * 0.1).round();
  return now.add(effective).add(Duration(seconds: jitterSeconds));
}

Duration _failureBackoff(int failures) {
  final hours = math.min(24, 1 << math.min(4, math.max(0, failures - 1)));
  return Duration(hours: hours);
}
