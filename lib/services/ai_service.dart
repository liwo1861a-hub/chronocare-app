import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/check_item.dart';
import '../models/medication.dart';
import 'package:uuid/uuid.dart';

class AiAnalysisResult {
  String hospital;
  String department;
  String doctorName;
  DateTime? checkDate;
  String category;
  String doctorAdvice;
  List<CheckItem> items;
  List<MedicationChange> medicationChanges;
  String rawResponse;

  AiAnalysisResult({
    this.hospital = '',
    this.department = '',
    this.doctorName = '',
    this.checkDate,
    this.category = '血液生化',
    this.doctorAdvice = '',
    List<CheckItem>? items,
    List<MedicationChange>? medicationChanges,
    this.rawResponse = '',
  })  : items = items ?? [],
        medicationChanges = medicationChanges ?? [];
}

class AiService {
  static final AiService instance = AiService._();
  AiService._();

  static const String _systemPrompt = '''
你是一位资深医疗化验单与病历解析专家。请严格分析输入的化验单图片或文本，提取以下结构化医疗信息，并以纯 JSON 格式输出（不要添加任何 markdown 代码块外部的多余文本）：
JSON 字段规范：
{
  "hospital": "医院名称（若未提及留空字符串）",
  "department": "就诊科室（如内分泌科、消化内科）",
  "doctorName": "就诊医生姓名（若无留空）",
  "checkDate": "检查日期，格式必须为 YYYY-MM-DD（若无则填写今天日期）",
  "category": "检查大类（如：血液生化、血常规、尿常规、肝肾功能、超声影像、CT/MRI、胃肠镜、心电图、病理报告、随访记录）",
  "doctorAdvice": "医生就诊医嘱或检查结论/诊断处置建议",
  "items": [
    {
      "itemName": "项目标准名称（如：糖化血红蛋白）",
      "value": "检测结果数值或定性结果（如：6.2 或 阴性）",
      "unit": "计量单位（如：mmol/L, %, μmol/L）",
      "referenceRange": "参考区间（如：4.0-6.0）",
      "status": "normal(正常) | high(偏高/阳性) | low(偏低) | abnormal(异常/需复查)",
      "category": "所属子类别（如：血糖指标、肝功能、脂质代谢）",
      "notes": "异常提示或关键说明（若无留空）"
    }
  ],
  "medicationChanges": [
    {
      "medicineName": "药名",
      "changeType": "new(新开) | increase(加量) | decrease(减量) | stop(停药) | maintain(维持) | switch(换药)",
      "dosage": "单次剂量（如：0.5g）",
      "frequency": "用药频次（如：每日2次）",
      "reason": "变更原因说明（若有）",
      "notes": "用药注意事项"
    }
  ]
}
''';

