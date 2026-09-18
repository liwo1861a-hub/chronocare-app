import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import 'storage_service.dart';

class WebDavService {
  static final WebDavService instance = WebDavService._();
  WebDavService._();

  String _getAuthHeader(AppSettings settings) {
    final creds = '${settings.webdavUsername}:${settings.webdavPassword}';
    return 'Basic ${base64Encode(utf8.encode(creds))}';
  }

  String _formatUrl(String baseUrl, String path) {
    var url = baseUrl.trim();
    if (!url.endsWith('/')) url += '/';
    var pStr = path.trim();
    if (pStr.startsWith('/')) pStr = pStr.substring(1);
    return url + pStr;
  }

  /// 测试 WebDAV 连接状态
  Future<bool> testConnection(AppSettings settings) async {
    try {
      final url = Uri.parse(_formatUrl(settings.webdavUrl, ''));
      final req = http.Request('PROPFIND', url);
      req.headers['Authorization'] = _getAuthHeader(settings);
      req.headers['Depth'] = '0';

      final res = await req.send();
      return res.statusCode == 207 || res.statusCode == 200 || res.statusCode == 404;
    } catch (e) {
      return false;
    }
  }

  /// 确保远端文件夹存在
  Future<void> ensureRemoteDirectory(AppSettings settings, String dirPath) async {
    final url = Uri.parse(_formatUrl(settings.webdavUrl, dirPath));
    final req = http.Request('MKCOL', url);
    req.headers['Authorization'] = _getAuthHeader(settings);
    await req.send();
  }

  /// 100% 全量上传：数据 + 全部设置 + 全部分类 + 所有化验单原图
  Future<void> uploadDataToWebDav(AppSettings settings) async {
    if (!settings.webdavEnabled || settings.webdavUrl.isEmpty) return;

    final remoteDir = settings.webdavRemoteDir.isNotEmpty
        ? settings.webdavRemoteDir
        : '/ChronoCare/';
    
    // 确保主目录与 images 目录存在
    await ensureRemoteDirectory(settings, remoteDir);
    await ensureRemoteDirectory(settings, '$remoteDir/images/');

    // 1. 上传全量 JSON 数据 (包含全部设置、分类、疾病、病历指标)
    final allData = await StorageService.instance.exportAllData();
    final jsonBytes = utf8.encode(jsonEncode(allData));
    final fileUrl = Uri.parse(_formatUrl(settings.webdavUrl, '$remoteDir/chronocare_data.json'));

    final response = await http.put(
      fileUrl,
      headers: {
        'Authorization': _getAuthHeader(settings),
        'Content-Type': 'application/json',
      },
      body: jsonBytes,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception('WebDAV 数据上传失败 (${response.statusCode}): ${response.body}');
    }

    // 2. 上传所有检查单照片原图到 WebDAV
    final records = await StorageService.instance.getRecords();
    for (var rec in records) {
      for (var imgPath in rec.imagePaths) {
        final imgFile = File(imgPath);
        if (await imgFile.exists()) {
          final fileName = p.basename(imgPath);
          final imgUploadUrl = Uri.parse(_formatUrl(settings.webdavUrl, '$remoteDir/images/$fileName'));
          final bytes = await imgFile.readAsBytes();

          await http.put(
            imgUploadUrl,
            headers: {
              'Authorization': _getAuthHeader(settings),
              'Content-Type': 'image/jpeg',
            },
            body: bytes,
          );
        }
      }
    }
  }

  /// 100% 全量从 WebDAV 拉取恢复（开箱即用，无需任何手动调整）
  Future<void> downloadDataFromWebDav(AppSettings settings) async {
    if (!settings.webdavEnabled || settings.webdavUrl.isEmpty) return;

    final remoteDir = settings.webdavRemoteDir.isNotEmpty
        ? settings.webdavRemoteDir
        : '/ChronoCare/';
    final fileUrl = Uri.parse(_formatUrl(settings.webdavUrl, '$remoteDir/chronocare_data.json'));

    final response = await http.get(
      fileUrl,
      headers: {
        'Authorization': _getAuthHeader(settings),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('WebDAV 拉取失败 (${response.statusCode}): ${response.body}');
    }

    final jsonStr = utf8.decode(response.bodyBytes);
    final data = jsonDecode(jsonStr);

    // 准备本地图片目录
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'records_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // 拉取所有图片并映射本地路径
    if (data['records'] != null && data['records'] is List) {
      for (var r in data['records']) {
        if (r['imagePaths'] != null) {
          List<String> rawPaths = [];
          try {
            final decoded = jsonDecode(r['imagePaths']);
            if (decoded is List) rawPaths = decoded.map((e) => e.toString()).toList();
          } catch (_) {}

          List<String> localPaths = [];
          for (var pStr in rawPaths) {
            final baseName = p.basename(pStr);
            final localFile = File(p.join(imagesDir.path, baseName));

            // 如果本地不存在，从 WebDAV 下载
            if (!await localFile.exists()) {
              try {
                final imgUrl = Uri.parse(_formatUrl(settings.webdavUrl, '$remoteDir/images/$baseName'));
                final imgRes = await http.get(
                  imgUrl,
                  headers: {'Authorization': _getAuthHeader(settings)},
                );
                if (imgRes.statusCode == 200) {
                  await localFile.writeAsBytes(imgRes.bodyBytes);
                }
              } catch (_) {}
            }

            localPaths.add(localFile.path);
          }
          r['imagePaths'] = jsonEncode(localPaths);
        }
      }
    }

    // 恢复全部数据、全部设置与自定义分类
    await StorageService.instance.importAllData(data);
  }
}
