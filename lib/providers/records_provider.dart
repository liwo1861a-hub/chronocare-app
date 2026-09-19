import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../models/category_group.dart';
import '../models/medication_plan.dart';
import '../models/consultation_question.dart';
import '../services/storage_service.dart';

class MetricHistoryPoint {
  final DateTime date;
  final String hospital;
  final double value;
  final String valueStr;
  final String unit;
  final String status;
  final String notes;
  final String recordId;
  final String parentCategory;
  final String diseaseName;
  final bool isQualitative;
  final String qualitativeChange;

  MetricHistoryPoint({
    required this.date,
    required this.hospital,
    required this.value,
    required this.valueStr,
    required this.unit,
    required this.status,
    required this.notes,
    required this.recordId,
    required this.parentCategory,
    this.diseaseName = '',
    this.isQualitative = false,
    this.qualitativeChange = '',
  });
}

class MedicationComparisonGroup {
  final DateTime date;
  final List<MedicationPlanWithDiff> items;
  MedicationComparisonGroup({required this.date, required this.items});
}

class MedicationPlanWithDiff {
  final MedicationPlan plan;
  final String diffTag;
  final MedicationPlan? previousPlan;
  MedicationPlanWithDiff({required this.plan, required this.diffTag, this.previousPlan});
}

/// 同一种药物的聚合档案与完整剂量演变走势
class MedicationDrugTimeline {
  final String medicineName;
  final String diseaseId;
  final String diseaseName;
  final String currentStatus; // active, stopped
  final String latestDosage;
  final String latestFrequency;
  final DateTime latestDate;
  final DateTime firstDate;
  final List<MedicationAdjustmentPoint> historyPoints;

  MedicationDrugTimeline({
    required this.medicineName,
    required this.diseaseId,
    required this.diseaseName,
    required this.currentStatus,
    required this.latestDosage,
    required this.latestFrequency,
    required this.latestDate,
    required this.firstDate,
    required this.historyPoints,
  });
}

/// 单次剂量调整点 (用于绘制走势图与时间线对比)
class MedicationAdjustmentPoint {
  final String id;
  final DateTime date;
  final String dosageStr;
  final double numericDosage; // 解析出的剂量数字 (如 0.5)
  final String unit; // 解析出的剂量单位 (如 g, mg, 片, μg)
  final String frequency;
  final String changeType; // new, increase, decrease, stop, maintain, switch
  final String reason;
  final String notes;
  final String diffFromPrevious; // 如 "+0.25g (加量 🔺)", "-1片 (减量 🔻)", "首次开具 🟢"

  MedicationAdjustmentPoint({
    required this.id,
    required this.date,
    required this.dosageStr,
    required this.numericDosage,
    required this.unit,
    required this.frequency,
    required this.changeType,
    required this.reason,
    required this.notes,
    required this.diffFromPrevious,
  });
}

class QuestionsByDateGroup {
  final DateTime date;
  final List<ConsultationQuestion> questions;
  final List<ConsultationQuestion> previousDateQuestions;
  QuestionsByDateGroup({
    required this.date,
    required this.questions,
    this.previousDateQuestions = const [],
  });
}

class RecordsProvider with ChangeNotifier {
  List<Disease> _diseases = [];
  List<CheckRecord> _records = [];
  List<CategoryGroup> _categoryGroups = [];
  List<MedicationPlan> _medicationPlans = [];
  List<ConsultationQuestion> _consultationQuestions = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedDiseaseId = '';
  String _selectedCategory = '';

  List<Disease> get diseases => _diseases;
  List<CheckRecord> get records => _records;
  List<CategoryGroup> get categoryGroups => _categoryGroups;
  List<MedicationPlan> get medicationPlans => _medicationPlans;
  List<ConsultationQuestion> get consultationQuestions => _consultationQuestions;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedDiseaseId => _selectedDiseaseId;
  String get selectedCategory => _selectedCategory;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _diseases = await StorageService.instance.getDiseases();
    _records = await StorageService.instance.getRecords();
    _categoryGroups = await StorageService.instance.getCategoryGroups();
    _medicationPlans = await StorageService.instance.getMedicationPlans();
    _consultationQuestions = await StorageService.instance.getConsultationQuestions();

