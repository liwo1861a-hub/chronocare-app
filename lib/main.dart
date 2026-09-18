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

    Color primaryColor = const Color(0xFF2563EB);
    try {
      primaryColor = Color(int.parse(settings.primaryColorHex.replaceFirst('#', '0xFF')));
    } catch (_) {}

    return MaterialApp(
      title: '脉络健康 (ChronoCare)',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // 浅色主题
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryColor,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // 高对比度极速优化的深色主题
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        cardColor: const Color(0xFF1E293B), // Slate 800
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8), // Sky 400
          secondary: Color(0xFF10B981), // Emerald 500
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
          error: Color(0xFFF43F5E), // Rose 500
          onPrimary: Colors.black,
          onSurface: Color(0xFFF8FAFC),
          onBackground: Color(0xFFF8FAFC),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
        ),
        dividerColor: const Color(0xFF334155),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF8FAFC)),
          bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
          titleMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
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
