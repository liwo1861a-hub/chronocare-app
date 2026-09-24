import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../models/record.dart';
import '../models/check_item.dart';
import '../services/ai_service.dart';
import 'record_edit_screen.dart';
import 'photo_gallery_viewer.dart';

class RecordDetailScreen extends StatefulWidget {
  final String recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  bool _isSummarizingAdvice = false;
  int _selectedCategoryIndex = 0;
  bool _showOnlyCurrentCategoryImages = true;

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // 1. 按检查项目大类/单据分类进行分栏目聚合 (支持“全部指标”与单据分栏查看)
    final Map<String, List<CheckItem>> categorizedItems = {};
    for (var item in record.items) {
      final cat = item.category.trim().isNotEmpty ? item.category.trim() : '常规检验报告';
      categorizedItems.putIfAbsent(cat, () => []).add(item);
    }

    final categoryNames = [
      if (categorizedItems.length > 1) '全部指标',
      ...categorizedItems.keys,
    ];

    if (_selectedCategoryIndex >= categoryNames.length && categoryNames.isNotEmpty) {
      _selectedCategoryIndex = 0;
    }

    final currentCategory = categoryNames.isNotEmpty ? categoryNames[_selectedCategoryIndex] : '常规化验';
    final currentItems = (currentCategory == '全部指标') ? record.items : (categorizedItems[currentCategory] ?? []);

    // 2. 构建图片路径 -> 对应栏目名称映射 (用于左右滑动无缝联动切换)
    final Map<String, String> imageCategoryMap = {};
    for (var item in record.items) {
      if (item.sourceImagePath.isNotEmpty) {
        imageCategoryMap[item.sourceImagePath] = item.category.trim().isNotEmpty ? item.category.trim() : '常规检验';
      }
    }
    for (var imgPath in record.imagePaths) {
      if (!imageCategoryMap.containsKey(imgPath)) {
        imageCategoryMap[imgPath] = currentCategory;
      }
    }

    // 3. 收集当前栏目对应的化验单图片
    final List<String> currentCategoryImages = [];
    if (currentCategory == '全部指标') {
      currentCategoryImages.addAll(record.imagePaths);
    } else {
      for (var it in currentItems) {
        if (it.sourceImagePath.isNotEmpty && !currentCategoryImages.contains(it.sourceImagePath)) {
          currentCategoryImages.add(it.sourceImagePath);
        }
      }
    }
    if (currentCategoryImages.isEmpty && record.imagePaths.isNotEmpty) {
      if (categoryNames.length == 1) {
        currentCategoryImages.addAll(record.imagePaths);
      }
    }

    final List<String> displayImages = _showOnlyCurrentCategoryImages
        ? currentCategoryImages
        : record.imagePaths;

