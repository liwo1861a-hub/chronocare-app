import 'dart:convert';
import 'check_item.dart';
import 'medication.dart';

class CheckRecord {
  String id;
  String diseaseId; // 关联的疾病 ID
  DateTime checkDate; // 检查/复查日期
  DateTime? nextCheckDate; // 下次复查提醒日期
  String hospital; // 医院
  String department; // 科室
  String doctorName; // 就诊医生
  String category; // 检查大类，如：血生化, 尿常规, 超声影像, CT/MRI, 胃肠镜, 肿瘤标志物, 随访记录
  String doctorAdvice; // 医生就诊医嘱/处置建议
  List<String> imagePaths; // 报告单图片路径列表
  List<CheckItem> items; // 结构化检验指标列表
  List<MedicationChange> medicationChanges; // 本次用药调整列表
  String overallNotes; // 本次复查总体备注
  List<String> tags; // 自定义标签
  DateTime createdAt;
  DateTime updatedAt;

  CheckRecord({
    required this.id,
    required this.diseaseId,
    required this.checkDate,
    this.nextCheckDate,
    this.hospital = '',
    this.department = '',
    this.doctorName = '',
    this.category = '血液生化',
    this.doctorAdvice = '',
    List<String>? imagePaths,
    List<CheckItem>? items,
    List<MedicationChange>? medicationChanges,
    this.overallNotes = '',
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : imagePaths = imagePaths ?? [],
        items = items ?? [],
        medicationChanges = medicationChanges ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 统计异常项数量
  int get abnormalCount =>
      items.where((i) => i.status != 'normal').length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseId': diseaseId,
      'checkDate': checkDate.toIso8601String(),
      'nextCheckDate': nextCheckDate?.toIso8601String(),
      'hospital': hospital,
      'department': department,
      'doctorName': doctorName,
      'category': category,
      'doctorAdvice': doctorAdvice,
      'imagePaths': jsonEncode(imagePaths),
      'items': jsonEncode(items.map((i) => i.toMap()).toList()),
      'medicationChanges':
          jsonEncode(medicationChanges.map((m) => m.toMap()).toList()),
      'overallNotes': overallNotes,
      'tags': jsonEncode(tags),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CheckRecord.fromMap(Map<String, dynamic> map) {
    List<String> imgs = [];
    if (map['imagePaths'] != null) {
      try {
        final decoded = jsonDecode(map['imagePaths']);
        if (decoded is List) imgs = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    List<CheckItem> itms = [];
    if (map['items'] != null) {
      try {
        final decoded = jsonDecode(map['items']);
        if (decoded is List) {
          itms = decoded.map((e) => CheckItem.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    }

    List<MedicationChange> meds = [];
    if (map['medicationChanges'] != null) {
      try {
        final decoded = jsonDecode(map['medicationChanges']);
        if (decoded is List) {
          meds = decoded.map((e) => MedicationChange.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    }

    List<String> tgs = [];
    if (map['tags'] != null) {
      try {
        final decoded = jsonDecode(map['tags']);
        if (decoded is List) tgs = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return CheckRecord(
      id: map['id'] ?? '',
      diseaseId: map['diseaseId'] ?? '',
      checkDate: map['checkDate'] != null
          ? DateTime.tryParse(map['checkDate']) ?? DateTime.now()
          : DateTime.now(),
      nextCheckDate: map['nextCheckDate'] != null
          ? DateTime.tryParse(map['nextCheckDate'])
          : null,
      hospital: map['hospital'] ?? '',
      department: map['department'] ?? '',
      doctorName: map['doctorName'] ?? '',
      category: map['category'] ?? '血液生化',
      doctorAdvice: map['doctorAdvice'] ?? '',
      imagePaths: imgs,
      items: itms,
      medicationChanges: meds,
      overallNotes: map['overallNotes'] ?? '',
      tags: tgs,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
