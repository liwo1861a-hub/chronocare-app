import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/records_provider.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../models/medication.dart';

class RecordEditScreen extends StatefulWidget {
  final CheckRecord? record;

  const RecordEditScreen({super.key, this.record});

  @override
  State<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends State<RecordEditScreen> {
  late String _id;
  late String _diseaseId;
  late DateTime _checkDate;
  DateTime? _nextCheckDate;
  late TextEditingController _hospitalCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _doctorCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _adviceCtrl;
  late TextEditingController _notesCtrl;

  List<String> _images = [];
  List<CheckItem> _items = [];
  List<MedicationChange> _medications = [];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _id = r?.id ?? const Uuid().v4();
    _diseaseId = r?.diseaseId ?? '';
    _checkDate = r?.checkDate ?? DateTime.now();
    _nextCheckDate = r?.nextCheckDate;
    _hospitalCtrl = TextEditingController(text: r?.hospital ?? '');
    _departmentCtrl = TextEditingController(text: r?.department ?? '');
    _doctorCtrl = TextEditingController(text: r?.doctorName ?? '');
    _categoryCtrl = TextEditingController(text: r?.category ?? '血液生化');
    _adviceCtrl = TextEditingController(text: r?.doctorAdvice ?? '');
    _notesCtrl = TextEditingController(text: r?.overallNotes ?? '');

    _images = List.from(r?.imagePaths ?? []);
    _items = List.from(r?.items ?? []);
    _medications = List.from(r?.medicationChanges ?? []);
  }

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _departmentCtrl.dispose();
    _doctorCtrl.dispose();
    _categoryCtrl.dispose();
    _adviceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final diseases = prov.diseases;
    if (_diseaseId.isEmpty && diseases.isNotEmpty) {
      _diseaseId = diseases.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? '新建复查记录' : '编辑复查记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _saveRecord(prov),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 关联疾病与就诊日期
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: diseases.any((d) => d.id == _diseaseId) ? _diseaseId : (diseases.isNotEmpty ? diseases.first.id : null),
                      decoration: const InputDecoration(labelText: '关联疾病/病种 *', prefixIcon: Icon(Icons.health_and_safety)),
                      items: diseases.map((d) {
                        return DropdownMenuItem(value: d.id, child: Text(d.name));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _diseaseId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickCheckDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: '检查日期 *', prefixIcon: Icon(Icons.calendar_today)),
                              child: Text(DateFormat('yyyy-MM-dd').format(_checkDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickNextCheckDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: '下次复查日期', prefixIcon: Icon(Icons.alarm)),
                              child: Text(_nextCheckDate != null ? DateFormat('yyyy-MM-dd').format(_nextCheckDate!) : '未设置'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 医院与科室医生
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _hospitalCtrl,
                      decoration: const InputDecoration(labelText: '就诊医院', prefixIcon: Icon(Icons.local_hospital_outlined)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _departmentCtrl,
                            decoration: const InputDecoration(labelText: '科室', prefixIcon: Icon(Icons.meeting_room_outlined)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _doctorCtrl,
                            decoration: const InputDecoration(labelText: '接诊医生', prefixIcon: Icon(Icons.person_outline)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(labelText: '检查大类 (如血液生化/超声/胃镜)', prefixIcon: Icon(Icons.category_outlined)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 检查单原图管理
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('化验单 / 报告单原图', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('添加照片'),
                  onPressed: _addImages,
                ),
              ],
            ),
            if (_images.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final path = _images[index];
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(index)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),

            // 检验指标列表
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('检验指标列表 (${_items.length}项)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新增指标'),
                  onPressed: () => _editCheckItem(null),
                ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无结构化指标，可手动添加或由 AI 自动扫描生成', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final it = entry.value;
                final isAbnormal = it.status != 'normal';
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Text(it.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          '${it.value} ${it.unit}',
                          style: TextStyle(
                            color: isAbnormal ? Colors.red : Colors.black87,
                            fontWeight: isAbnormal ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '参考区间: ${it.referenceRange.isNotEmpty ? it.referenceRange : "未注明"} ${it.notes.isNotEmpty ? "· 备注: ${it.notes}" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _editCheckItem(it, index: idx),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          onPressed: () => setState(() => _items.removeAt(idx)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 14),

            // 药物调整与变更
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('用药调整记录 (${_medications.length}项)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  icon: const Icon(Icons.medication, size: 16),
                  label: const Text('记录调药'),
                  onPressed: () => _editMedication(null),
                ),
              ],
            ),
            if (_medications.isNotEmpty)
              ..._medications.asMap().entries.map((entry) {
                final idx = entry.key;
                final med = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.healing, color: Colors.teal),
                    title: Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${med.dosage} · ${med.frequency} · 原因: ${med.reason}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      onPressed: () => setState(() => _medications.removeAt(idx)),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 14),

            // 医生医嘱
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _adviceCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '医生就诊医嘱 / 处置建议',
                    hintText: '如：饮食少盐、增加运动、两周后复查肾功等',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 全局备注
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '本次复查总体备注',
                    hintText: '如：前夜空腹10小时、当天稍有感冒等个人备注',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCheckDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _checkDate = picked);
  }

  Future<void> _pickNextCheckDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextCheckDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextCheckDate = picked);
  }

  Future<void> _addImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((e) => e.path));
      });
    }
  }

  void _editCheckItem(CheckItem? existing, {int? index}) {
    final nameCtrl = TextEditingController(text: existing?.itemName ?? '');
    final valCtrl = TextEditingController(text: existing?.value ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final refCtrl = TextEditingController(text: existing?.referenceRange ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String status = existing?.status ?? 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          return AlertDialog(
            title: Text(existing == null ? '新增检验指标' : '编辑检验指标'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '指标名称 * (如：糖化血红蛋白)')),
                  TextField(controller: valCtrl, decoration: const InputDecoration(labelText: '检测结果值 * (如：6.3)')),
                  TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: '单位 (如：mmol/L, %)')),
                  TextField(controller: refCtrl, decoration: const InputDecoration(labelText: '参考区间 (如：4.0-6.0)')),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: '异常状态'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('正常')),
                      DropdownMenuItem(value: 'high', child: Text('偏高 ↑')),
                      DropdownMenuItem(value: 'low', child: Text('偏低 ↓')),
                      DropdownMenuItem(value: 'abnormal', child: Text('其他异常')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDState(() => status = val);
                    },
                  ),
                  TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: '单项指标备注')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final item = CheckItem(
                    id: existing?.id ?? const Uuid().v4(),
                    itemName: nameCtrl.text.trim(),
                    value: valCtrl.text.trim(),
                    unit: unitCtrl.text.trim(),
                    referenceRange: refCtrl.text.trim(),
                    status: status,
                    notes: notesCtrl.text.trim(),
                  );
                  setState(() {
                    if (index != null) {
                      _items[index] = item;
                    } else {
                      _items.add(item);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editMedication(MedicationChange? existing) {
    final nameCtrl = TextEditingController(text: existing?.medicineName ?? '');
    final doseCtrl = TextEditingController(text: existing?.dosage ?? '');
    final freqCtrl = TextEditingController(text: existing?.frequency ?? '');
    final reasonCtrl = TextEditingController(text: existing?.reason ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记录用药调整'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '药名 *')),
            TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: '单次剂量 (如：0.5g / 1片)')),
            TextField(controller: freqCtrl, decoration: const InputDecoration(labelText: '频次 (如：每日2次 饭后)')),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: '调整原因 (如：遵医嘱加量)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _medications.add(MedicationChange(
                  id: const Uuid().v4(),
                  medicineName: nameCtrl.text.trim(),
                  dosage: doseCtrl.text.trim(),
                  frequency: freqCtrl.text.trim(),
                  reason: reasonCtrl.text.trim(),
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _saveRecord(RecordsProvider prov) {
    if (_diseaseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择关联的疾病')));
      return;
    }

    final record = CheckRecord(
      id: _id,
      diseaseId: _diseaseId,
      checkDate: _checkDate,
      nextCheckDate: _nextCheckDate,
      hospital: _hospitalCtrl.text.trim(),
      department: _departmentCtrl.text.trim(),
      doctorName: _doctorCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      doctorAdvice: _adviceCtrl.text.trim(),
      imagePaths: _images,
      items: _items,
      medicationChanges: _medications,
      overallNotes: _notesCtrl.text.trim(),
    );

    prov.saveRecord(record);
    Navigator.pop(context);
  }
}
