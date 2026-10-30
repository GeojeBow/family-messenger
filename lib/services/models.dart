class Profile {
  final String id;
  final String username;
  final String displayName;
  final String friendCode;
  final String dhPublicKey;
  final String signPublicKey;

  Profile.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        username = j['username'],
        displayName = j['display_name'],
        friendCode = j['friend_code'] ?? '',
        dhPublicKey = j['dh_public_key'],
        signPublicKey = j['sign_public_key'];
}

class ContactLink {
  final int id;
  final String requester;
  final String addressee;
  final String status;

  ContactLink.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        requester = j['requester'],
        addressee = j['addressee'],
        status = j['status'];

  String other(String me) => requester == me ? addressee : requester;
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
