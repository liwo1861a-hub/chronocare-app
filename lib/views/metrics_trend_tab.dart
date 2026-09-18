import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/records_provider.dart';
import 'record_detail_screen.dart';

class MetricsTrendTab extends StatefulWidget {
  const MetricsTrendTab({super.key});

  @override
  State<MetricsTrendTab> createState() => _MetricsTrendTabState();
}

class _MetricsTrendTabState extends State<MetricsTrendTab> {
  String? _selectedItemName;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchKeyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = prov.getAllItemNames();
    final filteredItems = prov.searchItemNames(_searchKeyword);

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('暂无指标数据，请先录入或扫描复查化验单'),
          ],
        ),
      );
    }

    if (_selectedItemName == null || !allItems.contains(_selectedItemName)) {
      _selectedItemName = filteredItems.isNotEmpty ? filteredItems.first : allItems.first;
    }

    final history = prov.getMetricHistory(_selectedItemName!);
    final bool isQualitativeProject = history.any((h) => h.isQualitative);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 关键词即时搜索单独项目
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '输入关键词搜索单独指标 (如: 尿蛋白、乙肝、肌酐、血糖、甲状腺)...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchKeyword = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchKeyword = val.trim();
                      final matched = prov.searchItemNames(_searchKeyword);
                      if (matched.isNotEmpty && !matched.contains(_selectedItemName)) {
                        _selectedItemName = matched.first;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 搜索结果快捷标签栏 / 当前追踪指标选择器
            if (filteredItems.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredItems.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final name = filteredItems[index];
                    final isSelected = name == _selectedItemName;
                    return ChoiceChip(
                      label: Text(name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: isDark ? const Color(0xFF0284C7) : Colors.blue.shade600,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedItemName = name);
                      },
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('未找到包含“$_searchKeyword”的指标，可重试其他关键词', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 14),

            if (history.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.grey, size: 36),
                        const SizedBox(height: 8),
                        Text('【$_selectedItemName】暂无历史记录', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // 2. 走势图卡片 (数值型连续折线图 或 定性/阴阳性阶梯状态图)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isQualitativeProject ? Colors.teal : Colors.blueAccent,
                                child: Icon(isQualitativeProject ? Icons.compare_arrows : Icons.show_chart, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isQualitativeProject ? '$_selectedItemName 定性演变对比' : '$_selectedItemName 历史走势图',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isQualitativeProject ? Colors.teal.withOpacity(0.15) : Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isQualitativeProject ? '定性/等级项目' : '单位: ${history.first.unit.isNotEmpty ? history.first.unit : "数值"}',
                              style: TextStyle(fontSize: 11, color: isQualitativeProject ? Colors.teal : Colors.blueAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isQualitativeProject
                            ? '已为您按历次复查日期自动比对阴阳性与等级转归 (点击下方列表可定位大报告单)'
                            : '共包含 ${history.length} 次复查测定数据 (点击数据点或下方列表可定位大报告单)',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(history, isDark, isQualitativeProject),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. 历次复查指标明细与【反向定位链接至大项目报告单】
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历次检测明细与转归比对 (点击直达大报告单)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '共 ${history.length} 次记录',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (c, i) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final dateStr = DateFormat('yyyy年MM月dd日').format(item.date);
                    final isAbnormal = item.status != 'normal' || (item.isQualitative && item.value > 0);

                    // 计算数值差值或定性转归
                    String diffStr = '';
                    if (item.isQualitative) {
                      diffStr = item.qualitativeChange;
                    } else if (index > 0) {
                      final prevVal = history[index - 1].value;
                      final diff = item.value - prevVal;
                      if (diff > 0) {
                        diffStr = ' (+${diff.toStringAsFixed(2)})';
                      } else if (diff < 0) {
                        diffStr = ' (${diff.toStringAsFixed(2)})';
                      } else {
                        diffStr = ' (持平)';
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      onTap: () {
                        // 一键反向跳转并定位到该复查档案与大报告单栏目
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailScreen(recordId: item.recordId),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: isAbnormal ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                        child: Icon(
                          isAbnormal ? (item.status == 'high' ? Icons.arrow_upward : Icons.priority_high) : Icons.check,
                          color: isAbnormal ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.hospital,
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            // 醒目标注其存在的大项目/大报告单名称
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.description, size: 11, color: Colors.blueAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '所属大项目: ${item.parentCategory}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('· ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.amber), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.valueStr.isNotEmpty ? '${item.valueStr} ${item.unit}' : '未注明',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isAbnormal
                                  ? (isDark ? const Color(0xFFFDA4AF) : Colors.red.shade700)
                                  : (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade800),
                            ),
                          ),
                          if (diffStr.isNotEmpty)
                            Text(
                              diffStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: diffStr.contains('+') || diffStr.contains('转阳') || diffStr.contains('加重')
                                    ? Colors.redAccent
                                    : (diffStr.contains('转阴') || diffStr.contains('好转') ? Colors.green : Colors.grey),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<MetricHistoryPoint> history, bool isDark, bool isQualitative) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].value));
    }

    final values = history.map((e) => e.value).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);

    if (isQualitative) {
      minY = 0;
      maxY = maxY < 3 ? 3 : maxY + 1;
    } else if (minY == maxY) {
      minY = minY * 0.8;
      maxY = maxY * 1.2;
    } else {
      final pad = (maxY - minY) * 0.15;
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
          horizontalInterval: isQualitative ? 1 : ((maxY - minY) / 4 > 0 ? (maxY - minY) / 4 : 1),
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
              reservedSize: isQualitative ? 46 : 42,
              getTitlesWidget: (val, meta) {
                if (isQualitative) {
                  if (val == 0) return _buildQualitativeLabel('阴性', Colors.green);
                  if (val == 0.5) return _buildQualitativeLabel('±', Colors.amber);
                  if (val == 1) return _buildQualitativeLabel('1+/阳', Colors.orange);
                  if (val == 2) return _buildQualitativeLabel('2+', Colors.redAccent);
                  if (val >= 3) return _buildQualitativeLabel('3+~4+', Colors.red);
                  return const Text('');
                }
                return Text(
                  val.toStringAsFixed(1),
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < history.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
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
            isCurved: !isQualitative,
            isStepLineChart: isQualitative,
            color: isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isAb = history[index].status != 'normal' || (isQualitative && history[index].value > 0);
                return FlDotCirclePainter(
                  radius: isAb ? 5.5 : 4,
                  color: isAb ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8)).withOpacity(0.35),
                  (isQualitative ? const Color(0xFF14B8A6) : const Color(0xFF38BDF8)).withOpacity(0.0),
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

  Widget _buildQualitativeLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }
}
