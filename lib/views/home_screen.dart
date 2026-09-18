import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import 'timeline_tab.dart';
import 'metrics_trend_tab.dart';
import 'medications_tab.dart';
import 'questions_tab.dart';
import 'diseases_tab.dart';
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
    MetricsTrendTab(),
    MedicationsTab(),
    QuestionsTab(),
    DiseasesTab(),
  ];

  final List<String> _tabTitles = const [
    '复查时间轴',
    '核心指标趋势',
    '慢病用药记录',
    '复查提问备忘',
    '慢病病程档案',
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
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '系统与同步设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: recordsProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: '时间轴',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: '指标走势',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: '药物记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_help_outlined),
            selectedIcon: Icon(Icons.live_help),
            label: '提问备忘',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            selectedIcon: Icon(Icons.folder_shared),
            label: '慢病档案',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'batch_ocr_btn',
                  tooltip: '批量图谱识别导入',
                  backgroundColor: const Color(0xFF0284C7),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BatchImportScreen()),
                    );
                  },
                  child: const Icon(Icons.document_scanner, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'add_record_btn',
                  tooltip: '新建复查单',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecordEditScreen()),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
    );
  }
}
