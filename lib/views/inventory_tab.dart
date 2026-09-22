import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medication_inventory.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'shortage', 'sufficient'
  bool _isFabExpanded = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var list = prov.medicationInventories;
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) =>
        i.medicineName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        i.notes.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        i.packageSpec.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    final shortageList = list.where((i) => i.isShortage).toList();
    if (_filterType == 'shortage') {
      list = shortageList;
    } else if (_filterType == 'sufficient') {
      list = list.where((i) => !i.isShortage).toList();
    }

    final allShortageCount = prov.shortageCount;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // 1. 顶部缺药告急 / 存量充足醒目预警横幅
              _buildTopAlertBanner(context, prov, allShortageCount, isDark),

              // 2. 搜索与快捷操作栏
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: '搜索药品存量、规格、备注...',
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // AI 解析导入快捷入口按钮
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showAiTextParseBottomSheet(context),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('AI 识别入库', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 3. 过滤选项条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('全部 (${prov.medicationInventories.length})'),
                      selected: _filterType == 'all',
                      onSelected: (v) => setState(() => _filterType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('缺药预警 ($allShortageCount)', style: TextStyle(color: allShortageCount > 0 ? Colors.redAccent : null)),
                      selected: _filterType == 'shortage',
                      onSelected: (v) => setState(() => _filterType = 'shortage'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('储备充足'),
                      selected: _filterType == 'sufficient',
                      onSelected: (v) => setState(() => _filterType = 'sufficient'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4. 核心药品存量列表
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 68, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            Text(
                              _filterType == 'shortage' ? '暂无存量不足的药品，药箱储备充足！' : '药箱中暂无存量记录',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text('可点击右上角“AI 识别入库”直接粘贴就诊开药描述，或手动添加', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showAiTextParseBottomSheet(context),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('粘贴文字让 AI 自动盘点入库'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return _buildInventoryCard(context, item, isDark, prov);
                        },
                      ),
              ),
            ],
          ),

          // 5. 右下侧【可侧边折叠/吸附隐藏的灵动新增悬浮按钮】
          Positioned(
            right: 12,
            bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isFabExpanded = !_isFabExpanded),
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  child: _isFabExpanded
                      ? FloatingActionButton.extended(
                          heroTag: 'inventory_add_fab_expanded',
                          elevation: 3,
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          onPressed: () => _showManualEditDialog(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('手动记一笔存量'),
                        )
                      : FloatingActionButton.small(
                          heroTag: 'inventory_add_fab_collapsed',
                          elevation: 3,
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          tooltip: '新增药物存量',
                          onPressed: () => _showManualEditDialog(context, null),
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

  /// 顶部缺药告急 / 存量充足醒目预警横幅
  Widget _buildTopAlertBanner(
    BuildContext context,
    RecordsProvider prov,
    int shortageCount,
    bool isDark,
  ) {
    if (prov.medicationInventories.isEmpty) {
      return const SizedBox.shrink();
    }

    if (shortageCount > 0) {
      final shortageItems = prov.shortageInventories;
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.35), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notification_important, color: Color(0xFFF43F5E), size: 22),
                const SizedBox(width: 8),
                Text(
                  '🚨 缺药告急预警：发现 $shortageCount 种药品存量不足！',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: shortageItems.map((item) {
                final days = item.estimatedDaysRemaining;
                final isCritical = days <= 3 || item.currentStock <= 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCritical ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isCritical ? Colors.redAccent : Colors.orange),
                  ),
                  child: Text(
                    '${item.medicineName}: 仅剩${days.toStringAsFixed(1)}天用量 (${item.currentStock.toStringAsFixed(0)}${item.unit})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCritical ? const Color(0xFFE11D48) : Colors.orange.shade900,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 建议尽快前往医院门诊开具处方或到药房备药，避免慢病服药断档。',
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🟢 药箱储备充足，所有在库药品均在安全服用周期内。',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个药品存量卡片
  Widget _buildInventoryCard(
    BuildContext context,
    MedicationInventory item,
    bool isDark,
    RecordsProvider prov,
  ) {
    final days = item.estimatedDaysRemaining;
    final level = item.alertLevel;

    Color badgeColor;
    String badgeText;
    if (level == 'empty') {
      badgeColor = Colors.grey;
      badgeText = '已耗尽';
    } else if (level == 'critical') {
      badgeColor = const Color(0xFFF43F5E);
      badgeText = '严重缺药 · 仅剩${days.toStringAsFixed(1)}天';
    } else if (level == 'warning') {
      badgeColor = Colors.orange;
      badgeText = '即将不足 · 剩${days.toStringAsFixed(1)}天';
    } else {
      badgeColor = const Color(0xFF10B981);
      badgeText = '充足 · 可服${days.toStringAsFixed(0)}天';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：药品名 + 状态徽章 + 更多操作
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: badgeColor.withOpacity(0.18),
                        child: Icon(Icons.medication, size: 18, color: badgeColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.medicineName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 核心存量与预计消耗信息
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('当前剩余存量', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(
                        '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.isShortage ? const Color(0xFFF43F5E) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withOpacity(0.3)),
                  Column(
                    children: [
                      const Text('每日预计消耗', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(
                        '${item.dailyConsumption.toStringAsFixed(1)} ${item.unit}/天',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withOpacity(0.3)),
                  Column(
                    children: [
                      const Text('预计可用天数', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(
                        '${days.toStringAsFixed(1)} 天',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (item.packageSpec.isNotEmpty || item.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.packageSpec.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('规格: ${item.packageSpec}', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (item.notes.isNotEmpty)
                    Expanded(
                      child: Text(
                        '备注: ${item.notes}',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // 快捷打卡与微调按钮栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '更新于: ${DateFormat("MM-dd HH:mm").format(item.updatedAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Row(
                  children: [
                    // 服药打卡快捷扣减
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.check, size: 14),
                      label: Text('服药 -${item.dailyConsumption.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        await prov.updateInventoryStock(item.id, -item.dailyConsumption);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已记录今日服药，${item.medicineName} 扣减 ${item.dailyConsumption} ${item.unit}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    // 快捷补药加量
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('补药', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showQuickRefillDialog(context, item),
                    ),
                    const SizedBox(width: 4),
                    // 编辑完整信息
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 20, color: Colors.blueAccent),
                      tooltip: '编辑存量与阈值',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showManualEditDialog(context, item),
                    ),
                    const SizedBox(width: 4),
                    // 删除
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      tooltip: '删除此存量',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🌟 核心功能：AI 文字解析智能录入 BottomSheet
  void _showAiTextParseBottomSheet(BuildContext context) {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    final textCtrl = TextEditingController();
    bool isParsing = false;
    List<MedicationInventory>? parsedItems;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题与关闭
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI 药物存量智能识别导入',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '直接粘贴医院处方说明、购药小票、或用微信打字习惯随手描述家中余药，AI 自动提取药品通用名、折算可用总片数与每日消耗量：',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    // 快速模板按钮
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('示例 1: 门诊开药清单', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              textCtrl.text = '今天去医院开了3盒二甲双胍片，每盒60片，家里还有上周剩下的15片，目前每天吃2片；另外开了1盒苯溴马隆20片，每天吃1片。';
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('示例 2: 家中余药盘点', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              textCtrl.text = '药箱盘点：阿托伐他汀钙片还剩2盒共56片每天1片；拜阿司匹林还剩不到10片每天1片；降压药代文还有28片每天1片。';
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 文本输入框
                    TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '如：今天买了2盒苯溴马隆每盒20片每天1片，家里二甲双胍还有30片每天2片...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // AI 识别执行按钮
                    if (isParsing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('AI 正在智能识别药品名称、折算总片数与每日消耗...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('开始 AI 智能解析'),
                          onPressed: () async {
                            final input = textCtrl.text.trim();
                            if (input.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先输入或粘贴药物存量描述文字')),
                              );
                              return;
                            }

                            setSheetState(() => isParsing = true);
                            try {
                              final res = await AiService.instance.parseMedicationInventoryText(
                                text: input,
                                settings: settingsProv.settings,
                              );
                              setSheetState(() {
                                isParsing = false;
                                parsedItems = res;
                              });
                              if (res.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('未从文字中解析出有效药品存量，请调整描述后重试')),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isParsing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('解析失败: $e')),
                              );
                            }
                          },
                        ),
                      ),

                    // 识别成功后的预览与手动核对编辑列表
                    if (parsedItems != null && parsedItems!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('AI 识别出 ${parsedItems!.length} 项药品存量 (可微调)：', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Text('可直接点击修改', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: parsedItems!.length,
                        separatorBuilder: (c, i) => const Divider(height: 12),
                        itemBuilder: (context, pIdx) {
                          final pItem = parsedItems![pIdx];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pItem.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text(
                                        '存量: ${pItem.currentStock} ${pItem.unit}   |   每日服: ${pItem.dailyConsumption} ${pItem.unit}   |   预计可服: ${pItem.estimatedDaysRemaining.toStringAsFixed(1)}天',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                                      ),
                                      if (pItem.notes.isNotEmpty)
                                        Text('备注: ${pItem.notes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                                  onPressed: () async {
                                    // 允许在导入前手动微调
                                    await _showPreImportEditDialog(context, pItem, (updated) {
                                      setSheetState(() {
                                        parsedItems![pIdx] = updated;
                                      });
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    setSheetState(() {
                                      parsedItems!.removeAt(pIdx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // 确认导入按钮
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final prov = Provider.of<RecordsProvider>(context, listen: false);
                            await prov.batchImportMedicationInventories(parsedItems!);
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ 成功导入 ${parsedItems!.length} 种药品存量到药箱！')),
                            );
                          },
                          child: Text('确认无误，一键导入药箱 (${parsedItems!.length}项)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 导入前单个项目的快速微调弹窗
  Future<void> _showPreImportEditDialog(BuildContext context, MedicationInventory item, Function(MedicationInventory) onSave) async {
    final nameCtrl = TextEditingController(text: item.medicineName);
    final stockCtrl = TextEditingController(text: item.currentStock.toString());
    final unitCtrl = TextEditingController(text: item.unit);
    final dailyCtrl = TextEditingController(text: item.dailyConsumption.toString());
    final notesCtrl = TextEditingController(text: item.notes);

    await showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('微调识别结果'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '药品通用名')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '当前剩余总数'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: '单位 (如片/粒)'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: dailyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '每日预计消耗 (片/天)')),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: '备注')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final updated = MedicationInventory(
                id: item.id,
                medicineName: nameCtrl.text.trim(),
                currentStock: double.tryParse(stockCtrl.text.trim()) ?? item.currentStock,
                unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : item.unit,
                dailyConsumption: double.tryParse(dailyCtrl.text.trim()) ?? item.dailyConsumption,
                alertThresholdDays: item.alertThresholdDays,
                packageSpec: item.packageSpec,
                notes: notesCtrl.text.trim(),
                updatedAt: DateTime.now(),
              );
              onSave(updated);
              Navigator.pop(dlgCtx);
            },
            child: const Text('保存微调'),
          ),
        ],
      ),
    );
  }

  /// 快捷补药入库加量弹窗
  void _showQuickRefillDialog(BuildContext context, MedicationInventory item) {
    final refillCtrl = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('【${item.medicineName}】补药入库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前药箱剩余: ${item.currentStock.toStringAsFixed(1)} ${item.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: refillCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: '本次补充增加数量 (${item.unit})',
                border: const OutlineInputBorder(),
                suffixText: item.unit,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionChip(label: const Text('+10片'), onPressed: () => refillCtrl.text = '10'),
                const SizedBox(width: 6),
                ActionChip(label: const Text('+20片'), onPressed: () => refillCtrl.text = '20'),
                const SizedBox(width: 6),
                ActionChip(label: const Text('+30片'), onPressed: () => refillCtrl.text = '30'),
                const SizedBox(width: 6),
                ActionChip(label: const Text('+60片'), onPressed: () => refillCtrl.text = '60'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final added = double.tryParse(refillCtrl.text.trim()) ?? 0.0;
              if (added > 0) {
                final prov = Provider.of<RecordsProvider>(context, listen: false);
                await prov.updateInventoryStock(item.id, added);
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已为【${item.medicineName}】成功补充 $added ${item.unit}')),
                );
              }
            },
            child: const Text('确认入库'),
          ),
        ],
      ),
    );
  }

  /// 手动添加或完整编辑存量
  void _showManualEditDialog(BuildContext context, MedicationInventory? existing) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    final isEdit = existing != null;

    final nameCtrl = TextEditingController(text: existing?.medicineName ?? '');
    final stockCtrl = TextEditingController(text: existing?.currentStock.toString() ?? '30');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '片');
    final dailyCtrl = TextEditingController(text: existing?.dailyConsumption.toString() ?? '1.0');
    final thresholdCtrl = TextEditingController(text: existing?.alertThresholdDays.toString() ?? '7');
    final specCtrl = TextEditingController(text: existing?.packageSpec ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    // 智能参考当前在服药品的用药频次
    final trackedDrugs = prov.getAggregatedMedicationTimelines();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(isEdit ? '编辑药品存量' : '手动记录药物存量'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEdit && trackedDrugs.isNotEmpty) ...[
                  const Text('从当前慢病在服药物中快速选择：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: trackedDrugs.map((d) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(d.medicineName, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDlgState(() {
                              nameCtrl.text = d.medicineName;
                              specCtrl.text = d.latestDosage;
                            });
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '药品通用名 *',
                    hintText: '如: 二甲双胍片',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '当前剩余数量 *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: '单位',
                          hintText: '片/粒/支',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dailyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '每日消耗用量 *',
                          hintText: '如: 2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: thresholdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '缺药预警阈值 (天)',
                          hintText: '默认 7 天',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(
                    labelText: '包装规格 (选填)',
                    hintText: '如: 60片/盒、0.5g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: '备注说明 (选填)',
                    hintText: '如: 随餐服用，开药地点',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入药品通用名')));
                  return;
                }
                final stock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                final daily = double.tryParse(dailyCtrl.text.trim()) ?? 1.0;
                final threshold = int.tryParse(thresholdCtrl.text.trim()) ?? 7;

                final item = MedicationInventory(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  medicineName: name,
                  currentStock: stock,
                  unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : '片',
                  dailyConsumption: daily > 0 ? daily : 1.0,
                  alertThresholdDays: threshold > 0 ? threshold : 7,
                  packageSpec: specCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  updatedAt: DateTime.now(),
                );

                await prov.saveMedicationInventory(item);
                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? '已更新【$name】存量' : '已添加【$name】到药箱')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MedicationInventory item) {
    final prov = Provider.of<RecordsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('确认删除该药品存量？'),
        content: Text('将从药箱中移除【${item.medicineName}】。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await prov.deleteMedicationInventory(item.id);
              Navigator.pop(dlgCtx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