    final abnormalCount = currentItems.where((i) => i.status != 'normal').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${DateFormat("yyyy-MM-dd").format(record.checkDate)} 复查档案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑整份档案',
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
                            '共 ${categoryNames.length} 个检验单栏目',
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.calendar_today, '开单检查日期', DateFormat('yyyy年MM月dd日').format(record.checkDate)),
                    if (record.nextCheckDate != null)
                      _buildInfoRow(Icons.alarm, '下次复查提醒', DateFormat('yyyy年MM月dd日').format(record.nextCheckDate!)),
                    _buildInfoRow(Icons.local_hospital, '就诊医院', record.hospital.isNotEmpty ? record.hospital : '未注明'),
                    _buildInfoRow(Icons.meeting_room, '科室/医生', '${record.department} ${record.doctorName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 医生医嘱
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
              color: isDark ? const Color(0xFF1E293B) : Colors.green.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.green.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: record.doctorAdvice.isNotEmpty
                    ? Text(record.doctorAdvice, style: const TextStyle(fontSize: 14, height: 1.5))
                    : const Text('暂无医生医嘱，点击上方【AI 总结医嘱】或右上角笔形图标单独添加', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),

            // 横向滑动选择检查栏目 (以整张单据为准，支持重命名与一键合并)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '检查报告单栏目 (横向滑动选择)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (categoryNames.length > 1)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.merge_type, size: 14, color: Colors.blueAccent),
                    label: const Text('合并栏目', style: TextStyle(fontSize: 12)),
                    onPressed: () => _mergeCategoryDialog(context, currentCategory, categoryNames, record, prov),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (categoryNames.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('暂无检查栏目或化验单', style: TextStyle(color: Colors.grey))),
                ),
              )
            else ...[
              // 横向选择栏目条
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryNames.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final catName = categoryNames[idx];
                    final isSelected = idx == _selectedCategoryIndex;
                    final count = (catName == '全部指标') ? record.items.length : (categorizedItems[catName]?.length ?? 0);
                    final hasAbnormal = (catName == '全部指标')
                        ? record.items.any((i) => i.status != 'normal')
                        : (categorizedItems[catName]?.any((i) => i.status != 'normal') ?? false);

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryIndex = idx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF0284C7) : Colors.blue.shade600)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? Colors.lightBlueAccent
                                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAbnormal)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF43F5E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            Text(
                              catName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // 当前选中栏目的详细内容面板
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF334155) : Colors.blue.withOpacity(0.25),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 栏目标题行：支持点击笔形图标重命名与合并
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.blue.withOpacity(0.15),
                                  child: const Icon(Icons.description, size: 16, color: Colors.blueAccent),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    currentCategory,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (currentCategory != '全部指标')
                                  IconButton(
                                    icon: const Icon(Icons.drive_file_rename_outline, size: 18, color: Colors.blueAccent),
                                    tooltip: '重命名此栏目名称',
                                    onPressed: () => _renameCategoryDialog(context, currentCategory, record, prov),
                                  ),
                              ],
                            ),
                          ),
                          if (abnormalCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                              ),
                              child: Text(
                                '$abnormalCount 项异常',
                                style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '全部正常',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20),

                      // 图片控制栏：切换“仅看本栏目对应图片”与“查看所有图片”
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showOnlyCurrentCategoryImages ? '📷 对应化验单原图 (${displayImages.length}张)' : '📷 本次复查所有化验单 (${displayImages.length}张)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            icon: Icon(
                              _showOnlyCurrentCategoryImages ? Icons.filter_alt_outlined : Icons.collections_outlined,
                              size: 14,
                            ),
                            label: Text(
                              _showOnlyCurrentCategoryImages ? '切换为看所有图片' : '切换为仅看对应图片',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              setState(() {
                                _showOnlyCurrentCategoryImages = !_showOnlyCurrentCategoryImages;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 缩略图区域：点击打开无黑边遮挡、支持左右滑动切换图片与栏目的全屏画廊
                      if (displayImages.isNotEmpty)
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: displayImages.length,
                            itemBuilder: (ctx, imgIdx) {
                              final imgPath = displayImages[imgIdx];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhotoGalleryViewer(
                                        imagePaths: record.imagePaths,
                                        initialIndex: record.imagePaths.indexOf(imgPath) >= 0
                                            ? record.imagePaths.indexOf(imgPath)
                                            : 0,
                                        imageCategoryMap: imageCategoryMap,
                                        onPageChanged: (newIdx, catName) {
                                          if (catName != null) {
                                            final cIdx = categoryNames.indexOf(catName);
                                            if (cIdx >= 0 && mounted) {
                                              setState(() => _selectedCategoryIndex = cIdx);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  width: 105,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                                    image: DecorationImage(image: FileImage(File(imgPath)), fit: BoxFit.cover),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('本栏目暂无单独绑定的原图 (可点击右上角切换为查看所有图片)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // 栏目下的检验指标结果表格
                      Text('📊 $currentCategory 检验指标 (${currentItems.length}项)：', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 6),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentItems.length,
                        separatorBuilder: (c, i) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                        itemBuilder: (c, itemIdx) {
                          final item = currentItems[itemIdx];
                          return _buildCheckItemRow(item, isDark);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                  separatorBuilder: (c, i) => const Divider(height: 1),
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

  Widget _buildCheckItemRow(CheckItem item, bool isDark) {
    final isAbnormal = item.status != 'normal';
    final refText = item.referenceRange.isNotEmpty ? item.referenceRange : '未注明';
    final noteText = item.notes.isNotEmpty ? ' · ${item.notes}' : '';
    final arrow = isAbnormal ? (item.status == 'high' ? ' ↑' : ' ↓') : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '参考值: $refText$noteText',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAbnormal
                      ? (isDark ? const Color(0xFF881337).withOpacity(0.5) : Colors.red.shade50)
                      : (isDark ? const Color(0xFF1E3A5F).withOpacity(0.5) : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAbnormal ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  '${item.value} ${item.unit}$arrow',
                  style: TextStyle(
                    color: isAbnormal
                        ? (isDark ? const Color(0xFFFDA4AF) : Colors.red.shade700)
                        : (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade800),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
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

  void _renameCategoryDialog(BuildContext context, String oldCategory, CheckRecord record, RecordsProvider prov) {
    final ctrl = TextEditingController(text: oldCategory);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名报告单栏目'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '栏目名称',
            hintText: '例如：血液生化全套、血常规报告、尿常规分析',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != oldCategory) {
                for (var item in record.items) {
                  if (item.category.trim() == oldCategory) {
                    item.category = newName;
                  }
                }
                await prov.saveRecord(record);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _mergeCategoryDialog(BuildContext context, String currentCategory, List<String> allCategories, CheckRecord record, RecordsProvider prov) {
    final otherCategories = allCategories.where((c) => c != currentCategory).toList();
    if (otherCategories.isEmpty) return;

    String targetCategory = otherCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('合并检查单栏目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将当前栏目【$currentCategory】内的所有检查指标合并并入到：', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetCategory,
                decoration: const InputDecoration(labelText: '目标报告单栏目', border: OutlineInputBorder()),
                items: otherCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => targetCategory = val);
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text('合并后，两者的指标将完整合并归入同一个大栏目下，方便统一查看。', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                await prov.mergeCategoriesInRecord(record.id, currentCategory, targetCategory);
                Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _selectedCategoryIndex = 0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ 已将【$currentCategory】成功合并至【$targetCategory】！')),
                  );
                }
              },
              child: const Text('确认合并'),
            ),
          ],
        ),
      ),
    );
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
