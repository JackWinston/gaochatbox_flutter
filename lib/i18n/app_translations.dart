import 'dart:ui';

import 'package:get/get.dart';

class AppTranslations extends Translations {
  static const localeZh = Locale('zh');
  static const localeEn = Locale('en');

  static const _presetDefault = 'default';
  static const _presetFamilyDoctor = 'family_doctor';
  static const _presetLawyer = 'lawyer';
  static const _presetTranslator = 'translator';
  static const _presetWriter = 'writer';
  static const _presetProgrammer = 'programmer';
  static const _presetInterviewCoach = 'interview_coach';
  static const _presetStudyTutor = 'study_tutor';

  @override
  Map<String, Map<String, String>> get keys => {
    'zh': _zh,
    'zh_CN': _zh,
    'zh_TW': _zh,
    'zh_HK': _zh,
    'en': _en,
    'en_US': _en,
    'en_GB': _en,
  };

  static String presetTag(String presetKey, {Locale? locale}) {
    final code = _languageCode(locale);
    return (_presetTexts[code] ?? _presetTexts['zh']!)[presetKey]?['tag'] ??
        presetKey;
  }

  static String presetContent(String presetKey, {Locale? locale}) {
    final code = _languageCode(locale);
    return (_presetTexts[code] ?? _presetTexts['zh']!)[presetKey]?['content'] ??
        '';
  }

  static String _languageCode(Locale? locale) {
    final resolved = locale ?? Get.locale ?? Get.deviceLocale ?? localeZh;
    return resolved.languageCode == 'en' ? 'en' : 'zh';
  }

