class MedicationChange {
  String id;
  String medicineName; // 药名
  String changeType; // 'new'(新开), 'increase'(加量), 'decrease'(减量), 'stop'(停药), 'maintain'(维持), 'switch'(换药)
  String dosage; // 剂量，如："0.5g / 次"
  String frequency; // 频次，如："每日2次 饭后"
  String reason; // 变更原因，如："空腹血糖达标，维持原量"
  String notes; // 备注

  MedicationChange({
    required this.id,
    required this.medicineName,
    this.changeType = 'maintain',
    this.dosage = '',
    this.frequency = '',
    this.reason = '',
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineName': medicineName,
      'changeType': changeType,
      'dosage': dosage,
      'frequency': frequency,
      'reason': reason,
      'notes': notes,
    };
  }

  factory MedicationChange.fromMap(Map<String, dynamic> map) {
    return MedicationChange(
      id: map['id'] ?? '',
      medicineName: map['medicineName'] ?? '',
      changeType: map['changeType'] ?? 'maintain',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      reason: map['reason'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
