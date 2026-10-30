import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final code = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구 코드로 추가'),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '상대방에게 받은 10자리 코드'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, code.text), child: const Text('요청 보내기')),
        ],
      ),
    );
    if (submitted == null || submitted.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppState.instance.sendRequest(submitted);
      messenger.showSnackBar(const SnackBar(content: Text('요청을 보냈어요. 상대방이 승인하면 대화할 수 있어요.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('코드를 다시 확인해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final me = state.userId!;
        return Scaffold(
          appBar: AppBar(title: const Text('가족')),
          body: ListView(
            children: [
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.person_add_alt_1, color: Colors.white)),
                title: const Text('친구 코드로 추가',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500)),
                onTap: () => _add(context),
              ),
              if (state.incoming.isNotEmpty) ...[
                const _Header('받은 요청'),
                for (final c in state.incoming)
                  _row(state, c.other(me),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => state.respond(c.id, false)),
                        IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => state.respond(c.id, true)),
                      ])),
              ],
              if (state.outgoing.isNotEmpty) ...[
                const _Header('보낸 요청 (승인 대기)'),
                for (final c in state.outgoing) _row(state, c.other(me), subtitle: '대기 중'),
              ],
              const _Header('대화 상대'),
              for (final c in state.accepted)
                _row(state, c.other(me),
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => ChatScreen(peerId: c.other(me))))),
            ],
          ),
        );
      },
    );
  }

  Widget _row(AppState state, String id,
      {Widget? trailing, String? subtitle, VoidCallback? onTap}) {
    final p = state.profiles[id];
    if (p == null) return const SizedBox.shrink();
    return ListTile(
      leading: Avatar(id: p.id, name: p.displayName, size: 44),
      title: Text(p.displayName),
      subtitle: Text(subtitle ?? '@${p.username}'),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFF1F2F6),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(text,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
      );
}
