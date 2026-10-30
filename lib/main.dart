import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';
import 'services/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  await Supabase.initialize(
      url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  runApp(const UrikkiriApp());
}

class UrikkiriApp extends StatelessWidget {
  const UrikkiriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리끼리',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Root(),
    );
  }
}

/// Decides between the sign-in screen and the chat list.
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  final state = AppState.instance;
  late Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = state.signedIn ? state.bootstrap() : Future.value();
    state.addListener(_onChange);
  }

  @override
  void dispose() {
    state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || state.me == null) return const AuthScreen();
        return const ChatListScreen();
      },
    );
  }
}
