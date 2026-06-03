import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/model/system_prompt.dart';
import 'logic.dart';

class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key});

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  final QuickStartLogic logic = Get.put(QuickStartLogic());

  int? _dragOverIndex;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (logic.state.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final theme = Theme.of(context);
      return SafeArea(child: _buildWaterfallGrid(theme));
    });
  }

  Widget _buildWaterfallGrid(ThemeData theme) {
    final prompts = logic.state.prompts;
    final List<_Item> items = [
      ...prompts.map((p) => _Item.prompt(p)),
      _Item.add(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columnWidth = (constraints.maxWidth - 16 * 2 - spacing) / 2;

        final leftItems = <_Item>[];
        final rightItems = <_Item>[];
        for (var i = 0; i < items.length; i++) {
          if (i.isEven) {
            leftItems.add(items[i]);
          } else {
            rightItems.add(items[i]);
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: columnWidth,
                child: Column(children: _buildColumnChildren(leftItems, theme)),
              ),
              const SizedBox(width: spacing),
              SizedBox(
                width: columnWidth,
                child: Column(
                  children: _buildColumnChildren(rightItems, theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildColumnChildren(List<_Item> items, ThemeData theme) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.isPrompt) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPromptCard(item.prompt!, theme),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAddCard(theme),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildPromptCard(SystemPrompt prompt, ThemeData theme) {
    if (prompt.isDefault) {
      return GestureDetector(
        onTap: () => logic.onPromptTap(prompt),
        child: _buildCardContent(prompt, theme),
      );
    }

    final index = logic.state.prompts.indexOf(prompt);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final fromIndex = details.data;
        if (fromIndex == index) return false;
        setState(() => _dragOverIndex = index);
        return true;
      },
      onLeave: (_) {
        if (_dragOverIndex == index) {
          setState(() => _dragOverIndex = null);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _dragOverIndex = null);
        final fromIndex = details.data;
        if (fromIndex == index) return;
        final items = logic.state.prompts.toList();
        if (fromIndex < 0 ||
            fromIndex >= items.length ||
            index < 0 ||
            index >= items.length) {
          return;
        }
        final moved = items.removeAt(fromIndex);
        items.insert(index, moved);
        logic.reorderPrompts(items);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = _dragOverIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: isHovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                )
              : null,
          child: GestureDetector(
            onTap: () => logic.onPromptTap(prompt),
            onLongPress: () {
              if (prompt.isPreset) {
                _showDeleteConfirm(prompt);
              } else {
                _showUserCardMenu(prompt);
              }
            },
            child: _buildCardContent(prompt, theme, dragIndex: index),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(
    SystemPrompt prompt,
    ThemeData theme, {
    int? dragIndex,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prompt.tag,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (prompt.isDefault)
                  Icon(
                    Icons.push_pin,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else if (dragIndex != null)
                  _buildDragHandle(prompt, theme, dragIndex),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prompt.content,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(SystemPrompt prompt, ThemeData theme, int index) {
    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 160,
          child: _buildCardContent(prompt, theme),
        ),
      ),
      onDragEnd: (_) => setState(() => _dragOverIndex = null),
      child: Icon(
        Icons.drag_handle,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildAddCard(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddDialog(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 4),
                Text(
                  '添加提示词',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserCardMenu(SystemPrompt prompt) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay?.size.width ?? 400,
        overlay?.size.height ?? 800,
        0,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('修改')),
        PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    ).then((value) {
      if (value == 'edit') {
        _showEditDialog(prompt);
      } else if (value == 'delete') {
        _showDeleteConfirm(prompt);
      }
    });
  }

  void _showAddDialog() {
    final tagController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增提示词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagController,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '标签名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '系统提示词内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final tag = tagController.text.trim();
              final content = contentController.text.trim();
              if (tag.isNotEmpty && content.isNotEmpty) {
                logic.addPrompt(tag, content);
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(SystemPrompt prompt) {
    final tagController = TextEditingController(text: prompt.tag);
    final contentController = TextEditingController(text: prompt.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑提示词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagController,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '标签名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '系统提示词内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final tag = tagController.text.trim();
              final content = contentController.text.trim();
              if (tag.isNotEmpty && content.isNotEmpty) {
                logic.updatePrompt(
                  SystemPrompt(
                    id: prompt.id,
                    tag: tag,
                    content: content,
                    isDefault: prompt.isDefault,
                    isPreset: prompt.isPreset,
                    presetKey: prompt.presetKey,
                    createdAt: prompt.createdAt,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(SystemPrompt prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个提示词吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              logic.deletePrompt(prompt);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final SystemPrompt? prompt;
  final bool isAdd;

  _Item.prompt(this.prompt) : isAdd = false;

  _Item.add() : prompt = null, isAdd = true;

  bool get isPrompt => prompt != null;
}
