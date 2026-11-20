import 'dart:js_interop';

@JS('window.localStorage')
external _BrowserStorage get _localStorage;

extension type _BrowserStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

String? readSessionValue(String key) => _localStorage.getItem(key);

void writeSessionValue(String key, String value) => _localStorage.setItem(key, value);

void removeSessionValue(String key) => _localStorage.removeItem(key);
