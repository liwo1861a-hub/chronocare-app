import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../models/record.dart';
import 'record_detail_screen.dart';
import 'record_edit_screen.dart';

class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  final Set<String> _expandedRecordIds = {};

  @override
  Widget build(BuildContext context) {
    final recordsProv = Provider.of<RecordsProvider>(context);
    final settingsProv = Provider.of<SettingsProvider>(context);
    final settings = settingsProv.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          elevation: isDark ? 0 : 1.5,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              width: 1,
            ),
          ),
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
                          const Icon(Icons.calendar_today, size: 15, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(record.checkDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (disease != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(int.parse(disease.colorHex.replaceFirst('#', '0xFF')))
                                .withOpacity(isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(int.parse(disease.colorHex.replaceFirst('#', '0xFF')))
                                  .withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            disease.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : Color(int.parse(disease.colorHex.replaceFirst('#', '0xFF'))),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 医院与科室
                  Row(
                    children: [
                      Icon(Icons.local_hospital_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${record.hospital.isNotEmpty ? record.hospital : "未填写医院"} · ${record.department.isNotEmpty ? record.department : "门诊"}',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.category,
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 18, color: isDark ? const Color(0xFF334155) : null),

                  // 检验指标展示 (支持全量展开与异常指标优先高亮，绝不隐匿指标)
                  if (record.items.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final isExpanded = _expandedRecordIds.contains(record.id);
                        final abnormalItems = record.items.where((i) => i.status != 'normal').toList();
                        final normalItems = record.items.where((i) => i.status == 'normal').toList();

                        // 未展开时优先展示所有异常项 + 部分正常项 (最多 8 项)
                        final List<dynamic> displayItems = isExpanded
                            ? record.items
                            : (abnormalItems.length >= 8
                                ? abnormalItems.take(8).toList()
                                : [...abnormalItems, ...normalItems.take(8 - abnormalItems.length)]);

                        final hasMore = record.items.length > displayItems.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '📊 检验指标 (${record.items.length}项)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (abnormalItems.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${abnormalItems.length}项异常',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '全部正常',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...displayItems.map((item) {
                                  final isAbnormal = item.status != 'normal';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAbnormal
                                          ? (isDark ? const Color(0xFF881337).withOpacity(0.4) : Colors.red.shade50)
                                          : (isDark ? const Color(0xFF1E3A5F).withOpacity(0.4) : Colors.blue.shade50.withOpacity(0.5)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isAbnormal
                                            ? (isDark ? const Color(0xFFF43F5E) : Colors.red.shade200)
                                            : (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade100),
                                      ),
                                    ),
                                    child: Text(
                                      '${item.itemName}: ${item.value} ${item.unit} ${isAbnormal ? (item.status == "high" ? "↑" : (item.status == "low" ? "↓" : "异常")) : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isAbnormal
                                            ? (isDark ? const Color(0xFFFDA4AF) : Colors.red.shade700)
                                            : (isDark ? const Color(0xFFBAE6FD) : Colors.black87),
                                        fontWeight: isAbnormal ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }),
                                if (hasMore && !isExpanded)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _expandedRecordIds.add(record.id));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        '+ 展开其余 ${record.items.length - displayItems.length} 项指标 ▾',
                                        style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                if (isExpanded && record.items.length > 8)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _expandedRecordIds.remove(record.id));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '收起部分指标 ▴',
                                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 医生医嘱摘要
                  if (record.doctorAdvice.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '医嘱: ${record.doctorAdvice}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFE2E8F0) : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 底部操作区（化验单原图角标与快速编辑）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (record.imagePaths.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.image, size: 13, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                            Text(
                              '${record.imagePaths.length} 张化验单原图',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
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
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF43F5E)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
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
