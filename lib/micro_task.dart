part of 'secure_lite_storage.dart';

class _MicroTask {
  static int _version = 0;
  static int _microTask = 0;

  static final _MicroTask _instance = _MicroTask._internal();

  factory _MicroTask() => _instance;

  _MicroTask._internal();

  static void exec(Function callback) {
    if (_microTask == _version) {
      _microTask++;
      scheduleMicrotask(() {
        _version++;
        _microTask = _version;
        callback();
      });
    }
  }
}