  /// 利用 Gemini 3.7 Flash 多模态视觉大模型直接分析图片
  Future<AiAnalysisResult> analyzeImageWithGemini({
    required File imageFile,
    required AppSettings settings,
  }) async {
    final apiKey = settings.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('请先在【设置 -> AI 大模型配置】中填入 Google Gemini API Key');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final modelName = settings.geminiModel.isNotEmpty
        ? settings.geminiModel
        : 'gemini-3.7-flash';

    final url = Uri.parse(
        '${settings.geminiBaseUrl}/v1beta/models/$modelName:generateContent?key=$apiKey');

    final payload = {
      "contents": [
        {
          "parts": [
            {
              "text": _systemPrompt +
                  "\n请全面扫描识别并提取此化验单/检查报告中的所有项目、指标、参考范围、异常状态、日期、医院与医嘱："
            },
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": settings.aiTemperature,
        "maxOutputTokens": settings.aiMaxTokens,
        "responseMimeType": "application/json",
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API 调用失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final contentText =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return _parseJsonToResult(contentText);
  }

  /// 利用 AI 分析已提取的 OCR 文本（支持 Gemini, OpenAI, DeepSeek, Claude 等）
  Future<AiAnalysisResult> analyzeTextWithAi({
    required String ocrText,
    required AppSettings settings,
  }) async {
    final provider = settings.aiProvider;

    if (provider == 'gemini') {
      return _analyzeTextGemini(ocrText, settings);
    } else if (provider == 'deepseek') {
      return _analyzeTextOpenAiCompatible(
        text: ocrText,
        baseUrl: settings.deepSeekBaseUrl,
        apiKey: settings.deepSeekApiKey,
        model: settings.deepSeekModel,
        temperature: settings.aiTemperature,
        maxTokens: settings.aiMaxTokens,
      );
    } else if (provider == 'openai') {
      return _analyzeTextOpenAiCompatible(
        text: ocrText,
        baseUrl: settings.openAiBaseUrl,
        apiKey: settings.openAiApiKey,
        model: settings.openAiModel,
        temperature: settings.aiTemperature,
        maxTokens: settings.aiMaxTokens,
      );
    } else {
      // custom openai compatible
      return _analyzeTextOpenAiCompatible(
        text: ocrText,
        baseUrl: settings.customBaseUrl,
        apiKey: settings.customApiKey,
        model: settings.customModel,
        temperature: settings.aiTemperature,
        maxTokens: settings.aiMaxTokens,
      );
    }
  }

  Future<AiAnalysisResult> _analyzeTextGemini(
      String text, AppSettings settings) async {
    final apiKey = settings.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('请先在【设置 -> AI 大模型配置】中填入 Google Gemini API Key');
    }

    final modelName = settings.geminiModel.isNotEmpty
        ? settings.geminiModel
        : 'gemini-3.7-flash';

    final url = Uri.parse(
        '${settings.geminiBaseUrl}/v1beta/models/$modelName:generateContent?key=$apiKey');

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": "$_systemPrompt\n\n以下是待解析的化验单 OCR 原始文本：\n$text"}
          ]
        }
      ],
      "generationConfig": {
        "temperature": settings.aiTemperature,
        "maxOutputTokens": settings.aiMaxTokens,
        "responseMimeType": "application/json",
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini 文本解析失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final contentText =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return _parseJsonToResult(contentText);
  }

  Future<AiAnalysisResult> _analyzeTextOpenAiCompatible({
    required String text,
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxTokens,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('API Key 未配置，请在设置中填写');
    }

    String cleanBaseUrl = baseUrl.trim();
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }
    final url = Uri.parse('$cleanBaseUrl/chat/completions');

    final payload = {
      "model": model,
      "messages": [
        {"role": "system", "content": _systemPrompt},
        {"role": "user", "content": "请解析以下化验单/检查单文本并返回 JSON：\n$text"}
      ],
      "temperature": temperature,
      "max_tokens": maxTokens,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('AI API 调用失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final content = data['choices']?[0]?['message']?['content'] ?? '';
    return _parseJsonToResult(content);
  }

  AiAnalysisResult _parseJsonToResult(String rawJson) {
    String cleanJson = rawJson.trim();
    // 清理 markdown 代码块包裹
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final map = jsonDecode(cleanJson);
    final uuid = const Uuid();

    List<CheckItem> items = [];
    if (map['items'] != null && map['items'] is List) {
      for (var itemMap in map['items']) {
        items.add(CheckItem(
          id: uuid.v4(),
          itemName: itemMap['itemName']?.toString() ?? '',
          value: itemMap['value']?.toString() ?? '',
          unit: itemMap['unit']?.toString() ?? '',
          referenceRange: itemMap['referenceRange']?.toString() ?? '',
          status: itemMap['status']?.toString() ?? 'normal',
          category: itemMap['category']?.toString() ?? '常规检验',
          notes: itemMap['notes']?.toString() ?? '',
        ));
      }
    }

    List<MedicationChange> meds = [];
    if (map['medicationChanges'] != null && map['medicationChanges'] is List) {
      for (var medMap in map['medicationChanges']) {
        meds.add(MedicationChange(
          id: uuid.v4(),
          medicineName: medMap['medicineName']?.toString() ?? '',
          changeType: medMap['changeType']?.toString() ?? 'maintain',
          dosage: medMap['dosage']?.toString() ?? '',
          frequency: medMap['frequency']?.toString() ?? '',
          reason: medMap['reason']?.toString() ?? '',
          notes: medMap['notes']?.toString() ?? '',
        ));
      }
    }

    DateTime? checkDate;
    if (map['checkDate'] != null) {
      checkDate = DateTime.tryParse(map['checkDate'].toString());
    }

    return AiAnalysisResult(
      hospital: map['hospital']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      doctorName: map['doctorName']?.toString() ?? '',
      checkDate: checkDate ?? DateTime.now(),
      category: map['category']?.toString() ?? '血液生化',
      doctorAdvice: map['doctorAdvice']?.toString() ?? '',
      items: items,
      medicationChanges: meds,
      rawResponse: rawJson,
    );
  }
}
