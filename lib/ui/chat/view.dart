import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'logic.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatLogic logic = Get.put(ChatLogic());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(logic.state.promptTag.value.isEmpty
            ? '聊天'
            : logic.state.promptTag.value)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '系统提示词',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                color: theme.colorScheme.surfaceContainerLow,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Obx(() => Text(
                        logic.state.systemPrompt.value.isEmpty
                            ? '暂无提示词'
                            : logic.state.systemPrompt.value,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                      )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
