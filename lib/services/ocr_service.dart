import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import 'ai_service.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  /// 执行 OCR 识别，返回提取的原始文本行
  Future<String> recognizeText({
    required File imageFile,
    required AppSettings settings,
  }) async {
    final engine = settings.ocrEngine;

    if (engine == 'ocr_space') {
      return _recognizeWithOcrSpace(imageFile, settings);
    } else if (engine == 'gemini_vision') {
      // 若选用 Gemini 视觉直出，直接调用 Gemini
      final aiRes = await AiService.instance.analyzeImageWithGemini(
        imageFile: imageFile,
        settings: settings,
      );
      return aiRes.rawResponse;
    } else {
      // 默认 fallback 或 ocr_space
      return _recognizeWithOcrSpace(imageFile, settings);
    }
  }

  /// 使用 OCR.space 免费 API (支持中文与英文)
  Future<String> _recognizeWithOcrSpace(
      File imageFile, AppSettings settings) async {
    final apiKey = settings.ocrSpaceApiKey.isNotEmpty
        ? settings.ocrSpaceApiKey
        : 'K88888888888957'; // 免费默认 Key

    final uri = Uri.parse('https://api.ocr.space/parse/image');
    final request = http.MultipartRequest('POST', uri);

    request.fields['apikey'] = apiKey;
    request.fields['language'] = 'chs'; // 简体中文
    request.fields['isOverlayRequired'] = 'false';
    request.fields['detectOrientation'] = settings.ocrAutoRotate ? 'true' : 'false';
    request.fields['scale'] = settings.ocrPreprocess ? 'true' : 'false';
    request.fields['isTable'] = 'true'; // 表格优化

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('OCR.space 识别失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['IsErroredOnProcessing'] == true) {
      final errMsg = data['ErrorMessage'] ?? 'OCR 处理发生错误';
      throw Exception('OCR 错误: $errMsg');
    }

    final parsedResults = data['ParsedResults'] as List?;
    if (parsedResults == null || parsedResults.isEmpty) {
      return '';
    }

    final fullText = parsedResults[0]['ParsedText']?.toString() ?? '';
    return fullText;
  }
}
