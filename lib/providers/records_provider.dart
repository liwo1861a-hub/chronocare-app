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
  final double value; // 数值型或定性量化值 (阴性=0, ±=0.5, +=1, 2+=2, 3+=3, 阳性=1)
  final String valueStr; // 原始文本结果 (如 "阴性", "2+", "未见异常", "轻度改变")
  final String unit;
  final String status; // 'normal', 'high', 'low', 'abnormal'
  final String notes;
  final String recordId;
  final String parentCategory; // 所属大项目/报告单名称 (如: 血液生化全项, 尿液常规)
  final String diseaseName;
  final bool isQualitative; // 是否为定性/文本型项目
  final String qualitativeChange; // 与上次比对判定 (如: "转阴 🟢", "转阳 🔴", "好转 🔻", "持平 ⚪")

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

  /// 获取指定指标的历史走势数据（包含数值型与定性/文字型，100% 支持时序比对）
  List<MetricHistoryPoint> getMetricHistory(String itemName) {
    final List<MetricHistoryPoint> rawPoints = [];
    final target = itemName.trim().toLowerCase();

    for (var r in _records) {
      final dis = getDiseaseById(r.diseaseId);
      for (var it in r.items) {
        if (it.itemName.trim().toLowerCase() == target) {
          double? val = it.numericValue;
          bool isQualitative = false;

          // 尝试数值解析
          if (val == null) {
            final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(it.value);
            if (match != null) {
              val = double.tryParse(match.group(0)!);
            }
          }

          // 定性/阴阳性/加号/文字结果量化映射
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
              val = 0.0; // 纯文本描述赋默认基准
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

    // 计算相邻复查的定性转归判定 (如: 转阴, 转阳, 加重, 好转, 稳定)
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
}
