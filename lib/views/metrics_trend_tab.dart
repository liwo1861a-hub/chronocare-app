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

    // 提取最新的参考范围与上下限 (用于走势图基准线与参考区间展示)
    String standardRefRange = '';
    double? activeRefMin;
    double? activeRefMax;
    for (var h in history.reversed) {
      if (standardRefRange.isEmpty && h.referenceRange.trim().isNotEmpty) {
        standardRefRange = h.referenceRange.trim();
      }
      if (activeRefMin == null && h.refMin != null) {
        activeRefMin = h.refMin;
      }
      if (activeRefMax == null && h.refMax != null) {
        activeRefMax = h.refMax;
      }
      if (standardRefRange.isNotEmpty && (activeRefMin != null || activeRefMax != null)) {
        break;
      }
    }

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
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isQualitativeProject ? Colors.teal : Colors.blueAccent,
                                  child: Icon(isQualitativeProject ? Icons.compare_arrows : Icons.show_chart, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isQualitativeProject ? '$_selectedItemName 定性演变对比' : '$_selectedItemName 历史走势图',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (standardRefRange.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_outlined, size: 12, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '参考: $standardRefRange',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isQualitativeProject ? Colors.teal.withOpacity(0.15) : Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isQualitativeProject ? '定性/等级' : '单位: ${history.first.unit.isNotEmpty ? history.first.unit : "数值"}',
                                  style: TextStyle(fontSize: 11, color: isQualitativeProject ? Colors.teal : Colors.blueAccent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.touch_app_outlined, size: 13, color: Colors.blue.shade300),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '点击图表数据点或下方明细列表，可直接跳转并定位至对应的检查报告单',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(context, history, isDark, isQualitativeProject, activeRefMin, activeRefMax),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      onTap: () {
                        // 🎯 核心跳转：点击指标直接跳转对应的检查单据报告单
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailScreen(
                              recordId: item.recordId,
                              initialCategory: item.parentCategory,
                            ),
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
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // 醒目标注其对应的单据报告单
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.description_outlined, size: 11, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '单据: ${item.parentCategory}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                // 🎯 重点：显示指标参考范围！
                                if (item.referenceRange.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      '参考: ${item.referenceRange}',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                    ),
                                  )
                                else if (standardRefRange.isNotEmpty)
                                  Text(
                                    '参考: $standardRefRange',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                  ),
                              ],
                            ),
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text('备注: ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.amber), overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
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
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
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

  Widget _buildLineChart(
    BuildContext context,
    List<MetricHistoryPoint> history,
    bool isDark,
    bool isQualitative,
    double? activeRefMin,
    double? activeRefMax,
  ) {
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
    } else {
      if (activeRefMin != null && activeRefMin < minY) {
        minY = activeRefMin;
      }
      if (activeRefMax != null && activeRefMax > maxY) {
        maxY = activeRefMax;
      }
      if (minY == maxY) {
        minY = minY * 0.8;
        maxY = maxY * 1.2;
      } else {
        final pad = (maxY - minY) * 0.15;
        minY = (minY - pad) > 0 ? (minY - pad) : 0;
        maxY = maxY + pad;
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble() > 0 ? (history.length - 1).toDouble() : 1,
        minY: minY,
        maxY: maxY,
        // 🎯 核心：在图表内绘制标准参考范围上下限辅助虚线与标识
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (!isQualitative && activeRefMin != null)
              HorizontalLine(
                y: activeRefMin,
                color: const Color(0xFF10B981).withOpacity(0.55),
                strokeWidth: 1.2,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                  labelResolver: (_) => '参考下限 $activeRefMin',
                ),
              ),
            if (!isQualitative && activeRefMax != null)
              HorizontalLine(
                y: activeRefMax,
                color: const Color(0xFF10B981).withOpacity(0.55),
                strokeWidth: 1.2,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                  labelResolver: (_) => '参考上限 $activeRefMax',
                ),
              ),
          ],
        ),
        // 🎯 核心：点击图表上的任意数据点，直接跳转定位到对应的检查报告单
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= history.length) return null;
                final pt = history[idx];
                final dateStr = DateFormat('yyyy-MM-dd').format(pt.date);
                final refStr = pt.referenceRange.isNotEmpty ? '\n参考: ${pt.referenceRange}' : '';
                return LineTooltipItem(
                  '$dateStr\n${pt.parentCategory}: ${pt.valueStr} ${pt.unit}$refStr\n[点击跳转报告单 ➔]',
                  TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (event is FlTapUpEvent &&
                touchResponse != null &&
                touchResponse.lineBarSpots != null &&
                touchResponse.lineBarSpots!.isNotEmpty) {
              final spotIdx = touchResponse.lineBarSpots!.first.spotIndex;
              if (spotIdx >= 0 && spotIdx < history.length) {
                final targetItem = history[spotIdx];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordDetailScreen(
                      recordId: targetItem.recordId,
                      initialCategory: targetItem.parentCategory,
                    ),
                  ),
                );
              }
            }
          },
        ),
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
