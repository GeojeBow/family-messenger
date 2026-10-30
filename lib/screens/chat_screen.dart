import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/app_state.dart';
import '../services/models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';
import 'contact_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  const ChatScreen({super.key, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final state = AppState.instance;
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    state.addListener(_markRead);
    _markRead();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    state.removeListener(_markRead);
    _input.dispose();
    super.dispose();
  }

  void _markRead() => state.markRead(widget.peerId).catchError((_) {});

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await state.send(widget.peerId, text);
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('보내지 못했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _actions(ChatMessage m) {
    final mine = m.senderId == state.userId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('복사'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: m.text));
              Navigator.pop(ctx);
            },
          ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('모두에게서 삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                state.deleteMessage(m);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final peer = state.profiles[widget.peerId];
        if (peer == null) return const Scaffold();
        final messages = state.chats[widget.peerId] ?? const <ChatMessage>[];
        final keyChanged = state.keyChanged.contains(widget.peerId);
        return Scaffold(
          backgroundColor: AppColors.chatBg,
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ContactInfoScreen(peerId: peer.id))),
              child: Row(children: [
                Avatar(id: peer.id, name: peer.displayName, size: 40),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(peer.displayName, style: const TextStyle(fontSize: 17)),
                  const Text('🔒 종단간 암호화',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70)),
                ]),
              ]),
            ),
          ),
          body: Column(
            children: [
              if (keyChanged)
                MaterialBanner(
                  backgroundColor: Colors.orange.shade50,
                  content: Text('${peer.displayName}님의 보안 키가 바뀌었습니다. '
                      '새 휴대폰이 아니라면 직접 확인해 주세요.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ContactInfoScreen(peerId: peer.id))),
                      child: const Text('확인하기'),
                    ),
                  ],
                ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final idx = messages.length - 1 - i;
                    final m = messages[idx];
                    final next =
                        idx + 1 < messages.length ? messages[idx + 1] : null;
                    final prev = idx > 0 ? messages[idx - 1] : null;
                    final tail = next == null || next.senderId != m.senderId;
                    final newDay =
                        prev == null || !_sameDay(prev.createdAt, m.createdAt);
                    return Column(children: [
                      if (newDay) _DayChip(m.createdAt),
                      MessageBubble(
                        message: m,
                        mine: m.senderId == state.userId,
                        tail: tail,
                        onLongPress: () => _actions(m),
                      ),
                    ]);
                  },
                ),
              ),
              _Composer(controller: _input, sending: _sending, onSend: _send),
            ],
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  const _DayChip(this.day);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(12)),
      child: Text(DateFormat('M월 d일 EEEE', 'ko').format(day),
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer(
      {required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: '메시지',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: hasText
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: const Icon(Icons.send, color: AppColors.accent),
                      onPressed: sending ? null : onSend,
                    )
                  : const SizedBox(
                      key: ValueKey('none'), width: 12, height: 48),
            ),
          ],
        ),
      ),
    );
  }
}
