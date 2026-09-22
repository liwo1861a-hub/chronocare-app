import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/medication_plan.dart';
import '../providers/records_provider.dart';

class MedicationsTab extends StatefulWidget {
  const MedicationsTab({super.key});

  @override
  State<MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<MedicationsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedDiseaseFilter = '';
  bool _isFabExpanded = true; // 控制新增按钮是否展开或侧边紧凑折叠
  bool _isOverviewExpanded = true; // 控制顶部最新完整用药记录卡片是否展开

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drugTimelines = prov.getAggregatedMedicationTimelines(
      searchQuery: _searchQuery,
      diseaseId: _selectedDiseaseFilter,
    );

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // 1. 顶部药品搜索栏
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '搜索药品名称、调药原因、注意事项...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
              ),

              // 2. 核心内容区：顶部【最新完整用药总览记录】+ 下方【单药剂量演变趋势卡片】
              Expanded(
                child: drugTimelines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medication_outlined, size: 68, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            const Text('暂无慢病用药记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('录入药物后，系统将自动汇总同种药品的全部剂量变动并绘制走势图', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showEditMedicationDialog(context, null, null),
                              icon: const Icon(Icons.add),
                              label: const Text('录入第一种慢病用药'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80), // 底部预留空间
                        itemCount: drugTimelines.length + 1, // index 0 为顶部最新完整用药总览
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildLatestCompleteMedicationOverviewCard(context, drugTimelines, isDark, prov);
                          }
                          final drug = drugTimelines[index - 1];
                          return _buildDrugAggregateCard(context, drug, isDark, prov);
                        },
                      ),
              ),
            ],
          ),

          // 3. 右下侧【可侧边折叠/吸附隐藏的灵动新增悬浮按钮】
          Positioned(
            right: 12,
            bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 侧边折叠/展开小箭头手柄
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFabExpanded = !_isFabExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155).withOpacity(0.8) : Colors.grey.shade300.withOpacity(0.85),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      _isFabExpanded ? Icons.chevron_right : Icons.chevron_left,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                // 主悬浮按钮
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  child: _isFabExpanded
                      ? FloatingActionButton.extended(
                          heroTag: 'med_add_fab_expanded',
                          elevation: 3,
                          onPressed: () => _showEditMedicationDialog(context, null, null),
                          icon: const Icon(Icons.add),
                          label: const Text('新增药品档案'),
                        )
                      : FloatingActionButton.small(
                          heroTag: 'med_add_fab_collapsed',
                          elevation: 3,
                          tooltip: '新增药品档案',
                          onPressed: () => _showEditMedicationDialog(context, null, null),
                          child: const Icon(Icons.add),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🌟 顶部核心模块：最新药物完整记录总览卡片 (当前全部在服处方方案清单)
  Widget _buildLatestCompleteMedicationOverviewCard(
    BuildContext context,
    List<MedicationDrugTimeline> drugTimelines,
    bool isDark,
    RecordsProvider prov,
  ) {
    final activeDrugs = drugTimelines.where((d) => d.currentStatus != 'stopped').toList();
    final stoppedDrugs = drugTimelines.where((d) => d.currentStatus == 'stopped').toList();

    DateTime? latestUpdateDate;
    for (var d in drugTimelines) {
      if (latestUpdateDate == null || d.latestDate.isAfter(latestUpdateDate)) {
        latestUpdateDate = d.latestDate;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.blueAccent.withOpacity(0.3), width: 1.2),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFFF0F9FF),
                        Colors.white,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部标题栏 + 徽章 + 操作工具
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.blueAccent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '最新在服药物完整记录',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (latestUpdateDate != null)
                              Text(
                                '最新方案调整: ${DateFormat("yyyy-MM-dd").format(latestUpdateDate)}',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // 一键复制完整方案
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 19, color: Colors.blueAccent),
                          tooltip: '复制当前完整用药方案',
                          onPressed: () => _copyMedicationRegimen(context, activeDrugs, latestUpdateDate),
                        ),
                        // 折叠/展开按钮
                        IconButton(
                          icon: Icon(_isOverviewExpanded ? Icons.expand_less : Icons.expand_more, size: 22),
                          tooltip: _isOverviewExpanded ? '折叠总览' : '展开总览',
                          onPressed: () {
                            setState(() {
                              _isOverviewExpanded = !_isOverviewExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // 方案统计栏
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            '正在服用: ${activeDrugs.length} 种',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    if (stoppedDrugs.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '已停用: ${stoppedDrugs.length} 种',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ],
                ),

                // 缺药预警提醒通知
                if (prov.shortageCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '药箱预警：有 ${prov.shortageCount} 种药品存量即将不足，请切换至【药箱存量】查看！',
                            style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 展开的完整处方清单列表
                if (_isOverviewExpanded) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  if (activeDrugs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '目前暂无正在服用的药物（已录入药物均处于停药状态）',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeDrugs.length,
                      separatorBuilder: (c, i) => Divider(height: 16, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                      itemBuilder: (context, idx) {
                        final drug = activeDrugs[idx];
                        final latestPoint = drug.historyPoints.isNotEmpty ? drug.historyPoints.last : null;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        drug.medicineName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      if (drug.diseaseName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            drug.diseaseName,
                                            style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.withOpacity(0.15)),
                                    ),
                                    child: Text(
                                      '${drug.latestDosage.isNotEmpty ? drug.latestDosage : "未注明剂量"}   ·   ${drug.latestFrequency.isNotEmpty ? drug.latestFrequency : "未注明频次"}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                  if (latestPoint != null && latestPoint.reason.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      '医嘱/原因: ${latestPoint.reason}',
                                      style: const TextStyle(fontSize: 11, color: Colors.amber),
                                    ),
                                  ],
                                  if (latestPoint != null && latestPoint.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '注意事项: ${latestPoint.notes}',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),

        // 分割标题：各药品长期历史与走势图
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Text(
                    '分项药品调药档案与走势图 (${drugTimelines.length}项)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '单药长程剂量演变',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 一键复制完整用药方案 (方便门诊出示或家属留档)
  void _copyMedicationRegimen(BuildContext context, List<MedicationDrugTimeline> activeDrugs, DateTime? latestDate) {
    if (activeDrugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前暂无正在服用的药物方案')),
      );
      return;
    }

    final sb = StringBuffer();
    sb.writeln('【脉络健康 · 最新慢病在服药物方案清单】');
    if (latestDate != null) {
      sb.writeln('最新调整日期: ${DateFormat("yyyy-MM-dd").format(latestDate)}');
    }
    sb.writeln('----------------------------------------');

    for (int i = 0; i < activeDrugs.length; i++) {
      final drug = activeDrugs[i];
      sb.writeln('${i + 1}. ${drug.medicineName}${drug.diseaseName.isNotEmpty ? " [${drug.diseaseName}]" : ""}');
      sb.writeln('   • 执行剂量: ${drug.latestDosage.isNotEmpty ? drug.latestDosage : "未注明"}');
      sb.writeln('   • 服用频次: ${drug.latestFrequency.isNotEmpty ? drug.latestFrequency : "未注明"}');
      final latestPoint = drug.historyPoints.isNotEmpty ? drug.historyPoints.last : null;
      if (latestPoint != null && latestPoint.reason.isNotEmpty) {
        sb.writeln('   • 调药医嘱: ${latestPoint.reason}');
      }
      if (latestPoint != null && latestPoint.notes.isNotEmpty) {
        sb.writeln('   • 注意事项: ${latestPoint.notes}');
      }
      if (i < activeDrugs.length - 1) sb.writeln();
    }

    sb.writeln('----------------------------------------');
    sb.writeln('当前在服共计: ${activeDrugs.length} 种药物');

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 已复制最新完整用药方案清单，可直接发给医生或家属！'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 构建同一种药物的整合卡片
  Widget _buildDrugAggregateCard(
    BuildContext context,
    MedicationDrugTimeline drug,
    bool isDark,
    RecordsProvider prov,
  ) {
    final bool isStopped = drug.currentStatus == 'stopped';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：药品名称 + 状态徽章 + 快捷新增调药按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isStopped ? Colors.grey.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.15),
                      child: Icon(
                        Icons.medication,
                        size: 20,
                        color: isStopped ? Colors.grey : Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug.medicineName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        if (drug.diseaseName.isNotEmpty)
                          Text(
                            '关联档案: ${drug.diseaseName}',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStopped ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isStopped ? '已停用' : '正在服用',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isStopped ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 一键记录本次调药快捷按钮
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.tune, size: 14),
                      label: const Text('记录调药', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showEditMedicationDialog(context, null, drug.medicineName),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 当前最新方案卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前最新执行方案：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(
                        '${drug.latestDosage.isNotEmpty ? drug.latestDosage : "未注明剂量"}  ·  ${drug.latestFrequency.isNotEmpty ? drug.latestFrequency : "未注明频次"}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    '历经 ${drug.historyPoints.length} 次调药',
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent.shade200, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 📈 剂量演变趋势图
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    const Text('剂量演变趋势图', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  '单位: ${drug.historyPoints.first.unit.isNotEmpty ? drug.historyPoints.first.unit : "实测剂量"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 160,
              padding: const EdgeInsets.only(top: 14, right: 16, left: 4, bottom: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              ),
              child: _buildDosageChart(drug.historyPoints, isDark),
            ),
            const SizedBox(height: 16),

            // 历次调药时间线与前后对比 (每一项均支持编辑与删除)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('调药演变历史记录：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  '点击右侧按钮可修改记录',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: drug.historyPoints.length,
              separatorBuilder: (c, i) => Divider(height: 16, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              itemBuilder: (context, pIdx) {
                // 倒序展示：最新调药排在最上方
                final point = drug.historyPoints[drug.historyPoints.length - 1 - pIdx];
                final dateStr = DateFormat('yyyy年MM月dd日').format(point.date);
                final isIncrease = point.diffFromPrevious.contains('加量') || point.diffFromPrevious.contains('+');
                final isDecrease = point.diffFromPrevious.contains('减量') || point.diffFromPrevious.contains('-');
                final isStop = point.diffFromPrevious.contains('停药');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: isIncrease
                            ? Colors.orange
                            : (isDecrease ? Colors.teal : (isStop ? Colors.red : Colors.blueAccent)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isIncrease
                                      ? Colors.orange.withOpacity(0.12)
                                      : (isDecrease
                                          ? Colors.teal.withOpacity(0.12)
                                          : (isStop ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.1))),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  point.diffFromPrevious,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isIncrease
                                        ? Colors.orange.shade800
                                        : (isDecrease ? Colors.teal.shade700 : (isStop ? const Color(0xFFF43F5E) : Colors.blueAccent)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '执行剂量: ${point.dosageStr}   |   频次: ${point.frequency}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                          ),
                          if (point.reason.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('调药原因: ${point.reason}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                          ],
                          if (point.notes.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text('注意事项: ${point.notes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                    // ✏️ 修改此条记录按钮
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 20, color: Colors.blueAccent),
                      tooltip: '修改此条调药记录',
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final rawPlan = prov.medicationPlans.firstWhere(
                          (p) => p.id == point.id,
                          orElse: () => MedicationPlan(
                            id: point.id,
                            diseaseId: drug.diseaseId,
                            date: point.date,
                            medicineName: drug.medicineName,
                            dosage: point.dosageStr,
                            frequency: point.frequency,
                            reason: point.reason,
                            notes: point.notes,
                            changeType: point.changeType,
                          ),
                        );
                        _showEditMedicationDialog(context, rawPlan, null);
                      },
                    ),
                    const SizedBox(width: 6),
                    // 🗑️ 删除此条记录按钮
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                      tooltip: '删除此记录',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeletePlan(context, point.id, drug.medicineName, point.date),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDosageChart(List<MedicationAdjustmentPoint> history, bool isDark) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].numericDosage));
    }

    final values = history.map((e) => e.numericDosage).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);

    if (minY == maxY) {
      minY = minY * 0.5 > 0 ? minY * 0.5 : 0;
      maxY = maxY * 1.5;
    } else {
      final pad = (maxY - minY) * 0.2;
      minY = (minY - pad) > 0 ? (minY - pad) : 0;
      maxY = maxY + pad;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble() > 0 ? (history.length - 1).toDouble() : 1,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3 > 0 ? (maxY - minY) / 3 : 1,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (val, meta) => Text(
                val.toStringAsFixed(1),
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < history.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('MM/dd').format(history[idx].date),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            isStepLineChart: true,
            color: const Color(0xFF38BDF8),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: const Color(0xFF0284C7),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF38BDF8).withOpacity(0.3),
                  const Color(0xFF38BDF8).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 智能微调剂量数值辅助方法 (支持 +0.25, -0.25, +0.5, -0.5, +半片 等)
  void _adjustDosageValue(TextEditingController ctrl, double delta, {String? defaultUnit}) {
    final text = ctrl.text.trim();
    final match = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(text);
    if (match != null) {
      final curVal = double.tryParse(match.group(0)!) ?? 1.0;
      final unit = text.replaceAll(match.group(0)!, '').trim();
      final newVal = curVal + delta;
      if (newVal > 0) {
        String formatted = newVal.toStringAsFixed(2);
        if (formatted.endsWith('00')) {
          formatted = formatted.substring(0, formatted.length - 3);
        } else if (formatted.endsWith('0')) {
          formatted = formatted.substring(0, formatted.length - 1);
        }
        ctrl.text = '$formatted$unit';
      }
    } else {
      final unit = defaultUnit ?? (text.isNotEmpty ? text : '片');
      final val = (1.0 + delta) > 0 ? (1.0 + delta) : 0.5;
      String formatted = val.toStringAsFixed(2);
      if (formatted.endsWith('00')) {
        formatted = formatted.substring(0, formatted.length - 3);
      } else if (formatted.endsWith('0')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
      ctrl.text = '$formatted$unit';
    }
  }

  void _showEditMedicationDialog(BuildContext context, MedicationPlan? existing, String? prefilledName) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    final isEdit = existing != null;
    final allTimelines = prov.getAggregatedMedicationTimelines();

    // 智能查找上一次的记录方案作为微调基准
    MedicationPlan? lastPlan;
    if (existing != null) {
      lastPlan = existing;
    } else if (prefilledName != null && prefilledName.isNotEmpty) {
      final matching = prov.medicationPlans.where((p) => p.medicineName.trim() == prefilledName.trim()).toList();
      matching.sort((a, b) => b.date.compareTo(a.date));
      if (matching.isNotEmpty) lastPlan = matching.first;
    } else if (allTimelines.isNotEmpty) {
      // 若是全局新增且存在历史药品，优先默认预备第一个药品供参考
      final matching = prov.medicationPlans.where((p) => p.medicineName.trim() == allTimelines.first.medicineName.trim()).toList();
      matching.sort((a, b) => b.date.compareTo(a.date));
      if (matching.isNotEmpty) lastPlan = matching.first;
    }

    DateTime chosenDate = existing?.date ?? DateTime.now();
    final nameCtrl = TextEditingController(text: existing?.medicineName ?? lastPlan?.medicineName ?? prefilledName ?? '');
    final dosageCtrl = TextEditingController(text: existing?.dosage ?? lastPlan?.dosage ?? '');
    final freqCtrl = TextEditingController(text: existing?.frequency ?? lastPlan?.frequency ?? '');
    final reasonCtrl = TextEditingController(text: existing?.reason ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? lastPlan?.notes ?? '');
    String chosenDiseaseId = existing?.diseaseId ?? lastPlan?.diseaseId ?? (prov.diseases.isNotEmpty ? prov.diseases.first.id : '');
    String chosenStatus = existing?.status ?? lastPlan?.status ?? 'active';

    String loadedSourceTip = lastPlan != null && !isEdit
        ? '已根据【${lastPlan.medicineName}】上一次方案载入 (${lastPlan.dosage.isNotEmpty ? lastPlan.dosage : "未注明"} · ${lastPlan.frequency.isNotEmpty ? lastPlan.frequency : "未注明"})，可直接微调'
        : '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? '修改调药记录' : (prefilledName != null ? '记录【$prefilledName】新剂量' : '新增药品与方案')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 上一次记录方案自动带入提示
                    if (loadedSourceTip.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                loadedSourceTip,
                                style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 2. 快速从已有药品一键切换载入并微调
                    if (!isEdit && allTimelines.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.history_toggle_off, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text('载入已有药品微调：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: allTimelines.map((drug) {
                                  final isCurrent = nameCtrl.text.trim() == drug.medicineName;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                      backgroundColor: isCurrent ? Colors.blueAccent.withOpacity(0.2) : null,
                                      avatar: Icon(Icons.medication, size: 13, color: isCurrent ? Colors.blueAccent : Colors.grey),
                                      label: Text(
                                        '${drug.medicineName} (${drug.latestDosage})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isCurrent ? Colors.blueAccent : null,
                                          fontWeight: isCurrent ? FontWeight.bold : null,
                                        ),
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          nameCtrl.text = drug.medicineName;
                                          dosageCtrl.text = drug.latestDosage;
                                          freqCtrl.text = drug.latestFrequency;
                                          chosenDiseaseId = drug.diseaseId;
                                          chosenStatus = drug.currentStatus;
                                          loadedSourceTip = '已根据【${drug.medicineName}】上一次方案载入，可直接微调';
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      title: const Text('调药/生效日期', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                        labelText: '药品通用名 *',
                        hintText: '如: 二甲双胍片、苯溴马隆',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 剂量与频次输入行
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dosageCtrl,
                            decoration: const InputDecoration(
                              labelText: '单次剂量 (含单位)',
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
                    const SizedBox(height: 8),

                    // 3. 剂量微调快捷步进按钮 (一键增减)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.tune, size: 13, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          const Text('剂量微调: ', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('-0.25', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, -0.25)),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('+0.25', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, 0.25)),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('-0.5', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, -0.5)),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('+0.5', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, 0.5)),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('-半片', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, -0.5, defaultUnit: '片')),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('+半片', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, 0.5, defaultUnit: '片')),
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: const Text('+1片', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => _adjustDosageValue(dosageCtrl, 1.0, defaultUnit: '片')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 4. 常用服用频次快捷微调标签
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 13, color: Colors.teal),
                          const SizedBox(width: 4),
                          const Text('频次快选: ', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
                          ...['每日1次', '每日2次', '每日3次', '随餐服用', '饭前', '饭后', '早晨空腹', '睡前'].map((freq) => Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                              label: Text(freq, style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                setDialogState(() {
                                  if (freqCtrl.text.isEmpty) {
                                    freqCtrl.text = freq;
                                  } else if (!freqCtrl.text.contains(freq)) {
                                    freqCtrl.text = '${freqCtrl.text} $freq';
                                  } else {
                                    freqCtrl.text = freq;
                                  }
                                });
                              },
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: '调药原因 / 医生医嘱',
                        hintText: '如: 空腹血糖偏高，遵医嘱加量至0.5g',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 5. 常用调药原因快选
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.tips_and_updates_outlined, size: 13, color: Colors.amber),
                          const SizedBox(width: 4),
                          const Text('原因预设: ', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600)),
                          ...['指标偏高加量', '控制平稳维持', '指标达标减量', '遵医嘱开始服药', '遵医嘱停药'].map((r) => Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                              label: Text(r, style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                setDialogState(() {
                                  reasonCtrl.text = r;
                                });
                              },
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: '注意事项 / 备注',
                        hintText: '如: 饭后服用，服药期间注意多喝水',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text('服药状态：', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('正在服用'),
                          selected: chosenStatus == 'active',
                          onSelected: (val) {
                            if (val) setDialogState(() => chosenStatus = 'active');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('已停药'),
                          selected: chosenStatus == 'stopped',
                          onSelected: (val) {
                            if (val) setDialogState(() => chosenStatus = 'stopped');
                          },
                        ),
                      ],
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
                        const SnackBar(content: Text('请输入药品通用名')),
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
                      status: chosenStatus,
                      notes: notesCtrl.text.trim(),
                    );

                    await prov.saveMedicationPlan(newPlan);
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? '调药记录已更新' : '已记录【$name】用药方案')),
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

  void _confirmDeletePlan(BuildContext context, String planId, String medName, DateTime date) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除该条调药记录？'),
        content: Text('将删除 $medName 在 ${DateFormat("yyyy-MM-dd").format(date)} 的调药记录。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await prov.deleteMedicationPlan(planId);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
