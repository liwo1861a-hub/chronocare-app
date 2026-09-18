import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
    var p = path.trim();
    if (p.startsWith('/')) p = p.substring(1);
    return url + p;
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
  Future<void> ensureRemoteDirectory(AppSettings settings) async {
    final remoteDir = settings.webdavRemoteDir.isNotEmpty
        ? settings.webdavRemoteDir
        : '/ChronoCare/';
    final url = Uri.parse(_formatUrl(settings.webdavUrl, remoteDir));
    
    final req = http.Request('MKCOL', url);
    req.headers['Authorization'] = _getAuthHeader(settings);
    await req.send();
  }

  /// 上传本地数据至 WebDAV
  Future<void> uploadDataToWebDav(AppSettings settings) async {
    if (!settings.webdavEnabled || settings.webdavUrl.isEmpty) return;

    await ensureRemoteDirectory(settings);

    final allData = await StorageService.instance.exportAllData();
    final jsonBytes = utf8.encode(jsonEncode(allData));

    final remoteDir = settings.webdavRemoteDir.isNotEmpty
        ? settings.webdavRemoteDir
        : '/ChronoCare/';
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
      throw Exception('WebDAV 上传失败 (${response.statusCode}): ${response.body}');
    }
  }

  /// 从 WebDAV 拉取并合并数据
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
    await StorageService.instance.importAllData(data);
  }
}
