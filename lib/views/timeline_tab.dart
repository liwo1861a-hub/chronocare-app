import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../models/record.dart';
import 'record_detail_screen.dart';
import 'record_edit_screen.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final recordsProv = Provider.of<RecordsProvider>(context);
    final settingsProv = Provider.of<SettingsProvider>(context);
    final settings = settingsProv.settings;

    final records = recordsProv.getFilteredRecords(
      sortOrder: settings.defaultRecordSort,
    );

    if (recordsProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无复查记录',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角 "+" 或 "批量扫单" 开始记录',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final disease = recordsProv.getDiseaseById(record.diseaseId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordDetailScreen(recordId: record.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部日期与疾病标签
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 15, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(record.checkDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      if (disease != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(int.parse(disease.colorHex.replaceFirst('#', '0xFF')))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            disease.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(int.parse(disease.colorHex.replaceFirst('#', '0xFF'))),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 医院与科室
                  Row(
                    children: [
                      Icon(Icons.local_hospital_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${record.hospital.isNotEmpty ? record.hospital : "未填写医院"} · ${record.department.isNotEmpty ? record.department : "门诊"}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.category,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // 关键指标摘要与异常项胶囊
                  if (record.items.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.items.take(4).map((item) {
                        final isAbnormal = item.status != 'normal';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAbnormal
                                ? Colors.red.shade50
                                : Colors.blue.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isAbnormal ? Colors.red.shade200 : Colors.blue.shade100,
                            ),
                          ),
                          child: Text(
                            '${item.itemName}: ${item.value} ${item.unit} ${isAbnormal ? "↑" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAbnormal ? Colors.red.shade700 : Colors.black87,
                              fontWeight: isAbnormal ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 医生医嘱摘要
                  if (record.doctorAdvice.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '医嘱: ${record.doctorAdvice}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 底部操作区（图片角标与快速编辑）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (record.imagePaths.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.image, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${record.imagePaths.length} 张化验单',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecordEditScreen(record: record),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () {
                              _confirmDelete(context, recordsProv, record.id);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, RecordsProvider prov, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条复查记录吗？删除后不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              prov.deleteRecord(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
