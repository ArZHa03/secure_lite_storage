import 'dart:async' show scheduleMicrotask;
import 'dart:convert' show json;
import 'dart:developer' show log;

import 'package:cryptography/cryptography.dart' show AesCtr, Hmac, Mac, Pbkdf2, SecretBox, SecretKey;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'html_storage.dart' if (dart.library.io) 'io_storage.dart';

part 'micro_task.dart';

class SecureLiteStorage {
  static final Map<String, SecureLiteStorage> _sync = {};
  static late Storage _storage;

  late Future<SecureLiteStorage> _initStorage;
  Map<String, dynamic>? _initialData;

  static bool _isInit = false;

  final String _kNonce = 'nonce';
  final String _kMac = 'mac';
  final String _kCipherText = 'cipherText';
  AesCtr? _algorithm;
  SecretKey? _secretKey;

  factory SecureLiteStorage({
    String container = 'SecureLiteStorage',
    String? password,
    String? path,
    Map<String, dynamic>? initialData,
  }) {
    if (_sync.containsKey(container)) {
      return _sync[container]!;
    } else {
      final instance = SecureLiteStorage._internal(container, path, initialData, password);
      _sync[container] = instance;
      return instance;
    }
  }

  SecureLiteStorage._internal(String key, [String? path, Map<String, dynamic>? initialData, String? password]) {
    _storage = Storage(key);
    _initialData = initialData;

    _initStorage = Future<SecureLiteStorage>(() async {
      if (password != null) {
        _algorithm = AesCtr.with128bits(macAlgorithm: Hmac.sha256());
        final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 1000, bits: 128);
        _secretKey = await pbkdf2.deriveKeyFromPassword(password: password, nonce: password.runes.toList().reversed.toList());
      }
      await _init();
      return this;
    });
  }

  Future<void> _init() async {
    try {
      await _storage.init(_initialData, _encrypt, _decrypt);
      _isInit = true;
    } catch (err) {
      rethrow;
    }
  }

  Future<SecureLiteStorage> init({String container = 'LiteStorage', String? password}) {
    WidgetsFlutterBinding.ensureInitialized();
    return SecureLiteStorage(container: container, password: password)._initStorage;
  }

  static dynamic read<T>(String key) => _isInit ? _storage.read(key) : _log();
  static void write(String key, dynamic value) {
    if (!_isInit) return _log();
    _storage.write(key, value);
    return _tryFlush();
  }

  static void remove(String key) {
    if (!_isInit) return _log();
    _storage.remove(key);
    return _tryFlush();
  }

  static void erase() {
    if (!_isInit) return _log();
    _storage.clear();
    return _tryFlush();
  }

  String _listToHexString(List<int> bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  List<int> _hexStringToList(String hexString) {
    List<int> data = [];
    for (int i = 0; i < hexString.length; i += 2) {
      int byte = int.parse(hexString.substring(i, i + 2), radix: 16);
      data.add(byte);
    }
    return data;
  }

  Future<String> _encrypt(String value) async {
    if (_algorithm != null) {
      final secretBox = await _algorithm!.encryptString(value, secretKey: _secretKey!);
      final jsonPayload = {
        _kNonce: _listToHexString(secretBox.nonce),
        _kMac: _listToHexString(secretBox.mac.bytes),
        _kCipherText: _listToHexString(secretBox.cipherText),
      };
      return json.encode(jsonPayload);
    }

    final dynamic jsonPayload = json.decode(value) ?? {};
    if (jsonPayload.containsKey(_kCipherText) || jsonPayload.containsKey(_kMac) || jsonPayload.containsKey(_kNonce)) {
      jsonPayload.remove(_kCipherText);
      jsonPayload.remove(_kMac);
      jsonPayload.remove(_kNonce);
      return json.encode(jsonPayload);
    }
    return value;
  }

  Future<String> _decrypt(String value) async {
    if (_algorithm != null) {
      final jsonPayload = json.decode(value);

      if (jsonPayload == null ||
          !jsonPayload.containsKey(_kCipherText) ||
          !jsonPayload.containsKey(_kMac) ||
          !jsonPayload.containsKey(_kNonce)) {
        return value;
      }

      if (jsonPayload[_kNonce] is! String || jsonPayload[_kCipherText] is! String || jsonPayload[_kMac] is! String) return '';

      final secretBox = SecretBox(
        _hexStringToList(jsonPayload[_kCipherText]),
        nonce: _hexStringToList(jsonPayload[_kNonce]),
        mac: Mac(_hexStringToList(jsonPayload[_kMac])),
      );

      try {
        return await _algorithm!.decryptString(secretBox, secretKey: _secretKey!);
      } catch (e) {
        rethrow;
      }
    }
    return value;
  }

  static void _tryFlush() => _MicroTask.exec(_addToQueue);

  static Future<void> _addToQueue() async => await _flush();

  static Future<void> _flush() async {
    try {
      await _storage.flush();
    } catch (e) {
      rethrow;
    }
    return;
  }

  static void _log() => log(name: 'LiteStorage', 'LiteStorage need to be initialized');
}
