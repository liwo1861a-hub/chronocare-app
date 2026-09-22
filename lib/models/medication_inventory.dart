class MedicationInventory {
  final String id;
  String medicineName;          // 药品通用名 (如 二甲双胍片)
  double currentStock;          // 当前剩余数量 (如 30.0)
  String unit;                  // 数量单位 (如 片, 粒, 支, 袋, 盒)
  double dailyConsumption;      // 每日预计消耗量 (如 2.0 片/天)
  int alertThresholdDays;       // 药品不足预警天数阈值 (默认 7 天)
  String packageSpec;           // 规格包装 (如 30片/盒, 0.5g*60片)
  String notes;                 // 备注 / 用药说明 (如 饭后服用, 剩半盒)
  DateTime updatedAt;           // 最后更新/盘点日期

  MedicationInventory({
    required this.id,
    required this.medicineName,
    required this.currentStock,
    this.unit = '片',
    this.dailyConsumption = 1.0,
    this.alertThresholdDays = 7,
    this.packageSpec = '',
    this.notes = '',
    required this.updatedAt,
  });

  /// 计算预计剩余可用天数
  double get estimatedDaysRemaining {
    if (dailyConsumption <= 0) return 999.0;
    return currentStock / dailyConsumption;
  }

  /// 预警级别:
  /// - empty (耗尽 / 0天): currentStock <= 0
  /// - critical (严重不足 / <= 3天): estimatedDaysRemaining <= 3
  /// - warning (即将不足 / <= alertThresholdDays): estimatedDaysRemaining <= alertThresholdDays
  /// - sufficient (充足): > alertThresholdDays
  String get alertLevel {
    if (currentStock <= 0) return 'empty';
    final days = estimatedDaysRemaining;
    if (days <= 3) return 'critical';
    if (days <= alertThresholdDays) return 'warning';
    return 'sufficient';
  }

  bool get isShortage => alertLevel == 'empty' || alertLevel == 'critical' || alertLevel == 'warning';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineName': medicineName,
      'currentStock': currentStock,
      'unit': unit,
      'dailyConsumption': dailyConsumption,
      'alertThresholdDays': alertThresholdDays,
      'packageSpec': packageSpec,
      'notes': notes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicationInventory.fromMap(Map<String, dynamic> map) {
    return MedicationInventory(
      id: map['id']?.toString() ?? '',
      medicineName: map['medicineName']?.toString() ?? '',
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit']?.toString() ?? '片',
      dailyConsumption: (map['dailyConsumption'] as num?)?.toDouble() ?? 1.0,
      alertThresholdDays: (map['alertThresholdDays'] as num?)?.toInt() ?? 7,
      packageSpec: map['packageSpec']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      updatedAt: map['updatedAt'] != null
          ? (DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
