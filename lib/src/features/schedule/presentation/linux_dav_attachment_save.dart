import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

/// Document portals allow sibling temporary files for atomic replacement, but
/// do not allow temporary directories. Keep the exclusively created 0600 file
/// open while writing, then rename it without ever opening the destination.
Future<void> saveLinuxDavAttachmentAtomically(
  File destination,
  List<int> bytes,
) => Isolate.run(() => _save(destination.path, bytes));

void _save(String path, List<int> bytes) {
  if (path.contains('\u0000')) {
    throw const FileSystemException('Invalid attachment destination.');
  }
  final api = _AtomicFileApi();
  Pointer<Uint8> destination = nullptr;
  Pointer<Uint8> staging = nullptr;
  Pointer<Uint8> data = nullptr;
  var fd = -1;
  var created = false;
  try {
    destination = api.string(path);
    staging = api.string(
      '${File(path).parent.path}/.busymax-attachment-XXXXXX',
    );
    data = api.allocate(bytes.length + 1).cast<Uint8>();
    if (data.address == 0) {
      throw FileSystemException('Could not stage attachment.', path);
    }
    data.asTypedList(bytes.length).setAll(0, bytes);
    // Linux O_CLOEXEC. mkostemp supplies O_CREAT | O_EXCL and mode 0600.
    fd = api.create(staging, 0x80000);
    if (fd < 0) throw FileSystemException('Could not stage attachment.', path);
    created = true;
    var written = 0;
    while (written < bytes.length) {
      final count = api.write(fd, data + written, bytes.length - written);
      if (count < 0 && api.error().value == 4) continue; // EINTR
      if (count <= 0) {
        throw FileSystemException('Could not write attachment.', path);
      }
      written += count;
    }
    if (api.sync(fd) != 0) {
      throw FileSystemException('Could not flush attachment.', path);
    }
    final result = api.close(fd);
    fd = -1;
    if (result != 0) {
      throw FileSystemException('Could not close attachment.', path);
    }
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The selected destination is not a file.',
        path,
      );
    }
    if (api.rename(staging, destination) != 0) {
      throw FileSystemException('Could not commit attachment.', path);
    }
  } finally {
    if (fd >= 0) api.close(fd);
    if (created) api.unlink(staging);
    api.free(data.cast());
    api.free(staging.cast());
    api.free(destination.cast());
  }
}

final class _AtomicFileApi {
  _AtomicFileApi() {
    final library = DynamicLibrary.open('libc.so.6');
    allocate = library
        .lookupFunction<
          Pointer<Void> Function(Size),
          Pointer<Void> Function(int)
        >('malloc');
    free = library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('free');
    create = library
        .lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int)
        >('mkostemp');
    write = library
        .lookupFunction<
          IntPtr Function(Int32, Pointer<Uint8>, Size),
          int Function(int, Pointer<Uint8>, int)
        >('write');
    sync = library.lookupFunction<Int32 Function(Int32), int Function(int)>(
      'fsync',
    );
    close = library.lookupFunction<Int32 Function(Int32), int Function(int)>(
      'close',
    );
    rename = library
        .lookupFunction<
          Int32 Function(Pointer<Uint8>, Pointer<Uint8>),
          int Function(Pointer<Uint8>, Pointer<Uint8>)
        >('rename');
    unlink = library
        .lookupFunction<
          Int32 Function(Pointer<Uint8>),
          int Function(Pointer<Uint8>)
        >('unlink');
    error = library
        .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
          '__errno_location',
        );
  }

  late final Pointer<Void> Function(int) allocate;
  late final void Function(Pointer<Void>) free;
  late final int Function(Pointer<Uint8>, int) create;
  late final int Function(int, Pointer<Uint8>, int) write;
  late final int Function(int) sync;
  late final int Function(int) close;
  late final int Function(Pointer<Uint8>, Pointer<Uint8>) rename;
  late final int Function(Pointer<Uint8>) unlink;
  late final Pointer<Int32> Function() error;

  Pointer<Uint8> string(String value) {
    final bytes = utf8.encode(value);
    final pointer = allocate(bytes.length + 1).cast<Uint8>();
    if (pointer.address == 0) {
      throw const FileSystemException('Could not stage attachment.');
    }
    pointer.asTypedList(bytes.length + 1)
      ..setRange(0, bytes.length, bytes)
      ..[bytes.length] = 0;
    return pointer;
  }
}
