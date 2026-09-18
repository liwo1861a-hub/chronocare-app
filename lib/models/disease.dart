import 'dart:convert';

class Disease {
  String id;
  String name;
  String stage; // 如：平稳期、急性期、随访期、观察期
  String colorHex; // 如：#3B82F6
  String targetNotes; // 个人控制目标说明
  String notes; // 备注
  DateTime createdAt;
  Map<String, String> customFields; // 自定义字段

  Disease({
    required this.id,
    required this.name,
    this.stage = '平稳期',
    this.colorHex = '#2563EB',
    this.targetNotes = '',
    this.notes = '',
    DateTime? createdAt,
    Map<String, String>? customFields,
  })  : createdAt = createdAt ?? DateTime.now(),
        customFields = customFields ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stage': stage,
      'colorHex': colorHex,
      'targetNotes': targetNotes,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'customFields': jsonEncode(customFields),
    };
  }

  factory Disease.fromMap(Map<String, dynamic> map) {
    Map<String, String> custom = {};
    if (map['customFields'] != null) {
      try {
        final decoded = jsonDecode(map['customFields']);
        if (decoded is Map) {
          custom = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }

    return Disease(
      id: map['id'] ?? '',
      name: map['name'] ?? '未命名疾病',
      stage: map['stage'] ?? '平稳期',
      colorHex: map['colorHex'] ?? '#2563EB',
      targetNotes: map['targetNotes'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      customFields: custom,
    );
  }
}
