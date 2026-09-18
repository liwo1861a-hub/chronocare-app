import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease.dart';
import '../models/record.dart';
import '../models/app_settings.dart';
import '../models/category_group.dart';
import '../models/medication_plan.dart';
import '../models/consultation_question.dart';

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
      version: 3,
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

        await db.execute('''
          CREATE TABLE category_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            iconName TEXT,
            colorHex TEXT,
            matchedItemNames TEXT,
            notes TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE medication_plans (
            id TEXT PRIMARY KEY,
            diseaseId TEXT,
            date TEXT,
            medicineName TEXT NOT NULL,
            dosage TEXT,
            frequency TEXT,
            changeType TEXT,
            reason TEXT,
            status TEXT,
            notes TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE consultation_questions (
            id TEXT PRIMARY KEY,
            diseaseId TEXT,
            targetDate TEXT,
            question TEXT NOT NULL,
            detail TEXT,
            isAsked INTEGER,
            doctorAnswer TEXT,
            category TEXT,
            createdAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS category_groups (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              iconName TEXT,
              colorHex TEXT,
              matchedItemNames TEXT,
              notes TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS medication_plans (
              id TEXT PRIMARY KEY,
              diseaseId TEXT,
              date TEXT,
              medicineName TEXT NOT NULL,
              dosage TEXT,
              frequency TEXT,
              changeType TEXT,
              reason TEXT,
              status TEXT,
              notes TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS consultation_questions (
              id TEXT PRIMARY KEY,
              diseaseId TEXT,
              targetDate TEXT,
              question TEXT NOT NULL,
              detail TEXT,
              isAsked INTEGER,
              doctorAnswer TEXT,
              category TEXT,
              createdAt TEXT
            )
          ''');
        }
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
    await _db!.delete('medication_plans', where: 'diseaseId = ?', whereArgs: [id]);
    await _db!.delete('consultation_questions', where: 'diseaseId = ?', whereArgs: [id]);
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

  // --- 自定义检查项目分类分组操作 ---
  Future<List<CategoryGroup>> getCategoryGroups() async {
    final res = await _db!.query('category_groups');
    return res.map((m) => CategoryGroup.fromMap(m)).toList();
  }

  Future<void> saveCategoryGroup(CategoryGroup group) async {
    await _db!.insert(
      'category_groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategoryGroup(String id) async {
    await _db!.delete('category_groups', where: 'id = ?', whereArgs: [id]);
  }

  // --- 药物记录与方案操作 ---
  Future<List<MedicationPlan>> getMedicationPlans() async {
    final res = await _db!.query('medication_plans', orderBy: 'date DESC');
    return res.map((m) => MedicationPlan.fromMap(m)).toList();
  }

  Future<void> saveMedicationPlan(MedicationPlan plan) async {
    await _db!.insert(
      'medication_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMedicationPlan(String id) async {
    await _db!.delete('medication_plans', where: 'id = ?', whereArgs: [id]);
  }

  // --- 复查提问备忘录操作 ---
  Future<List<ConsultationQuestion>> getConsultationQuestions() async {
    final res = await _db!.query('consultation_questions', orderBy: 'targetDate DESC, createdAt DESC');
    return res.map((m) => ConsultationQuestion.fromMap(m)).toList();
  }

  Future<void> saveConsultationQuestion(ConsultationQuestion question) async {
    await _db!.insert(
      'consultation_questions',
      question.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteConsultationQuestion(String id) async {
    await _db!.delete('consultation_questions', where: 'id = ?', whereArgs: [id]);
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
    final groups = await getCategoryGroups();
    final meds = await getMedicationPlans();
    final questions = await getConsultationQuestions();
    final settings = await getSettings();

    return {
      'app': 'ChronoCare',
      'version': '1.1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'diseases': diseases.map((d) => d.toMap()).toList(),
      'records': records.map((r) => r.toMap()).toList(),
      'category_groups': groups.map((g) => g.toMap()).toList(),
      'medication_plans': meds.map((m) => m.toMap()).toList(),
      'consultation_questions': questions.map((q) => q.toMap()).toList(),
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
    if (data['category_groups'] != null && data['category_groups'] is List) {
      for (var gMap in data['category_groups']) {
        await saveCategoryGroup(CategoryGroup.fromMap(Map<String, dynamic>.from(gMap)));
      }
    }
    if (data['medication_plans'] != null && data['medication_plans'] is List) {
      for (var mMap in data['medication_plans']) {
        await saveMedicationPlan(MedicationPlan.fromMap(Map<String, dynamic>.from(mMap)));
      }
    }
    if (data['consultation_questions'] != null && data['consultation_questions'] is List) {
      for (var qMap in data['consultation_questions']) {
        await saveConsultationQuestion(ConsultationQuestion.fromMap(Map<String, dynamic>.from(qMap)));
      }
    }
    if (data['settings'] != null && data['settings'] is Map) {
      await saveSettings(AppSettings.fromMap(Map<String, dynamic>.from(data['settings'])));
    }
  }
}
