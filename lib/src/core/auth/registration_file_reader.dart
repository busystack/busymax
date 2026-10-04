import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'oauth_models.dart';

/// Only configuration-file bytes cross this boundary. Native code opens once,
/// validates that handle, and reads it off the UI thread.
final class RegistrationFileReader {
  const RegistrationFileReader({this.libraryPath});
  final String? libraryPath;

  Future<Uint8List> read(
    String path, {
    required int maximumBytes,
    required Future<void> cancellation,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final nativePath = libraryPath ?? _packagedLibrary;
    final _ReaderApi api;
    try {
      api = _ReaderApi(nativePath);
    } on Object {
      throw _readerFailure(1);
    }
    final encoded = utf8.encode(path);
    final pathBuffer = api.allocate(encoded.length + 1).cast<Uint8>();
    if (pathBuffer.address == 0) throw _readerFailure(1);
    Pointer<Void> request;
    try {
      pathBuffer.asTypedList(encoded.length + 1)
        ..setRange(0, encoded.length, encoded)
        ..[encoded.length] = 0;
      request = api.create(pathBuffer, maximumBytes, timeout.inMilliseconds);
    } finally {
      api.free(pathBuffer.cast());
    }
    if (request.address == 0) throw _readerFailure(1);
    final receive = ReceivePort();
    final stopped = Completer<Never>();
    // Observe immediately: cancellation may precede the isolate's delivery.
    unawaited(
      stopped.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    var active = true;
    void stop(int reason) {
      if (!active || stopped.isCompleted) return;
      api.cancel(request);
      stopped.completeError(_readerFailure(reason));
    }

    unawaited(cancellation.then((_) => stop(4)));
    final timer = Timer(timeout, () => stop(5));
    Future<Isolate>? worker;
    try {
      worker = Isolate.spawn(_readConfiguration, (
        nativePath,
        request.address,
        receive.sendPort,
      ));
      // A failed spawn relinquishes the reserved worker reference. A late
      // successful spawn owns it and will close the handle even after timeout.
      unawaited(
        worker.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {
            api.release(request);
            stop(1);
          },
        ),
      );
      final result = await Future.any<Object?>([receive.first, stopped.future]);
      if (result is! (int, Uint8List)) throw _readerFailure(1);
      if (result.$1 != 0) throw _readerFailure(result.$1);
      return result.$2;
    } finally {
      active = false;
      timer.cancel();
      api.cancel(request);
      api.release(request);
      receive.close();
    }
  }

  static String get _packagedLibrary {
    final directory = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isLinux) {
      return '$directory/lib/libbusymax_registration_reader.so';
    }
    if (Platform.isWindows) {
      return '$directory/busymax_registration_reader.dll';
    }
    throw _readerFailure(2);
  }
}

void _readConfiguration((String, int, SendPort) arguments) {
  final api = _ReaderApi(arguments.$1);
  final request = Pointer<Void>.fromAddress(arguments.$2);
  int result = 1;
  Uint8List bytes = Uint8List(0);
  try {
    result = api.run(request);
    if (result == 0) {
      bytes = Uint8List.fromList(
        api.bytes(request).asTypedList(api.size(request)),
      );
    }
  } finally {
    api.release(request);
  }
  Isolate.exit(arguments.$3, (result, bytes));
}

OAuthException _readerFailure(int reason) => switch (reason) {
  2 => const OAuthException(
    'OAuthUnsupportedFileSource',
    'Select a regular local JSON file.',
  ),
  3 => const OAuthException(
    'OAuthConfigurationTooLarge',
    'The OAuth JSON file exceeds 64 KiB.',
  ),
  4 => const OAuthException(
    'OAuthSignInCancelled',
    'Registration setup was cancelled.',
  ),
  5 => const OAuthException(
    'OAuthRequestTimeout',
    'Reading the registration timed out.',
  ),
  _ => const OAuthException(
    'OAuthConfigurationUnreadable',
    'The selected OAuth file could not be read.',
  ),
};

final class _ReaderApi {
  _ReaderApi(String path) {
    final library = DynamicLibrary.open(path);
    create = library
        .lookupFunction<
          Pointer<Void> Function(Pointer<Uint8>, Size, Int64),
          Pointer<Void> Function(Pointer<Uint8>, int, int)
        >('busymax_reader_create');
    cancel = library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('busymax_reader_cancel');
    release = library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('busymax_reader_release');
    run = library
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('busymax_reader_run');
    bytes = library
        .lookupFunction<
          Pointer<Uint8> Function(Pointer<Void>),
          Pointer<Uint8> Function(Pointer<Void>)
        >('busymax_reader_bytes');
    size = library
        .lookupFunction<
          Size Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('busymax_reader_size');
    allocate = library
        .lookupFunction<
          Pointer<Void> Function(Size),
          Pointer<Void> Function(int)
        >('busymax_reader_allocate');
    free = library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('busymax_reader_free');
  }
  late final Pointer<Void> Function(Pointer<Uint8>, int, int) create;
  late final void Function(Pointer<Void>) cancel;
  late final void Function(Pointer<Void>) release;
  late final int Function(Pointer<Void>) run;
  late final Pointer<Uint8> Function(Pointer<Void>) bytes;
  late final int Function(Pointer<Void>) size;
  late final Pointer<Void> Function(int) allocate;
  late final void Function(Pointer<Void>) free;
}
