# ChatBox Flutter

基于 Android View 版本（`chatbox_view`）的 Flutter 重写项目，用于复习 Flutter 基础知识。
Android View 版本相对路径如下：../chatbox_view

## 原项目概述

原项目是一个多模型 AI 聊天应用，使用 Kotlin + Android View + MVVM + Dagger + Room + Retrofit 构建。

## 功能清单

### 首页（底部导航 3 个 Tab）

1. **快捷开始** — 角色预设卡片，2 列瀑布流网格，支持拖拽排序、增删改查
2. **历史记录** — 会话列表，支持关键词搜索、标签筛选、长按删除/查看日志
3. **设置** — 三个可折叠分组：模型管理、UI 设置、能力设置

### 聊天页

- 流式 AI 回复（SSE），实时内容展示
- Markdown 渲染（表格、链接、删除线）
- 6 种消息类型：时间戳、系统提示词、用户消息、助手消息、流式消息（含思考指示器、耗时、字数、停止按钮）、工具调用消息
- 多模态输入：文本 + 图片附件（Base64 编码，缩放到 1024px）+ 文本文件附件
- 模型选择器对话框（按配置分组展开列表）
- Web 搜索工具调用（并发执行）
- 上下文压缩：自动历史摘要和附件截断以适配模型上下文窗口
- 自动生成会话标题、编辑标题、删除会话、新建聊天
- 长按复制消息内容
- 上下文使用量进度条

### 调试日志页

- 格式化 JSON 请求/响应日志查看
- 复制到剪贴板、删除日志

## Flutter 架构设计

### 状态管理 + 路由：GetX

原项目使用 Dagger + ViewModel + Intent，Flutter 版使用 GetX 替代：

**状态管理**：
- `.obs` + `Obx` 响应式变量（推荐，简单直接）
- `GetBuilder` + `update()` 手动刷新（性能优先场景）
- `Worker`（`ever`/`once`/`debounce`/`interval`）处理副作用

**路由**：
- `Get.to(() => Page())` — 跳转
- `Get.back()` — 返回
- `Get.offAll(() => Page())` — 清栈跳转

**依赖注入**：
- `Get.put(Controller())` — 注入
- `Get.find<Controller>()` — 获取
- `Get.lazyPut(() => Controller())` — 懒加载

### 页面结构约定

每个页面模块包含三个文件：
- `view.dart` — UI 视图（StatelessWidget / StatefulWidget）
- `logic.dart` — 业务逻辑（继承 GetxController）
- `status.dart` — 状态定义（响应式变量）

### 本地存储

| 原项目 (Android)        | Flutter 替代方案              |
|------------------------|------------------------------|
| Room (SQLite)          | drift (原 moor) 或 sqflite   |
| DataStore Preferences  | shared_preferences           |
| 文件存储 (JSON 日志)    | path_provider + dart:io      |

### 网络层

| 原项目 (Android)        | Flutter 替代方案              |
|------------------------|------------------------------|
| Retrofit + OkHttp      | dio                          |
| SSE 流式解析            | dio + StreamTransformer 手动解析 |
| Gson                   | json_serializable / freezed  |

### UI 组件映射

| 原项目 (Android View)        | Flutter 对应                     |
|-----------------------------|----------------------------------|
| RecyclerView + Adapter      | ListView / GridView.builder      |
| BRVAH 多类型 Adapter         | ListView.builder + sealed class  |
| Material 3 BottomNav        | BottomNavigationBar / NavigationBar |
| ConstraintLayout            | Stack + Positioned / LayoutBuilder |
| FlexboxLayout               | Wrap                            |
| Dialog                      | showDialog + AlertDialog         |
| SplashScreen                | flutter_native_splash            |
| Markwon (Markdown)          | flutter_markdown                 |
| ItemTouchHelper (拖拽)       | ReorderableListView              |
| ViewBinding                 | 自动（Widget 树即 UI）             |

