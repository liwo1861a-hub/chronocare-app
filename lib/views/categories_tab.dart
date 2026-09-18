import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/records_provider.dart';
import 'record_detail_screen.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  static const List<String> defaultCategories = [
    '血液生化',
    '血常规',
    '尿常规',
    '超声影像',
    'CT/MRI',
    '胃肠镜',
    '心电图',
    '病理报告',
    '随访记录',
    '其他检查',
  ];

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<RecordsProvider>(context);
    final records = prov.records;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: defaultCategories.length,
      itemBuilder: (context, index) {
        final cat = defaultCategories[index];
        final catRecords = records.where((r) => r.category == cat).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: Icon(_getCategoryIcon(cat), color: Colors.indigo),
            ),
            title: Text(
              cat,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${catRecords.length} 份',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              if (catRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('暂无该分类的检查记录', style: TextStyle(color: Colors.grey)),
                )
              else
                ...catRecords.map((r) => ListTile(
                      title: Text('${r.checkDate.toIso8601String().substring(0, 10)} - ${r.hospital}'),
                      subtitle: Text(
                        r.items.isNotEmpty
                            ? '检验指标: ${r.items.map((i) => i.itemName).take(3).join(", ")}...'
                            : r.doctorAdvice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case '血液生化':
      case '血常规':
        return Icons.bloodtype;
      case '尿常规':
        return Icons.science_outlined;
      case '超声影像':
      case 'CT/MRI':
        return Icons.scanner;
      case '胃肠镜':
        return Icons.camera_alt_outlined;
      case '心电图':
        return Icons.monitor_heart_outlined;
      case '病理报告':
        return Icons.biotech;
      default:
        return Icons.folder_open;
    }
  }
}
