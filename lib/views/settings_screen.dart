import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../services/webdav_service.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';
import 'advanced_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _webdavUrlCtrl;
  late TextEditingController _webdavUserCtrl;
  late TextEditingController _webdavPassCtrl;
  late TextEditingController _webdavDirCtrl;

  bool _isTestingWebdav = false;
  bool _isSyncing = false;
  bool _isCheckingUpdate = false;
  double _downloadProgress = 0.0;
  bool _isDownloadingApk = false;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    _webdavUrlCtrl = TextEditingController(text: s.webdavUrl);
    _webdavUserCtrl = TextEditingController(text: s.webdavUsername);
    _webdavPassCtrl = TextEditingController(text: s.webdavPassword);
    _webdavDirCtrl = TextEditingController(text: s.webdavRemoteDir);
  }

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPassCtrl.dispose();
    _webdavDirCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final s = prov.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 0. 高级功能入口卡片 (显眼置顶)
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.tune, color: Colors.white),
              ),
              title: const Text('高级功能与深度配置', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('OCR 引擎切换、AI 模型微调、Prompt 自定义、生物锁'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 1. WebDAV 云同步配置
          const Text('☁️ WebDAV 云端同步与自动同步', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('启用 WebDAV 自动同步', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('支持坚果云、Nextcloud、群晖 NAS 等'),
                    value: s.webdavEnabled,
                    onChanged: (val) {
                      s.webdavEnabled = val;
                      prov.updateSettings(s);
                    },
                  ),
                  if (s.webdavEnabled) ...[
                    TextField(
                      controller: _webdavUrlCtrl,
                      decoration: const InputDecoration(labelText: 'WebDAV 服务器地址', hintText: 'https://dav.jianguoyun.com/dav/'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webdavUserCtrl,
                      decoration: const InputDecoration(labelText: '账号 / 邮箱'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webdavPassCtrl,
                      decoration: const InputDecoration(labelText: '应用密码 / Token'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webdavDirCtrl,
                      decoration: const InputDecoration(labelText: '远端存储目录', hintText: '/ChronoCare/'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: s.autoSyncInterval,
                      decoration: const InputDecoration(labelText: '自动同步时机'),
                      items: const [
                        DropdownMenuItem(value: 'on_startup', child: Text('每次启动 App 时自动拉取')),
                        DropdownMenuItem(value: 'daily', child: Text('每日固定时间自动同步')),
                        DropdownMenuItem(value: 'manual', child: Text('仅手动同步')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          s.autoSyncInterval = val;
                          prov.updateSettings(s);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isTestingWebdav ? null : () => _testWebdav(s),
                            child: _isTestingWebdav
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('测试连接'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSyncing ? null : () => _syncNow(s),
                            child: _isSyncing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('立即同步'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. 本地数据全量备份与恢复
          const Text('💾 本地备份与恢复', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download, color: Colors.indigo),
                  title: const Text('导出完整数据备份 (ZIP 包)'),
                  subtitle: const Text('包含全部复查记录、检验指标与化验单照片原图'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload, color: Colors.teal),
                  title: const Text('从备份包恢复数据'),
                  subtitle: const Text('选择本地 .zip 备份包快速还原'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. UI 与外观个性化
          const Text('🎨 外观与栏目个性化', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_4_outlined),
                  title: const Text('外观模式'),
                  trailing: DropdownButton<String>(
                    value: s.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                      DropdownMenuItem(value: 'light', child: Text('浅色模式')),
                      DropdownMenuItem(value: 'dark', child: Text('深色模式')),
                    ],
                    onChanged: (val) {
                      if (val != null) prov.updatePartial(themeMode: val);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('紧凑卡片视图'),
                  subtitle: const Text('缩减卡片间距，一屏展示更多记录'),
                  value: s.compactCardMode,
                  onChanged: (val) => prov.updatePartial(compactCardMode: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. 关于与 App 内检查更新
          const Text('ℹ️ 关于与更新', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
                  title: const Text('脉络健康 (ChronoCare)'),
                  subtitle: Text('当前版本: v${UpdateService.currentVersion} (Build ${UpdateService.currentBuildNumber})'),
                  trailing: ElevatedButton(
                    onPressed: _isCheckingUpdate ? null : _checkAppUpdate,
                    child: _isCheckingUpdate
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('检查更新'),
                  ),
                ),
                if (_isDownloadingApk)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('正在下载最新更新包: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: _downloadProgress),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _testWebdav(s) async {
    _saveWebdavFields(s);
    setState(() => _isTestingWebdav = true);
    final ok = await WebDavService.instance.testConnection(s);
    setState(() => _isTestingWebdav = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ WebDAV 连接测试成功！' : '❌ WebDAV 连接失败，请检查地址或密码'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _syncNow(s) async {
    _saveWebdavFields(s);
    setState(() => _isSyncing = true);
    try {
      await WebDavService.instance.uploadDataToWebDav(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 数据已成功同步至 WebDAV 云端！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _saveWebdavFields(s) {
    s.webdavUrl = _webdavUrlCtrl.text.trim();
    s.webdavUsername = _webdavUserCtrl.text.trim();
    s.webdavPassword = _webdavPassCtrl.text.trim();
    s.webdavRemoteDir = _webdavDirCtrl.text.trim();
    Provider.of<SettingsProvider>(context, listen: false).updateSettings(s);
  }

  Future<void> _exportBackup() async {
    try {
      final zipFile = await BackupService.instance.createFullBackupZip();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份导出成功！保存在: ${zipFile.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'ccbackup'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        await BackupService.instance.restoreFromBackupZip(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已从备份包成功恢复！')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final release = await UpdateService.instance.checkUpdate();
    setState(() => _isCheckingUpdate = false);

    if (release == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本 (v1.0.0)')),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('发现新版本 ${release.tagName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(release.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(release.body),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后再说')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startDownloadUpdate(release.downloadUrl);
                },
                child: const Text('立即更新'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _startDownloadUpdate(String url) async {
    if (url.isEmpty) return;
    setState(() {
      _isDownloadingApk = true;
      _downloadProgress = 0.0;
    });

    await UpdateService.instance.downloadAndInstallApk(
      downloadUrl: url,
      onProgress: (p) => setState(() => _downloadProgress = p),
    );

    setState(() => _isDownloadingApk = false);
  }
}
