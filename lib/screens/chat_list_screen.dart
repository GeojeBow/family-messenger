import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_state.dart';
import '../services/models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';
import 'my_profile_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final rows = state.members.map((p) => p.id).toList()
          ..sort((a, b) {
            final la = state.chats[a]?.lastOrNull?.createdAt ?? DateTime(2000);
            final lb = state.chats[b]?.lastOrNull?.createdAt ?? DateTime(2000);
            return lb.compareTo(la);
          });
        return Scaffold(
          appBar: AppBar(title: const Text('우리끼리')),
          drawer: _Drawer(),
          body: RefreshIndicator(
            onRefresh: state.bootstrap,
            child: rows.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 160),
                    Center(
                      child: Text('가족 목록을 불러오지 못했어요.\n아래로 당겨 새로고침해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subtitle)),
                    ),
                  ])
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _ChatTile(peerId: rows[i]),
                  ),
          ),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String peerId;
  const _ChatTile({required this.peerId});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = state.profiles[peerId];
    if (p == null) return const SizedBox.shrink();
    final last = state.chats[peerId]?.lastOrNull;
    final unread = state.unreadCount(peerId);
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(peerId: peerId))),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          children: [
            Avatar(id: p.id, name: p.displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.divider, width: 0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (state.keyChanged.contains(peerId))
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.warning_amber,
                              size: 16, color: Colors.orange),
                        ),
                      Expanded(
                        child: Text(p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w600)),
                      ),
                      if (last != null) ...[
                        if (last.senderId == state.userId)
                          Icon(
                              last.readAt != null ? Icons.done_all : Icons.done,
                              size: 16,
                              color: AppColors.unread),
                        const SizedBox(width: 4),
                        Text(_when(last.createdAt),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.subtitle)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(
                            last?.text ??
                                (p.hasKeys
                                    ? '대화를 시작해 보세요'
                                    : '아직 앱에 로그인하지 않았어요'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.subtitle)),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.unread,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return DateFormat('HH:mm').format(t);
    }
    if (now.difference(t).inDays < 7) return DateFormat('E', 'ko').format(t);
    return DateFormat('yy.MM.dd').format(t);
  }
}

class _Drawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final me = state.me!;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture:
                Avatar(id: me.id, name: me.displayName, size: 64),
            accountName: Text(me.displayName),
            accountEmail: Text('@${me.username}'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('내 정보 · 이름 바꾸기'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              Navigator.pop(context);
              state.signOut();
            },
          ),
        ],
      ),
    );
  }
}

extension _Last on List<ChatMessage> {
  ChatMessage? get lastOrNull => isEmpty ? null : last;
}
