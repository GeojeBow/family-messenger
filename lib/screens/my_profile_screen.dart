import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String? _invite;
  bool _busy = false;

  Future<void> _createInvite() async {
    setState(() => _busy = true);
    try {
      final code = await AppState.instance.createInvite();
      setState(() => _invite = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('초대 코드를 만들지 못했어요 (열린 초대는 최대 5개)')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.instance.me!;
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Avatar(id: me.id, name: me.displayName, size: 96)),
          const SizedBox(height: 12),
          Text(me.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          const Text('내 친구 코드', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('이미 가입한 가족이 이 코드로 대화 요청을 보낼 수 있어요. 내가 승인해야 대화가 열립니다.',
              style: TextStyle(color: AppColors.subtitle)),
          _CodeBox(code: me.friendCode, onCopy: () => _copy(me.friendCode)),
          const SizedBox(height: 32),
          const Text('새 가족 초대', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('아직 앱에 가입하지 않은 가족에게 줄 일회용 코드예요. 3일 뒤 만료되며, '
              '가입하면 나와 자동으로 연결됩니다.',
              style: TextStyle(color: AppColors.subtitle)),
          if (_invite != null) _CodeBox(code: _invite!, onCopy: () => _copy(_invite!)),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: _busy ? null : _createInvite,
            icon: const Icon(Icons.card_giftcard),
            label: const Text('초대 코드 만들기'),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _CodeBox({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
            child: SelectableText(code,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 22, letterSpacing: 3)),
          ),
          IconButton(icon: const Icon(Icons.copy), onPressed: onCopy),
        ]),
      );
}
