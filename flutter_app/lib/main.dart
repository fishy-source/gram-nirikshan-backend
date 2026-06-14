// Main App Entry Point with Provider setup and GoRouter navigation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/constants/app_constants.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/inspection_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/welcome/welcome_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/inspections/inspection_list_screen.dart';
import 'presentation/screens/inspections/inspection_detail_screen.dart';
import 'presentation/screens/inspections/new_inspection_screen.dart';
import 'presentation/screens/ai_assistant/ai_assistant_screen.dart';
import 'presentation/screens/photos/photo_upload_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/reports/pdf_preview_screen.dart';
import 'presentation/screens/map/map_screen.dart';
import 'presentation/screens/calendar/calendar_screen.dart';
import 'presentation/screens/users/add_user_screen.dart';
import 'presentation/providers/language_provider.dart';

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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
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
      locale: context.watch<LanguageProvider>().locale,
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
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (_) => const HomeScreen(),
        '/inspections': (_) => const InspectionListScreen(),
        '/inspections/new': (_) => const NewInspectionScreen(),
        '/ai-assistant': (_) => const AIAssistantScreen(),
        '/photos': (_) => const PhotoUploadScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/map': (_) => const MapScreen(),
        '/calendar': (_) => const CalendarScreen(),
        '/users/add': (_) => const AddUserScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/inspections/detail') {
          final id = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => InspectionDetailScreen(inspectionId: id));
        }
        if (settings.name == '/reports/preview') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              inspectionId: args['inspectionId'] as String,
              title: args['title'] as String,
              format: args['format'] as String? ?? 'pdf_en',
            ),
          );
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
    Navigator.pushReplacementNamed(context, auth.isLoggedIn ? '/welcome' : '/login');
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
    const _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIAssistantScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
        label: Text(context.tr('ai_assistant'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard_rounded), label: context.tr('dashboard')),
          NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment_rounded), label: context.tr('inspections')),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: context.tr('profile')),
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
      appBar: AppBar(title: Text(context.tr('profile'))),
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
        const SizedBox(height: 16),
        
        // Language Selector Card
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate_rounded, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('भाषा / Language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: context.watch<LanguageProvider>().isHindi ? 'hi' : 'en',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      onChanged: (String? val) {
                        if (val != null) {
                          context.read<LanguageProvider>().setLanguage(val);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'hi',
                          child: Text('हिन्दी'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('English'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Share App Card
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.share_rounded, color: AppTheme.primaryColor),
            title: Text(context.tr('share_app'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            onTap: () => _showShareAppBottomSheet(context),
          ),
        ),
        const SizedBox(height: 16),
        
        _ProfileTile(Icons.badge_rounded, context.tr('employee_id'), user?.employeeId ?? 'N/A'),
        _ProfileTile(Icons.phone_rounded, context.tr('mobile'), user?.mobile ?? 'N/A'),
        _ProfileTile(Icons.email_rounded, context.tr('email'), user?.email ?? 'N/A'),
        _ProfileTile(Icons.location_city_rounded, context.tr('district'), user?.district ?? 'N/A'),
        _ProfileTile(Icons.business_rounded, context.tr('block'), user?.block ?? 'N/A'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.tr('logout')),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
        ),
      ]),
    );
  }

  void _showShareAppBottomSheet(BuildContext context) {
    final isHindi = context.read<LanguageProvider>().isHindi;
    final shareText = context.read<LanguageProvider>().translate('share_app_text');
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isHindi ? 'ऐप शेयर करें' : 'Share App',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: AppTheme.primaryColor),
                  title: Text(isHindi ? 'सिस्टम शेयर (Native Share)' : 'System Share'),
                  subtitle: Text(isHindi ? 'फ़ोन के शेयर डायलॉग से भेजें' : 'Share via device settings'),
                  onTap: () {
                    Navigator.pop(context);
                    final box = context.findRenderObject() as RenderBox?;
                    Share.share(
                      shareText,
                      sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_rounded, color: Colors.green),
                  title: Text(isHindi ? 'व्हाट्सएप पर शेयर करें' : 'Share on WhatsApp'),
                  subtitle: Text(isHindi ? 'व्हाट्सएप ऐप सीधे खोलें' : 'Open WhatsApp directly'),
                  onTap: () async {
                    Navigator.pop(context);
                    final whatsappUrl = Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareText)}");
                    try {
                      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isHindi ? 'व्हाट्सएप खोलने में विफल' : 'Failed to open WhatsApp')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: AppTheme.secondaryColor),
                  title: Text(isHindi ? 'लिंक कॉपी करें' : 'Copy Link'),
                  subtitle: Text(isHindi ? 'क्लिपबोर्ड पर सेव करें' : 'Copy to clipboard'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isHindi ? 'लिंक क्लिपबोर्ड पर कॉपी किया गया!' : 'Link copied to clipboard!'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
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
