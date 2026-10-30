import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// End-to-end encryption for 1:1 messages.
///
/// Every message gets a fresh random content key. The body is sealed with
/// XChaCha20-Poly1305 under that key, and the key itself is wrapped twice
/// (once for the recipient, once for the sender so they can read their own
/// history) using an ephemeral X25519 exchange + HKDF. The sender signs the
/// whole envelope with Ed25519 so a compromised server cannot forge or alter
/// messages. The server only ever sees ciphertext.
class E2E {
  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  static final _aead = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const _wrapInfo = 'urikkiri-wrap-v1';

  static Future<Envelope> seal({
    required String plaintext,
    required String senderId,
    required String recipientId,
    required List<int> recipientDhPublic,
    required List<int> senderDhPublic,
    required SimpleKeyPair signingKeyPair,
  }) async {
    final contentKey = await _aead.newSecretKey();
    final contentKeyBytes = await contentKey.extractBytes();
    final box = await _aead.encrypt(utf8.encode(plaintext), secretKey: contentKey);
    final body = base64Encode(box.concatenation());
    final forRecipient = await _wrap(contentKeyBytes, recipientDhPublic);
    final forSender = await _wrap(contentKeyBytes, senderDhPublic);
    final sig = await _ed25519.sign(
      _signedBytes(senderId, recipientId, body, forRecipient, forSender),
      keyPair: signingKeyPair,
    );
    return Envelope(
      body: body,
      keyForRecipient: forRecipient,
      keyForSender: forSender,
      signature: base64Encode(sig.bytes),
    );
  }

  /// Verifies the signature and decrypts. Throws if anything was tampered with.
  static Future<String> open({
    required Envelope envelope,
    required String senderId,
    required String recipientId,
    required bool iAmSender,
    required SimpleKeyPair myDhKeyPair,
    required List<int> senderSignPublic,
  }) async {
    final ok = await _ed25519.verify(
      _signedBytes(senderId, recipientId, envelope.body, envelope.keyForRecipient,
          envelope.keyForSender),
      signature: Signature(base64Decode(envelope.signature),
          publicKey: SimplePublicKey(senderSignPublic, type: KeyPairType.ed25519)),
    );
    if (!ok) throw const E2EException('서명이 올바르지 않습니다');
    final keyBytes = await _unwrap(
        iAmSender ? envelope.keyForSender : envelope.keyForRecipient, myDhKeyPair);
    final box = SecretBox.fromConcatenation(base64Decode(envelope.body),
        nonceLength: _aead.nonceLength, macLength: _aead.macAlgorithm.macLength);
    final clear = await _aead.decrypt(box, secretKey: SecretKey(keyBytes));
    return utf8.decode(clear);
  }

  static Future<String> _wrap(List<int> contentKey, List<int> theirPublic) async {
    final eph = await _x25519.newKeyPair();
    final ephPub = (await eph.extractPublicKey()).bytes;
    final kek = await _kek(eph, theirPublic, ephPub, theirPublic);
    final box = await _aead.encrypt(contentKey, secretKey: kek);
    return base64Encode([...ephPub, ...box.concatenation()]);
  }

  static Future<List<int>> _unwrap(String wrapped, SimpleKeyPair mine) async {
    final raw = base64Decode(wrapped);
    final ephPub = raw.sublist(0, 32);
    final myPub = (await mine.extractPublicKey()).bytes;
    final kek = await _kek(mine, ephPub, ephPub, myPub);
    final box = SecretBox.fromConcatenation(raw.sublist(32),
        nonceLength: _aead.nonceLength, macLength: _aead.macAlgorithm.macLength);
    return _aead.decrypt(box, secretKey: kek);
  }

  static Future<SecretKey> _kek(SimpleKeyPair mine, List<int> theirPublic,
      List<int> ephPub, List<int> recipientPub) async {
    final shared = await _x25519.sharedSecretKey(
        keyPair: mine,
        remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519));
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: [...ephPub, ...recipientPub],
      info: utf8.encode(_wrapInfo),
    );
  }

  static List<int> _signedBytes(String senderId, String recipientId, String body,
          String keyForRecipient, String keyForSender) =>
      utf8.encode(
          ['v1', senderId, recipientId, body, keyForRecipient, keyForSender].join('|'));

  /// A short, human-comparable fingerprint of both people's keys. Two people
  /// see the same number; if it matches when they compare in person, nobody
  /// is in the middle.
  static Future<String> safetyNumber(List<int> a, List<int> b) async {
    final ordered = [a, b]..sort((x, y) => base64Encode(x).compareTo(base64Encode(y)));
    final hash = await Sha256().hash([...ordered[0], ...ordered[1]]);
    final digits = StringBuffer();
    final bytes = Uint8List.fromList(hash.bytes);
    for (var i = 0; i < 30; i += 5) {
      final chunk = bytes.buffer.asByteData().getUint32(i) % 100000;
      digits.write(chunk.toString().padLeft(5, '0'));
      if (i < 25) digits.write(' ');
    }
    return digits.toString();
  }
}

class Envelope {
  final String body;
  final String keyForRecipient;
  final String keyForSender;
  final String signature;

  const Envelope({
    required this.body,
    required this.keyForRecipient,
    required this.keyForSender,
    required this.signature,
  });
}

class E2EException implements Exception {
  final String message;
  const E2EException(this.message);
  @override
  String toString() => message;
}
