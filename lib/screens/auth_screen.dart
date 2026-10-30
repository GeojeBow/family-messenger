import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  String? _error;
  final _invite = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = AppState.instance;
      final username = _username.text.trim().toLowerCase();
      if (_register) {
        if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
          throw '아이디는 영문 소문자, 숫자, _ 3~20자로 정해 주세요';
        }
        if (_password.text.length < 8) throw '비밀번호는 8자 이상이어야 합니다';
        if (_name.text.trim().isEmpty) throw '이름을 입력해 주세요';
        await state.register(
          inviteCode: _invite.text.trim(),
          username: username,
          displayName: _name.text.trim(),
          password: _password.text,
        );
      } else {
        await state.signIn(username, _password.text);
      }
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('invalid invite')) return '초대 코드가 올바르지 않거나 만료되었습니다';
    if (s.contains('Invalid login')) return '아이디 또는 비밀번호가 틀렸습니다';
    if (s.contains('already registered') || s.contains('duplicate')) {
      return '이미 사용 중인 아이디입니다';
    }
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
            Text(_register ? '초대받은 가족만 가입할 수 있어요' : '가족 전용 메신저',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtitle)),
            const SizedBox(height: 32),
            if (_register) ...[
              _field(_invite, '초대 코드 (첫 가입자는 비워두기)', caps: true),
              _field(_name, '이름 (가족에게 보이는 이름)'),
            ],
            _field(_username, '아이디'),
            _field(_password, '비밀번호', obscure: true),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_register ? '가입하기' : '로그인', style: const TextStyle(fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              child: Text(_register ? '이미 계정이 있어요' : '초대 코드로 가입하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool obscure = false, bool caps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
