import 'package:local_auth/local_auth.dart';

/// Gates the Progress Vault behind device biometrics / passcode, separately
/// from the diary. The diary stays usable while the Vault is locked.
class VaultLockService {
  VaultLockService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompt for auth. Returns true on success. Falls back to device passcode
  /// when biometrics aren't enrolled.
  Future<bool> authenticate({
    String reason = 'Unlock your Progress Vault',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
