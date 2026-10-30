import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

class ContactInfoScreen extends StatelessWidget {
  final String peerId;
  const ContactInfoScreen({super.key, required this.peerId});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = state.profiles[peerId]!;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final changed = state.keyChanged.contains(peerId);
        return Scaffold(
          appBar: AppBar(title: const Text('정보')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Avatar(id: p.id, name: p.displayName, size: 96)),
              const SizedBox(height: 12),
              Text(p.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              Text('@${p.username}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.subtitle)),
              const SizedBox(height: 32),
              const Text('보안 번호', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              FutureBuilder(
                future: state.safetyNumber(peerId),
                builder: (context, snap) => Text(
                  snap.data ?? '...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 20, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '만났을 때 서로의 화면에서 이 숫자가 같은지 비교해 보세요. '
                '같다면 중간에서 대화를 엿보는 사람이 없다는 뜻입니다.',
                style: TextStyle(color: AppColors.subtitle),
              ),
              if (changed) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('보안 키가 바뀌었습니다',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('휴대폰을 바꾸거나 앱을 다시 설치하면 키가 바뀝니다. '
                          '본인에게 직접 확인한 뒤 승인해 주세요.'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => state.trustNewKey(peerId),
                        child: const Text('확인했어요, 새 키를 신뢰'),
                      ),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('대화 상대에서 삭제'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: Text('${p.displayName}님을 삭제할까요? 다시 대화하려면 서로 승인해야 합니다.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await state.removeContact(peerId);
                    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
