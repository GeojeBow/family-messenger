import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../theme.dart';

/// Asks for fingerprint / face / device PIN whenever the app is opened or
/// comes back from the background, so a borrowed or lost phone does not
/// expose the chats.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _locked = true;
  bool _busy = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && _pausedAt != null &&
        DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
      setState(() => _locked = true);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // No screen lock on this phone: nothing to check against.
        setState(() => _locked = false);
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: '우리끼리를 열려면 본인 확인이 필요합니다',
        persistAcrossBackgrounding: true,
      );
      if (ok) setState(() => _locked = false);
    } catch (_) {
      // Stay locked; the user can tap to retry.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text('우리끼리', style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 32),
            FilledButton.tonal(onPressed: _unlock, child: const Text('잠금 해제')),
          ],
        ),
      ),
    );
  }
}
