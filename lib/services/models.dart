class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? dhPublicKey;
  final String? signPublicKey;

  Profile.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        username = j['username'],
        displayName = j['display_name'],
        dhPublicKey = j['dh_public_key'],
        signPublicKey = j['sign_public_key'];

  /// False until this member has signed in on a phone for the first time.
  bool get hasKeys => dhPublicKey != null && signPublicKey != null;
}

class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;
  final DateTime? readAt;
  final String text;
  final bool failed;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.readAt,
    required this.text,
    this.failed = false,
  });

  String peer(String me) => senderId == me ? recipientId : senderId;
}
