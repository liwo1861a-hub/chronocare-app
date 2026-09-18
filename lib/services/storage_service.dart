import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/app_settings.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Database? _db;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'chronocare.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diseases (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            stage TEXT,
            colorHex TEXT,
            targetNotes TEXT,
            notes TEXT,
            createdAt TEXT,
            customFields TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE records (
            id TEXT PRIMARY KEY,
            diseaseId TEXT,
            checkDate TEXT,
            nextCheckDate TEXT,
            hospital TEXT,
            department TEXT,
            doctorName TEXT,
            category TEXT,
            doctorAdvice TEXT,
            imagePaths TEXT,
            items TEXT,
            medicationChanges TEXT,
            overallNotes TEXT,
            tags TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');
      },
    );
  }

  // --- 疾病操作 ---
  Future<List<Disease>> getDiseases() async {
    final res = await _db!.query('diseases', orderBy: 'createdAt DESC');
    return res.map((m) => Disease.fromMap(m)).toList();
  }

  Future<void> saveDisease(Disease disease) async {
    await _db!.insert(
      'diseases',
      disease.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDisease(String id) async {
    await _db!.delete('diseases', where: 'id = ?', whereArgs: [id]);
    await _db!.delete('records', where: 'diseaseId = ?', whereArgs: [id]);
  }

  // --- 复查记录操作 ---
  Future<List<CheckRecord>> getRecords() async {
    final res = await _db!.query('records', orderBy: 'checkDate DESC');
    return res.map((m) => CheckRecord.fromMap(m)).toList();
  }

  Future<void> saveRecord(CheckRecord record) async {
    await _db!.insert(
      'records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecord(String id) async {
    await _db!.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  // --- 设置操作 ---
  Future<AppSettings> getSettings() async {
    if (_prefs == null) await init();
    final jsonStr = _prefs!.getString('app_settings');
    if (jsonStr == null || jsonStr.isEmpty) {
      return AppSettings();
    }
    try {
      final map = jsonDecode(jsonStr);
      return AppSettings.fromMap(map);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    if (_prefs == null) await init();
    await _prefs!.setString('app_settings', jsonEncode(settings.toMap()));
  }

  // --- 导出全量 JSON 数据 ---
  Future<Map<String, dynamic>> exportAllData() async {
    final diseases = await getDiseases();
    final records = await getRecords();
    final settings = await getSettings();

    return {
      'app': 'ChronoCare',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'diseases': diseases.map((d) => d.toMap()).toList(),
      'records': records.map((r) => r.toMap()).toList(),
      'settings': settings.toMap(),
    };
  }

  // --- 导入全量 JSON 数据 ---
  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['diseases'] != null && data['diseases'] is List) {
      for (var dMap in data['diseases']) {
        await saveDisease(Disease.fromMap(Map<String, dynamic>.from(dMap)));
      }
    }
    if (data['records'] != null && data['records'] is List) {
      for (var rMap in data['records']) {
        await saveRecord(CheckRecord.fromMap(Map<String, dynamic>.from(rMap)));
      }
    }
    if (data['settings'] != null && data['settings'] is Map) {
      await saveSettings(AppSettings.fromMap(Map<String, dynamic>.from(data['settings'])));
    }
  }
}