  static const Map<String, String> _zh = {
    'app.title': 'ChatBox',
    'nav.quick_start': '快捷开始',
    'nav.history': '历史记录',
    'nav.settings': '设置',
    'history.title': '历史记录',
    'history.search_hint': '搜索标题或消息内容',
    'history.filter_by_tag': '按标签筛选',
    'history.filter_all': '全部',
    'history.active_filter': '筛选: @tag',
    'history.empty': '暂无历史会话',
    'history.empty_search': '没有匹配的历史记录',
    'history.no_message': '暂无消息预览',
    'history.menu.debug': '查看调试日志',
    'history.menu.delete': '删除对话',
    'history.delete_title': '删除会话',
    'history.delete_message': '确认删除这条历史会话吗？',
    'history.deleted': '会话已删除',
    'history.debug_unavailable': '调试日志页暂未实现',
    'history.time.yesterday': '昨天',
    'history.time.day_before_yesterday': '前天',
    'debug_log.title': '调试日志',
    'debug_log.copy': '复制',
    'debug_log.delete': '删除日志',
    'debug_log.empty': '暂无调试日志',
    'debug_log.error': '错误',
    'debug_log.request': '请求',
    'debug_log.response': '响应',
    'debug_log.copied': '调试日志已复制',
    'debug_log.deleted': '调试日志已删除',
    'debug_log.delete_title': '删除调试日志',
    'debug_log.delete_message': '确认删除“@title”的调试日志吗？',
    'chat.title': '聊天',
    'chat.system_prompt': '系统提示词',
    'chat.empty_prompt': '暂无提示词',
    'quickstart.add_prompt': '添加提示词',
    'quickstart.menu.edit': '修改',
    'quickstart.menu.delete': '删除',
    'quickstart.dialog.add_title': '新增提示词',
    'quickstart.dialog.edit_title': '编辑提示词',
    'quickstart.dialog.delete_title': '确认删除',
    'quickstart.dialog.delete_message': '确定要删除这个提示词吗？',
    'quickstart.field.tag': '标签名称',
    'quickstart.field.content': '系统提示词内容',
    'common.cancel': '取消',
    'common.confirm': '确定',
    'common.delete': '删除',
    'common.edit': '编辑',
    'common.default': '默认',
    'common.loading': '加载中...',
    'settings.title': '设置',
    'settings.section.model.title': '模型管理',
    'settings.section.model.subtitle': '配置 OpenAI / Anthropic 接口与默认模型',
    'settings.section.ui.title': 'UI 设置',
    'settings.section.ui.subtitle': '主题、语言和消息展示偏好',
    'settings.section.capability.title': '能力设置',
    'settings.section.capability.subtitle': '网页搜索和工具调用限制',
    'settings.add_model': '添加模型',
    'settings.theme': '主题',
    'settings.language': '语言',
    'settings.show_char_count': '显示字符数',
    'settings.show_token_count': '显示 Token 数',
    'settings.show_model_name': '显示模型名',
    'settings.show_timestamp': '显示时间戳',
    'settings.enable_web_search': '启用网页搜索',
    'settings.max_tool_call_rounds': '最大工具调用轮次',
    'settings.model.api_type': 'API 类型：@value',
    'settings.model.default_model': '默认模型：@value',
    'settings.model.api_url': '接口地址：@value',
    'settings.model.temperature': '温度：@value',
    'settings.model.delete_title': '确认删除',
    'settings.model.delete_message': '确定删除模型配置“@name”吗？',
    'settings.dialog.select_theme': '选择主题',
    'settings.dialog.select_language': '选择语言',
    'settings.theme.system': '跟随系统',
    'settings.theme.light': '浅色模式',
    'settings.theme.dark': '深色模式',
    'settings.language.system': '跟随系统',
    'settings.language.zh': '中文',
    'settings.language.en': 'English',
    'settings.dialog.max_tool_call_rounds': '最大工具调用轮次',
    'settings.snackbar.invalid_input': '输入无效',
    'settings.snackbar.invalid_rounds': '请输入 @min 到 @max 之间的整数',
    'settings.dialog.add_model': '添加模型',
    'settings.dialog.edit_model': '编辑模型',
    'settings.field.tag': '标签名称',
    'settings.field.api_type': 'API 类型',
    'settings.field.api_url': 'API 地址',
    'settings.field.api_key': 'API Key',
    'settings.fetch_models': '获取模型列表',
    'settings.fetching_models': '获取中...',
    'settings.field.default_model': '默认模型',
    'settings.field.models': '模型列表（逗号或换行分隔）',
    'settings.field.context_limit': '上下文限制',
    'settings.resolve_context_limit': '自动检测上下文限制',
    'settings.resolving_context_limit': '检测中...',
    'settings.last_detected_context_limit': '最近一次自动检测结果：@value',
    'settings.set_as_default': '设为默认',
    'settings.snackbar.request_unavailable': '无法请求',
    'settings.snackbar.fill_url_key': '请先填写 API 地址和 API Key',
    'settings.snackbar.request_done': '请求完成',
    'settings.snackbar.empty_model_list': '接口返回了空模型列表',
    'settings.snackbar.request_success': '请求成功',
    'settings.snackbar.models_fetched': '已获取 @count 个模型',
    'settings.snackbar.request_failed': '请求失败',
    'settings.snackbar.detect_unavailable': '无法检测',
    'settings.snackbar.fill_default_model': '请先填写默认模型',
    'settings.snackbar.detect_done': '检测完成',
    'settings.snackbar.context_limit_updated': '上下文限制已更新为 @value',
    'settings.snackbar.detect_failed': '检测失败',
    'settings.snackbar.save_failed': '保存失败',
    'settings.snackbar.empty_tag': '标签名称不能为空',
  };

