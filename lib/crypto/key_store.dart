import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds this device's identity keys. Private keys live only in the platform
/// keystore (Android Keystore / iOS Keychain) and never leave the phone.
class KeyStore {
  static const _storage = FlutterSecureStorage();
  static const _dhKey = 'identity_dh_private';
  static const _signKey = 'identity_sign_private';
  static const _pinPrefix = 'pinned_sign_key_';

  SimpleKeyPair? dh;
  SimpleKeyPair? sign;

  String get _scope => _userId ?? '';
  String? _userId;

  Future<bool> load(String userId) async {
    _userId = userId;
    final dhSeed = await _storage.read(key: '$_dhKey$_scope');
    final signSeed = await _storage.read(key: '$_signKey$_scope');
    if (dhSeed == null || signSeed == null) return false;
    dh = await X25519().newKeyPairFromSeed(base64Decode(dhSeed));
    sign = await Ed25519().newKeyPairFromSeed(base64Decode(signSeed));
    return true;
  }

  /// Creates fresh identity keys and returns their public halves (base64).
  Future<({String dhPublic, String signPublic})> generate(String userId) async {
    _userId = userId;
    final dhPair = await X25519().newKeyPair();
    final signPair = await Ed25519().newKeyPair();
    await _storage.write(
        key: '$_dhKey$_scope',
        value: base64Encode(await dhPair.extractPrivateKeyBytes()));
    await _storage.write(
        key: '$_signKey$_scope',
        value: base64Encode(await signPair.extractPrivateKeyBytes()));
    dh = dhPair;
    sign = signPair;
    return (
      dhPublic: base64Encode((await dhPair.extractPublicKey()).bytes),
      signPublic: base64Encode((await signPair.extractPublicKey()).bytes),
    );
  }

  /// Trust-on-first-use pinning of a contact's signing key. Returns false if
  /// the contact's key changed since we first saw it.
  Future<bool> checkPinned(String contactId, String signPublic) async {
    final key = '$_pinPrefix$_scope$contactId';
    final pinned = await _storage.read(key: key);
    if (pinned == null) {
      await _storage.write(key: key, value: signPublic);
      return true;
    }
    return pinned == signPublic;
  }

  Future<void> repin(String contactId, String signPublic) =>
      _storage.write(key: '$_pinPrefix$_scope$contactId', value: signPublic);
}
