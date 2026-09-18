import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/records_provider.dart';
import '../models/category_group.dart';
import 'record_detail_screen.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final allOcrItems = prov.getAllItemNames();
    final groups = prov.categoryGroups;

    // 找出所有未被分配到任何自定义组的 OCR 项目
    final Set<String> assignedItems = {};
    for (var g in groups) {
      assignedItems.addAll(g.matchedItemNames);
    }
    final unassignedItems = allOcrItems.where((name) => !assignedItems.contains(name)).toList();

    if (allOcrItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('暂无 OCR 检查项目', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('上传化验单并通过智能 OCR 整理后，项目将自动归类显示在此', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 顶部操作提示栏与新建整合分类按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OCR 识别项目 (共 ${allOcrItems.length} 项)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.create_new_folder, size: 16),
                label: const Text('新建整合分类'),
                onPressed: () => _showCreateGroupDialog(context, prov, null),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. 自定义整合分类列表
          if (groups.isNotEmpty) ...[
            ...groups.map((group) {
              final groupItems = group.matchedItemNames;
              final color = Color(int.parse(group.colorHex.replaceFirst('#', '0xFF')));

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: color.withOpacity(0.4), width: 1.2),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.folder_special, color: color),
                  ),
                  title: Row(
                    children: [
                      Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '整合 ${groupItems.length} 项',
                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: () => _showCreateGroupDialog(context, prov, group),
                      ),
                    ],
                  ),
                  children: [
                    if (groupItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('此分类暂未添加项目，可在下方项目点击【移入】', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    else
                      ...groupItems.map((itemName) => _buildItemTile(context, prov, itemName, currentGroupId: group.id)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          // 2. OCR 独立项目列表（名字直接取自 OCR 提取的项目名）
          if (unassignedItems.isNotEmpty) ...[
            const Text(
              '独立检查项目 (按 OCR 名称命名)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...unassignedItems.map((itemName) => _buildItemTile(context, prov, itemName)),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, RecordsProvider prov, String itemName, {String? currentGroupId}) {
    final history = prov.getMetricHistory(itemName);
    final lastPoint = history.isNotEmpty ? history.last : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.biotech, color: Colors.blueAccent, size: 20),
        ),
        title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          lastPoint != null
              ? '最新值: ${lastPoint.valueStr} ${lastPoint.unit} (${history.length}次历史记录)'
              : '共 ${history.length} 次记录',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.drive_file_move_outlined, size: 18, color: Colors.indigo),
              tooltip: '移动/整合到分类',
              onPressed: () => _showMoveItemDialog(context, prov, itemName),
            ),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
        onTap: () {
          if (lastPoint != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordDetailScreen(recordId: lastPoint.recordId),
              ),
            );
          }
        },
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, RecordsProvider prov, CategoryGroup? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedColor = existing?.colorHex ?? '#2563EB';
    final colors = ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#06B6D4'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing == null ? '新建自定义整合分类' : '编辑整合分类'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '分类名称 *',
                    hintText: '如：肝功能全套、肾病专项、糖脂监测',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('主题颜色', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    prov.deleteCategoryGroup(existing.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('删除分类', style: TextStyle(color: Colors.red)),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final group = CategoryGroup(
                    id: existing?.id ?? const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    colorHex: selectedColor,
                    matchedItemNames: existing?.matchedItemNames,
                  );
                  prov.saveCategoryGroup(group);
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

  void _showMoveItemDialog(BuildContext context, RecordsProvider prov, String itemName) {
    final groups = prov.categoryGroups;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('移动/整合 [$itemName]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择目标整合分类：', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('移出所有分类 (独立显示)'),
              onTap: () {
                prov.moveItemToGroup(itemName, '');
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('暂无自定义分类，请先点击【新建整合分类】', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ...groups.map((g) {
                final isCurrent = g.matchedItemNames.contains(itemName);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_special, color: Colors.blueAccent),
                  title: Text(g.name),
                  trailing: isCurrent ? const Icon(Icons.check, color: Colors.green, size: 18) : null,
                  onTap: () {
                    prov.moveItemToGroup(itemName, g.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }
}