## 目录结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # GetMaterialApp 配置、主题
├── app_theme.dart               # 主题定义（亮色/暗色）
│
├── data/
│   ├── model/
│   │   ├── model_config.dart        # AI 模型配置
│   │   └── system_prompt.dart       # 角色预设
│   ├── local/
│   │   ├── app_database.dart        # drift 数据库定义
│   │   ├── dao/
│   │   │   ├── conversation_dao.dart
│   │   │   └── message_dao.dart
│   │   └── entity/
│   │       ├── conversation_entity.dart
│   │       └── message_entity.dart
│   ├── remote/
│   │   ├── api_client.dart          # Dio 客户端配置
│   │   ├── openai_api.dart          # OpenAI 兼容接口
│   │   ├── anthropic_api.dart       # Anthropic 接口
│   │   ├── openai_models.dart       # OpenAI 请求/响应模型
│   │   ├── anthropic_models.dart    # Anthropic 请求/响应模型
│   │   └── sse_parser.dart          # SSE 流式解析
│   └── repository/
│       ├── chat_repository.dart     # 聊天业务逻辑
│       └── settings_repository.dart # 设置数据操作
│
├── ui/
│   ├── home/
│   │   ├── home_page.dart           # 底部导航壳
│   │   ├── quickstart/
│   │   │   ├── view.dart            # 快捷开始页面 UI
│   │   │   ├── logic.dart           # 快捷开始业务逻辑
│   │   │   └── status.dart          # 快捷开始状态定义
│   │   ├── history/
│   │   │   ├── view.dart
│   │   │   ├── logic.dart
│   │   │   └── status.dart
│   │   └── settings/
│   │       ├── view.dart
│   │       ├── logic.dart
│   │       └── status.dart
│   ├── chat/
│   │   ├── view.dart
│   │   ├── logic.dart
│   │   ├── status.dart
│   │   └── widget/
│   │       ├── message_bubble.dart       # 消息气泡
│   │       ├── streaming_message.dart    # 流式消息
│   │       ├── tool_call_message.dart    # 工具调用消息
│   │       ├── timestamp_item.dart       # 时间戳
│   │       ├── system_prompt_item.dart   # 系统提示词
│   │       ├── chat_input_bar.dart       # 输入栏
│   │       ├── model_selector.dart       # 模型选择器
│   │       └── context_usage_bar.dart    # 上下文使用量
│   └── debug_log/
│       └── view.dart
│
├── util/
│   ├── model_config_manager.dart    # 模型配置管理
│   ├── system_prompt_manager.dart   # 系统提示词管理
│   ├── debug_log_manager.dart       # 调试日志管理
│   ├── web_search_tool.dart         # Web 搜索工具
│   ├── context_compression.dart     # 上下文压缩
│   └── image_utils.dart             # 图片处理（缩放、Base64）
│
└── widget/
    ├── expandable_section.dart      # 可折叠分组
    └── confirm_dialog.dart          # 确认对话框
```

## 关键依赖

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状态管理 + 路由 + 依赖注入
  get: ^4.x

  # 网络
  dio: ^5.x

  # 数据库
  drift: ^2.x
  sqlite3_flutter_libs: ^0.5.x

  # 偏好存储
  shared_preferences: ^2.x

  # JSON 序列化
  json_annotation: ^4.x
  freezed_annotation: ^2.x

  # Markdown 渲染
  flutter_markdown: ^0.7.x

  # 工具
  path_provider: ^2.x
  image_picker: ^1.x
  file_picker: ^8.x
  intl: ^0.19.x  # 日期格式化

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.x
  json_serializable: ^6.x
  freezed: ^2.x
  drift_dev: ^2.x
  flutter_lints: ^6.0.0
```

## 数据模型

### 会话 (conversations)

| 字段              | 类型     | 说明                     |
|------------------|----------|--------------------------|
| id               | int      | 自增主键                  |
| title            | String   | 会话标题                  |
| characterId      | int?     | 角色 ID                  |
| modelId          | int      | 模型配置 ID               |
| systemPromptTag  | String?  | 系统提示词标签             |
| systemPrompt     | String?  | 系统提示词内容             |
| displayTag       | String?  | 显示标签                  |
| totalTokenCount  | int      | 总 token 数              |
| createdAt        | int      | 创建时间戳                |
| updatedAt        | int      | 更新时间戳（索引）         |

