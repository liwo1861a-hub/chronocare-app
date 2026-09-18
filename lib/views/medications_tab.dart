import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medication_plan.dart';
import '../providers/records_provider.dart';

class MedicationsTab extends StatefulWidget {
  const MedicationsTab({super.key});

  @override
  State<MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<MedicationsTab> {
  String _selectedDiseaseFilter = '';

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = prov.getMedicationComparisonGroups(diseaseId: _selectedDiseaseFilter);

    return Scaffold(
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication_outlined, size: 68, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  const Text('暂无用药记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('点击右下角按钮添加当前服用的慢病药物与调药记录', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showEditMedicationDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('录入第一条用药记录'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final dateStr = DateFormat('yyyy年MM月dd日').format(group.date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部调药/就诊日期指示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '共 ${group.items.length} 种用药',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // 用药明细列表与【与上一次复查用药智能比对】
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: group.items.length,
                          separatorBuilder: (c, i) => const Divider(height: 16),
                          itemBuilder: (context, itemIdx) {
                            final itemWithDiff = group.items[itemIdx];
                            final plan = itemWithDiff.plan;
                            final diffTag = itemWithDiff.diffTag;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: diffTag.contains('新开')
                                      ? Colors.green.withOpacity(0.15)
                                      : (diffTag.contains('调整')
                                          ? Colors.orange.withOpacity(0.15)
                                          : (diffTag.contains('停用') ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15))),
                                  child: Icon(
                                    Icons.medication,
                                    size: 18,
                                    color: diffTag.contains('新开')
                                        ? const Color(0xFF10B981)
                                        : (diffTag.contains('调整')
                                            ? Colors.orange
                                            : (diffTag.contains('停用') ? const Color(0xFFF43F5E) : Colors.blueAccent)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            plan.medicineName,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                                onPressed: () => _showEditMedicationDialog(context, plan),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                                onPressed: () => _confirmDeleteMedication(context, plan),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '剂量: ${plan.dosage.isNotEmpty ? plan.dosage : "未注明"}   |   频次: ${plan.frequency.isNotEmpty ? plan.frequency : "未注明"}',
                                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                      ),
                                      const SizedBox(height: 6),
                                      // 醒目的与前一次比对变动标签
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: diffTag.contains('新开')
                                              ? Colors.green.withOpacity(0.12)
                                              : (diffTag.contains('调整')
                                                  ? Colors.orange.withOpacity(0.12)
                                                  : (diffTag.contains('停用') ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.1))),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '对比上次: $diffTag',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: diffTag.contains('新开')
                                                ? const Color(0xFF10B981)
                                                : (diffTag.contains('调整')
                                                    ? Colors.orange.shade700
                                                    : (diffTag.contains('停用') ? const Color(0xFFF43F5E) : Colors.blueAccent)),
                                          ),
                                        ),
                                      ),
                                      if (plan.reason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('调药原因: ${plan.reason}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                                      ],
                                      if (plan.notes.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text('备注: ${plan.notes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditMedicationDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('新增用药记录'),
      ),
    );
  }

  void _showEditMedicationDialog(BuildContext context, MedicationPlan? existing) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    final isEdit = existing != null;

    DateTime chosenDate = existing?.date ?? DateTime.now();
    final nameCtrl = TextEditingController(text: existing?.medicineName ?? '');
    final dosageCtrl = TextEditingController(text: existing?.dosage ?? '');
    final freqCtrl = TextEditingController(text: existing?.frequency ?? '');
    final reasonCtrl = TextEditingController(text: existing?.reason ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String chosenDiseaseId = existing?.diseaseId ?? (prov.diseases.isNotEmpty ? prov.diseases.first.id : '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑用药方案' : '新增药物记录'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择调药/复查日期
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      title: const Text('执行/调药日期', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(chosenDate),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: chosenDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => chosenDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '药品名称 *',
                        hintText: '如: 二甲双胍缓释片、苯溴马隆',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dosageCtrl,
                            decoration: const InputDecoration(
                              labelText: '单次剂量',
                              hintText: '如: 0.5g / 1片',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: freqCtrl,
                            decoration: const InputDecoration(
                              labelText: '服用频次',
                              hintText: '如: 每日2次 随餐',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: '调药原因 / 医嘱说明',
                        hintText: '如: 糖化血红蛋白偏高，遵医嘱加量',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: '注意事项 / 备注',
                        hintText: '如: 饭后服用，服药期间多喝水',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入药品名称')),
                      );
                      return;
                    }

                    final newPlan = MedicationPlan(
                      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      diseaseId: chosenDiseaseId,
                      date: chosenDate,
                      medicineName: name,
                      dosage: dosageCtrl.text.trim(),
                      frequency: freqCtrl.text.trim(),
                      reason: reasonCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );

                    await prov.saveMedicationPlan(newPlan);
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? '用药记录已更新' : '已添加用药记录')),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMedication(BuildContext context, MedicationPlan plan) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除该用药记录？'),
        content: Text('删除后不可恢复：${plan.medicineName} (${DateFormat("yyyy-MM-dd").format(plan.date)})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await prov.deleteMedicationPlan(plan.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
