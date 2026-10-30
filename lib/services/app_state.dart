import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../crypto/e2e.dart';
import '../crypto/key_store.dart';
import 'models.dart';

/// Single place that talks to Supabase. Screens listen to it for changes.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  SupabaseClient get _db => Supabase.instance.client;
  final keys = KeyStore();

  Profile? me;
  final Map<String, Profile> profiles = {};
  final Map<String, List<ChatMessage>> chats = {};
  final Set<String> keyChanged = {};
  RealtimeChannel? _channel;

  String? get userId => _db.auth.currentUser?.id;
  bool get signedIn => _db.auth.currentSession != null;

  // ---------------------------------------------------------------- auth

  Future<void> signIn(String username, String password) async {
    await _db.auth.signInWithPassword(
        email: Config.emailFor(username), password: password);
    await bootstrap();
  }

  /// Loads profile, keys, contacts and messages and starts realtime.
  Future<void> bootstrap() async {
    final uid = userId!;
    final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) throw const AuthException('가입이 완료되지 않은 계정입니다.');
    me = Profile.fromJson(row);
    profiles[uid] = me!;
    if (!await keys.load(uid) || !me!.hasKeys) {
      // First sign-in, new phone or reinstalled app: make new keys. Messages
      // sent to the old key can no longer be decrypted on this device.
      final pub = await keys.generate(uid);
      await _db.from('profiles').update({
        'dh_public_key': pub.dhPublic,
        'sign_public_key': pub.signPublic
      }).eq('id', uid);
      me = Profile.fromJson(
          (await _db.from('profiles').select().eq('id', uid).single()));
      profiles[uid] = me!;
    }
    await refreshMembers();
    await _loadMessages();
    _subscribe();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _channel?.unsubscribe();
    _channel = null;
    me = null;
    profiles.clear();
    chats.clear();
    await _db.auth.signOut();
    notifyListeners();
  }

  // ------------------------------------------------------------- members

  Future<void> refreshMembers() async {
    final rows = await _db.from('profiles').select();
    for (final p in rows) {
      final profile = Profile.fromJson(p);
      profiles[profile.id] = profile;
    }
    if (me != null) me = profiles[me!.id];
    keyChanged.clear();
    for (final p in members) {
      if (p.hasKeys && !await keys.checkPinned(p.id, p.signPublicKey!)) {
        keyChanged.add(p.id);
      }
    }
    notifyListeners();
  }

  /// Everyone in the family except me.
  List<Profile> get members =>
      profiles.values.where((p) => p.id != userId).toList();

  Future<void> rename(String displayName) async {
    await _db
        .from('profiles')
        .update({'display_name': displayName}).eq('id', userId!);
    await refreshMembers();
  }

  Future<void> trustNewKey(String contactId) async {
    await keys.repin(contactId, profiles[contactId]!.signPublicKey!);
    keyChanged.remove(contactId);
    notifyListeners();
  }

  Future<String> safetyNumber(String contactId) => E2E.safetyNumber(
      base64Decode(me!.signPublicKey!),
      base64Decode(profiles[contactId]!.signPublicKey!));

  // ------------------------------------------------------------ messages

  Future<void> _loadMessages() async {
    chats.clear();
    final rows = await _db
        .from('messages')
        .select()
        .order('created_at', ascending: true)
        .limit(5000);
    for (final r in rows) {
      _add(await _decrypt(r), notify: false);
    }
  }

  Future<ChatMessage> _decrypt(Map<String, dynamic> r) async {
    final me = userId!;
    final sender = profiles[r['sender_id']];
    String text;
    var failed = false;
    try {
      if (sender == null || !sender.hasKeys) {
        throw const E2EException('알 수 없는 사용자');
      }
      if (keyChanged.contains(sender.id)) {
        throw const E2EException('보안 키가 바뀌었습니다');
      }
      text = await E2E.open(
        envelope: Envelope(
          body: r['body'],
          keyForRecipient: r['key_for_recipient'],
          keyForSender: r['key_for_sender'],
          signature: r['signature'],
        ),
        senderId: r['sender_id'],
        recipientId: r['recipient_id'],
        iAmSender: r['sender_id'] == me,
        myDhKeyPair: keys.dh!,
        senderSignPublic: base64Decode(sender.signPublicKey!),
      );
    } catch (_) {
      text = '🔒 이 기기에서 열 수 없는 메시지입니다';
      failed = true;
    }
    return ChatMessage(
      id: r['id'],
      senderId: r['sender_id'],
      recipientId: r['recipient_id'],
      createdAt: DateTime.parse(r['created_at']).toLocal(),
      readAt:
          r['read_at'] == null ? null : DateTime.parse(r['read_at']).toLocal(),
      text: text,
      failed: failed,
    );
  }

  void _add(ChatMessage m, {bool notify = true}) {
    final list = chats.putIfAbsent(m.peer(userId!), () => []);
    final i = list.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      list[i] = m;
    } else {
      list.add(m);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    if (notify) notifyListeners();
  }

  Future<void> send(String recipientId, String text) async {
    var recipient = profiles[recipientId]!;
    if (!recipient.hasKeys) {
      await refreshMembers();
      recipient = profiles[recipientId]!;
      if (!recipient.hasKeys) {
        throw const E2EException('상대방이 아직 앱에 한 번도 로그인하지 않았어요.');
      }
    }
    if (keyChanged.contains(recipientId)) {
      throw const E2EException('상대방의 보안 키가 바뀌었습니다. 먼저 확인해 주세요.');
    }
    final env = await E2E.seal(
      plaintext: text,
      senderId: userId!,
      recipientId: recipientId,
      recipientDhPublic: base64Decode(recipient.dhPublicKey!),
      senderDhPublic: base64Decode(me!.dhPublicKey!),
      signingKeyPair: keys.sign!,
    );
    final row = await _db
        .from('messages')
        .insert({
          'recipient_id': recipientId,
          'body': env.body,
          'key_for_recipient': env.keyForRecipient,
          'key_for_sender': env.keyForSender,
          'signature': env.signature,
        })
        .select()
        .single();
    _add(ChatMessage(
      id: row['id'],
      senderId: userId!,
      recipientId: recipientId,
      createdAt: DateTime.parse(row['created_at']).toLocal(),
      readAt: null,
      text: text,
    ));
  }

  Future<void> deleteMessage(ChatMessage m) async {
    await _db.from('messages').delete().eq('id', m.id);
    chats[m.peer(userId!)]?.removeWhere((x) => x.id == m.id);
    notifyListeners();
  }

  Future<void> markRead(String other) async {
    final unread = (chats[other] ?? [])
        .any((m) => m.senderId == other && m.readAt == null);
    if (!unread) return;
    await _db.rpc('mark_read', params: {'p_other': other});
    final now = DateTime.now();
    chats[other] = [
      for (final m in chats[other]!)
        m.senderId == other && m.readAt == null
            ? ChatMessage(
                id: m.id,
                senderId: m.senderId,
                recipientId: m.recipientId,
                createdAt: m.createdAt,
                readAt: now,
                text: m.text,
                failed: m.failed)
            : m
    ];
    notifyListeners();
  }

  int unreadCount(String other) => (chats[other] ?? [])
      .where((m) => m.senderId == other && m.readAt == null)
      .length;

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = _db
        .channel('inbox-${userId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id'];
              for (final list in chats.values) {
                list.removeWhere((m) => m.id == id);
              }
              notifyListeners();
              return;
            }
            final r = payload.newRecord;
            if (!(profiles[r['sender_id']]?.hasKeys ?? false)) {
              await refreshMembers();
            }
            _add(await _decrypt(r));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) => refreshMembers(),
        )
        .subscribe();
  }
}
