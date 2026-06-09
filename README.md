# ChatBox Flutter

一款支持多模型、多角色人设的 AI 聊天应用，基于原生 Android 版本（`chatbox_view`）的 Flutter 重写。

## 功能特性

### 快捷开始

- 以瀑布流网格展示所有角色预设（系统提示词）
- 点击卡片即可开始新对话
- 支持新增、编辑、删除自定义角色
- 支持拖拽排序自定义角色

### 聊天

- 流式传输实时显示 AI 响应（SSE）
- Markdown 渲染（表格、链接、删除线等）
- 多模态输入：文本 + 图片/文件附件
- 工具调用：支持网页搜索，展示调用过程和结果
- 上下文压缩：自动管理历史消息以适应模型上下文窗口
- 自动为新对话生成标题
- 编辑对话标题、删除对话、新建对话
- 停止正在生成的响应
- 长按复制消息内容
- 上下文使用量进度条

### 历史记录

- 对话列表展示（标题、最后消息预览、相对时间戳）
- 关键词搜索对话
- 按标签筛选对话
- 长按查看调试日志或删除对话

### 设置

- **模型管理**：添加/编辑/删除 AI 模型配置
  - 支持 OpenAI 和 Anthropic API 类型
  - 自动获取可用模型列表
  - 自动检测上下文 token 限制
  - 温度参数调节
- **界面设置**：主题（系统/浅色/深色）、语言（系统/中文/英文）
- **能力设置**：网页搜索开关、最大工具调用轮次

## 技术栈

| 项目 | 技术 |
|------|------|
| 语言 | Dart |
| 框架 | Flutter |
| 状态管理 | GetX |
| 路由 | GetX |
| 网络 | Dio |
| 偏好存储 | shared_preferences |
| Markdown | flutter_markdown |
| UI | Material Design 3 |

### 目录结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # GetMaterialApp 配置、主题
├── app_settings_service.dart    # 全局设置服务
├── app_theme.dart               # 主题定义（亮色/暗色）
├── i18n/                        # 国际化
│
├── data/
│   ├── model/                   # 数据模型
│   ├── local/                   # 本地存储（数据库、DAO、实体）
│   ├── remote/                  # 网络 API（Dio 客户端、SSE 解析）
│   └── repository/              # 仓库层
│
├── ui/
│   ├── home/                    # 首页（底部 3 Tab）
│   │   ├── quickstart/          # 快捷开始
│   │   ├── history/             # 历史记录
│   │   └── settings/            # 设置
│   ├── chat/                    # 聊天页面
│   │   └── widget/              # 聊天相关组件
│   └── debug_log/               # 调试日志
│
├── util/                        # 工具类
└── widget/                      # 通用组件
```

## 构建与运行

### 环境要求

- Flutter SDK 3.12.1+
- Dart SDK 3.12.1+

### 构建命令

```bash
# 安装依赖
flutter pub get

# 代码生成（drift、json_serializable、freezed）
dart run build_runner build --delete-conflicting-outputs

# 运行调试版
flutter run

# 构建 APK
flutter build apk --release

# 运行测试
flutter test
```

## 代码规范

- 遵循 GetX 页面结构约定：`view.dart`（UI）+ `logic.dart`（逻辑）+ `status.dart`（状态）
- 使用 `.obs` + `Obx` 实现响应式状态管理
- 使用 Dio 处理网络请求，手动解析 SSE 流
- 使用 Material 3 组件和主题
- 支持中英文国际化

## 开源许可

本项目仅供学习交流使用。
