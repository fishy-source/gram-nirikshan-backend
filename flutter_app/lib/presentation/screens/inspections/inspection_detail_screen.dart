// Inspection Detail Screen with GPS, Photos, Approval workflow

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/models.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;
  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspectionDetail(widget.inspectionId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final inspection = provider.selectedInspection;
        if (inspection == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = context.read<AuthProvider>().currentUser;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          body: NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(inspection.inspectionId,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inspection.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(children: [
                            _buildStatusBadge(inspection.status),
                            const SizedBox(width: 8),
                            if (inspection.panchayat != null)
                              Expanded(child: Text(
                                inspection.panchayat!.name,
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              )),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: () => _shareReport(inspection)),
                  IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => _showOptions(inspection, user)),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accentColor,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  tabs: const [
                    Tab(text: 'विवरण'),
                    Tab(text: 'GPS'),
                    Tab(text: 'फ़ोटो'),
                    Tab(text: 'अनुमोदन'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(inspection, provider),
                _buildGPSTab(inspection, provider, user),
                _buildPhotosTab(inspection),
                _buildApprovalTab(inspection, provider, user),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomActions(inspection, provider, user),
        );
      },
    );
  }

  Future<void> _runAISuggestions(String id, InspectionProvider provider) async {
    final success = await provider.suggestAIReport(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ AI रिपोर्ट मसौदा सफलतापूर्वक तैयार हो गया!' : '❌ AI जनरेशन विफल हुआ'),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDetailsTab(InspectionModel inspection, InspectionProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard('बुनियादी जानकारी', [
            _InfoRow(Icons.badge_rounded, 'निरीक्षण ID', inspection.inspectionId),
            if (inspection.inspectionType != null)
              _InfoRow(Icons.category_rounded, 'प्रकार', inspection.inspectionType!),
            if (inspection.projectName != null)
              _InfoRow(Icons.work_rounded, 'परियोजना', inspection.projectName!),
            if (inspection.projectCode != null)
              _InfoRow(Icons.qr_code_rounded, 'परियोजना कोड', inspection.projectCode!),
            if (inspection.inspectionDate != null)
              _InfoRow(Icons.calendar_today_rounded, 'निरीक्षण तिथि', _formatDate(inspection.inspectionDate!)),
            _InfoRow(Icons.person_rounded, 'अभियंता', inspection.engineer?.name ?? 'N/A'),
          ]),
          if (inspection.observations != null && inspection.observations!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard('अवलोकन (Observations)', inspection.observations!),
          ],
          if (inspection.recommendations != null && inspection.recommendations!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard('सुझाव (Recommendations)', inspection.recommendations!),
          ],
          if (inspection.actionTaken != null && inspection.actionTaken!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard('की गई कार्रवाई (Action Taken)', inspection.actionTaken!),
          ],
          const SizedBox(height: 16),
          // AI Suggested Report Card
          if (inspection.aiReportDraft != null && inspection.aiReportDraft!.isNotEmpty) ...[
            _buildTextCard('AI द्वारा सुझाया गया मसौदा (AI Suggested Draft)', inspection.aiReportDraft!),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('अवलोकन में कॉपी करें?'),
                          content: const Text('क्या आप इस AI रिपोर्ट मसौदे को अपने मुख्य अवलोकन (Observations) में कॉपी करना चाहते हैं?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करें')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('कॉपी करें')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final ok = await provider.updateInspection(inspection.id, {
                          'observations': inspection.aiReportDraft,
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? '✅ अवलोकन सफलतापूर्वक अपडेट किया गया!' : '❌ अपडेट विफल'),
                              backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                    label: const Text('अवलोकन में सेट करें', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
                  onPressed: provider.isLoading ? null : () => _runAISuggestions(inspection.id, provider),
                  tooltip: 'पुनः जनरेट करें',
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  const Icon(Icons.smart_toy_rounded, size: 36, color: AppTheme.primaryColor),
                  const SizedBox(height: 8),
                  const Text(
                    'AI से रिपोर्ट का मसौदा तैयार करवाएं',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'यह आपके निरीक्षण डेटा, पंचायत और फ़ोटो के आधार पर विभाग-अनुकूल रिपोर्ट का मसौदा तैयार करेगा।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  provider.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: () => _runAISuggestions(inspection.id, provider),
                          icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                          label: const Text('AI (Gemini) से रिपोर्ट लिखवाएं', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGPSTab(InspectionModel inspection, InspectionProvider provider, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (inspection.checkinTime != null)
            _buildInfoCard('चेक-इन विवरण', [
              _InfoRow(Icons.access_time_rounded, 'समय', _formatDateTime(inspection.checkinTime!)),
              if (inspection.checkinLatitude != null)
                _InfoRow(Icons.location_on_rounded, 'GPS',
                    '${inspection.checkinLatitude!.toStringAsFixed(6)}, ${inspection.checkinLongitude!.toStringAsFixed(6)}'),
              if (inspection.checkinAddress != null)
                _InfoRow(Icons.home_rounded, 'पता', inspection.checkinAddress!),
            ]),
          if (inspection.checkoutTime != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard('चेक-आउट विवरण', [
              _InfoRow(Icons.access_time_rounded, 'समय', _formatDateTime(inspection.checkoutTime!)),
              if (inspection.checkoutLatitude != null)
                _InfoRow(Icons.location_on_rounded, 'GPS',
                    '${inspection.checkoutLatitude!.toStringAsFixed(6)}, ${inspection.checkoutLongitude!.toStringAsFixed(6)}'),
              if (inspection.distanceCoveredKm != null)
                _InfoRow(Icons.directions_rounded, 'दूरी', '${inspection.distanceCoveredKm!.toStringAsFixed(2)} km'),
            ]),
          ],
          const SizedBox(height: 20),
          if (user?.isJE == true || user?.isAdmin == true) ...[
            if (inspection.checkinTime == null)
              ElevatedButton.icon(
                onPressed: _gpsLoading ? null : () => _handleCheckIn(inspection, provider),
                icon: const Icon(Icons.login_rounded),
                label: const Text('GPS चेक-इन करें'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
              ),
            if (inspection.isCheckedIn)
              ElevatedButton.icon(
                onPressed: _gpsLoading ? null : () => _handleCheckOut(inspection, provider),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('GPS चेक-आउट करें'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              ),
          ],
          if (_gpsLoading)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(InspectionModel inspection) {
    if (inspection.photos.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('कोई फ़ोटो नहीं', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/photos/upload', arguments: inspection.id),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('फ़ोटो जोड़ें'),
          ),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4,
      ),
      itemCount: inspection.photos.length + 1,
      itemBuilder: (context, i) {
        if (i == inspection.photos.length) {
          return InkWell(
            onTap: () => Navigator.pushNamed(context, '/photos/upload', arguments: inspection.id),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), style: BorderStyle.solid),
              ),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppTheme.primaryColor),
                SizedBox(height: 8),
                Text('फ़ोटो जोड़ें', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
              ]),
            ),
          );
        }
        final photo = inspection.photos[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            '${ApiService().toString()}/${photo.thumbnailPath ?? photo.filePath}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApprovalTab(InspectionModel inspection, InspectionProvider provider, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Workflow steps
          _buildWorkflowStepper(inspection.status),
          const SizedBox(height: 20),

          // Approval Action (for approvers)
          if (user?.canApprove == true && inspection.status == 'submitted') ...[
            _buildApprovalActions(inspection, provider),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkflowStepper(String status) {
    final steps = [
      ('मसौदा', 'draft', Icons.edit_rounded),
      ('जमा किया', 'submitted', Icons.send_rounded),
      ('सत्यापित', 'verified', Icons.verified_rounded),
      ('स्वीकृत', 'approved', Icons.check_circle_rounded),
    ];
    final statusOrder = ['draft', 'submitted', 'verified', 'approved'];
    final currentIdx = statusOrder.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('कार्यप्रवाह स्थिति', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final idx = e.key;
            final step = e.value;
            final isDone = idx <= currentIdx;
            final isReject = status == 'rejected';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? (isReject && idx == currentIdx ? AppTheme.rejectedColor : AppTheme.primaryColor) : Colors.grey.shade200,
                  ),
                  child: Icon(step.$3, size: 18,
                      color: isDone ? Colors.white : Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step.$1,
                    style: TextStyle(
                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? AppTheme.primaryColor : Colors.grey,
                      fontSize: 14,
                    ))),
                if (idx < steps.length - 1)
                  Container(width: 1, height: 20, color: isDone ? AppTheme.primaryColor : Colors.grey.shade300),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildApprovalActions(InspectionModel inspection, InspectionProvider provider) {
    final remarksCtrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('अनुमोदन कार्रवाई', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),
          TextField(
            controller: remarksCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'टिप्पणी दर्ज करें (वैकल्पिक)', labelText: 'टिप्पणी'),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => provider.approveInspection(inspection.id, 'approved', remarksCtrl.text, null),
              icon: const Icon(Icons.check_rounded),
              label: const Text('स्वीकार करें'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => provider.approveInspection(inspection.id, 'rejected', remarksCtrl.text, null),
              icon: const Icon(Icons.close_rounded),
              label: const Text('अस्वीकार करें'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor, side: const BorderSide(color: AppTheme.errorColor)),
            )),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => provider.approveInspection(inspection.id, 'forwarded', remarksCtrl.text, null),
            icon: const Icon(Icons.forward_rounded),
            label: const Text('आगे भेजें'),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomActions(InspectionModel inspection, InspectionProvider provider, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        if (inspection.isDraft && user?.isJE == true) ...[
          Expanded(child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/inspections/edit', arguments: inspection.id),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('संपादित करें'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor)),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _handleSubmit(inspection, provider),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('जमा करें'),
          )),
        ] else ...[
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _generateReport(inspection),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('PDF रिपोर्ट'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _shareReport(inspection),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('शेयर करें'),
          )),
        ],
      ]),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(_getStatusLabel(status),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInfoCard(String title, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
        const SizedBox(height: 12),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(r.icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('${r.label}: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(child: Text(r.value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTextCard(String title, String content) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
      ]),
    );
  }

  // ── Actions ────────────────────────────────────────────────────

  Future<void> _handleCheckIn(InspectionModel inspection, InspectionProvider provider) async {
    setState(() => _gpsLoading = true);
    try {
      final position = await _getCurrentPosition();
      if (position != null) {
        await provider.checkIn(inspection.id, position.latitude, position.longitude, null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ चेक-इन सफल!'), backgroundColor: AppTheme.successColor),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _handleCheckOut(InspectionModel inspection, InspectionProvider provider) async {
    setState(() => _gpsLoading = true);
    try {
      final position = await _getCurrentPosition();
      if (position != null) {
        final result = await provider.checkOut(inspection.id, position.latitude, position.longitude, null);
        if (mounted && result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ चेक-आउट! दूरी: ${result['distance_km']?.toStringAsFixed(2) ?? 'N/A'} km'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<Position?> _getCurrentPosition() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _handleSubmit(InspectionModel inspection, InspectionProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('निरीक्षण जमा करें?'),
        content: const Text('क्या आप इस निरीक्षण को अनुमोदन के लिए जमा करना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करें')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('जमा करें')),
        ],
      ),
    );
    if (confirm == true) {
      final success = await provider.submitInspection(inspection.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '✅ जमा सफल!' : '❌ जमा विफल'), backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _generateReport(InspectionModel inspection) async {
    try {
      await ApiService().generateReport(inspection.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF रिपोर्ट तैयार!'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ रिपोर्ट विफल: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _shareReport(InspectionModel inspection) {
    Share.share('Gram Nirikshan Report\nInspection: ${inspection.inspectionId}\n${inspection.title}');
  }

  void _showOptions(InspectionModel inspection, UserModel? user) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('PDF जनरेट करें'),
            onTap: () { Navigator.pop(context); _generateReport(inspection); }),
        ListTile(leading: const Icon(Icons.share_rounded), title: const Text('शेयर करें'),
            onTap: () { Navigator.pop(context); _shareReport(inspection); }),
        if (inspection.panchayat?.latitude != null)
          ListTile(
            leading: const Icon(Icons.map_rounded),
            title: const Text('मानचित्र पर देखें'),
            onTap: () {
              Navigator.pop(context);
              final lat = inspection.panchayat!.latitude!;
              final lng = inspection.panchayat!.longitude!;
              launchUrl(Uri.parse('https://maps.google.com/?q=$lat,$lng'));
            },
          ),
      ]),
    ));
  }

  String _getStatusLabel(String status) {
    const m = {'draft': 'मसौदा', 'submitted': 'जमा', 'verified': 'सत्यापित', 'approved': 'स्वीकृत', 'rejected': 'अस्वीकृत'};
    return m[status] ?? status;
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  String _formatDateTime(DateTime dt) => '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoRow {
  final IconData icon;
  final String label, value;
  _InfoRow(this.icon, this.label, this.value);
}
