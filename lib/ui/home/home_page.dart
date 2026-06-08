import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../chat/conversation_store.dart';
import '../chat/models.dart';
import '../chat/view.dart';
import 'settings/view.dart';
import 'quickstart/view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = [
    const QuickStartPage(),
    const _HistoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch),
            label: 'nav.quick_start'.tr,
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'nav.history'.tr,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'nav.settings'.tr,
          ),
        ],
      ),
    );
  }
}

class _HistoryPage extends StatefulWidget {
  const _HistoryPage();

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  final ChatConversationStore _store = ChatConversationStore();
  List<ChatConversationSummary> _conversations = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final list = await _store.getConversations();
    if (!mounted) {
      return;
    }
    setState(() {
      _conversations = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_conversations.isEmpty) {
      return SafeArea(
        child: Center(
          child: Text(
            '暂无历史会话',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _conversations.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final conversation = _conversations[index];
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text(
                  conversation.displayTag.isNotEmpty
                      ? conversation.displayTag
                      : conversation.title,
                ),
                subtitle: Text(
                  conversation.systemPromptTag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(_formatDate(conversation.updatedAt)),
                onTap: () async {
                  await Get.to(
                    () => const ChatPage(),
                    arguments: {
                      'conversationId': conversation.id,
                      'tag': conversation.systemPromptTag,
                      'content': conversation.systemPromptContent,
                      'displayTag': conversation.displayTag,
                    },
                  );
                  await _loadConversations();
                },
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }
}