    if (_diseases.isEmpty) {
      final defaultDisease = Disease(
        id: 'dis_default_01',
        name: '慢病综合管理档案',
        stage: '随访监测期',
        colorHex: '#2563EB',
        targetNotes: '保持各项指标平稳，定期复查',
      );
      await StorageService.instance.saveDisease(defaultDisease);
      _diseases.add(defaultDisease);
    }

    _isLoading = false;
    notifyListeners();
  }

  List<CheckRecord> getFilteredRecords({String sortOrder = 'date_desc'}) {
    var list = List<CheckRecord>.from(_records);

    if (_selectedDiseaseId.isNotEmpty) {
      list = list.where((r) => r.diseaseId == _selectedDiseaseId).toList();
    }

    if (_selectedCategory.isNotEmpty) {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final matchHospital = r.hospital.toLowerCase().contains(q);
        final matchAdvice = r.doctorAdvice.toLowerCase().contains(q);
        final matchNotes = r.overallNotes.toLowerCase().contains(q);
        final matchItems = r.items.any((i) =>
            i.itemName.toLowerCase().contains(q) ||
            i.value.toLowerCase().contains(q) ||
            i.notes.toLowerCase().contains(q));
        final matchMeds = r.medicationChanges.any((m) =>
            m.medicineName.toLowerCase().contains(q) ||
            m.reason.toLowerCase().contains(q));
        return matchHospital || matchAdvice || matchNotes || matchItems || matchMeds;
      }).toList();
    }

    if (sortOrder == 'date_desc') {
      list.sort((a, b) => b.checkDate.compareTo(a.checkDate));
    } else {
      list.sort((a, b) => a.checkDate.compareTo(b.checkDate));
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedDiseaseId(String id) {
    _selectedDiseaseId = id;
    notifyListeners();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  Disease? getDiseaseById(String id) {
    try {
      return _diseases.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDisease(Disease disease) async {
    await StorageService.instance.saveDisease(disease);
    final idx = _diseases.indexWhere((d) => d.id == disease.id);
    if (idx >= 0) {
      _diseases[idx] = disease;
    } else {
      _diseases.add(disease);
    }
    notifyListeners();
  }

  Future<void> addOrUpdateDisease(Disease disease) async {
    await saveDisease(disease);
  }

  Future<void> deleteDisease(String id) async {
    await StorageService.instance.deleteDisease(id);
    _diseases.removeWhere((d) => d.id == id);
    _medicationPlans.removeWhere((m) => m.diseaseId == id);
    _consultationQuestions.removeWhere((q) => q.diseaseId == id);
    notifyListeners();
  }

  Future<void> saveRecord(CheckRecord record) async {
    await StorageService.instance.saveRecord(record);
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
    }
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    await StorageService.instance.deleteRecord(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> mergeOrSaveRecordByDate(CheckRecord newRecord) async {
    final newDateStr = DateFormat('yyyy-MM-dd').format(newRecord.checkDate);

    CheckRecord? existing;
    for (var r in _records) {
      final curDateStr = DateFormat('yyyy-MM-dd').format(r.checkDate);
      if (curDateStr == newDateStr) {
        if (newRecord.diseaseId.isEmpty || r.diseaseId == newRecord.diseaseId) {
          existing = r;
          break;
        }
      }
    }

    if (existing == null) {
      await saveRecord(newRecord);
      return;
    }

    final Set<String> allImages = Set.from(existing.imagePaths);
    for (var img in newRecord.imagePaths) {
      if (img.isNotEmpty) allImages.add(img);
    }
    existing.imagePaths = allImages.toList();

    final Map<String, CheckItem> itemMap = {};
    for (var it in existing.items) {
      itemMap[it.itemName.trim()] = it;
    }
    for (var it in newRecord.items) {
      final key = it.itemName.trim();
      if (itemMap.containsKey(key)) {
        final ex = itemMap[key]!;
        if (ex.value != it.value) {
          itemMap[key] = it;
        }
      } else {
        itemMap[key] = it;
      }
    }
    existing.items = itemMap.values.toList();

    if (newRecord.doctorAdvice.isNotEmpty) {
      if (existing.doctorAdvice.isEmpty) {
        existing.doctorAdvice = newRecord.doctorAdvice;
      } else if (!existing.doctorAdvice.contains(newRecord.doctorAdvice)) {
        existing.doctorAdvice = '${existing.doctorAdvice}\n${newRecord.doctorAdvice}';
      }
    }

    if (existing.hospital.isEmpty && newRecord.hospital.isNotEmpty) {
      existing.hospital = newRecord.hospital;
    }
    if (existing.department.isEmpty && newRecord.department.isNotEmpty) {
      existing.department = newRecord.department;
    }
    if (existing.doctorName.isEmpty && newRecord.doctorName.isNotEmpty) {
      existing.doctorName = newRecord.doctorName;
    }

    await saveRecord(existing);
  }

  Future<void> mergeCategoriesInRecord(String recordId, String fromCategory, String toCategory) async {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx < 0) return;

    final record = _records[idx];
    for (var it in record.items) {
      if (it.category.trim() == fromCategory.trim()) {
        it.category = toCategory.trim();
      }
    }

    await saveRecord(record);
  }

  Future<void> saveCategoryGroup(CategoryGroup group) async {
    await StorageService.instance.saveCategoryGroup(group);
    final idx = _categoryGroups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _categoryGroups[idx] = group;
    } else {
      _categoryGroups.add(group);
    }
    notifyListeners();
  }

  Future<void> deleteCategoryGroup(String id) async {
    await StorageService.instance.deleteCategoryGroup(id);
    _categoryGroups.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<void> moveItemToGroup(String itemName, String targetGroupId) async {
    for (var g in _categoryGroups) {
      if (g.matchedItemNames.contains(itemName)) {
        g.matchedItemNames.remove(itemName);
        await StorageService.instance.saveCategoryGroup(g);
      }
    }

    if (targetGroupId.isNotEmpty) {
      final target = _categoryGroups.firstWhere((g) => g.id == targetGroupId);
      if (!target.matchedItemNames.contains(itemName)) {
        target.matchedItemNames.add(itemName);
        await StorageService.instance.saveCategoryGroup(target);
      }
    }
    notifyListeners();
  }

  List<String> getAllItemNames() {
    final Set<String> names = {};
    for (var r in _records) {
      for (var it in r.items) {
        if (it.itemName.trim().isNotEmpty) {
          names.add(it.itemName.trim());
        }
      }
    }
    return names.toList()..sort();
  }

  List<String> searchItemNames(String query) {
    if (query.trim().isEmpty) return getAllItemNames();
    final q = query.trim().toLowerCase();
    return getAllItemNames().where((name) => name.toLowerCase().contains(q)).toList();
  }

  List<MetricHistoryPoint> getMetricHistory(String itemName) {
    final List<MetricHistoryPoint> rawPoints = [];
    final target = itemName.trim().toLowerCase();

    for (var r in _records) {
      final dis = getDiseaseById(r.diseaseId);
      for (var it in r.items) {
        if (it.itemName.trim().toLowerCase() == target) {
          double? val = it.numericValue;
          bool isQualitative = false;

          if (val == null) {
            final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(it.value);
            if (match != null) {
              val = double.tryParse(match.group(0)!);
            }
          }

          if (val == null) {
            isQualitative = true;
            final vStr = it.value.trim().toLowerCase();
            if (vStr.contains('阴') || vStr.contains('(-)') || vStr == '-' || vStr.contains('未见') || vStr.contains('正常')) {
              val = 0.0;
            } else if (vStr.contains('±') || vStr.contains('弱阳') || vStr.contains('可疑')) {
              val = 0.5;
            } else if (vStr.contains('4+') || vStr.contains('++++')) {
              val = 4.0;
            } else if (vStr.contains('3+') || vStr.contains('+++')) {
              val = 3.0;
            } else if (vStr.contains('2+') || vStr.contains('++')) {
              val = 2.0;
            } else if (vStr.contains('1+') || vStr.contains('+') || vStr.contains('阳') || vStr.contains('异常')) {
              val = 1.0;
            } else {
              val = 0.0;
            }
          }

          rawPoints.add(MetricHistoryPoint(
            date: r.checkDate,
            hospital: r.hospital.isNotEmpty ? r.hospital : '未注明医院',
            value: val,
            valueStr: it.value.isNotEmpty ? it.value : '未注明',
            unit: it.unit,
            status: it.status,
            notes: it.notes,
            recordId: r.id,
            parentCategory: it.category.isNotEmpty ? it.category : (r.category.isNotEmpty ? r.category : '常规化验单'),
            diseaseName: dis?.name ?? '',
            isQualitative: isQualitative,
          ));
        }
      }
    }

    rawPoints.sort((a, b) => a.date.compareTo(b.date));

    final List<MetricHistoryPoint> finalPoints = [];
    for (int i = 0; i < rawPoints.length; i++) {
      final cur = rawPoints[i];
      String change = '';
      if (i > 0) {
        final prev = rawPoints[i - 1];
        if (cur.isQualitative || prev.isQualitative) {
          if (cur.value < prev.value) {
            change = cur.value == 0 ? '转阴 🟢' : '好转/减弱 🔻';
          } else if (cur.value > prev.value) {
            change = prev.value == 0 ? '转阳 🔴' : '加重/增强 🔺';
          } else {
            change = cur.value == 0 ? '持续阴性 ⚪' : '维持原样 ⚪';
          }
        }
      }

      finalPoints.add(MetricHistoryPoint(
        date: cur.date,
        hospital: cur.hospital,
        value: cur.value,
        valueStr: cur.valueStr,
        unit: cur.unit,
        status: cur.status,
        notes: cur.notes,
        recordId: cur.recordId,
        parentCategory: cur.parentCategory,
        diseaseName: cur.diseaseName,
        isQualitative: cur.isQualitative,
        qualitativeChange: change,
      ));
    }

    return finalPoints;
  }

  // =========================================================================
  // --- 💊 慢病药物记录：同种药物聚合档案与剂量调整走势图 ---
  // =========================================================================

  Future<void> saveMedicationPlan(MedicationPlan plan) async {
    await StorageService.instance.saveMedicationPlan(plan);
    final idx = _medicationPlans.indexWhere((m) => m.id == plan.id);
    if (idx >= 0) {
      _medicationPlans[idx] = plan;
    } else {
      _medicationPlans.add(plan);
    }
    notifyListeners();
  }

  Future<void> deleteMedicationPlan(String id) async {
    await StorageService.instance.deleteMedicationPlan(id);
    _medicationPlans.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// 提取同一种药物的所有调药记录，聚合成独立档案并生成剂量时序走势
  List<MedicationDrugTimeline> getAggregatedMedicationTimelines({
    String searchQuery = '',
    String diseaseId = '',
  }) {
    var list = List<MedicationPlan>.from(_medicationPlans);
    if (diseaseId.isNotEmpty) {
      list = list.where((m) => m.diseaseId == diseaseId).toList();
    }

    // 按药品名称分组
    final Map<String, List<MedicationPlan>> groupedByName = {};
    for (var m in list) {
      final name = m.medicineName.trim();
      if (name.isEmpty) continue;
      groupedByName.putIfAbsent(name, () => []).add(m);
    }

    final List<MedicationDrugTimeline> timelines = [];

    for (var entry in groupedByName.entries) {
      final medName = entry.key;
      final rawPlans = entry.value;

      // 关键词搜索过滤
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        if (!medName.toLowerCase().contains(q) &&
            !rawPlans.any((p) => p.reason.toLowerCase().contains(q) || p.notes.toLowerCase().contains(q))) {
          continue;
        }
      }

      // 按日期升序排列，以便计算剂量前后变化
      rawPlans.sort((a, b) => a.date.compareTo(b.date));

      final List<MedicationAdjustmentPoint> points = [];
      double prevNumDosage = 0.0;

      for (int i = 0; i < rawPlans.length; i++) {
        final cur = rawPlans[i];
        final parsed = _parseDosageNumeric(cur.dosage);

        String diff = '维持方案 ⚪';
        if (i == 0) {
          diff = '初始用药方案 🟢';
        } else {
          final prev = rawPlans[i - 1];
          if (cur.status == 'stopped' || cur.changeType == 'stop') {
            diff = '遵医嘱停药 🔴';
          } else if (parsed.value > prevNumDosage && prevNumDosage > 0) {
            final delta = parsed.value - prevNumDosage;
            diff = '加量 +${delta.toStringAsFixed(2)}${parsed.unit} 🔺';
          } else if (parsed.value < prevNumDosage && prevNumDosage > 0) {
            final delta = prevNumDosage - parsed.value;
            diff = '减量 -${delta.toStringAsFixed(2)}${parsed.unit} 🔻';
          } else if (cur.dosage != prev.dosage || cur.frequency != prev.frequency) {
            diff = '频次/剂型调整 🔄';
          }
        }

        prevNumDosage = parsed.value;

        points.add(MedicationAdjustmentPoint(
          id: cur.id,
          date: cur.date,
          dosageStr: cur.dosage.isNotEmpty ? cur.dosage : '未注明',
          numericDosage: parsed.value,
          unit: parsed.unit,
          frequency: cur.frequency.isNotEmpty ? cur.frequency : '未注明',
          changeType: cur.changeType,
          reason: cur.reason,
          notes: cur.notes,
          diffFromPrevious: diff,
        ));
      }

      final latest = rawPlans.last;
      final dis = getDiseaseById(latest.diseaseId);

      timelines.add(MedicationDrugTimeline(
        medicineName: medName,
        diseaseId: latest.diseaseId,
        diseaseName: dis?.name ?? '',
        currentStatus: latest.status,
        latestDosage: latest.dosage,
        latestFrequency: latest.frequency,
        latestDate: latest.date,
        firstDate: rawPlans.first.date,
        historyPoints: points, // 按时间正序排列
      ));
    }

    // 默认按最新调药日期倒序排列（最近调整的药物排在最前）
    timelines.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return timelines;
  }

  /// 智能解析剂量字符串中的数值与单位 (如 "0.5g", "500mg", "1片", "50μg")
  _ParsedDosage _parseDosageNumeric(String dosage) {
    if (dosage.isEmpty) return _ParsedDosage(1.0, '');
    final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(dosage);
    if (match != null) {
      final numVal = double.tryParse(match.group(0)!) ?? 1.0;
      final unit = dosage.replaceAll(match.group(0)!, '').replaceAll('/', '').replaceAll('次', '').trim();
      return _ParsedDosage(numVal, unit.isNotEmpty ? unit : '剂量');
    }
    return _ParsedDosage(1.0, '剂量');
  }

  /// 获取按日期分组且携带与上一次日期自动比对的用药记录 (供日期流水视图使用)
  List<MedicationComparisonGroup> getMedicationComparisonGroups({String diseaseId = ''}) {
    var list = List<MedicationPlan>.from(_medicationPlans);
    if (diseaseId.isNotEmpty) {
      list = list.where((m) => m.diseaseId == diseaseId).toList();
    }

    list.sort((a, b) => a.date.compareTo(b.date));

    final Map<String, List<MedicationPlan>> groupedByDate = {};
    for (var m in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(m.date);
      groupedByDate.putIfAbsent(dateKey, () => []).add(m);
    }

    final sortedDateKeys = groupedByDate.keys.toList()..sort();
    final List<MedicationComparisonGroup> groups = [];

    for (int i = 0; i < sortedDateKeys.length; i++) {
      final dateKey = sortedDateKeys[i];
      final currentPlans = groupedByDate[dateKey]!;
      final currentDateTime = currentPlans.first.date;

      final List<MedicationPlanWithDiff> itemsWithDiff = [];

      List<MedicationPlan> prevPlans = [];
      if (i > 0) {
        final prevDateKey = sortedDateKeys[i - 1];
        prevPlans = groupedByDate[prevDateKey]!;
      }

      for (var plan in currentPlans) {
        final prevMatch = prevPlans.where(
          (p) => p.medicineName.trim().toLowerCase() == plan.medicineName.trim().toLowerCase(),
        ).toList();

        String diffTag = '维持原方案 ⚪';
        MedicationPlan? prevPlan;

        if (prevMatch.isEmpty) {
          diffTag = '本次新开药物 🟢';
        } else {
          prevPlan = prevMatch.first;
          if (plan.dosage != prevPlan.dosage || plan.frequency != prevPlan.frequency) {
            diffTag = '剂量/频次调整 🔄 (前次: ${prevPlan.dosage} ${prevPlan.frequency})';
          } else if (plan.changeType == 'stop' || plan.status == 'stopped') {
            diffTag = '已停用 🔴';
          } else {
            diffTag = '遵医嘱维持 ⚪';
          }
        }

        itemsWithDiff.add(MedicationPlanWithDiff(
          plan: plan,
          diffTag: diffTag,
          previousPlan: prevPlan,
        ));
      }

      groups.add(MedicationComparisonGroup(
        date: currentDateTime,
        items: itemsWithDiff,
      ));
    }

    return groups.reversed.toList();
  }

  // =========================================================================
  // --- 📝 复查提问备忘录与历史解答前后对比 ---
  // =========================================================================

  Future<void> saveConsultationQuestion(ConsultationQuestion q) async {
    await StorageService.instance.saveConsultationQuestion(q);
    final idx = _consultationQuestions.indexWhere((item) => item.id == q.id);
    if (idx >= 0) {
      _consultationQuestions[idx] = q;
    } else {
      _consultationQuestions.add(q);
    }
    notifyListeners();
  }

  Future<void> toggleQuestionAskedStatus(String questionId) async {
    final idx = _consultationQuestions.indexWhere((q) => q.id == questionId);
    if (idx >= 0) {
      final cur = _consultationQuestions[idx];
      cur.isAsked = !cur.isAsked;
      await saveConsultationQuestion(cur);
    }
  }

  Future<void> deleteConsultationQuestion(String id) async {
    await StorageService.instance.deleteConsultationQuestion(id);
    _consultationQuestions.removeWhere((q) => q.id == id);
    notifyListeners();
  }

  List<QuestionsByDateGroup> getQuestionsGroupedByDate({String diseaseId = ''}) {
    var list = List<ConsultationQuestion>.from(_consultationQuestions);
    if (diseaseId.isNotEmpty) {
      list = list.where((q) => q.diseaseId == diseaseId).toList();
    }

    list.sort((a, b) => a.targetDate.compareTo(b.targetDate));

    final Map<String, List<ConsultationQuestion>> grouped = {};
    for (var q in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(q.targetDate);
      grouped.putIfAbsent(dateKey, () => []).add(q);
    }

    final sortedDateKeys = grouped.keys.toList()..sort();
    final List<QuestionsByDateGroup> groups = [];

    for (int i = 0; i < sortedDateKeys.length; i++) {
      final dateKey = sortedDateKeys[i];
      final currentQuestions = grouped[dateKey]!;
      final currentDateTime = currentQuestions.first.targetDate;

      List<ConsultationQuestion> prevQuestions = [];
      if (i > 0) {
        final prevDateKey = sortedDateKeys[i - 1];
        prevQuestions = grouped[prevDateKey]!;
      }

      groups.add(QuestionsByDateGroup(
        date: currentDateTime,
        questions: currentQuestions,
        previousDateQuestions: prevQuestions,
      ));
    }

    return groups.reversed.toList();
  }
}

class _ParsedDosage {
  final double value;
  final String unit;
  _ParsedDosage(this.value, this.unit);
}
