import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and persists the SQLCipher database key in the platform keystore
/// (iOS Keychain / Android Keystore via flutter_secure_storage).
///
/// The key is created once on first launch and never leaves the device.
class KeyService {
  KeyService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _keyName = 'macrovault_db_key_v1';

  Future<String> getOrCreateDbKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = _generateKey();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  /// 256 bits of CSPRNG entropy, base64-encoded.
  String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Used by "delete everything" to also drop the key (renders the DB file
  /// permanently unreadable).
  Future<void> deleteDbKey() => _storage.delete(key: _keyName);
}
