part of 'secure_lite_storage.dart';

class _HTMLStorage implements _IStorage {
  static _HTMLStorage? _instance;
  static late String _fileName;
  static final _ValueStorage<Map<String, dynamic>> _subject = _ValueStorage<Map<String, dynamic>>(<String, dynamic>{});

  static late Future<String> Function(String) _encrypt;
  static late Future<String> Function(String) _decrypt;

  factory _HTMLStorage(String fileName) {
    _instance ??= _HTMLStorage._internal(fileName);
    return _instance!;
  }

  _HTMLStorage._internal(String fileName) {
    _fileName = fileName;
  }

  @override
  Future<void> init(Map<String, dynamic>? initialData, Future<String> Function(String) encrypt, Future<String> Function(String) decrypt) async {
    _encrypt = encrypt;
    _decrypt = decrypt;
    _subject.value = initialData ?? <String, dynamic>{};
    if (await _exists()) return await _readFromStorage();
    return await _writeToStorage(_subject.value);
  }

  @override
  T? read<T>(String key) => _subject.value[key] as T?;
  @override
  void remove(String key) => _subject.value.remove(key);
  @override
  void write(String key, dynamic value) => _subject.value[key] = value;
  @override
  void clear() {
    _localStorage.remove(_fileName);
    _subject.value.clear();
  }

  @override
  Future<void> flush() => _writeToStorage(_subject.value);

  static html.Storage get _localStorage => html.window.localStorage;
  static Future<bool> _exists() async => _localStorage.containsKey(_fileName);
  static Future<void> _writeToStorage(Map<String, dynamic> data) async {
    final dataValue = await _encrypt(json.encode(data));
    final subjectValue = await _encrypt(json.encode(_subject.value));
    _localStorage.update(_fileName, (val) => dataValue, ifAbsent: () => subjectValue);
  }

  static Future<void> _readFromStorage() async {
    final dataFromLocal = _localStorage.entries._firstWhereOrNull((value) => value.key == _fileName);
    if (dataFromLocal == null) return await _writeToStorage(<String, dynamic>{});
    _subject.value = json.decode(await _decrypt(dataFromLocal.value)) as Map<String, dynamic>;
  }
}

extension _FirstWhereExt<T> on Iterable<T> {
  T? _firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class _ValueStorage<T> extends ValueNotifier<T> {
  _ValueStorage(super.value);
}
