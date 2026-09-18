import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import '../models/record.dart';
import 'record_edit_screen.dart';

class RecordDetailScreen extends StatelessWidget {
  final String recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final record = prov.records.firstWhere(
      (r) => r.id == recordId,
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
                          disease?.name ?? '未分类慢病',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.category,
                            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.calendar_today, '复查日期', DateFormat('yyyy年MM月dd日').format(record.checkDate)),
                    if (record.nextCheckDate != null)
                      _buildInfoRow(Icons.alarm, '下次复查提醒', DateFormat('yyyy年MM月dd日').format(record.nextCheckDate!)),
                    _buildInfoRow(Icons.local_hospital, '就诊医院', record.hospital.isNotEmpty ? record.hospital : '未填写'),
                    _buildInfoRow(Icons.meeting_room, '科室/医生', '${record.department} ${record.doctorName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 化验单原图预览
            if (record.imagePaths.isNotEmpty) ...[
              const Text('化验单 / 报告单照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          border: Border.all(color: Colors.grey.shade300),
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
                              color: isAbnormal ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.value} ${item.unit} ${isAbnormal ? (item.status == "high" ? "↑" : "↓") : ""}',
                              style: TextStyle(
                                color: isAbnormal ? Colors.red.shade700 : Colors.green.shade800,
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

            // 医生医嘱
            if (record.doctorAdvice.isNotEmpty) ...[
              const Text('医生就诊医嘱 / 处置建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.medical_services, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(record.doctorAdvice, style: const TextStyle(fontSize: 14, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
