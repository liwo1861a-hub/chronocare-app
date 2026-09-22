import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ReleaseInfo {
  final String tagName;
  final String title;
  final String body;
  final String downloadUrl;
  final String publishedAt;

  ReleaseInfo({
    required this.tagName,
    required this.title,
    required this.body,
    required this.downloadUrl,
    required this.publishedAt,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const String currentVersion = '1.1.8';
  static const int currentBuildNumber = 19;

  static const String repoOwner = 'liwo1861a-hub';
  static const String repoName = 'chronocare-app';

  /// 检查 GitHub Releases 最新版本
  Future<ReleaseInfo?> checkUpdate() async {
    final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'ChronoCare-App',
    });

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final tagName = data['tag_name']?.toString() ?? '';
    final name = data['name']?.toString() ?? tagName;
    final body = data['body']?.toString() ?? '';
    final publishedAt = data['published_at']?.toString() ?? '';

    String downloadUrl = '';
    final assets = data['assets'] as List?;
    if (assets != null && assets.isNotEmpty) {
      for (var asset in assets) {
        final assetName = asset['name']?.toString().toLowerCase() ?? '';
        if (assetName.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url']?.toString() ?? '';
          break;
        }
      }
    }

    String cleanRemote = tagName.replaceAll('v', '').replaceAll('V', '').trim();
    if (_isNewerVersion(cleanRemote, currentVersion)) {
      return ReleaseInfo(
        tagName: tagName,
        title: name,
        body: body,
        downloadUrl: downloadUrl,
        publishedAt: publishedAt,
      );
    }

    return null;
  }

  bool _isNewerVersion(String remote, String current) {
    try {
      final rParts = remote.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < rParts.length && i < cParts.length; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return rParts.length > cParts.length;
    } catch (_) {
      return remote != current;
    }
  }

  /// 下载 APK 并安装
  Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    final req = http.Request('GET', Uri.parse(downloadUrl));
    final res = await client.send(req);

    final contentLength = res.contentLength ?? 0;
    int received = 0;

    final tempDir = await getTemporaryDirectory();
    final apkFile = File(p.join(tempDir.path, 'update.apk'));
    final sink = apkFile.openWrite();

    await res.stream.listen((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0) {
        onProgress(received / contentLength);
      }
    }).asFuture();

    await sink.flush();
    await sink.close();

    // 打开 APK 安装器 (就地覆盖更新)
    await OpenFilex.open(apkFile.path);
  }
}
