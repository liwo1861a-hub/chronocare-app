class CheckItem {
  String id;
  String itemName; // 指标名称，如：糖化血红蛋白
  String value; // 实际检测值字符串，如："6.3" 或 "阴性"
  double? numericValue; // 提取出的数值，用于折线图和对比
  String unit; // 单位，如：mmol/L, %, μmol/L
  String referenceRange; // 参考范围，如："3.9-6.1" 或 "4.0~6.0"
  double? refMin; // 范围下限
  double? refMax; // 范围上限
  String status; // 'normal', 'high', 'low', 'abnormal'
  String category; // 项目大类/单据栏目名：如 血液生化, 肝功能, 血常规, 尿常规
  String sourceImagePath; // 对应的化验单原图路径
  String notes; // 单项备注

  CheckItem({
    required this.id,
    required this.itemName,
    required this.value,
    this.numericValue,
    this.unit = '',
    this.referenceRange = '',
    this.refMin,
    this.refMax,
    this.status = 'normal',
    this.category = '常规检验',
    this.sourceImagePath = '',
    this.notes = '',
  }) {
    if (numericValue == null) {
      final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(value);
      if (match != null) {
        numericValue = double.tryParse(match.group(0)!);
      }
    }
    _parseRefRange();
  }

  void _parseRefRange() {
    if (referenceRange.isEmpty) return;
    final nums = RegExp(r'[-+]?[0-9]*\.?[0-9]+')
        .allMatches(referenceRange)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    if (nums.length >= 2) {
      refMin = nums[0];
      refMax = nums[1];
    } else if (nums.length == 1) {
      if (referenceRange.contains('<') || referenceRange.contains('≤')) {
        refMax = nums[0];
      } else if (referenceRange.contains('>') || referenceRange.contains('≥')) {
        refMin = nums[0];
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'value': value,
      'numericValue': numericValue,
      'unit': unit,
      'referenceRange': referenceRange,
      'refMin': refMin,
      'refMax': refMax,
      'status': status,
      'category': category,
      'sourceImagePath': sourceImagePath,
      'notes': notes,
    };
  }

  factory CheckItem.fromMap(Map<String, dynamic> map) {
    return CheckItem(
      id: map['id'] ?? '',
      itemName: map['itemName'] ?? '',
      value: map['value'] ?? '',
      numericValue: map['numericValue'] != null
          ? (map['numericValue'] as num).toDouble()
          : null,
      unit: map['unit'] ?? '',
      referenceRange: map['referenceRange'] ?? '',
      refMin: map['refMin'] != null ? (map['refMin'] as num).toDouble() : null,
      refMax: map['refMax'] != null ? (map['refMax'] as num).toDouble() : null,
      status: map['status'] ?? 'normal',
      category: map['category'] ?? '常规检验',
      sourceImagePath: map['sourceImagePath'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
