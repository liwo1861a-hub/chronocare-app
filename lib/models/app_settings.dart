import 'dart:convert';

class AppSettings {
  // --- AI 配置 ---
  String aiProvider; // 'gemini', 'openai', 'deepseek', 'claude', 'custom'
  String geminiApiKey;
  String geminiModel; // 默认 'gemini-3.7-flash'
  String geminiBaseUrl;
  
  String openAiApiKey;
  String openAiBaseUrl;
  String openAiModel;
  
  String deepSeekApiKey;
  String deepSeekBaseUrl;
  String deepSeekModel; // 'deepseek-chat', 'deepseek-reasoner'
  
  String customApiKey;
  String customBaseUrl;
  String customModel;
  
  double aiTemperature;
  int aiMaxTokens;
  String customSystemPrompt;

  // --- OCR 配置 ---
  String ocrEngine; // 'gemini_vision'(默认), 'mlkit_local', 'ocr_space', 'custom_ocr'
  String ocrSpaceApiKey; // 免费公共 Key 或用户自定义 Key
  bool ocrAutoRotate; // 图像自动旋转矫正
  bool ocrPreprocess; // 图像对比度增强

  // --- 批量导入与自动化（两个独立核心开关） ---
  bool batchAutoOcr; // 开关1：批量上传后自动进行 OCR 识别
  bool batchAutoAiParse; // 开关2：OCR 完成后自动调用 AI 整理分类入库
  int batchConcurrency; // 批量并发数 (1~5)

  // --- WebDAV 同步配置 ---
  bool webdavEnabled;
  String webdavUrl;
  String webdavUsername;
  String webdavPassword;
  String webdavRemoteDir; // 如 /ChronoCare/
  String autoSyncInterval; // 'manual', 'on_startup', 'on_change', 'daily', 'weekly'
  String autoSyncTime; // '22:00'
  bool syncWifiOnlyForImages;
  bool syncEncryptBackup; // 上传备份时是否加密
  String syncEncryptKey;

  // --- UI 与外观偏好 ---
  String themeMode; // 'system', 'light', 'dark'
  String primaryColorHex; // 主题色 如 #2563EB
  bool compactCardMode; // 紧凑卡片模式
  double fontScale; // 字体缩放比例 0.9 ~ 1.3
  
  // --- 栏目与排序自定义 ---
  List<String> enabledTabs; // ['timeline', 'diseases', 'categories', 'trend']
  String defaultStartupTab; // 默认启动栏目
  String defaultRecordSort; // 'date_desc', 'date_asc', 'abnormal_first'

  // --- 高级功能与实验性开关 ---
  bool enableBiometricLock; // 生物指纹/面容解锁
  bool enableDebugLogs; // 开启调试日志
  bool autoCheckUpdates; // 自动检查更新
  String updateChannel; // 'stable', 'beta'

  AppSettings({
    this.aiProvider = 'gemini',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-3.7-flash',
    this.geminiBaseUrl = 'https://generativelanguage.googleapis.com',
    this.openAiApiKey = '',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.openAiModel = 'gpt-4o',
    this.deepSeekApiKey = '',
    this.deepSeekBaseUrl = 'https://api.deepseek.com/v1',
    this.deepSeekModel = 'deepseek-chat',
    this.customApiKey = '',
    this.customBaseUrl = 'https://api.openai.com/v1',
    this.customModel = 'gpt-4o-mini',
    this.aiTemperature = 0.2,
    this.aiMaxTokens = 4096,
    this.customSystemPrompt = '',
    this.ocrEngine = 'gemini_vision',
    this.ocrSpaceApiKey = 'K88888888888957',
    this.ocrAutoRotate = true,
    this.ocrPreprocess = true,
    this.batchAutoOcr = true,
    this.batchAutoAiParse = true,
    this.batchConcurrency = 2,
    this.webdavEnabled = false,
    this.webdavUrl = 'https://dav.jianguoyun.com/dav/',
    this.webdavUsername = '',
    this.webdavPassword = '',
    this.webdavRemoteDir = '/ChronoCare/',
    this.autoSyncInterval = 'daily',
    this.autoSyncTime = '22:00',
    this.syncWifiOnlyForImages = true,
    this.syncEncryptBackup = false,
    this.syncEncryptKey = '',
    this.themeMode = 'system',
    this.primaryColorHex = '#2563EB',
    this.compactCardMode = false,
    this.fontScale = 1.0,
    List<String>? enabledTabs,
    this.defaultStartupTab = 'timeline',
    this.defaultRecordSort = 'date_desc',
    this.enableBiometricLock = false,
    this.enableDebugLogs = false,
    this.autoCheckUpdates = true,
    this.updateChannel = 'stable',
  }) : enabledTabs = enabledTabs ?? ['timeline', 'diseases', 'categories', 'trend'];

