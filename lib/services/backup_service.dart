import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import '../models/record.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  /// 获取默认或自定义的备份保存目录
  Future<Directory> getEffectiveBackupDirectory() async {
    final settings = await StorageService.instance.getSettings();
    if (settings.customLocalBackupPath.trim().isNotEmpty) {
      final customDir = Directory(settings.customLocalBackupPath.trim());
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (e) {
        // 如果自定义目录无权限或无法创建，回退至系统目录
      }
    }

    // 默认尝试使用公共 Downloads 目录，若不可用则使用 App Documents
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final chronoDir = Directory(p.join(downloadsDir.path, 'ChronoCare'));
        if (!await chronoDir.exists()) {
          await chronoDir.create(recursive: true);
        }
        return chronoDir;
      }
    } catch (_) {}

    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDocDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 导出 100% 完整备份 ZIP 文件（包含 data.json、全部化验单原图、全部用药记录、提问备忘、设置与偏好）
  Future<File> createFullBackupZip({String? customTargetDirPath}) async {
    final archive = Archive();

    // 1. 导出全量结构化数据（含全部数据表 + 设置 Settings）
    final allData = await StorageService.instance.exportAllData();
    final jsonString = jsonEncode(allData);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // 2. 收集所有化验单图片文件并无损打包
    final records = await StorageService.instance.getRecords();
    final Set<String> processedImages = {};

    for (var rec in records) {
      for (var imgPath in rec.imagePaths) {
        if (imgPath.isEmpty || processedImages.contains(imgPath)) continue;
        final f = File(imgPath);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final fileName = p.basename(imgPath);
          archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
          processedImages.add(imgPath);
        }
      }
    }

    // 3. 压缩打包为 .zip
    final zipEncoder = ZipEncoder();
    final encodedBytes = zipEncoder.encode(archive);
    if (encodedBytes == null) {
      throw Exception('创建备份压缩包失败');
    }

    Directory targetDir;
    if (customTargetDirPath != null && customTargetDirPath.trim().isNotEmpty) {
      targetDir = Directory(customTargetDirPath.trim());
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
    } else {
      targetDir = await getEffectiveBackupDirectory();
    }

    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final backupFile = File(p.join(targetDir.path, 'ChronoCare_FullBackup_$dateStr.zip'));
    await backupFile.writeAsBytes(encodedBytes);

    return backupFile;
  }

  /// 从 ZIP 备份文件中 100% 完整还原（数据 + 设置 + 分类 + 药物 + 提问 + 原图路径自动重映射）
  Future<void> restoreFromBackupZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'records_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    Map<String, String> oldToNewPathMap = {};

    // 1. 首先解压所有图片到当前设备的本地持久化目录
    for (final file in archive) {
      if (file.isFile && file.name.startsWith('images/')) {
        final fileName = p.basename(file.name);
        if (fileName.isNotEmpty) {
          final outFile = File(p.join(imagesDir.path, fileName));
          await outFile.writeAsBytes(file.content as List<int>);
          oldToNewPathMap[fileName] = outFile.path;
        }
      }
    }

    // 2. 解压并恢复数据与设置
    for (final file in archive) {
      if (file.isFile && file.name == 'data.json') {
        final dataString = utf8.decode(file.content as List<int>);
        final map = jsonDecode(dataString);

        // 重新矫正 records 中的图片绝对路径，确保跨设备或重装后图片 100% 正常显示
        if (map['records'] != null && map['records'] is List) {
          for (var r in map['records']) {
            if (r['imagePaths'] != null) {
              List<String> rawPaths = [];
              try {
                final decoded = jsonDecode(r['imagePaths']);
                if (decoded is List) rawPaths = decoded.map((e) => e.toString()).toList();
              } catch (_) {}

              List<String> updatedPaths = [];
              for (var rawP in rawPaths) {
                final baseName = p.basename(rawP);
                if (oldToNewPathMap.containsKey(baseName)) {
                  updatedPaths.add(oldToNewPathMap[baseName]!);
                } else {
                  updatedPaths.add(rawP);
                }
              }
              r['imagePaths'] = jsonEncode(updatedPaths);
            }
          }
        }

        await StorageService.instance.importAllData(map);
      }
    }
  }
}
