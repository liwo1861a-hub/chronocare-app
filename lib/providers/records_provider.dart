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
  final String parentCategory; // 所属大项目/报告单名称 (如: 血液生化全项)
  final String diseaseName;

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

  /// 提取所有指标名称（无论正常、偏高、偏低还是自定义，100% 全量包含）
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

  /// 关键词模糊搜索指标名称
  List<String> searchItemNames(String query) {
    if (query.trim().isEmpty) return getAllItemNames();
    final q = query.trim().toLowerCase();
    return getAllItemNames().where((name) => name.toLowerCase().contains(q)).toList();
  }

  /// 获取指定指标的历史走势数据（包含正常指标与异常指标，指向所在大项目）
  List<MetricHistoryPoint> getMetricHistory(String itemName) {
    final List<MetricHistoryPoint> points = [];
    final target = itemName.trim().toLowerCase();

    for (var r in _records) {
      final dis = getDiseaseById(r.diseaseId);
      for (var it in r.items) {
        if (it.itemName.trim().toLowerCase() == target) {
          double? val = it.numericValue;
          if (val == null) {
            final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(it.value);
            if (match != null) val = double.tryParse(match.group(0)!);
          }

          if (val != null) {
            points.add(MetricHistoryPoint(
              date: r.checkDate,
              hospital: r.hospital.isNotEmpty ? r.hospital : '未注明医院',
              value: val,
              valueStr: it.value,
              unit: it.unit,
              status: it.status,
              notes: it.notes,
              recordId: r.id,
              parentCategory: it.category.isNotEmpty ? it.category : (r.category.isNotEmpty ? r.category : '常规化验单'),
              diseaseName: dis?.name ?? '',
            ));
          }
        }
      }
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}
