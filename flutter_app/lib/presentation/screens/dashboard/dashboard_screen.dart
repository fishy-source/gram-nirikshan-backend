// Dashboard Screen with analytics, stats cards, and quick actions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../../data/models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final response = await ApiService().getDashboardStats();
      setState(() {
        _stats = DashboardStats.fromJson(response.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(user),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeBanner(user),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_stats != null) ...[
                    _buildStatsGrid(_stats!),
                    const SizedBox(height: 20),
                    _buildStatusChart(_stats!),
                    const SizedBox(height: 20),
                  ],
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildRecentActivity(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(UserModel? user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
            ),
          ),
        ),
        title: Text(context.tr('app_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (_) => [
            PopupMenuItem(child: Text(context.tr('profile')), onTap: () {}),
            PopupMenuItem(child: Text(context.tr('settings')), onTap: () {}),
            PopupMenuItem(
              child: Text(context.tr('logout'), style: const TextStyle(color: Colors.red)),
              onTap: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomeBanner(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A5276), Color(0xFF2E86C1)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              user?.name.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('welcome_back').replaceAll('{name}', user?.name ?? "User"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(user?.designation ?? user?.role.toUpperCase() ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                if (user?.district != null)
                  Text(user!.district!, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    final user = context.watch<AuthProvider>().currentUser;
    final isHindi = context.read<LanguageProvider>().isHindi;
    final String totalLabel = (user?.isInspector ?? false) 
        ? (isHindi ? 'आपके द्वारा किए गए कुल निरीक्षण' : 'Total Inspections Conducted by You')
        : context.tr('total_inspections');

    final items = [
      _StatItem(totalLabel, stats.totalInspections.toString(), Icons.assignment_rounded, AppTheme.primaryColor),
      _StatItem(context.tr('this_month'), stats.thisMonthInspections.toString(), Icons.calendar_month_rounded, AppTheme.infoColor),
      _StatItem(context.tr('approved'), stats.approvedCount.toString(), Icons.check_circle_rounded, AppTheme.successColor),
      _StatItem(context.tr('submitted'), stats.submittedCount.toString(), Icons.pending_rounded, AppTheme.warningColor),
      _StatItem(context.tr('panchayats'), stats.totalPanchayats.toString(), Icons.location_city_rounded, AppTheme.secondaryColor),
      _StatItem(context.tr('engineers'), stats.totalEngineers.toString(), Icons.engineering_rounded, AppTheme.accentColor),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.28,
      children: items.map((item) => _buildStatCard(item)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: item.color)),
              Text(item.label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(DashboardStats stats) {
    final sections = [
      PieChartSectionData(value: stats.approvedCount.toDouble(), color: AppTheme.approvedColor, title: context.tr('approved'), radius: 60, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: stats.submittedCount.toDouble(), color: AppTheme.submittedColor, title: context.tr('submitted'), radius: 55, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: stats.draftCount.toDouble(), color: AppTheme.draftColor, title: context.tr('draft'), radius: 50, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: stats.rejectedCount.toDouble(), color: AppTheme.rejectedColor, title: context.tr('rejected'), radius: 50, titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    ].where((s) => s.value > 0).toList();
    
    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('status_chart'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(PieChartData(
              sections: sections, centerSpaceRadius: 40,
              sectionsSpace: 2, borderData: FlBorderData(show: false),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(context.tr('new_inspection'), Icons.add_circle_rounded, AppTheme.primaryColor, '/inspections/new'),
      _QuickAction(context.tr('calendar'), Icons.calendar_today_rounded, AppTheme.infoColor, '/calendar'),
      _QuickAction(context.tr('ai_assistant'), Icons.smart_toy_rounded, AppTheme.accentColor, '/ai-assistant'),
      _QuickAction(context.tr('map'), Icons.map_rounded, AppTheme.successColor, '/map'),
      _QuickAction(context.tr('view_reports'), Icons.picture_as_pdf_rounded, AppTheme.errorColor, '/reports'),
      _QuickAction(context.tr('photo_upload'), Icons.camera_alt_rounded, AppTheme.secondaryColor, '/photos'),
    ];

    final user = context.watch<AuthProvider>().currentUser;
    if (user != null && (user.isAdmin || user.role == 'superadmin')) {
      actions.add(_QuickAction(
        context.read<LanguageProvider>().isHindi ? 'नया यूज़र जोड़ें' : 'Add User', 
        Icons.person_add_rounded, 
        Colors.deepPurple, 
        '/users/add'
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('quick_actions'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9,
          children: actions.map((a) => _buildQuickActionButton(context, a)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, action.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(action.label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('recent_activity'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/inspections'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: Center(
              child: Column(children: [
                const Icon(Icons.history_rounded, size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 8),
                Text(context.tr('tap_to_view_inspections'), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  _StatItem(this.label, this.value, this.icon, this.color);
}

class _QuickAction {
  final String label, route;
  final IconData icon;
  final Color color;
  _QuickAction(this.label, this.icon, this.color, this.route);
}
