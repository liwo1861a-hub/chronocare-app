import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../models/record.dart';
import '../services/ai_service.dart';
import 'record_edit_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final String recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  bool _isSummarizingAdvice = false;

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final record = prov.records.firstWhere(
      (r) => r.id == widget.recordId,
      orElse: () => CheckRecord(
        id: '',
        diseaseId: '',
        checkDate: DateTime.now(),
      ),
    );

    if (record.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('记录详情')),
        body: const Center(child: Text('该记录已不存在')),
      );
    }

    final disease = prov.getDiseaseById(record.diseaseId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${DateFormat("yyyy-MM-dd").format(record.checkDate)} 复查详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑档案',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecordEditScreen(record: record)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基础信息卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          disease?.name ?? '慢病档案',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.category,
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.calendar_today, '复查日期', DateFormat('yyyy年MM月dd日').format(record.checkDate)),
                    if (record.nextCheckDate != null)
                      _buildInfoRow(Icons.alarm, '下次复查提醒', DateFormat('yyyy年MM月dd日').format(record.nextCheckDate!)),
                    _buildInfoRow(Icons.local_hospital, '就诊医院', record.hospital.isNotEmpty ? record.hospital : '未注明'),
                    _buildInfoRow(Icons.meeting_room, '科室/医生', '${record.department} ${record.doctorName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 医生医嘱（支持独立添加、编辑与 AI 智能总结）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('医生医嘱 / 处置建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: _isSummarizingAdvice
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('AI 总结医嘱', style: TextStyle(fontSize: 12)),
                      onPressed: _isSummarizingAdvice ? null : () => _generateAiAdvice(record, disease?.name ?? '慢病', settings, prov),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 20, color: Colors.blueAccent),
                      tooltip: '单独编辑医嘱',
                      onPressed: () => _editSingleAdviceDialog(context, record, prov),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.green.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: record.doctorAdvice.isNotEmpty
                    ? Text(record.doctorAdvice, style: const TextStyle(fontSize: 14, height: 1.5))
                    : const Text('暂无医生医嘱，点击上方【AI 总结医嘱】或右上角笔形图标单独添加', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 16),

            // 化验单原图预览
            if (record.imagePaths.isNotEmpty) ...[
              Text('化验单照片 (${record.imagePaths.length}张 已合并)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: record.imagePaths.length,
                  itemBuilder: (context, index) {
                    final path = record.imagePaths[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('查看化验单原图')),
                              backgroundColor: Colors.black,
                              body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 检验指标列表
            Text('检验指标详情 (${record.items.length}项)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: record.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('暂无结构化检验指标', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: record.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = record.items[index];
                        final isAbnormal = item.status != 'normal';
                        return ListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('参考范围: ${item.referenceRange.isNotEmpty ? item.referenceRange : "未注明"} ${item.notes.isNotEmpty ? "· 备注: ${item.notes}" : ""}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAbnormal ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.value} ${item.unit} ${isAbnormal ? (item.status == "high" ? "↑" : "↓") : ""}',
                              style: TextStyle(
                                color: isAbnormal ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // 用药调整
            if (record.medicationChanges.isNotEmpty) ...[
              const Text('用药方案变更', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: record.medicationChanges.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final med = record.medicationChanges[index];
                    return ListTile(
                      leading: const Icon(Icons.medication, color: Colors.teal),
                      title: Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${med.dosage} · ${med.frequency}\n变更原因: ${med.reason.isNotEmpty ? med.reason : "遵医嘱"}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 总体备注
            if (record.overallNotes.isNotEmpty) ...[
              const Text('就诊与复查备注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.note_alt_outlined, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(record.overallNotes, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _generateAiAdvice(CheckRecord record, String diseaseName, settings, RecordsProvider prov) async {
    setState(() => _isSummarizingAdvice = true);
    try {
      final summary = await AiService.instance.summarizeAdviceWithAi(
        items: record.items,
        meds: record.medicationChanges,
        diseaseName: diseaseName,
        hospital: record.hospital,
        userNotes: record.overallNotes,
        settings: settings,
      );

      record.doctorAdvice = summary;
      await prov.saveRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ AI 已成功结合所有指标与用药总结生成医嘱！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 总结失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSummarizingAdvice = false);
    }
  }

  void _editSingleAdviceDialog(BuildContext context, CheckRecord record, RecordsProvider prov) {
    final ctrl = TextEditingController(text: record.doctorAdvice);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('单独编辑医嘱建议'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '输入医生医嘱、处置建议或健康管理计划...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              record.doctorAdvice = ctrl.text.trim();
              prov.saveRecord(record);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
