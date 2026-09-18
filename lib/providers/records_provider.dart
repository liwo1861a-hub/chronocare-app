import 'package:flutter/material.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/check_item.dart';
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
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedDiseaseId = '';
  String _selectedCategory = '';

  List<Disease> get diseases => _diseases;
  List<CheckRecord> get records => _records;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedDiseaseId => _selectedDiseaseId;
  String get selectedCategory => _selectedCategory;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _diseases = await StorageService.instance.getDiseases();
    _records = await StorageService.instance.getRecords();

    // 如果是第一次使用，初始化一些常见示例慢病
    if (_diseases.isEmpty) {
      final defaultDisease = Disease(
        id: 'dis_default_01',
        name: '慢性病管理档案',
        stage: '随访监测期',
        colorHex: '#2563EB',
        targetNotes: '保持指标平稳，定期复查',
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
    } else if (sortOrder == 'date_asc') {
      list.sort((a, b) => a.checkDate.compareTo(b.checkDate));
    } else if (sortOrder == 'abnormal_first') {
      list.sort((a, b) => b.abnormalCount.compareTo(a.abnormalCount));
    }

    return list;
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSelectedDisease(String id) {
    _selectedDiseaseId = id;
    notifyListeners();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  // --- 疾病操作 ---
  Future<void> addOrUpdateDisease(Disease d) async {
    await StorageService.instance.saveDisease(d);
    final idx = _diseases.indexWhere((item) => item.id == d.id);
    if (idx >= 0) {
      _diseases[idx] = d;
    } else {
      _diseases.insert(0, d);
    }
    notifyListeners();
  }

  Future<void> deleteDisease(String id) async {
    await StorageService.instance.deleteDisease(id);
    _diseases.removeWhere((item) => item.id == id);
    _records.removeWhere((item) => item.diseaseId == id);
    notifyListeners();
  }

  Disease? getDiseaseById(String id) {
    try {
      return _diseases.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- 记录操作 ---
  Future<void> saveRecord(CheckRecord r) async {
    await StorageService.instance.saveRecord(r);
    final idx = _records.indexWhere((item) => item.id == r.id);
    if (idx >= 0) {
      _records[idx] = r;
    } else {
      _records.insert(0, r);
    }
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    await StorageService.instance.deleteRecord(id);
    _records.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // --- 提取所有去重的检验项目名称 ---
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

  // --- 获取指定指标的历史走势数据 ---
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
