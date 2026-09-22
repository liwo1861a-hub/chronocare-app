import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/check_item.dart';
import '../models/medication.dart';
import '../models/app_settings.dart';
import '../models/medication_inventory.dart';

class AiAnalysisResult {
  final DateTime? checkDate;
  final String hospital;
  final String department;
  final String doctorName;
  final String category; // 顶级检查单据大类名称
  final String doctorAdvice;
  final List<CheckItem> items;
  final List<MedicationChange> medicationChanges;
  final String rawResponse;

  AiAnalysisResult({
    this.checkDate,
    this.hospital = '',
    this.department = '',
    this.doctorName = '',
    this.category = '常规化验',
    this.doctorAdvice = '',
    this.items = const [],
    this.medicationChanges = const [],
    this.rawResponse = '',
  });
}

class AiService {
  static final AiService instance = AiService._();
  AiService._();

  /// 使用 Google Gemini (默认 gemini-3.7-flash) 或自定义 OpenAI 兼容模型多模态直接识别化验单
  Future<AiAnalysisResult> analyzeImageWithGemini({
    required File imageFile,
    required AppSettings settings,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final model = settings.geminiModel.isNotEmpty ? settings.geminiModel : 'gemini-3.7-flash';
    final apiKey = settings.geminiApiKey.isNotEmpty ? settings.geminiApiKey : settings.customApiKey;

    if (apiKey.isEmpty) {
      throw Exception('请先在高级设置中配置 Gemini 或自定义 AI 的 API Key！');
    }

    final prompt = '''
你是一位资深医疗化验单结构化识别专家。请深度分析这张检查单/化验单图片，并提取结构化 JSON 数据。

【🚨 核心栏目归类硬性规则（绝对禁止拆分过细）】：
1. 一张化验单必须且只能提取为一个统一的顶级单据大类名称（category），例如："血常规"、"血液生化全项"、"肝肾功能"、"尿液分析"、"凝血功能"、"甲状腺功能"、"超声影像报告" 等。
2. 严禁把同一张化验单上的指标拆分成多个不同的小栏目！同一张单据上的所有检测指标（如生化单上的白蛋白、转氨酶、肌酐、尿酸、血糖、血脂）其 category 必须全部统一命名为该整张化验单的顶级大类名称！

【🚨 开单日期提取权重硬性规则】：
1. 第一优先级：提取医生【开单日期 / 申请日期 / 采样抽血日期 / 就诊日期】；
2. 严禁使用延迟出具的【报告打印日期 / 审核日期】作为就诊日期。

请严格返回如下 JSON 格式（不要输出 markdown 代码块外的内容）：
{
  "checkDate": "YYYY-MM-DD",
  "hospital": "医院名称",
  "department": "科室",
  "doctorName": "开单医生",
  "category": "该整张化验单的统一大类名称(如:血液生化全项/血常规/尿常规)",
  "doctorAdvice": "化验单或病历上的医生诊断结论、医嘱或临床意见",
  "items": [
    {
      "itemName": "指标名称(如: 空腹血糖)",
      "value": "检测值(如: 6.2 或 阴性)",
      "unit": "单位(如: mmol/L)",
      "referenceRange": "参考区间(如: 3.9-6.1)",
      "status": "normal(正常) | high(偏高) | low(偏低) | abnormal(阳性/异常)",
      "category": "必须与整张化验单的统一大类名称完全一致",
      "notes": "备注/临床意义"
    }
  ],
  "medicationChanges": []
}
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
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
        "response_mime_type": "application/json",
        "temperature": 0.1,
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini 接口请求失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 未返回有效识别内容');
    }

    final text = candidates[0]['content']['parts'][0]['text']?.toString() ?? '';
    return _parseJsonResponse(text, imageFile.path);
  }

  /// AI 智能总结医嘱与处置建议
  Future<String> summarizeAdviceWithAi({
    required List<CheckItem> items,
    required List<MedicationChange> meds,
    required String diseaseName,
    required String hospital,
    required String userNotes,
    required AppSettings settings,
  }) async {
    final apiKey = settings.geminiApiKey.isNotEmpty ? settings.geminiApiKey : settings.customApiKey;
    if (apiKey.isEmpty) {
      throw Exception('请先在高级设置中配置 AI API Key！');
    }

    final abnormalItems = items.where((i) => i.status != 'normal').toList();
    final itemsSummary = items.map((i) => '${i.itemName}: ${i.value} ${i.unit} (参考: ${i.referenceRange}) [${i.status}]').join('\n');
    final medsSummary = meds.map((m) => '${m.medicineName}: ${m.dosage} ${m.frequency} (原因: ${m.reason})').join('\n');

    final prompt = '''
你是一位资深慢病管理与全科医学专家。请根据以下患者的慢病复查检验指标结果与用药方案，为患者生成一份专业、清晰、易懂的【医生医嘱与健康管理建议总结】：

【患者慢病档案】：$diseaseName
【就诊医院/机构】：$hospital
【就诊与自述备注】：$userNotes
【异常检验指标 (${abnormalItems.length}项)】：
${abnormalItems.map((i) => '- ${i.itemName}: ${i.value} ${i.unit} (参考值: ${i.referenceRange}) - 状态: ${i.status}').join('\n')}

【全部检验指标详情】：
$itemsSummary

【当前用药方案调整】：
$medsSummary

请从以下几个方面给出条理分明的总结建议（直接给出纯文本或清晰标点的建议，语气专业温和）：
1. 核心指标解读（重点分析异常项与疾病控制情况）
2. 关键用药与服药注意事项（结合指标异常评估）
3. 饮食、生活方式与日常监测要点
4. 下次复查重点关注项目与建议周期
''';

    final model = settings.geminiModel.isNotEmpty ? settings.geminiModel : 'gemini-3.7-flash';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final requestBody = {
      "contents": [
        {
          "parts": [{"text": prompt}]
        }
      ],
      "generationConfig": {
        "temperature": 0.3,
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 总结医嘱失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('未生成有效医嘱建议');
    }

    return candidates[0]['content']['parts'][0]['text']?.toString().trim() ?? '';
  }

  AiAnalysisResult _parseJsonResponse(String jsonString, String imagePath) {
    try {
      String cleanJson = jsonString.trim();
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

      DateTime? checkDate;
      if (map['checkDate'] != null && map['checkDate'].toString().isNotEmpty) {
        checkDate = DateTime.tryParse(map['checkDate'].toString());
      }

      final singleMainCategory = map['category']?.toString().trim() ?? '常规化验';

      List<CheckItem> items = [];
      if (map['items'] != null && map['items'] is List) {
        for (var i in map['items']) {
          items.add(CheckItem(
            id: DateTime.now().microsecondsSinceEpoch.toString() + '_' + items.length.toString(),
            itemName: i['itemName']?.toString() ?? '',
            value: i['value']?.toString() ?? '',
            unit: i['unit']?.toString() ?? '',
            referenceRange: i['referenceRange']?.toString() ?? '',
            status: i['status']?.toString() ?? 'normal',
            // 确保单张化验单上的所有指标统归属于该单据的大类名称，拒绝碎片化细分
            category: singleMainCategory,
            sourceImagePath: imagePath,
            notes: i['notes']?.toString() ?? '',
          ));
        }
      }

      List<MedicationChange> meds = [];
      if (map['medicationChanges'] != null && map['medicationChanges'] is List) {
        for (var m in map['medicationChanges']) {
          meds.add(MedicationChange(
            id: DateTime.now().microsecondsSinceEpoch.toString() + '_' + meds.length.toString(),
            medicineName: m['medicineName']?.toString() ?? '',
            dosage: m['dosage']?.toString() ?? '',
            frequency: m['frequency']?.toString() ?? '',
            reason: m['reason']?.toString() ?? '',
          ));
        }
      }

      return AiAnalysisResult(
        checkDate: checkDate,
        hospital: map['hospital']?.toString() ?? '',
        department: map['department']?.toString() ?? '',
        doctorName: map['doctorName']?.toString() ?? '',
        category: singleMainCategory,
        doctorAdvice: map['doctorAdvice']?.toString() ?? '',
        items: items,
        medicationChanges: meds,
        rawResponse: jsonString,
      );
    } catch (e) {
      throw Exception('解析化验单 JSON 失败: $e\n原始返回: $jsonString');
    }
  }

  /// 通过 AI 解析用户自由输入的文本（或离线降级正则解析），提取结构化药物存量与每日消耗
  Future<List<MedicationInventory>> parseMedicationInventoryText({
    required String text,
    required AppSettings settings,
  }) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return [];

    final apiKey = settings.geminiApiKey.isNotEmpty ? settings.geminiApiKey : settings.customApiKey;

    // 如果未配置 AI API Key，采用本地高精度医疗文本正则解析器兜底
    if (apiKey.isEmpty) {
      return _parseInventoryLocally(cleanInput);
    }

    final prompt = '''
你是一位资深医疗药剂师与数据结构化专家。用户提供了一段关于家中慢病药物存量、开药记录或盘点的口语化描述。
请将其中涉及的所有药品名称、当前剩余库存数量、单位、每日预计消耗量、规格包装和备注准确提取并折算为结构化 JSON 数组。

【🚨 折算与提取硬性规则】：
1. 数量折算：如果用户描述包含盒数与每盒规格（如“开了3盒二甲双胍，每盒60片，还有上次剩下的12片”），必须计算总可用片数（3*60 + 12 = 192片）。
2. 每日消耗：根据用户描述（如“每天吃2片”、“每日3次每次1片”等），计算每日总片数。如果未提及，默认 1.0。
3. 预警天数阈值：默认 7 天。
4. 单位：根据描述提取，通常为“片”、“粒”、“支”、“袋”、“盒”等，默认为“片”。

请严格返回纯 JSON 数组（不要包含任何 markdown 说明之外的文字）：
[
  {
    "medicineName": "药品通用名(如: 二甲双胍片)",
    "currentStock": 192.0,
    "unit": "片",
    "dailyConsumption": 2.0,
    "alertThresholdDays": 7,
    "packageSpec": "规格(如: 60片/盒)",
    "notes": "备注说明"
  }
]
用户输入的文本如下：
$cleanInput
''';

    try {
      final model = settings.geminiModel.isNotEmpty ? settings.geminiModel : 'gemini-3.7-flash';
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final requestBody = {
        "contents": [
          {
            "parts": [{"text": prompt}]
          }
        ],
        "generationConfig": {
          "response_mime_type": "application/json",
          "temperature": 0.1,
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final resText = candidates[0]['content']['parts'][0]['text']?.toString() ?? '';
          final items = _parseInventoryJson(resText);
          if (items.isNotEmpty) return items;
        }
      }
    } catch (_) {
      // 出现异常时无缝降级兜底
    }

    return _parseInventoryLocally(cleanInput);
  }

  List<MedicationInventory> _parseInventoryJson(String jsonString) {
    try {
      String clean = jsonString.trim();
      if (clean.startsWith('```json')) clean = clean.substring(7);
      if (clean.startsWith('```')) clean = clean.substring(3);
      if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
      clean = clean.trim();

      final decoded = jsonDecode(clean);
      if (decoded is List) {
        final List<MedicationInventory> list = [];
        for (var item in decoded) {
          if (item is Map) {
            final name = item['medicineName']?.toString().trim() ?? '';
            if (name.isNotEmpty) {
              list.add(MedicationInventory(
                id: DateTime.now().microsecondsSinceEpoch.toString() + '_' + list.length.toString(),
                medicineName: name,
                currentStock: (item['currentStock'] as num?)?.toDouble() ?? 10.0,
                unit: item['unit']?.toString().trim() ?? '片',
                dailyConsumption: (item['dailyConsumption'] as num?)?.toDouble() ?? 1.0,
                alertThresholdDays: (item['alertThresholdDays'] as num?)?.toInt() ?? 7,
                packageSpec: item['packageSpec']?.toString().trim() ?? '',
                notes: item['notes']?.toString().trim() ?? '',
                updatedAt: DateTime.now(),
              ));
            }
          }
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// 本地智能正则降级解析器 (无需网络与 API Key)
  List<MedicationInventory> _parseInventoryLocally(String text) {
    final List<MedicationInventory> list = [];
    final clauses = text.split(RegExp(r'[\n;；,，。、]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    for (var clause in clauses) {
      // 尝试匹配药品名、数量与频次
      // 例如: "开了3盒二甲双胍每盒60片每天2片" 或 "苯溴马隆20片每天1片"
      final stockMatch = RegExp(r'(\d+)\s*(盒|瓶|支|袋|包|粒|片)').firstMatch(clause);
      final dailyMatch = RegExp(r'(?:每天|每日|每顿|每次|日服)\s*(\d+(?:\.\d+)?)\s*(?:次|片|粒)?').firstMatch(clause);

      // 提取中文药品名称候选 (剔除开、买、还剩、盒、片等干扰词)
      String cleanName = clause
          .replaceAll(RegExp(r'(今天|昨天|去医院|买了|开了|还剩|还有|家里|目前|每天|每日|每盒|一共|共|每次|饭后|随餐)'), '')
          .replaceAll(RegExp(r'\d+(?:\.\d+)?\s*(盒|瓶|支|袋|包|粒|片|次|天)'), '')
          .replaceAll(RegExp(r'[0-9\.\+\-\*\/]'), '')
          .trim();

      if (cleanName.length >= 2 && cleanName.length <= 15) {
        double stock = 30.0;
        String unit = '片';
        if (stockMatch != null) {
          final count = double.tryParse(stockMatch.group(1)!) ?? 1.0;
          final unitStr = stockMatch.group(2) ?? '片';
          if (unitStr == '盒' || unitStr == '瓶') {
            // 如果是盒，检查是否有每盒规格如每盒60片
            final specMatch = RegExp(r'(?:每盒|每瓶)\s*(\d+)\s*(?:片|粒)').firstMatch(clause);
            final specCount = specMatch != null ? (double.tryParse(specMatch.group(1)!) ?? 30.0) : 30.0;
            stock = count * specCount;
            unit = '片';
          } else {
            stock = count;
            unit = unitStr;
          }
        }

        double daily = 1.0;
        if (dailyMatch != null) {
          daily = double.tryParse(dailyMatch.group(1)!) ?? 1.0;
        }

        list.add(MedicationInventory(
          id: DateTime.now().microsecondsSinceEpoch.toString() + '_' + list.length.toString(),
          medicineName: cleanName,
          currentStock: stock,
          unit: unit,
          dailyConsumption: daily > 0 ? daily : 1.0,
          alertThresholdDays: 7,
          packageSpec: clause.contains('盒') ? '盒装' : '',
          notes: '由文字智能识别录入',
          updatedAt: DateTime.now(),
        ));
      }
    }

    return list;
  }
}
