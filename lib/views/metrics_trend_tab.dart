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

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final allItems = prov.getAllItemNames();

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('暂无指标数据，请先录入复查化验单'),
          ],
        ),
      );
    }

    // 默认选择第一个指标
    _selectedItemName ??= allItems.first;
    final history = prov.getMetricHistory(_selectedItemName!);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 指标选择下拉框
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    const Text('追踪指标：', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: allItems.contains(_selectedItemName) ? _selectedItemName : allItems.first,
                          isExpanded: true,
                          items: allItems.map((name) {
                            return DropdownMenuItem(
                              value: name,
                              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedItemName = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('该指标暂无数值型记录'),
                ),
              )
            else ...[
              // 走势折线图卡片
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
                          Text(
                            '$_selectedItemName 历史趋势',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '单位: ${history.first.unit}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(history),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 横向对比表格
              const Text(
                '历次复查数值横向对比',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
                    final isAbnormal = item.status != 'normal';

                    // 计算与上一次的差值
                    String diffStr = '';
                    if (index > 0) {
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailScreen(recordId: item.recordId),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: isAbnormal ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          isAbnormal ? Icons.trending_up : Icons.check,
                          color: isAbnormal ? Colors.red : Colors.green,
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            item.hospital,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      subtitle: item.notes.isNotEmpty
                          ? Text('备注: ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.amber))
                          : null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.valueStr} ${item.unit}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isAbnormal ? Colors.red : Colors.black87,
                            ),
                          ),
                          if (diffStr.isNotEmpty)
                            Text(
                              diffStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: diffStr.contains('+') ? Colors.red : Colors.green,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<MetricHistoryPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    double minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    double maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    minY = (minY * 0.85).floorToDouble();
    maxY = (maxY * 1.15).ceilToDouble();
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx >= 0 && idx < points.length) {
                  final pt = points[idx];
                  return LineTooltipItem(
                    '${DateFormat("MM-dd").format(pt.date)}\n${pt.value} ${pt.unit}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      DateFormat('MM/dd').format(points[idx].date),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final pt = points[index];
                final isAbnormal = pt.status != 'normal';
                return FlDotCirclePainter(
                  radius: 5,
                  color: isAbnormal ? Colors.red : Colors.blueAccent,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
