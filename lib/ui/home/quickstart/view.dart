import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import '../../../data/model/system_prompt.dart';
import 'logic.dart';

/// 快捷开始页面
/// 展示角色预设卡片的瀑布流网格，支持拖拽排序、增删改查。
/// 使用 [MasonryGridView] 实现懒加载，避免大量卡片时的性能问题。
class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key});

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  /// 业务逻辑控制器，通过 GetX 注入
  final QuickStartLogic logic = Get.put(QuickStartLogic());

  //构建 widget 树
  @override
  Widget build(BuildContext context) {
    // Obx 监听响应式变量变化，自动重建
    return Obx(() {
      // 数据加载中显示进度指示器
      if (logic.state.isLoading.value) {
        return const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final theme = Theme.of(context);
      // SafeArea 避免内容被状态栏/刘海遮挡
      return SafeArea(child: _buildWaterfallGrid(theme));
    });
  }

  /// 构建瀑布流网格
  /// 使用 [MasonryGridView.count] 实现两列瀑布流布局。
  /// 内部基于 Sliver 机制，只构建屏幕可见区域的 item，
  /// 滚动出屏幕的 widget 会被回收，适合大量数据场景。
  Widget _buildWaterfallGrid(ThemeData theme) {
    // 将提示词列表转换为 _Item 包装对象，末尾追加一个"添加"按钮 item
    final items = [
      ...logic.state.prompts.map((p) => _Item.prompt(p)),
      _Item.add(),
    ];

    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      // 两列
      mainAxisSpacing: 12,
      // 行间距
      crossAxisSpacing: 12,
      // 列间距
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // 根据 item 类型渲染不同的卡片
        return item.isPrompt
            ? _buildPromptCard(item.prompt!, theme)
            : _buildAddCard(theme);
      },
    );
  }

  /// 构建单个提示词卡片
  /// 默认提示词（isDefault）不可拖拽，仅支持点击跳转。
  /// 自定义提示词支持：点击跳转、长按菜单（编辑/删除）、拖拽排序。
  Widget _buildPromptCard(SystemPrompt prompt, ThemeData theme) {
    // 默认提示词：固定在首位，不可拖拽，只响应点击
    if (prompt.isDefault) {
      return GestureDetector(
        onTap: () => logic.onPromptTap(prompt),
        child: _buildCardContent(prompt, theme),
      );
    }

    // 获取当前 prompt 在列表中的索引，用于拖拽排序
    final index = logic.state.prompts.indexOf(prompt);

    // DragTarget 接收拖拽数据，处理排序逻辑
    return DragTarget<int>(
      // 当拖拽项进入此区域时，高亮提示
      onWillAcceptWithDetails: (details) {
        final fromIndex = details.data;
        if (fromIndex == index) return false; // 不能拖到自己身上
        logic.updateDragOverIndex(index);
        return true;
      },
      // 拖拽项离开此区域时，取消高亮
      onLeave: (_) {
        if (logic.state.dragOverIndex.value == index) {
          logic.updateDragOverIndex(-1);
        }
      },
      // 拖拽项放下时，执行排序
      onAcceptWithDetails: (details) {
        logic.updateDragOverIndex(-1);
        final fromIndex = details.data;
        if (fromIndex == index) return;
        final items = logic.state.prompts.toList();
        // 边界检查防止越界
        if (fromIndex < 0 ||
            fromIndex >= items.length ||
            index < 0 ||
            index >= items.length) {
          return;
        }
        // 从原位置移除，插入到目标位置
        final moved = items.removeAt(fromIndex);
        items.insert(index, moved);
        logic.reorderPrompts(items);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = logic.state.dragOverIndex.value == index;
        // AnimatedContainer 实现高亮边框的平滑过渡动画
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
              // 预设提示词只能删除；自定义提示词弹出编辑/删除菜单
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

  /// 构建卡片内容
  /// 显示标签名称和提示词内容摘要。
  /// [dragIndex] 非空时显示拖拽手柄，否则不显示（如默认提示词）。
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
          mainAxisSize: MainAxisSize.min, // 高度自适应内容
          children: [
            Row(
              children: [
                // 标签名称，最多两行，超出省略
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
                // 默认提示词显示固定图标；自定义提示词显示拖拽手柄
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
            // 提示词内容预览，最多 8 行
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

  /// 构建拖拽手柄
  /// 长按触发拖拽，[LongPressDraggable] 拖拽时显示半透明反馈卡片。
  /// [delay] 设置长按 200ms 后才触发，避免与点击/长按菜单冲突。
  Widget _buildDragHandle(SystemPrompt prompt, ThemeData theme, int index) {
    return LongPressDraggable<int>(
      data: index,
      // 传递索引给 DragTarget 用于排序
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        // feedback 是拖拽时跟随手指的浮动卡片
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: 160, child: _buildCardContent(prompt, theme)),
      ),
      onDragEnd: (_) => logic.updateDragOverIndex(-1),
      child: Icon(
        Icons.drag_handle,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 构建"添加提示词"卡片
  /// 固定在列表末尾，点击弹出新增对话框。
  Widget _buildAddCard(ThemeData theme) {
    return SizedBox(
      width: double.infinity, // 占满整列宽度
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

  /// 弹出长按上下文菜单（编辑/删除）
  /// 菜单位置固定在屏幕右下角。
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

  /// 弹出新增提示词对话框
  /// 包含标签名称（最多 20 字）和系统提示词内容（4-8 行输入框）两个输入项。
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

  /// 弹出编辑提示词对话框
  /// 复用新增对话框的 UI 结构，回填原有数据。
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

  /// 弹出删除确认对话框
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

/// 列表项包装类
/// 用于区分普通提示词卡片和末尾的"添加"按钮卡片。
class _Item {
  final SystemPrompt? prompt;
  final bool isAdd;

  _Item.prompt(this.prompt) : isAdd = false;

  _Item.add() : prompt = null, isAdd = true;

  bool get isPrompt => prompt != null;
}
