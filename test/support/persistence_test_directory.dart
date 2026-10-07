import 'dart:io';

/// Creates a private directory for file-backed persistence regressions.
///
/// Linux tmpfs keeps these fixtures independent of the shared host disk's
/// journal latency. Tests still use real native files, flushes, atomic renames,
/// and close/reopen cycles with unchanged SQLite durability settings. Callers
/// must finish pending writes and close databases before deleting the directory.
/// Executable fixtures should use the normal system temporary filesystem.
Future<Directory> createPersistenceTestDirectory(String prefix) async {
  if (Platform.isLinux) {
    try {
      return await Directory('/dev/shm').createTemp(prefix);
    } on FileSystemException {
      // Fall back on hosts without writable Linux tmpfs.
    }
  }
  return Directory.systemTemp.createTemp(prefix);
}
