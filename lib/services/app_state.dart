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
  List<ContactLink> contacts = [];
  final Map<String, List<ChatMessage>> chats = {};
  final Set<String> keyChanged = {};
  RealtimeChannel? _channel;

  String? get userId => _db.auth.currentUser?.id;
  bool get signedIn => _db.auth.currentSession != null;

  // ---------------------------------------------------------------- auth

  Future<void> signIn(String username, String password) async {
    await _db.auth.signInWithPassword(email: Config.emailFor(username), password: password);
    await bootstrap();
  }

  Future<void> register({
    required String inviteCode,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final res = await _db.auth.signUp(email: Config.emailFor(username), password: password);
    final uid = res.user?.id;
    if (uid == null || res.session == null) {
      throw const AuthException('가입에 실패했습니다. 관리자에게 문의하세요.');
    }
    final pub = await keys.generate(uid);
    try {
      await _db.rpc('register_profile', params: {
        'p_invite_code': inviteCode,
        'p_username': username,
        'p_display_name': displayName,
        'p_dh_public_key': pub.dhPublic,
        'p_sign_public_key': pub.signPublic,
      });
    } catch (e) {
      await _db.auth.signOut();
      rethrow;
    }
    await bootstrap();
  }

  /// Loads profile, keys, contacts and messages and starts realtime.
  Future<void> bootstrap() async {
    final uid = userId!;
    final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) throw const AuthException('가입이 완료되지 않은 계정입니다.');
    me = Profile.fromJson(row);
    profiles[uid] = me!;
    if (!await keys.load(uid)) {
      // New phone or reinstalled app: the old private key is gone, so make
      // new keys. Older messages can no longer be decrypted on this device.
      final pub = await keys.generate(uid);
      await _db.from('profiles').update(
          {'dh_public_key': pub.dhPublic, 'sign_public_key': pub.signPublic}).eq('id', uid);
      me = Profile.fromJson(
          (await _db.from('profiles').select().eq('id', uid).single()));
      profiles[uid] = me!;
    }
    await refreshContacts();
    await _loadMessages();
    _subscribe();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _channel?.unsubscribe();
    _channel = null;
    me = null;
    profiles.clear();
    contacts = [];
    chats.clear();
    await _db.auth.signOut();
    notifyListeners();
  }

  // ------------------------------------------------------------ contacts

  Future<void> refreshContacts() async {
    final rows = await _db.from('contacts').select();
    contacts = rows.map(ContactLink.fromJson).toList();
    final others = contacts.map((c) => c.other(userId!)).toSet();
    if (others.isNotEmpty) {
      final ps = await _db.from('profiles').select().inFilter('id', others.toList());
      for (final p in ps) {
        final profile = Profile.fromJson(p);
        profiles[profile.id] = profile;
      }
    }
    keyChanged.clear();
    for (final c in accepted) {
      final p = profiles[c.other(userId!)];
      if (p != null && !await keys.checkPinned(p.id, p.signPublicKey)) keyChanged.add(p.id);
    }
    notifyListeners();
  }

  List<ContactLink> get accepted => contacts.where((c) => c.status == 'accepted').toList();
  List<ContactLink> get incoming =>
      contacts.where((c) => c.status == 'pending' && c.addressee == userId).toList();
  List<ContactLink> get outgoing =>
      contacts.where((c) => c.status == 'pending' && c.requester == userId).toList();

  Future<void> sendRequest(String friendCode) async {
    await _db.rpc('send_contact_request', params: {'p_friend_code': friendCode});
    await refreshContacts();
  }

  Future<void> respond(int id, bool accept) async {
    await _db.rpc('respond_contact_request', params: {'p_id': id, 'p_accept': accept});
    await refreshContacts();
  }

  Future<void> removeContact(String other) async {
    await _db.rpc('remove_contact', params: {'p_other': other});
    await refreshContacts();
  }

  Future<String> createInvite() async => await _db.rpc('create_invite') as String;

  Future<void> trustNewKey(String contactId) async {
    await keys.repin(contactId, profiles[contactId]!.signPublicKey);
    keyChanged.remove(contactId);
    notifyListeners();
  }

  Future<String> safetyNumber(String contactId) => E2E.safetyNumber(
      base64Decode(me!.signPublicKey), base64Decode(profiles[contactId]!.signPublicKey));

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
      if (sender == null) throw const E2EException('알 수 없는 사용자');
      if (keyChanged.contains(sender.id)) throw const E2EException('보안 키가 바뀌었습니다');
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
        senderSignPublic: base64Decode(sender.signPublicKey),
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
      readAt: r['read_at'] == null ? null : DateTime.parse(r['read_at']).toLocal(),
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
    final recipient = profiles[recipientId]!;
    if (keyChanged.contains(recipientId)) {
      throw const E2EException('상대방의 보안 키가 바뀌었습니다. 먼저 확인해 주세요.');
    }
    final env = await E2E.seal(
      plaintext: text,
      senderId: userId!,
      recipientId: recipientId,
      recipientDhPublic: base64Decode(recipient.dhPublicKey),
      senderDhPublic: base64Decode(me!.dhPublicKey),
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
    final unread = (chats[other] ?? []).any((m) => m.senderId == other && m.readAt == null);
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

  int unreadCount(String other) =>
      (chats[other] ?? []).where((m) => m.senderId == other && m.readAt == null).length;

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
            if (!profiles.containsKey(r['sender_id'])) await refreshContacts();
            _add(await _decrypt(r));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contacts',
          callback: (_) => refreshContacts(),
        )
        .subscribe();
  }
}