  static const Map<String, String> _en = {
    'app.title': 'ChatBox',
    'nav.quick_start': 'Quick Start',
    'nav.history': 'History',
    'nav.settings': 'Settings',
    'history.title': 'History',
    'history.search_hint': 'Search title or message',
    'history.filter_by_tag': 'Filter by tag',
    'history.filter_all': 'All',
    'history.active_filter': 'Filter: @tag',
    'history.empty': 'No history yet',
    'history.empty_search': 'No matching history found',
    'history.no_message': 'No message preview',
    'history.menu.debug': 'View Debug Log',
    'history.menu.delete': 'Delete Conversation',
    'history.delete_title': 'Delete Conversation',
    'history.delete_message': 'Delete this conversation?',
    'history.deleted': 'Conversation deleted',
    'history.debug_unavailable': 'Debug log page is not available yet',
    'history.time.yesterday': 'Yesterday',
    'history.time.day_before_yesterday': '2 days ago',
    'debug_log.title': 'Debug Log',
    'debug_log.copy': 'Copy',
    'debug_log.delete': 'Delete Log',
    'debug_log.empty': 'No debug log yet',
    'debug_log.error': 'Error',
    'debug_log.request': 'Request',
    'debug_log.response': 'Response',
    'debug_log.copied': 'Debug log copied',
    'debug_log.deleted': 'Debug log deleted',
    'debug_log.delete_title': 'Delete Debug Log',
    'debug_log.delete_message': 'Delete debug log for "@title"?',
    'chat.title': 'Chat',
    'chat.system_prompt': 'System Prompt',
    'chat.empty_prompt': 'No prompt yet',
    'quickstart.add_prompt': 'Add Prompt',
    'quickstart.menu.edit': 'Edit',
    'quickstart.menu.delete': 'Delete',
    'quickstart.dialog.add_title': 'Add Prompt',
    'quickstart.dialog.edit_title': 'Edit Prompt',
    'quickstart.dialog.delete_title': 'Confirm Delete',
    'quickstart.dialog.delete_message': 'Delete this prompt?',
    'quickstart.field.tag': 'Tag',
    'quickstart.field.content': 'System prompt content',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.default': 'Default',
    'common.loading': 'Loading...',
    'settings.title': 'Settings',
    'settings.section.model.title': 'Models',
    'settings.section.model.subtitle':
        'Configure OpenAI / Anthropic endpoints and default models',
    'settings.section.ui.title': 'UI',
    'settings.section.ui.subtitle': 'Theme, language, and display preferences',
    'settings.section.capability.title': 'Capabilities',
    'settings.section.capability.subtitle':
        'Web search and tool call limitations',
    'settings.add_model': 'Add Model',
    'settings.theme': 'Theme',
    'settings.language': 'Language',
    'settings.show_char_count': 'Show character count',
    'settings.show_token_count': 'Show token count',
    'settings.show_model_name': 'Show model name',
    'settings.show_timestamp': 'Show timestamp',
    'settings.enable_web_search': 'Enable web search',
    'settings.max_tool_call_rounds': 'Max tool call rounds',
    'settings.model.api_type': 'API Type: @value',
    'settings.model.default_model': 'Default model: @value',
    'settings.model.api_url': 'API URL: @value',
    'settings.model.temperature': 'Temperature: @value',
    'settings.model.delete_title': 'Confirm Delete',
    'settings.model.delete_message': 'Delete model config "@name"?',
    'settings.dialog.select_theme': 'Select Theme',
    'settings.dialog.select_language': 'Select Language',
    'settings.theme.system': 'Follow system',
    'settings.theme.light': 'Light',
    'settings.theme.dark': 'Dark',
    'settings.language.system': 'Follow system',
    'settings.language.zh': 'Chinese',
    'settings.language.en': 'English',
    'settings.dialog.max_tool_call_rounds': 'Max Tool Call Rounds',
    'settings.snackbar.invalid_input': 'Invalid input',
    'settings.snackbar.invalid_rounds':
        'Enter an integer between @min and @max',
    'settings.dialog.add_model': 'Add Model',
    'settings.dialog.edit_model': 'Edit Model',
    'settings.field.tag': 'Tag',
    'settings.field.api_type': 'API Type',
    'settings.field.api_url': 'API URL',
    'settings.field.api_key': 'API Key',
    'settings.fetch_models': 'Fetch Models',
    'settings.fetching_models': 'Fetching...',
    'settings.field.default_model': 'Default Model',
    'settings.field.models': 'Models (comma or newline separated)',
    'settings.field.context_limit': 'Context Limit',
    'settings.resolve_context_limit': 'Detect Context Limit',
    'settings.resolving_context_limit': 'Detecting...',
    'settings.last_detected_context_limit': 'Last detected value: @value',
    'settings.set_as_default': 'Set as default',
    'settings.snackbar.request_unavailable': 'Request unavailable',
    'settings.snackbar.fill_url_key': 'Fill in API URL and API Key first',
    'settings.snackbar.request_done': 'Request finished',
    'settings.snackbar.empty_model_list':
        'The API returned an empty model list',
    'settings.snackbar.request_success': 'Request succeeded',
    'settings.snackbar.models_fetched': 'Fetched @count models',
    'settings.snackbar.request_failed': 'Request failed',
    'settings.snackbar.detect_unavailable': 'Detection unavailable',
    'settings.snackbar.fill_default_model': 'Fill in the default model first',
    'settings.snackbar.detect_done': 'Detection finished',
    'settings.snackbar.context_limit_updated':
        'Context limit updated to @value',
    'settings.snackbar.detect_failed': 'Detection failed',
    'settings.snackbar.save_failed': 'Save failed',
    'settings.snackbar.empty_tag': 'Tag cannot be empty',
  };

