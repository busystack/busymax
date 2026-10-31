import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Wait on SQLite's own lock acquisition, never replay an application callback.
/// Drift's native transactions already begin IMMEDIATE, before reading rows.
/// Keep the existing rollback journal; ordinary account writers use this too.
void configureAndroidDatabase(sqlite.Database database) {
  // SQLite's default handler budgets requested sleeps. VM signals can
  // interrupt those sleeps (observed with the real Flutter runtime), consuming
  // that budget before the lock owner can finish. Use the supported callback
  // and elapsed monotonic time on this executor isolate instead. SQLite still
  // decides when calling a busy handler would risk a deadlock and may decline.
  const bound = Duration(seconds: 5);
  final wait = Stopwatch();
  database.busyHandler = (count) {
    if (count == 0) wait.reset();
    wait.start();
    final remaining = bound - wait.elapsed;
    if (remaining <= Duration.zero) return false;
    sleep(
      remaining < const Duration(milliseconds: 10)
          ? remaining
          : const Duration(milliseconds: 10),
    );
    return wait.elapsed < bound;
  };
}

Future<QueryExecutor> openNativeDatabase(
  File file, {
  required bool android,
  bool trace = const bool.fromEnvironment('BUSYMAX_SQLITE_TRACE'),
}) async {
  final executor = NativeDatabase.createInBackground(
    file,
    setup: android ? configureAndroidDatabase : null,
  );
  if (!trace) return executor;
  try {
    final directory = await file.parent.createTemp('busymax-qa-sql-$pid-');
    return executor.interceptWith(
      _DatabaseTrace(File('${directory.path}/operations.jsonl').openWrite()),
    );
  } catch (_) {
    // Diagnostics must not change database behavior; the verifier fails if
    // evidence could not be collected.
    // ignore: avoid_print
    print('BUSYMAX_SQLITE_TRACE_FAILED');
    return executor;
  }
}

/// Opt-in native acceptance evidence. No SQL text, arguments, credentials or
/// account data are logged. Times include the real connection's lock wait.
final class _DatabaseTrace extends QueryInterceptor {
  _DatabaseTrace(this._sink) {
    unawaited(_sink.done.catchError((Object _) => _traceFailed()));
  }
  final IOSink _sink;
  bool _closed = false, _failed = false;
  int _records = 0;

  void _traceFailed() {
    if (_failed) return;
    _failed = true;
    // ignore: avoid_print
    print('BUSYMAX_SQLITE_TRACE_FAILED');
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    try {
      await inner.close();
    } finally {
      _closed = true;
      try {
        await _sink.close();
      } catch (_) {
        _traceFailed();
      }
    }
  }

  final String connection =
      '$pid/${developer.Service.getIsolateId(Isolate.current)}/${DateTime.now().microsecondsSinceEpoch}';
  final _transactions = <QueryExecutor, int>{};
  final _opened = <QueryExecutor>{};
  int _next = 0;

  Future<T> _measure<T>(
    String operation,
    QueryExecutor executor,
    Future<T> Function() action,
  ) async {
    final event = ++_next;
    final watch = Stopwatch()..start();
    void emit(String phase, [bool? failed, Object? failure]) {
      try {
        if (_closed || _failed) return;
        if (++_records > 100000) {
          _traceFailed();
          return;
        }
        int? sqliteCode;
        if (failure is sqlite.SqliteException) {
          sqliteCode = failure.extendedResultCode;
        } else if (failure != null) {
          // Drift serializes native SQLite errors across its executor isolate.
          // Parse only a bounded diagnostic prefix, never log SQL or arguments.
          final description = failure.toString();
          final prefix = description.substring(
            0,
            description.length.clamp(0, 256),
          );
          final match = RegExp(r'SqliteException\((\d+)\)').firstMatch(prefix);
          sqliteCode = int.tryParse(match?.group(1) ?? '');
        }
        _sink.writeln(
          jsonEncode({
            'connection': connection,
            'event': event,
            'operation': operation,
            'transaction': _transactions[executor],
            'phase': phase,
            'utcMicros': DateTime.now().toUtc().microsecondsSinceEpoch,
            'elapsedMicros': watch.elapsedMicroseconds,
            if (failed != null) 'failed': failed,
            if (failure != null) 'errorType': failure.runtimeType.toString(),
            if (failure != null) 'cancelled': failure is CancellationException,
            if (sqliteCode != null) ...{
              'sqliteResultCode': sqliteCode & 0xff,
              'sqliteExtendedResultCode': sqliteCode,
            },
          }),
        );
      } catch (_) {
        // A failed diagnostic stream must not change SQL behavior.
        _traceFailed();
      }
    }

    emit('start');
    try {
      final result = await action();
      emit('end', false);
      return result;
    } catch (error) {
      emit('end', true, error);
      rethrow;
    }
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final transaction = parent.beginTransaction();
    _transactions[transaction] = ++_next;
    return transaction;
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (_transactions.containsKey(executor) && _opened.add(executor)) {
      return _measure('begin', executor, () => executor.ensureOpen(user));
    }
    return executor.ensureOpen(user);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await _measure('commit', inner, inner.send);
    _transactions.remove(inner);
    _opened.remove(inner);
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    try {
      await _measure('rollback', inner, inner.rollback);
    } finally {
      _transactions.remove(inner);
      _opened.remove(inner);
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _measure('read', executor, () => executor.runSelect(statement, args));
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _measure('insert', executor, () => executor.runInsert(statement, args));
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _measure('update', executor, () => executor.runUpdate(statement, args));
  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _measure('delete', executor, () => executor.runDelete(statement, args));
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _measure('custom', executor, () => executor.runCustom(statement, args));
  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _measure('batch', executor, () => executor.runBatched(statements));
}
