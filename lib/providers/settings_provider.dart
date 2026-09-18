import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider with ChangeNotifier {
  AppSettings _settings = AppSettings();
  bool _isLoading = true;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    _settings = await StorageService.instance.getSettings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await StorageService.instance.saveSettings(newSettings);
    notifyListeners();
  }

  Future<void> updatePartial({
    String? aiProvider,
    String? geminiApiKey,
    String? geminiModel,
    String? ocrEngine,
    bool? batchAutoOcr,
    bool? batchAutoAiParse,
    bool? webdavEnabled,
    String? webdavUrl,
    String? webdavUsername,
    String? webdavPassword,
    String? themeMode,
    String? primaryColorHex,
    bool? compactCardMode,
    List<String>? enabledTabs,
  }) async {
    if (aiProvider != null) _settings.aiProvider = aiProvider;
    if (geminiApiKey != null) _settings.geminiApiKey = geminiApiKey;
    if (geminiModel != null) _settings.geminiModel = geminiModel;
    if (ocrEngine != null) _settings.ocrEngine = ocrEngine;
    if (batchAutoOcr != null) _settings.batchAutoOcr = batchAutoOcr;
    if (batchAutoAiParse != null) _settings.batchAutoAiParse = batchAutoAiParse;
    if (webdavEnabled != null) _settings.webdavEnabled = webdavEnabled;
    if (webdavUrl != null) _settings.webdavUrl = webdavUrl;
    if (webdavUsername != null) _settings.webdavUsername = webdavUsername;
    if (webdavPassword != null) _settings.webdavPassword = webdavPassword;
    if (themeMode != null) _settings.themeMode = themeMode;
    if (primaryColorHex != null) _settings.primaryColorHex = primaryColorHex;
    if (compactCardMode != null) _settings.compactCardMode = compactCardMode;
    if (enabledTabs != null) _settings.enabledTabs = enabledTabs;

    await StorageService.instance.saveSettings(_settings);
    notifyListeners();
  }
}
