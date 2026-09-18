import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/settings_provider.dart';
import '../providers/records_provider.dart';
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
  bool _isDownloadingWebdav = false;
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
    final recordsProv = Provider.of<RecordsProvider>(context, listen: false);
    final s = prov.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 0. 高级功能入口卡片 (显眼置顶)
          Card(
            color: Colors.blue.shade50.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blue.withOpacity(0.3)),
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

          // 1. 本地数据全量备份与自定义保存文件夹 (用户关注重点)
          const Text('💾 本地完整备份与自定义保存目录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 自定义保存目录设置
                  Row(
                    children: [
                      const Icon(Icons.folder_special, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '本地备份与导出保存目录',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                        label: const Text('自定义文件夹'),
                        onPressed: () => _pickCustomDirectory(context, s, prov),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.customLocalBackupPath.isNotEmpty
                                ? s.customLocalBackupPath
                                : '[系统默认] /Downloads/ChronoCare/ 或 App 专属目录',
                            style: TextStyle(
                              fontSize: 12,
                              color: s.customLocalBackupPath.isNotEmpty ? Colors.blueAccent : Colors.grey,
                              fontWeight: s.customLocalBackupPath.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (s.customLocalBackupPath.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.restore, size: 18, color: Colors.grey),
                            tooltip: '恢复默认目录',
                            onPressed: () {
                              s.customLocalBackupPath = '';
                              prov.updateSettings(s);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已恢复为系统默认保存目录')),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.file_download, color: Colors.white, size: 20),
                    ),
                    title: const Text('导出完整数据备份 (ZIP 包)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('生成包含全部病历、检验指标、用药、提问及照片原图的 ZIP 包'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _exportBackup(s),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.file_upload, color: Colors.white, size: 20),
                    ),
                    title: const Text('从备份包恢复数据 (开箱即用)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('一键还原全部病历、化验单照片、API Keys 与所有设置'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _restoreBackup(prov, recordsProv),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. WebDAV 云同步配置与自动同步时间设置
          const Text('☁️ WebDAV 云端全量同步与定时策略', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('启用 WebDAV 自动同步', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('支持坚果云、Nextcloud、群晖 NAS 等 (同步全部图片与配置)'),
                    value: s.webdavEnabled,
                    onChanged: (val) {
                      s.webdavEnabled = val;
                      prov.updateSettings(s);
                    },
                  ),
                  if (s.webdavEnabled) ...[
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 服务器地址',
                        hintText: '如 https://dav.jianguoyun.com/dav/',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavUserCtrl,
                      decoration: const InputDecoration(
                        labelText: '账号 / 邮箱',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '应用专属密码 / 授权 Token',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _webdavDirCtrl,
                      decoration: const InputDecoration(
                        labelText: '云端同步目录',
                        hintText: '/ChronoCare/',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sync, color: Colors.blueAccent),
                      title: const Text('同步触发策略'),
                      trailing: DropdownButton<String>(
                        value: s.autoSyncInterval,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'manual', child: Text('仅手动同步')),
                          DropdownMenuItem(value: 'on_startup', child: Text('每次打开 App 时')),
                          DropdownMenuItem(value: 'on_change', child: Text('每次数据变更时')),
                          DropdownMenuItem(value: 'daily', child: Text('每日定时自动同步')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            s.autoSyncInterval = val;
                            prov.updateSettings(s);
                          }
                        },
                      ),
                    ),
                    if (s.autoSyncInterval == 'daily') ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                        title: const Text('每日自动同步时间', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('将在每天 ${s.autoSyncTime} 自动静默同步全部数据与图片'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _pickSyncTime(context, s, prov),
                          child: Text(s.autoSyncTime),
                        ),
                      ),
                    ],
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                            label: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('全量上传', style: TextStyle(color: Colors.white)),
                            onPressed: _isSyncing ? null : () => _syncNow(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            icon: const Icon(Icons.cloud_download, size: 16, color: Colors.white),
                            label: _isDownloadingWebdav
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('从云端还原', style: TextStyle(color: Colors.white)),
                            onPressed: _isDownloadingWebdav ? null : () => _pullFromWebdav(s, prov, recordsProv),
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

          // 3. UI 与外观个性化
          const Text('🎨 外观与个性化', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                      DropdownMenuItem(value: 'dark', child: Text('深色模式 (高对比度)')),
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
          const Text('ℹ️ 关于与更新 (永久固定签名)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                        Text('正在下载最新安装包 (支持就地覆盖升级): ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
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

  Future<void> _pickCustomDirectory(BuildContext context, s, SettingsProvider prov) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '请选择本地备份与导出保存文件夹',
      );
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        s.customLocalBackupPath = selectedDirectory;
        await prov.updateSettings(s);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ 已成功将保存目录设置为:\n$selectedDirectory')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickSyncTime(BuildContext context, s, SettingsProvider prov) async {
    final parts = s.autoSyncTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 22 : 22;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      s.autoSyncTime = '$hourStr:$minStr';
      prov.updateSettings(s);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 全部数据、化验单图片与设置已成功同步至 WebDAV 云端！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pullFromWebdav(s, SettingsProvider prov, RecordsProvider recordsProv) async {
    _saveWebdavFields(s);
    setState(() => _isDownloadingWebdav = true);
    try {
      await WebDavService.instance.restoreDataFromWebDav(s);
      await prov.loadSettings();
      await recordsProv.loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 已从 WebDAV 成功恢复全量数据、化验单照片与设置！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端恢复失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDownloadingWebdav = false);
    }
  }

  void _saveWebdavFields(s) {
    s.webdavUrl = _webdavUrlCtrl.text.trim();
    s.webdavUsername = _webdavUserCtrl.text.trim();
    s.webdavPassword = _webdavPassCtrl.text.trim();
    s.webdavRemoteDir = _webdavDirCtrl.text.trim();
  }

  Future<void> _exportBackup(s) async {
    try {
      final file = await BackupService.instance.createFullBackupZip(
        customTargetDirPath: s.customLocalBackupPath,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🎉 本地全量备份成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已将全部病历、检验指标、用药、提问与照片完整打包：'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('打开文件所在位置'),
                onPressed: () async {
                  await OpenFilex.open(file.parent.path);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreBackup(SettingsProvider prov, RecordsProvider recordsProv) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (res != null && res.files.single.path != null) {
        final zipFile = File(res.files.single.path!);
        await BackupService.instance.restoreFromBackupZip(zipFile);
        await prov.loadSettings();
        await recordsProv.loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 备份还原成功！所有病历、照片与设置已全部恢复')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('还原失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final info = await UpdateService.instance.checkUpdate();
      setState(() => _isCheckingUpdate = false);

      if (!mounted) return;

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本 🎉')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本: ${info.tagName}'),
          content: SingleChildScrollView(
            child: Text(info.body.isNotEmpty ? info.body : '包含最新功能优化与体验升级。'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后再说'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (info.downloadUrl.isNotEmpty) {
                  setState(() => _isDownloadingApk = true);
                  await UpdateService.instance.downloadAndInstallApk(
                    downloadUrl: info.downloadUrl,
                    onProgress: (p) {
                      if (mounted) setState(() => _downloadProgress = p);
                    },
                  );
                  if (mounted) setState(() => _isDownloadingApk = false);
                }
              },
              child: const Text('立即更新 (覆盖安装)'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isCheckingUpdate = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
