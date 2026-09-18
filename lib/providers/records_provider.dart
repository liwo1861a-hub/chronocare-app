import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../models/category_group.dart';
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

  MetricHistoryPoint({
    required this.date,
    required this.hospital,
    required this.value,
    required this.valueStr,
    required this.unit,
    required this.status,
    required this.notes,
    required this.recordId,
  });
}

class RecordsProvider with ChangeNotifier {
  List<Disease> _diseases = [];
  List<CheckRecord> _records = [];
  List<CategoryGroup> _categoryGroups = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedDiseaseId = '';
  String _selectedCategory = '';

  List<Disease> get diseases => _diseases;
  List<CheckRecord> get records => _records;
  List<CategoryGroup> get categoryGroups => _categoryGroups;
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

    // 如果第一次使用，初始化默认慢病档案
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

  // --- 过滤后的记录列表 ---
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

  // --- 疾病管理 ---
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

  Future<void> deleteDisease(String id) async {
    await StorageService.instance.deleteDisease(id);
    _diseases.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // --- 记录管理 ---
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

  /// 严格按照医生开单日期/检查日期进行自动合并或归档
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

    // 存在同日记录，执行合并
    final Set<String> allImages = Set.from(existing.imagePaths);
    for (var img in newRecord.imagePaths) {
      if (img.isNotEmpty) allImages.add(img);
    }
    existing.imagePaths = allImages.toList();

    // 合并指标
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

    // 合并医嘱
    if (newRecord.doctorAdvice.isNotEmpty) {
      if (existing.doctorAdvice.isEmpty) {
        existing.doctorAdvice = newRecord.doctorAdvice;
      } else if (!existing.doctorAdvice.contains(newRecord.doctorAdvice)) {
        existing.doctorAdvice = '${existing.doctorAdvice}\n${newRecord.doctorAdvice}';
      }
    }

    // 医院科室信息补齐
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

  /// 一键合并档案内的两个检查栏目（将 fromCategory 的所有指标合并入 toCategory）
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

  // --- 分类组与整合管理 ---
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

  List<MetricHistoryPoint> getMetricHistory(String itemName) {
    final List<MetricHistoryPoint> points = [];
    final target = itemName.trim().toLowerCase();

    for (var r in _records) {
      for (var it in r.items) {
        if (it.itemName.trim().toLowerCase() == target) {
          if (it.numericValue != null) {
            points.add(MetricHistoryPoint(
              date: r.checkDate,
              hospital: r.hospital,
              value: it.numericValue!,
              valueStr: it.value,
              unit: it.unit,
              status: it.status,
              notes: it.notes,
              recordId: r.id,
            ));
          }
        }
      }
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}