### 消息 (messages)

| 字段             | 类型     | 说明                          |
|-----------------|----------|-------------------------------|
| id              | int      | 自增主键                       |
| conversationId  | int      | 外键，级联删除                 |
| role            | String   | user / assistant / system / tool |
| content         | String   | 消息内容                       |
| displayContent  | String?  | 显示内容（可能与 content 不同）  |
| attachmentName  | String?  | 附件名称                       |
| imageUri        | String?  | 图片 URI                       |
| tokenCount      | int      | token 数                      |
| modelName       | String?  | 模型名称                       |
| isStreaming     | bool     | 是否正在流式传输                |
| createdAt       | int      | 创建时间戳                      |
| toolCallId      | String?  | 工具调用 ID                    |
| toolCalls       | String?  | JSON 序列化的工具调用            |

### 模型配置 (ModelConfig)

非持久化，通过 SharedPreferences + JSON 存储。

| 字段                    | 类型     | 说明                    |
|------------------------|----------|-------------------------|
| id                     | int      | 唯一 ID                 |
| tag                    | String   | 标签名称                 |
| apiType                | String   | openai / anthropic      |
| apiUrl                 | String   | API 地址                 |
| apiKey                 | String   | API Key                 |
| models                 | List     | 可用模型列表              |
| defaultModel           | String?  | 默认模型                 |
| contextLimit           | int?     | 上下文 token 限制         |
| detectedContextLimit   | int?     | 自动检测的上下文限制       |
| contextLimitManuallySet| bool     | 是否手动设置              |
| temperature            | double   | 温度参数                 |
| isDefault              | bool     | 是否默认配置              |
| createdAt              | int      | 创建时间戳                |

### 角色预设 (SystemPrompt)

非持久化，通过 SharedPreferences + JSON 存储。

| 字段       | 类型     | 说明              |
|-----------|----------|-------------------|
| id        | int      | 唯一 ID           |
| content   | String   | 提示词内容         |
| tag       | String   | 标签名称           |
| isDefault | bool     | 是否默认           |
| isPreset  | bool     | 是否内置预设       |
| presetKey | String?  | 内置预设标识       |
| createdAt | int      | 创建时间戳         |

## API 接口

### OpenAI 兼容接口

- `GET /models` — 获取可用模型列表
- `POST /chat/completions` — 非流式聊天补全
- `POST /chat/completions`（流式）— 流式聊天补全，返回 SSE

### Anthropic 接口

- `GET /models` — 获取模型列表
- `GET /models/{modelId}` — 获取单个模型信息
- `POST /messages` — 非流式消息
- `POST /messages`（流式）— 流式消息，返回 SSE

### SSE 解析

- OpenAI：解析 `data: ` 前缀行，处理 `[DONE]` 终止信号
- Anthropic：处理 `content_block_delta`、`message_delta`、`message_stop` 事件类型
- 统一输出为 `StreamEvent` sealed class：ContentDelta / ToolCallDelta / StreamEnd / Error

## 实现注意事项

1. **流式响应**：使用 Dio 的 `responseType: ResponseType.stream`，手动解析 SSE 数据流
2. **图片处理**：选择图片后缩放到最大 1024px，转换为 Base64 编码发送
3. **上下文压缩**：当消息总 token 接近模型上下文限制时，自动摘要历史消息、截断附件
4. **Web 搜索**：通过抓取 Bing/DuckDuckGo HTML 搜索结果实现，无需 API Key
5. **URL 检测**：输入看起来像 URL 时，直接抓取并提取可读内容
6. **拖拽排序**：使用 `ReorderableListView` 或 `ReorderableGridView`（需自定义）
7. **多语言**：使用 `intl` + ARB 文件实现中英文切换
8. **主题**：支持跟随系统 / 亮色 / 暗色三种模式

## 开发命令

```bash
# 安装依赖
flutter pub get

# 代码生成（drift、json_serializable、freezed）
dart run build_runner build --delete-conflicting-outputs

# 运行
flutter run

# 构建 APK
flutter build apk --release

# 运行测试
flutter test
```