  Map<String, dynamic> toMap() {
    return {
      'aiProvider': aiProvider,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'geminiBaseUrl': geminiBaseUrl,
      'openAiApiKey': openAiApiKey,
      'openAiBaseUrl': openAiBaseUrl,
      'openAiModel': openAiModel,
      'deepSeekApiKey': deepSeekApiKey,
      'deepSeekBaseUrl': deepSeekBaseUrl,
      'deepSeekModel': deepSeekModel,
      'customApiKey': customApiKey,
      'customBaseUrl': customBaseUrl,
      'customModel': customModel,
      'aiTemperature': aiTemperature,
      'aiMaxTokens': aiMaxTokens,
      'customSystemPrompt': customSystemPrompt,
      'ocrEngine': ocrEngine,
      'ocrSpaceApiKey': ocrSpaceApiKey,
      'ocrAutoRotate': ocrAutoRotate,
      'ocrPreprocess': ocrPreprocess,
      'batchAutoOcr': batchAutoOcr,
      'batchAutoAiParse': batchAutoAiParse,
      'batchConcurrency': batchConcurrency,
      'webdavEnabled': webdavEnabled,
      'webdavUrl': webdavUrl,
      'webdavUsername': webdavUsername,
      'webdavPassword': webdavPassword,
      'webdavRemoteDir': webdavRemoteDir,
      'autoSyncInterval': autoSyncInterval,
      'autoSyncTime': autoSyncTime,
      'syncWifiOnlyForImages': syncWifiOnlyForImages,
      'syncEncryptBackup': syncEncryptBackup,
      'syncEncryptKey': syncEncryptKey,
      'themeMode': themeMode,
      'primaryColorHex': primaryColorHex,
      'compactCardMode': compactCardMode,
      'fontScale': fontScale,
      'enabledTabs': jsonEncode(enabledTabs),
      'defaultStartupTab': defaultStartupTab,
      'defaultRecordSort': defaultRecordSort,
      'enableBiometricLock': enableBiometricLock,
      'enableDebugLogs': enableDebugLogs,
      'autoCheckUpdates': autoCheckUpdates,
      'updateChannel': updateChannel,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    List<String> tabs = ['timeline', 'diseases', 'categories', 'trend'];
    if (map['enabledTabs'] != null) {
      try {
        final decoded = jsonDecode(map['enabledTabs']);
        if (decoded is List) tabs = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return AppSettings(
      aiProvider: map['aiProvider'] ?? 'gemini',
      geminiApiKey: map['geminiApiKey'] ?? '',
      geminiModel: map['geminiModel'] ?? 'gemini-3.7-flash',
      geminiBaseUrl: map['geminiBaseUrl'] ?? 'https://generativelanguage.googleapis.com',
      openAiApiKey: map['openAiApiKey'] ?? '',
      openAiBaseUrl: map['openAiBaseUrl'] ?? 'https://api.openai.com/v1',
      openAiModel: map['openAiModel'] ?? 'gpt-4o',
      deepSeekApiKey: map['deepSeekApiKey'] ?? '',
      deepSeekBaseUrl: map['deepSeekBaseUrl'] ?? 'https://api.deepseek.com/v1',
      deepSeekModel: map['deepSeekModel'] ?? 'deepseek-chat',
      customApiKey: map['customApiKey'] ?? '',
      customBaseUrl: map['customBaseUrl'] ?? 'https://api.openai.com/v1',
      customModel: map['customModel'] ?? 'gpt-4o-mini',
      aiTemperature: (map['aiTemperature'] as num?)?.toDouble() ?? 0.2,
      aiMaxTokens: map['aiMaxTokens'] ?? 4096,
      customSystemPrompt: map['customSystemPrompt'] ?? '',
      ocrEngine: map['ocrEngine'] ?? 'gemini_vision',
      ocrSpaceApiKey: map['ocrSpaceApiKey'] ?? 'K88888888888957',
      ocrAutoRotate: map['ocrAutoRotate'] ?? true,
      ocrPreprocess: map['ocrPreprocess'] ?? true,
      batchAutoOcr: map['batchAutoOcr'] ?? true,
      batchAutoAiParse: map['batchAutoAiParse'] ?? true,
      batchConcurrency: map['batchConcurrency'] ?? 2,
      webdavEnabled: map['webdavEnabled'] ?? false,
      webdavUrl: map['webdavUrl'] ?? 'https://dav.jianguoyun.com/dav/',
      webdavUsername: map['webdavUsername'] ?? '',
      webdavPassword: map['webdavPassword'] ?? '',
      webdavRemoteDir: map['webdavRemoteDir'] ?? '/ChronoCare/',
      autoSyncInterval: map['autoSyncInterval'] ?? 'daily',
      autoSyncTime: map['autoSyncTime'] ?? '22:00',
      syncWifiOnlyForImages: map['syncWifiOnlyForImages'] ?? true,
      syncEncryptBackup: map['syncEncryptBackup'] ?? false,
      syncEncryptKey: map['syncEncryptKey'] ?? '',
      themeMode: map['themeMode'] ?? 'system',
      primaryColorHex: map['primaryColorHex'] ?? '#2563EB',
      compactCardMode: map['compactCardMode'] ?? false,
      fontScale: (map['fontScale'] as num?)?.toDouble() ?? 1.0,
      enabledTabs: tabs,
      defaultStartupTab: map['defaultStartupTab'] ?? 'timeline',
      defaultRecordSort: map['defaultRecordSort'] ?? 'date_desc',
      enableBiometricLock: map['enableBiometricLock'] ?? false,
      enableDebugLogs: map['enableDebugLogs'] ?? false,
      autoCheckUpdates: map['autoCheckUpdates'] ?? true,
      updateChannel: map['updateChannel'] ?? 'stable',
    );
  }
}
