import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/consultation_question.dart';
import '../providers/records_provider.dart';

class QuestionsTab extends StatefulWidget {
  const QuestionsTab({super.key});

  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  String _selectedDiseaseFilter = '';

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = prov.getQuestionsGroupedByDate(diseaseId: _selectedDiseaseFilter);

    return Scaffold(
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_help_outlined, size: 68, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  const Text('暂无复查提问备忘', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('见医生前把想问的问题随手记下，现场逐条勾选并记录医嘱', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showEditQuestionDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('新增提问备忘'),
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
                final totalCount = group.questions.length;
                final askedCount = group.questions.where((q) => q.isAsked).length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部就诊日期与完成进度
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.event_note, color: Colors.purpleAccent, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: askedCount == totalCount
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '已提问 $askedCount / $totalCount 项',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: askedCount == totalCount ? const Color(0xFF10B981) : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // 本次复查的独立问题列表
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: group.questions.length,
                          separatorBuilder: (c, i) => const Divider(height: 14),
                          itemBuilder: (context, qIdx) {
                            final q = group.questions[qIdx];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 确定是否已提问复选框
                                    Checkbox(
                                      value: q.isAsked,
                                      activeColor: Colors.green,
                                      onChanged: (val) {
                                        prov.toggleQuestionAskedStatus(q.id);
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            q.question,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              decoration: q.isAsked ? TextDecoration.lineThrough : null,
                                              color: q.isAsked ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                          if (q.detail.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              '补充背景: ${q.detail}',
                                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                                            ),
                                          ],
                                          // 医生现场解答记录
                                          if (q.doctorAnswer.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.medical_services_outlined, size: 14, color: Colors.green),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '医生解答: ${q.doctorAnswer}',
                                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900, fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 20, color: Colors.grey),
                                      onPressed: () => _showEditQuestionDialog(context, q),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () => _confirmDeleteQuestion(context, q),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),

                        // 与上一次就诊日期的提问与医嘱解答对比展示
                        if (group.previousDateQuestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.history, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      '回顾前次复查提问 (${DateFormat("MM/dd").format(group.previousDateQuestions.first.targetDate)})：',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...group.previousDateQuestions.map((pq) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      '• ${pq.question} ${pq.doctorAnswer.isNotEmpty ? "➔ [解答: " + pq.doctorAnswer + "]" : ""}',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditQuestionDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('新增提问备忘'),
      ),
    );
  }

  void _showEditQuestionDialog(BuildContext context, ConsultationQuestion? existing) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    final isEdit = existing != null;

    DateTime chosenDate = existing?.targetDate ?? DateTime.now();
    final questionCtrl = TextEditingController(text: existing?.question ?? '');
    final detailCtrl = TextEditingController(text: existing?.detail ?? '');
    final answerCtrl = TextEditingController(text: existing?.doctorAnswer ?? '');
    bool isAsked = existing?.isAsked ?? false;
    String chosenDiseaseId = existing?.diseaseId ?? (prov.diseases.isNotEmpty ? prov.diseases.first.id : '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑提问备忘' : '新增复查提问'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择对应的就诊/复查日期
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.purpleAccent),
                      title: const Text('对应复查就诊日期', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                      controller: questionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '想向医生咨询的问题 *',
                        hintText: '如: 最近早晨空腹偶尔心慌，需要调药吗？',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: detailCtrl,
                      decoration: const InputDecoration(
                        labelText: '补充细节 / 症状背景',
                        hintText: '如: 近两周出现过3次，每次持续10分钟',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: answerCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '医生的现场解答与医嘱 (就诊后填写)',
                        hintText: '如: 医生建议查动态心电图，二甲双胍继续维持',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('已向医生提问 (勾选标记完成)'),
                      value: isAsked,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setDialogState(() => isAsked = val ?? false);
                      },
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
                    final qText = questionCtrl.text.trim();
                    if (qText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入问题内容')),
                      );
                      return;
                    }

                    final newQ = ConsultationQuestion(
                      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      diseaseId: chosenDiseaseId,
                      targetDate: chosenDate,
                      question: qText,
                      detail: detailCtrl.text.trim(),
                      doctorAnswer: answerCtrl.text.trim(),
                      isAsked: isAsked,
                    );

                    await prov.saveConsultationQuestion(newQ);
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? '提问备忘已更新' : '已添加提问备忘')),
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

  void _confirmDeleteQuestion(BuildContext context, ConsultationQuestion q) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除该提问？'),
        content: Text('删除后不可恢复：${q.question}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await prov.deleteConsultationQuestion(q.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
