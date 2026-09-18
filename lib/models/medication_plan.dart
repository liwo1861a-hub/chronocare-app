class MedicationPlan {
  String id;
  String diseaseId; // 关联的慢病档案
  DateTime date; // 指向的调药/复查日期
  String medicineName; // 药品名称 (如：二甲双胍片)
  String dosage; // 剂量 (如：0.5g / 次)
  String frequency; // 服药频次 (如：每日2次，随餐服用)
  String changeType; // 'new'(新开), 'increase'(加量), 'decrease'(减量), 'stop'(停药), 'maintain'(维持), 'switch'(换药)
  String reason; // 调药原因 (如：餐后血糖波动较大，遵医嘱加量)
  String status; // 'active'(正在服用), 'stopped'(已停药)
  String notes; // 注意事项 (如：注意监测低血糖)

  MedicationPlan({
    required this.id,
    required this.diseaseId,
    required this.date,
    required this.medicineName,
    this.dosage = '',
    this.frequency = '',
    this.changeType = 'maintain',
    this.reason = '',
    this.status = 'active',
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseId': diseaseId,
      'date': date.toIso8601String(),
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'changeType': changeType,
      'reason': reason,
      'status': status,
      'notes': notes,
    };
  }

  factory MedicationPlan.fromMap(Map<String, dynamic> map) {
    return MedicationPlan(
      id: map['id'] ?? '',
      diseaseId: map['diseaseId'] ?? '',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      medicineName: map['medicineName'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      changeType: map['changeType'] ?? 'maintain',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'active',
      notes: map['notes'] ?? '',
    );
  }
}
