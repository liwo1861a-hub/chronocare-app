import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../models/medication.dart';
import '../services/ocr_service.dart';
import '../services/ai_service.dart';
import 'record_edit_screen.dart';

enum BatchTaskStatus { pending, ocring, aiParsing, completed, failed }

class BatchTaskItem {
  final String id;
  final File file;
  BatchTaskStatus status;
  String ocrText;
  AiAnalysisResult? result;
  String error;

  BatchTaskItem({
    required this.id,
    required this.file,
    this.status = BatchTaskStatus.pending,
    this.ocrText = '',
    this.result,
    this.error = '',
  });
}

class BatchImportScreen extends StatefulWidget {
  const BatchImportScreen({super.key});

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  final List<BatchTaskItem> _tasks = [];
  bool _isProcessing = false;
  bool _mergeSameDateRecords = true; // 同一个日期的自动规整保存在同一个档案里

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<SettingsProvider>(context);
    final settings = settingsProv.settings;
    final recordsProv = Provider.of<RecordsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量导入与智能扫单'),
        actions: [
          if (_tasks.isNotEmpty && !_isProcessing)
            TextButton.icon(
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: Text(
                _mergeSameDateRecords ? '按日期规整入库' : '单张独立入库',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _saveAllCompletedTasks(recordsProv),
            ),
        ],
      ),
      body: Column(
        children: [
          // 两个独立的核心控制开关面板
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.document_scanner, size: 20, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('开关 1：上传后自动 OCR 识别', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    subtitle: const Text('选图后自动提取图片中的所有文字行', style: TextStyle(fontSize: 12)),
                    value: settings.batchAutoOcr,
                    onChanged: (val) {
                      settingsProv.updatePartial(batchAutoOcr: val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20, color: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text('开关 2：自动 AI 深度整理与 100% 全量提取', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    subtitle: const Text('通过 AI 将单据中的所有检测指标逐行全量结构化，绝不遗漏', style: TextStyle(fontSize: 12)),
                    value: settings.batchAutoAiParse,
                    onChanged: (val) {
                      settingsProv.updatePartial(batchAutoAiParse: val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.folder_shared_outlined, size: 20, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('开关 3：同日化验单自动规整在同一档案', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    subtitle: const Text('推荐开启：同一天就医复查的多张化验单自动规整在同一份档案中，支持在档案内滑动切图与分栏整理', style: TextStyle(fontSize: 12)),
                    value: _mergeSameDateRecords,
                    onChanged: (val) {
                      setState(() => _mergeSameDateRecords = val);
                    },
                  ),
                ],
              ),
            ),
          ),

          // 操作按钮区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('选择化验单图片 (多选)'),
                    onPressed: _isProcessing ? null : _pickImages,
                  ),
                ),
                const SizedBox(width: 10),
                if (_tasks.isNotEmpty && !_isProcessing)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('开始处理', style: TextStyle(color: Colors.white)),
                    onPressed: () => _runBatchPipeline(settings),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 任务列表
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('点击上方按钮批量选择化验单或报告单照片', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 6),
                        const Text('同一开单日期的化验单将自动合并，并按检查项目分栏目管理', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(task.file, width: 50, height: 50, fit: BoxFit.cover),
                          ),
                          title: Text('图片 #${index + 1} (${task.file.path.split("/").last.split("\\").last})'),
                          subtitle: _buildTaskSubtitle(task),
                          trailing: _buildTaskTrailing(task, index, settings, recordsProv),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSubtitle(BatchTaskItem task) {
    switch (task.status) {
      case BatchTaskStatus.pending:
        return const Text('等待处理', style: TextStyle(color: Colors.grey, fontSize: 12));
      case BatchTaskStatus.ocring:
        return const Text('正在进行 OCR 识别...', style: TextStyle(color: Colors.blue, fontSize: 12));
      case BatchTaskStatus.aiParsing:
        return const Text('正在通过 Gemini 3.7 Flash 结构化整理...', style: TextStyle(color: Colors.purple, fontSize: 12));
      case BatchTaskStatus.completed:
        final count = task.result?.items.length ?? 0;
        final dStr = task.result?.checkDate?.toIso8601String().substring(0, 10) ?? '';
        final cat = task.result?.category ?? '检验项目';
        return Text('已解析 $count 个指标 · $cat · $dStr', style: const TextStyle(color: Colors.green, fontSize: 12));
      case BatchTaskStatus.failed:
        return Text('失败: ${task.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
    }
  }

  Widget _buildTaskTrailing(BatchTaskItem task, int index, settings, RecordsProvider recordsProv) {
    if (task.status == BatchTaskStatus.ocring || task.status == BatchTaskStatus.aiParsing) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (task.status == BatchTaskStatus.completed) {
      return IconButton(
        icon: const Icon(Icons.arrow_forward, color: Colors.blueAccent),
        onPressed: () => _openTaskEdit(task, recordsProv),
      );
    }
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.grey, size: 18),
      onPressed: () {
        setState(() => _tasks.removeAt(index));
      },
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        for (var p in picked) {
          _tasks.add(BatchTaskItem(
            id: const Uuid().v4(),
            file: File(p.path),
          ));
        }
      });
      final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
      if (settings.batchAutoOcr) {
        _runBatchPipeline(settings);
      }
    }
  }

  Future<void> _runBatchPipeline(settings) async {
    setState(() => _isProcessing = true);

    for (var task in _tasks) {
      if (task.status == BatchTaskStatus.completed) continue;

      try {
        final engine = settings.ocrEngine;

        if (engine == 'gemini_vision') {
          // 方式 1: Gemini 视觉多模态直出
          setState(() => task.status = BatchTaskStatus.aiParsing);
          final res = await AiService.instance.analyzeImageWithGemini(
            imageFile: task.file,
            settings: settings,
          );
          _bindResultToTask(task, res);
        } else {
          // 方式 2 & 3: 联网 OCR (ocr_space) 或端侧离线引擎提取文字，再由 AI 深度整理
          setState(() => task.status = BatchTaskStatus.ocring);
          final text = await OcrService.instance.recognizeText(
            imageFile: task.file,
            settings: settings,
          );
          task.ocrText = text;

          if (settings.batchAutoAiParse) {
            setState(() => task.status = BatchTaskStatus.aiParsing);
            final res = await AiService.instance.analyzeOcrTextWithAi(
              ocrText: text,
              settings: settings,
              imagePath: task.file.path,
            );
            _bindResultToTask(task, res);
          } else {
            task.status = BatchTaskStatus.completed;
          }
        }
      } catch (e) {
        task.status = BatchTaskStatus.failed;
        task.error = e.toString();
      }
      setState(() {});
    }

    setState(() => _isProcessing = false);
  }

  void _bindResultToTask(BatchTaskItem task, AiAnalysisResult res) {
    // 核心绑定：将当次识别出来的所有 items 的 sourceImagePath 绑定为当前图片
    final categoryName = res.category.isNotEmpty ? res.category : '常规化验';
    for (var item in res.items) {
      item.sourceImagePath = task.file.path;
      if (item.category.isEmpty || item.category == '常规检验') {
        item.category = categoryName;
      }
    }
    task.result = res;
    task.status = BatchTaskStatus.completed;
  }

  void _openTaskEdit(BatchTaskItem task, RecordsProvider recordsProv) {
    final res = task.result;
    final rec = CheckRecord(
      id: const Uuid().v4(),
      diseaseId: recordsProv.diseases.isNotEmpty ? recordsProv.diseases.first.id : '',
      checkDate: res?.checkDate ?? DateTime.now(),
      hospital: res?.hospital ?? '',
      department: res?.department ?? '',
      doctorName: res?.doctorName ?? '',
      category: res?.category ?? '血液生化',
      doctorAdvice: res?.doctorAdvice ?? '',
      imagePaths: [task.file.path],
      items: res?.items ?? [],
      medicationChanges: res?.medicationChanges ?? [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordEditScreen(record: rec)),
    );
  }

  void _saveAllCompletedTasks(RecordsProvider recordsProv) async {
    int processedCount = 0;
    for (var task in _tasks) {
      if (task.status == BatchTaskStatus.completed && task.result != null) {
        final res = task.result!;
        final rec = CheckRecord(
          id: const Uuid().v4(),
          diseaseId: recordsProv.diseases.isNotEmpty ? recordsProv.diseases.first.id : '',
          checkDate: res.checkDate ?? DateTime.now(),
          hospital: res.hospital,
          department: res.department,
          doctorName: res.doctorName,
          category: res.category.isNotEmpty ? res.category : '常规化验',
          doctorAdvice: res.doctorAdvice,
          imagePaths: [task.file.path], // 每张图片独立绑定当前化验单
          items: res.items,
          medicationChanges: res.medicationChanges,
        );

        if (_mergeSameDateRecords) {
          // 同一个日期的自动规整保存在同一个档案里
          await recordsProv.mergeOrSaveRecordByDate(rec);
        } else {
          // 独立分开保存
          await recordsProv.saveRecord(rec);
        }
        processedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mergeSameDateRecords
                ? '✅ 已成功将 $processedCount 份化验单按就诊日期自动规整至复查档案！'
                : '✅ 已将 $processedCount 份化验单独立保存入库！',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}
