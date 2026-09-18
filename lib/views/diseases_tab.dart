import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/records_provider.dart';
import '../models/disease.dart';
import 'record_detail_screen.dart';

class DiseasesTab extends StatelessWidget {
  const DiseasesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final diseases = prov.diseases;

    return Scaffold(
      body: diseases.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_special_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('暂无慢病档案，点击右下角添加'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: diseases.length,
              itemBuilder: (context, index) {
                final d = diseases[index];
                final records =
                    prov.records.where((r) => r.diseaseId == d.id).toList();
                final diseaseColor =
                    Color(int.parse(d.colorHex.replaceFirst('#', '0xFF')));

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: diseaseColor.withOpacity(0.4), width: 1.2),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: diseaseColor.withOpacity(0.15),
                      child: Icon(Icons.health_and_safety, color: diseaseColor),
                    ),
                    title: Row(
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            d.stage,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (d.targetNotes.isNotEmpty)
                          Text(
                            '控制目标: ${d.targetNotes}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        Text(
                          '共 ${records.length} 次复查记录',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showEditDiseaseDialog(context, prov, d),
                        ),
                      ],
                    ),
                    children: [
                      if (d.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 14, color: Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('备注: ${d.notes}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      if (records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('该疾病下暂无复查记录', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        )
                      else
                        ...records.map((r) => ListTile(
                              dense: true,
                              title: Text('${r.checkDate.toIso8601String().substring(0, 10)} - ${r.hospital} (${r.category})'),
                              subtitle: Text(
                                r.doctorAdvice.isNotEmpty ? '医嘱: ${r.doctorAdvice}' : '包含 ${r.items.length} 项检验',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecordDetailScreen(recordId: r.id),
                                  ),
                                );
                              },
                            )),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增疾病档案'),
        onPressed: () => _showEditDiseaseDialog(context, prov, null),
      ),
    );
  }

  void _showEditDiseaseDialog(BuildContext context, RecordsProvider prov, Disease? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final stageCtrl = TextEditingController(text: existing?.stage ?? '平稳期');
    final targetCtrl = TextEditingController(text: existing?.targetNotes ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String selectedColor = existing?.colorHex ?? '#2563EB';

    final colors = ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#06B6D4'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing == null ? '新增疾病档案' : '编辑疾病档案'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '疾病名称 *',
                      hintText: '如：2型糖尿病、高血压、桥本甲状腺炎',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stageCtrl,
                    decoration: const InputDecoration(
                      labelText: '当前病程阶段',
                      hintText: '如：平稳控制期、药物调整期、随访期',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: targetCtrl,
                    decoration: const InputDecoration(
                      labelText: '个人专属控制目标',
                      hintText: '如：空腹血糖<7.0，糖化<6.5%',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '病程重要备注',
                      hintText: '家族史、确诊时间、过敏史或核心关注点',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('标签主题色', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: colors.map((c) {
                      final isSelected = c == selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    prov.deleteDisease(existing.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('删除此疾病', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final d = Disease(
                    id: existing?.id ?? const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    stage: stageCtrl.text.trim(),
                    targetNotes: targetCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    colorHex: selectedColor,
                    createdAt: existing?.createdAt,
                  );
                  prov.addOrUpdateDisease(d);
                  Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
