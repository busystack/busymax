import 'dart:ffi';
import 'dart:io';

typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeNative = Void Function(Pointer<Void> pointer);
typedef _FreeDart = void Function(Pointer<Void> pointer);
typedef _SetEnvNative =
    Int32 Function(Pointer<Char> name, Pointer<Char> value, Int32 overwrite);
typedef _SetEnvDart =
    int Function(Pointer<Char> name, Pointer<Char> value, int overwrite);
typedef _UnsetEnvNative = Int32 Function(Pointer<Char> name);
typedef _UnsetEnvDart = int Function(Pointer<Char> name);
typedef _TimeZoneSetNative = Void Function();
typedef _TimeZoneSetDart = void Function();

final class ProcessTimeZone {
  ProcessTimeZone()
    : _previous = Platform.environment['TZ'],
      _malloc = DynamicLibrary.process()
          .lookupFunction<_MallocNative, _MallocDart>('malloc'),
      _free = DynamicLibrary.process().lookupFunction<_FreeNative, _FreeDart>(
        'free',
      ),
      _setEnv = DynamicLibrary.process()
          .lookupFunction<_SetEnvNative, _SetEnvDart>('setenv'),
      _unsetEnv = DynamicLibrary.process()
          .lookupFunction<_UnsetEnvNative, _UnsetEnvDart>('unsetenv'),
      _timeZoneSet = DynamicLibrary.process()
          .lookupFunction<_TimeZoneSetNative, _TimeZoneSetDart>('tzset');

  final String? _previous;
  final _MallocDart _malloc;
  final _FreeDart _free;
  final _SetEnvDart _setEnv;
  final _UnsetEnvDart _unsetEnv;
  final _TimeZoneSetDart _timeZoneSet;

  void set(String value) {
    final namePointer = _allocateString('TZ');
    final valuePointer = _allocateString(value);
    try {
      if (_setEnv(namePointer, valuePointer, 1) != 0) {
        throw StateError('Unable to set the process time zone.');
      }
      _timeZoneSet();
    } finally {
      _free(namePointer.cast<Void>());
      _free(valuePointer.cast<Void>());
    }
  }

  void restore() {
    if (_previous case final previous?) {
      set(previous);
      return;
    }

    final namePointer = _allocateString('TZ');
    try {
      if (_unsetEnv(namePointer) != 0) {
        throw StateError('Unable to restore the process time zone.');
      }
      _timeZoneSet();
    } finally {
      _free(namePointer.cast<Void>());
    }
  }

  Pointer<Char> _allocateString(String value) {
    final units = value.codeUnits;
    final pointer = _malloc(units.length + 1).cast<Uint8>();
    for (var index = 0; index < units.length; index++) {
      pointer[index] = units[index];
    }
    pointer[units.length] = 0;
    return pointer.cast<Char>();
  }
}
