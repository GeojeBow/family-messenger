import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  Future<void> _rename(BuildContext context) async {
    final state = AppState.instance;
    final name = TextEditingController(text: state.me!.displayName);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 바꾸기'),
        content: TextField(
          controller: name,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '가족에게 보이는 이름'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, name.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.rename(value);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('이름을 바꾸지 못했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final me = state.me!;
        return Scaffold(
          appBar: AppBar(title: const Text('내 정보')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Avatar(id: me.id, name: me.displayName, size: 96)),
              const SizedBox(height: 12),
              Text(me.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600)),
              Text('@${me.username}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.subtitle)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _rename(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('이름 바꾸기'),
              ),
            ],
          ),
        );
      },
    );
  }
}
