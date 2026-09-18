import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  /// 导出完整备份 ZIP 文件（包含 data.json 和全部化验单图片）
  Future<File> createFullBackupZip() async {
    final archive = Archive();

    // 1. 导出 JSON 数据
    final allData = await StorageService.instance.exportAllData();
    final jsonString = jsonEncode(allData);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // 2. 收集所有图片文件
    final records = await StorageService.instance.getRecords();
    for (var rec in records) {
      for (var imgPath in rec.imagePaths) {
        final f = File(imgPath);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final fileName = p.basename(imgPath);
          archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
        }
      }
    }

    // 3. 压缩打包
    final zipEncoder = ZipEncoder();
    final encodedBytes = zipEncoder.encode(archive);
    if (encodedBytes == null) {
      throw Exception('创建备份压缩包失败');
    }

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final backupFile = File(p.join(tempDir.path, 'ChronoCare_Backup_$dateStr.zip'));
    await backupFile.writeAsBytes(encodedBytes);

    return backupFile;
  }

  /// 从 ZIP 备份文件中恢复数据
  Future<void> restoreFromBackupZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'records_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    for (final file in archive) {
      if (file.isFile) {
        if (file.name == 'data.json') {
          final dataString = utf8.decode(file.content as List<int>);
          final map = jsonDecode(dataString);
          await StorageService.instance.importAllData(map);
        } else if (file.name.startsWith('images/')) {
          final fileName = p.basename(file.name);
          final outFile = File(p.join(imagesDir.path, fileName));
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
    }
  }
}
