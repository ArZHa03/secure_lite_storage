part of 'secure_lite_storage.dart';

abstract class _IStorage {
  Future<void> init(Map<String, dynamic>? initialData, Future<String> Function(String) encrypt, Future<String> Function(String) decrypt);

  T? read<T>(String key);
  void remove(String key);
  void write(String key, dynamic value);
  void clear();

  Future<void> flush();
}