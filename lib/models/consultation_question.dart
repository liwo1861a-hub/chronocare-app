class ConsultationQuestion {
  String id;
  String diseaseId; // 关联的慢病档案
  DateTime targetDate; // 指向的复查就诊日期
  String question; // 准备向医生咨询的问题
  String detail; // 症状或指标背景补充
  bool isAsked; // 是否已提问 (勾选状态)
  String doctorAnswer; // 医生的回复与解答
  String category; // 问题大类：如 用药咨询, 检查复查, 日常饮食, 异常症状
  DateTime createdAt;

  ConsultationQuestion({
    required this.id,
    required this.diseaseId,
    required this.targetDate,
    required this.question,
    this.detail = '',
    this.isAsked = false,
    this.doctorAnswer = '',
    this.category = '就诊咨询',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseId': diseaseId,
      'targetDate': targetDate.toIso8601String(),
      'question': question,
      'detail': detail,
      'isAsked': isAsked ? 1 : 0,
      'doctorAnswer': doctorAnswer,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ConsultationQuestion.fromMap(Map<String, dynamic> map) {
    return ConsultationQuestion(
      id: map['id'] ?? '',
      diseaseId: map['diseaseId'] ?? '',
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      question: map['question'] ?? '',
      detail: map['detail'] ?? '',
      isAsked: map['isAsked'] == 1 || map['isAsked'] == true,
      doctorAnswer: map['doctorAnswer'] ?? '',
      category: map['category'] ?? '就诊咨询',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
