import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart' as impl;

/// Persistance légère de session (localStorage sur Flutter Web, no-op hors web).
class SessionStorage {
  static String? read(String key) => impl.readSessionValue(key);

  static void write(String key, String value) => impl.writeSessionValue(key, value);

  static void remove(String key) => impl.removeSessionValue(key);
}
