import 'dart:convert';

class CategoryGroup {
  String id;
  String name; // 自定义分类名称，如 "肝功能全套"、"糖代谢监测"
  String iconName; // 图标标识
  String colorHex; // 颜色
  List<String> matchedItemNames; // 包含的 OCR 检验指标名称列表
  String notes; // 分类备注

  CategoryGroup({
    required this.id,
    required this.name,
    this.iconName = 'science',
    this.colorHex = '#2563EB',
    List<String>? matchedItemNames,
    this.notes = '',
  }) : matchedItemNames = matchedItemNames ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
      'matchedItemNames': jsonEncode(matchedItemNames),
      'notes': notes,
    };
  }

  factory CategoryGroup.fromMap(Map<String, dynamic> map) {
    List<String> items = [];
    if (map['matchedItemNames'] != null) {
      try {
        final decoded = jsonDecode(map['matchedItemNames']);
        if (decoded is List) items = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return CategoryGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '未命名分类',
      iconName: map['iconName'] ?? 'science',
      colorHex: map['colorHex'] ?? '#2563EB',
      matchedItemNames: items,
      notes: map['notes'] ?? '',
    );
  }
}
