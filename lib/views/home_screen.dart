import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import 'timeline_tab.dart';
import 'diseases_tab.dart';
import 'categories_tab.dart';
import 'metrics_trend_tab.dart';
import 'record_edit_screen.dart';
import 'batch_import_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Widget> _tabs = const [
    TimelineTab(),
    DiseasesTab(),
    CategoriesTab(),
    MetricsTrendTab(),
  ];

  final List<String> _tabTitles = const [
    '复查时间轴',
    '慢病病程档案',
    '检查项目分类',
    '核心指标趋势',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsProv = Provider.of<RecordsProvider>(context);
    final settingsProv = Provider.of<SettingsProvider>(context);
    final settings = settingsProv.settings;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索医院、化验项、用药、医嘱、备注...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (val) => recordsProv.setSearchQuery(val),
              )
            : Text(_tabTitles[_currentIndex]),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  recordsProv.setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onSelected: (val) {
              settings.defaultRecordSort = val;
              settingsProv.updateSettings(settings);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'date_desc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 16, color: settings.defaultRecordSort == 'date_desc' ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('按日期倒序 (最新在前)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date_asc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 16, color: settings.defaultRecordSort == 'date_asc' ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('按日期正序 (最早在前)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'abnormal_first',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: settings.defaultRecordSort == 'abnormal_first' ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('异常指标优先'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: '时间轴',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '病程档案',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: '检查分类',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: '指标走势',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'batch_scan',
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('批量智能扫单'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BatchImportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'add_single',
                  child: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecordEditScreen()),
                    );
                  },
                ),
              ],
            )
          : null,
    );
  }
}
