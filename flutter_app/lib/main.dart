// Main App Entry Point with Provider setup and GoRouter navigation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/constants/app_constants.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/inspection_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/inspections/inspection_list_screen.dart';
import 'presentation/screens/inspections/inspection_detail_screen.dart';
import 'presentation/screens/inspections/new_inspection_screen.dart';
import 'presentation/screens/ai_assistant/ai_assistant_screen.dart';
import 'presentation/screens/photos/photo_upload_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/map/map_screen.dart';
import 'presentation/screens/calendar/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize API service
  ApiService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
      ],
      child: const GramNirikshanApp(),
    ),
  );
}

class GramNirikshanApp extends StatefulWidget {
  const GramNirikshanApp({super.key});

  @override
  State<GramNirikshanApp> createState() => _GramNirikshanAppState();
}

class _GramNirikshanAppState extends State<GramNirikshanApp> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gram Nirikshan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('hi', 'IN'),
      supportedLocales: const [Locale('hi', 'IN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/inspections': (_) => const InspectionListScreen(),
        '/inspections/new': (_) => const NewInspectionScreen(),
        '/ai-assistant': (_) => const AIAssistantScreen(),
        '/photos': (_) => const PhotoUploadScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/map': (_) => const MapScreen(),
        '/calendar': (_) => const CalendarScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/inspections/detail') {
          final id = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => InspectionDetailScreen(inspectionId: id));
        }
        return null;
      },
    );
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _ctrl.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, auth.isLoggedIn ? '/home' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A5276), Color(0xFF154360), Color(0xFF0B3C5D)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: const Icon(Icons.domain_verification_rounded, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  const Text('ग्राम निरीक्षण',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
                  const SizedBox(height: 8),
                  const Text('Gram Nirikshan App',
                      style: TextStyle(fontSize: 16, color: Colors.white70, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  const Text('ग्राम पंचायत निरीक्षण एवं निगरानी',
                      style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 60),
                  const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Screen with Bottom Nav ───────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = [
    const DashboardScreen(),
    const InspectionListScreen(),
    const AIAssistantScreen(),
    const _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'डैशबोर्ड'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'निरीक्षण'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy_rounded), label: 'AI सहायक'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'प्रोफ़ाइल'),
        ],
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('प्रोफ़ाइल')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty)
                ? NetworkImage('${AppConstants.baseUrl.replaceAll('/api/v1', '')}${user.profilePhoto}')
                : null,
            child: (user?.profilePhoto == null || user!.profilePhoto!.isEmpty)
                ? Text(
                    user?.name.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(user?.name ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
        Center(child: Text(user?.designation ?? user?.role.toUpperCase() ?? '', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),
        _ProfileTile(Icons.badge_rounded, 'कर्मचारी ID', user?.employeeId ?? 'N/A'),
        _ProfileTile(Icons.phone_rounded, 'मोबाइल', user?.mobile ?? 'N/A'),
        _ProfileTile(Icons.email_rounded, 'ईमेल', user?.email ?? 'N/A'),
        _ProfileTile(Icons.location_city_rounded, 'जिला', user?.district ?? 'N/A'),
        _ProfileTile(Icons.business_rounded, 'ब्लॉक', user?.block ?? 'N/A'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('लॉगआउट'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
        ),
      ]),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfileTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}
