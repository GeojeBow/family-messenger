import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urikkiri/crypto/e2e.dart';

void main() {
  Future<(SimpleKeyPair, SimpleKeyPair, List<int>, List<int>)> identity() async {
    final dh = await X25519().newKeyPair();
    final sign = await Ed25519().newKeyPair();
    return (
      dh,
      sign,
      (await dh.extractPublicKey()).bytes,
      (await sign.extractPublicKey()).bytes,
    );
  }

  test('sender and recipient can both read, others cannot', () async {
    final (aDh, aSign, aDhPub, aSignPub) = await identity();
    final (bDh, _, bDhPub, _) = await identity();
    final (eveDh, _, _, _) = await identity();

    final env = await E2E.seal(
      plaintext: '안녕하세요 👋',
      senderId: 'a',
      recipientId: 'b',
      recipientDhPublic: bDhPub,
      senderDhPublic: aDhPub,
      signingKeyPair: aSign,
    );
    expect(env.body.contains('안녕'), isFalse);

    Future<String> openAs(SimpleKeyPair dh, bool sender) => E2E.open(
          envelope: env,
          senderId: 'a',
          recipientId: 'b',
          iAmSender: sender,
          myDhKeyPair: dh,
          senderSignPublic: aSignPub,
        );

    expect(await openAs(bDh, false), '안녕하세요 👋');
    expect(await openAs(aDh, true), '안녕하세요 👋');
    expect(openAs(eveDh, false), throwsA(anything));
  });

  test('tampering or a forged sender is rejected', () async {
    final (_, aSign, aDhPub, _) = await identity();
    final (bDh, _, bDhPub, _) = await identity();
    final (_, _, _, malloryPub) = await identity();
    final env = await E2E.seal(
      plaintext: 'hi',
      senderId: 'a',
      recipientId: 'b',
      recipientDhPublic: bDhPub,
      senderDhPublic: aDhPub,
      signingKeyPair: aSign,
    );
    final raw = base64Decode(env.body)..[30] ^= 1;
    final tampered = Envelope(
        body: base64Encode(raw),
        keyForRecipient: env.keyForRecipient,
        keyForSender: env.keyForSender,
        signature: env.signature);
    expect(
        E2E.open(
            envelope: tampered,
            senderId: 'a',
            recipientId: 'b',
            iAmSender: false,
            myDhKeyPair: bDh,
            senderSignPublic: (await aSign.extractPublicKey()).bytes),
        throwsA(isA<E2EException>()));
    expect(
        E2E.open(
            envelope: env,
            senderId: 'a',
            recipientId: 'b',
            iAmSender: false,
            myDhKeyPair: bDh,
            senderSignPublic: malloryPub),
        throwsA(isA<E2EException>()));
  });

  test('safety number is symmetric', () async {
    final a = List<int>.generate(32, (i) => i);
    final b = List<int>.generate(32, (i) => 255 - i);
    expect(await E2E.safetyNumber(a, b), await E2E.safetyNumber(b, a));
    expect((await E2E.safetyNumber(a, b)).split(' ').length, 6);
  });
}
