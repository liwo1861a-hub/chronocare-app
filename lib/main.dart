import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/storage_service.dart';
import 'providers/records_provider.dart';
import 'providers/settings_provider.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => RecordsProvider()..loadData()),
      ],
      child: const ChronoCareApp(),
    ),
  );
}

class ChronoCareApp extends StatelessWidget {
  const ChronoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<SettingsProvider>(context);
    final settings = settingsProv.settings;

    ThemeMode themeMode = ThemeMode.system;
    if (settings.themeMode == 'light') themeMode = ThemeMode.light;
    if (settings.themeMode == 'dark') themeMode = ThemeMode.dark;

    Color primaryColor = Colors.blue;
    try {
      primaryColor = Color(int.parse(settings.primaryColorHex.replaceFirst('#', '0xFF')));
    } catch (_) {}

    return MaterialApp(
      title: '脉络健康 (ChronoCare)',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryColor,
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryColor,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: const HomeScreen(),
    );
  }
}
