import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _busy = false;
  String? _error;
  final _username = TextEditingController();
  final _password = TextEditingController();

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = AppState.instance;
      final username = _username.text.trim().toLowerCase();
      await state.signIn(username, _password.text);
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login')) return '아이디 또는 비밀번호가 틀렸습니다';
    return s.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 40),
            const Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.forum_rounded, size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            const Text('우리끼리',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('가족 전용 메신저',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subtitle)),
            const SizedBox(height: 32),
            _field(_username, '아이디'),
            _field(_password, '비밀번호', obscure: true),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('로그인', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