  static const Map<String, Map<String, Map<String, String>>> _presetTexts = {
    'zh': {
      _presetDefault: {'tag': '默认', 'content': '你是一个智能助手'},
      _presetFamilyDoctor: {
        'tag': '家庭医生',
        'content':
            '你是一位谨慎的家庭医生，请用通俗易懂的中文分析常见症状、可能原因、居家处理建议，以及何时需要尽快线下就医。不要替代正式诊断；若出现急重症风险，请优先建议前往急诊，并提醒用户及时呼叫急救。',
      },
      _presetLawyer: {
        'tag': '律师',
        'content':
            '你是一名专业律师助理，请基于中国语境提供清晰、审慎的法律信息梳理，说明常见风险、可行思路、需要准备的材料，以及建议咨询执业律师的边界，不要编造法条。',
      },
      _presetTranslator: {
        'tag': '翻译助手',
        'content':
            '你是一名专业翻译助手，请根据上下文进行准确、自然、地道的双语翻译；把中文翻译成英文，把英文翻译成中文，不必有其他输出。',
      },
      _presetWriter: {
        'tag': '写作助手',
        'content':
            '你是一名中文写作助手，请帮助我润色、扩写、改写和提炼内容，让表达更清晰、更有逻辑、更自然；必要时给出多个不同风格版本。',
      },
      _presetProgrammer: {
        'tag': '编程助手',
        'content':
            '你是一名资深编程助手，请优先给出可执行的解决方案、关键代码、排查思路和注意事项；回答尽量准确、简洁，并说明方案适用前提。',
      },
      _presetInterviewCoach: {
        'tag': '面试教练',
        'content': '你是一名面试教练，请围绕岗位要求帮助我准备自我介绍、项目亮点、常见追问和回答优化建议；必要时模拟面试并给出反馈。',
      },
      _presetStudyTutor: {
        'tag': '学习辅导',
        'content':
            '你是一名耐心的学习辅导老师，请按照由浅入深的方式讲解知识点，结合示例、类比和练习题帮助我理解，并根据我的水平调整难度。',
      },
    },
    'en': {
      _presetDefault: {
        'tag': 'Default',
        'content': 'You are an intelligent assistant.',
      },
      _presetFamilyDoctor: {
        'tag': 'Family Doctor',
        'content':
            'You are a cautious family doctor. Explain common symptoms, possible causes, home care suggestions, and when urgent in-person treatment is needed in clear language. Do not replace formal diagnosis. If there are emergency risks, advise the user to seek emergency care immediately.',
      },
      _presetLawyer: {
        'tag': 'Lawyer',
        'content':
            'You are a professional legal assistant. Provide clear and careful legal information, explain common risks, practical options, required materials, and when the user should consult a licensed lawyer. Do not fabricate laws or regulations.',
      },
      _presetTranslator: {
        'tag': 'Translator',
        'content':
            'You are a professional translation assistant. Translate accurately, naturally, and fluently according to context. Translate Chinese into English and English into Chinese without extra commentary.',
      },
      _presetWriter: {
        'tag': 'Writing Assistant',
        'content':
            'You are a Chinese writing assistant. Help polish, expand, rewrite, and summarize content so it becomes clearer, more logical, and more natural. Provide multiple styles when helpful.',
      },
      _presetProgrammer: {
        'tag': 'Coding Assistant',
        'content':
            'You are a senior coding assistant. Prioritize executable solutions, key code snippets, debugging ideas, and important caveats. Keep answers accurate and concise, and explain the assumptions behind the solution.',
      },
      _presetInterviewCoach: {
        'tag': 'Interview Coach',
        'content':
            'You are an interview coach. Help prepare self-introductions, project highlights, likely follow-up questions, and answer improvements based on the target role. Simulate interviews and provide feedback when useful.',
      },
      _presetStudyTutor: {
        'tag': 'Study Tutor',
        'content':
            'You are a patient tutor. Explain concepts step by step with examples, analogies, and exercises, and adjust the difficulty to the learner level.',
      },
    },
  };
}
