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
import '../../providers/language_provider.dart';
import '../../../core/constants/app_constants.dart';
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
  late TextEditingController _remarksCtrl;
  late TextEditingController _refinePromptCtrl;
  bool _gpsLoading = false;
  bool _isRefining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _remarksCtrl = TextEditingController();
    _refinePromptCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspectionDetail(widget.inspectionId);
      context.read<InspectionProvider>().loadApprovalHistory(widget.inspectionId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _remarksCtrl.dispose();
    _refinePromptCtrl.dispose();
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
                title: Text(inspection.isDraft ? '' : inspection.inspectionId,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                flexibleSpace: FlexibleSpaceBar(
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
                  IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: () => _showLanguageSelection(inspection)),
                  IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => _showOptions(inspection, user)),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accentColor,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  tabs: [
                    Tab(text: context.tr('details_tab')),
                    Tab(text: context.tr('gps_tab')),
                    Tab(text: context.tr('photos_tab')),
                    Tab(text: context.tr('approval_tab')),
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
          content: Text(success ? context.tr('ai_generation_success') : context.tr('ai_generation_failed')),
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
          _buildInfoCard(context.tr('basic_info'), [
            if (!inspection.isDraft)
              _InfoRow(Icons.badge_rounded, context.tr('inspection_id'), inspection.inspectionId),
            if (inspection.investigatorName != null && inspection.investigatorName!.isNotEmpty)
              _InfoRow(Icons.person_outline_rounded, context.tr('investigator_name_label'), inspection.investigatorName!),
            if (inspection.district != null && inspection.district!.isNotEmpty)
              _InfoRow(Icons.map_rounded, context.tr('district'), inspection.district!),
            if (inspection.block != null && inspection.block!.isNotEmpty)
              _InfoRow(Icons.location_on_rounded, context.tr('block'), inspection.block!),
            if (inspection.inspectionType != null)
              _InfoRow(Icons.category_rounded, context.tr('inspection_type'), inspection.inspectionType!),
            if (inspection.projectName != null)
              _InfoRow(Icons.work_rounded, context.tr('project_name'), inspection.projectName!),
            if (inspection.projectCode != null)
              _InfoRow(Icons.qr_code_rounded, context.tr('project_code'), inspection.projectCode!),
            if (inspection.inspectionDate != null)
              _InfoRow(Icons.calendar_today_rounded, context.tr('inspection_date'), _formatDate(inspection.inspectionDate!)),
            _InfoRow(Icons.person_rounded, context.tr('engineers'), inspection.engineer?.name ?? 'N/A'),
          ]),
          if (!inspection.isDraft) ...[
            const SizedBox(height: 12),
            _buildInfoCard(context.tr('approval_review_details'), [
              _InfoRow(Icons.info_outline_rounded, context.tr('current_status'), context.tr(inspection.status)),
              if (inspection.status == 'submitted')
                _InfoRow(Icons.person_outline_rounded, context.tr('sent_to'), context.tr('ae_pending')),
              if (inspection.status == 'forwarded')
                _InfoRow(Icons.forward_rounded, context.tr('sent_to'), context.tr('xen_pending')),
              if (inspection.status == 'approved')
                _InfoRow(Icons.check_circle_outline_rounded, context.tr('verification_approval'), context.tr('officer_approved')),
              if (inspection.status == 'rejected')
                _InfoRow(Icons.highlight_off_rounded, context.tr('verification_approval'), context.tr('officer_rejected')),
            ]),
          ],
          if (inspection.observations != null && inspection.observations!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard(context.tr('observations'), inspection.observations!),
          ],
          if (inspection.recommendations != null && inspection.recommendations!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard(context.tr('recommendations'), inspection.recommendations!),
          ],
          if (inspection.actionTaken != null && inspection.actionTaken!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard(context.tr('action_taken'), inspection.actionTaken!),
          ],
          const SizedBox(height: 16),
            // AI Suggested Report Card
            if (inspection.aiReportDraft != null && inspection.aiReportDraft!.isNotEmpty) ...[
              _buildTextCard(context.tr('ai_draft'), inspection.aiReportDraft!),
              const SizedBox(height: 8),

              // Refine Report UI
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.read<LanguageProvider>().isHindi ? 'अतिरिक्त निर्देश (Additional Prompt)' : 'Additional Prompt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _refinePromptCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: context.read<LanguageProvider>().isHindi ? 'उदाहरण: इसे और छोटा करें' : 'Example: Make it shorter',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRefining ? null : () async {
                          if (_refinePromptCtrl.text.trim().isEmpty) return;
                          setState(() { _isRefining = true; });
                          try {
                            final lang = context.read<LanguageProvider>().isHindi ? 'hi' : 'en';
                            await ApiService().refineReport(inspection.id, inspection.aiReportDraft!, _refinePromptCtrl.text.trim(), language: lang);
                            await context.read<InspectionProvider>().loadInspectionDetail(inspection.id);
                            _refinePromptCtrl.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<LanguageProvider>().isHindi ? 'रिपोर्ट सफलतापूर्वक सही की गई!' : 'Report refined successfully!'), backgroundColor: AppTheme.successColor));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
                            }
                          } finally {
                            if (mounted) setState(() { _isRefining = false; });
                          }
                        },
                        icon: _isRefining ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_fix_high, size: 16, color: Colors.white),
                        label: Text(context.read<LanguageProvider>().isHindi ? 'रिपोर्ट सही करें (Refine Report)' : 'Refine Report', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(context.tr('copy_to_observations')),
                          content: Text(context.tr('copy_confirm')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('copy'))),
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
                              content: Text(ok ? context.tr('observations_update_success') : context.tr('update_failed')),
                              backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                    label: Text(context.tr('set_to_observations'), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
                  onPressed: provider.isLoading ? null : () => _runAISuggestions(inspection.id, provider),
                  tooltip: context.tr('regenerate'),
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
                  Text(
                    context.tr('get_ai_draft'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('get_ai_draft_sub'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  provider.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: () => _runAISuggestions(inspection.id, provider),
                          icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                          label: Text(context.tr('generate_ai_report'), style: const TextStyle(color: Colors.white)),
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
            _buildInfoCard(context.tr('checkin_details'), [
              _InfoRow(Icons.access_time_rounded, context.tr('time'), _formatDateTime(inspection.checkinTime!)),
              if (inspection.checkinLatitude != null)
                _InfoRow(Icons.location_on_rounded, context.tr('gps'),
                    '${inspection.checkinLatitude!.toStringAsFixed(6)}, ${inspection.checkinLongitude!.toStringAsFixed(6)}'),
              if (inspection.checkinAddress != null)
                _InfoRow(Icons.home_rounded, context.tr('address'), inspection.checkinAddress!),
            ]),
          if (inspection.checkoutTime != null) ...[
            const SizedBox(height: 12),
            _buildInfoCard(context.tr('checkout_details'), [
              _InfoRow(Icons.access_time_rounded, context.tr('time'), _formatDateTime(inspection.checkoutTime!)),
              if (inspection.checkoutLatitude != null)
                _InfoRow(Icons.location_on_rounded, context.tr('gps'),
                    '${inspection.checkoutLatitude!.toStringAsFixed(6)}, ${inspection.checkoutLongitude!.toStringAsFixed(6)}'),
              if (inspection.distanceCoveredKm != null)
                _InfoRow(Icons.directions_rounded, context.tr('distance'), '${inspection.distanceCoveredKm!.toStringAsFixed(2)} km'),
            ]),
          ],
          if (inspection.mapImagePath != null && inspection.mapImagePath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('inspection_location_map'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '${AppConstants.baseUrl.replaceAll('/api/v1', '')}/${inspection.mapImagePath}',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (user?.isInspector == true || user?.isAdmin == true) ...[
            if (inspection.checkinTime == null)
              ElevatedButton.icon(
                onPressed: _gpsLoading ? null : () => _handleCheckIn(inspection, provider),
                icon: const Icon(Icons.login_rounded),
                label: Text(context.tr('gps_checkin')),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
              ),
            if (inspection.isCheckedIn)
              ElevatedButton.icon(
                onPressed: _gpsLoading ? null : () => _handleCheckOut(inspection, provider),
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.tr('gps_checkout_action')),
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
          Text(context.tr('no_photos'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/photos/upload', arguments: inspection.id),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(context.tr('add_photo')),
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
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppTheme.primaryColor),
                const SizedBox(height: 8),
                Text(context.tr('add_photo'), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
              ]),
            ),
          );
        }
        final photo = inspection.photos[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            '${AppConstants.baseUrl.replaceAll('/api/v1', '')}/${photo.thumbnailPath ?? photo.filePath}',
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

          // Approval Trail / History
          if (provider.approvals.isNotEmpty) ...[
            _buildApprovalHistoryCard(provider.approvals),
            const SizedBox(height: 20),
          ],

          // Forward Action
          if (inspection.status != 'approved' && inspection.status != 'rejected') ...[
            _buildForwardAction(inspection, provider),
            const SizedBox(height: 20),
          ],

          // Approval Action (for approvers)
          if (user?.canApprove == true && (inspection.status == 'submitted' || inspection.status == 'forwarded')) ...[
            _buildApprovalActions(inspection, provider),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkflowStepper(String status) {
    final steps = [
      (context.tr('draft'), 'draft', Icons.edit_rounded),
      (context.tr('submitted'), 'submitted', Icons.send_rounded),
      (context.tr('forwarded'), 'forwarded', Icons.forward_rounded),
      (context.tr('approved'), 'approved', Icons.check_circle_rounded),
    ];
    final statusOrder = ['draft', 'submitted', 'forwarded', 'approved'];
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
          Text(context.tr('workflow_status'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('approval_action'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksCtrl,
            maxLines: 3,
            decoration: InputDecoration(hintText: context.tr('enter_remarks_optional'), labelText: context.tr('remarks')),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _handleApprovalAction(inspection.id, 'approved', _remarksCtrl.text, provider),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr('approve')),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                if (_remarksCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(context.read<LanguageProvider>().isHindi ? 'अस्वीकृत करने के लिए कारण (Remarks) लिखना अनिवार्य है' : 'Remarks are required for rejection'),
                    backgroundColor: AppTheme.errorColor,
                  ));
                  return;
                }
                _handleApprovalAction(inspection.id, 'rejected', _remarksCtrl.text, provider);
              },
              icon: const Icon(Icons.close_rounded),
              label: Text(context.tr('reject')),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor, side: const BorderSide(color: AppTheme.errorColor)),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildForwardAction(InspectionModel inspection, InspectionProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showForwardModal(context, inspection, provider),
        icon: const Icon(Icons.forward_rounded),
        label: Text(context.tr('forward')),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppTheme.primaryColor),
          elevation: 2,
        ),
      ),
    );
  }

  void _showForwardModal(BuildContext context, InspectionModel inspection, InspectionProvider provider) {
    final designationCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.read<LanguageProvider>().isHindi ? 'निरीक्षण अग्रेषित करें' : 'Forward Inspection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final options = ['AE', 'XEN', 'CDO', 'DPRO', 'DM', 'SDM', 'BDO'];
                    if (textEditingValue.text.isEmpty) {
                      return options;
                    }
                    return options.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    designationCtrl.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    // Update main controller when this changes
                    controller.addListener(() {
                      designationCtrl.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: context.read<LanguageProvider>().isHindi ? 'प्राप्तकर्ता का पद (चुनें या टाइप करें)' : 'Recipient Designation (Type or Select)',
                        border: const OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactCtrl,
                  decoration: InputDecoration(
                    labelText: context.read<LanguageProvider>().isHindi ? 'प्राप्तकर्ता का मोबाइल/ईमेल' : 'Recipient Contact',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.read<LanguageProvider>().isHindi ? 'टिप्पणी (वैकल्पिक)' : 'Remarks (Optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.read<LanguageProvider>().isHindi ? 'रद्द करें' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (designationCtrl.text.isEmpty || contactCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.read<LanguageProvider>().isHindi ? 'पद और संपर्क अनिवार्य हैं' : 'Designation and contact are required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _handleForwardAction(inspection.id, designationCtrl.text, contactCtrl.text, remarksCtrl.text, provider);
              },
              child: Text(context.read<LanguageProvider>().isHindi ? 'अग्रेषित करें' : 'Forward'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleForwardAction(String id, String designation, String contact, String remarks, InspectionProvider provider) async {
    final success = await provider.forwardInspection(id, designation, contact, remarks);
    if (mounted) {
      final isHindi = context.read<LanguageProvider>().isHindi;
      String msg = success 
          ? (isHindi ? "➡️ निरीक्षण सफलतापूर्वक अग्रेषित (Forward) कर दिया गया है।" : "➡️ Inspection forwarded successfully.")
          : (isHindi ? "⚠️ कार्रवाई विफल रही। कृपया पुनः प्रयास करें।" : "⚠️ Action failed. Please try again.");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handleApprovalAction(String id, String action, String remarks, InspectionProvider provider) async {
    final success = await provider.approveInspection(id, action, remarks, null);
    if (mounted) {
      final isHindi = context.read<LanguageProvider>().isHindi;
      String msg = "";
      if (success) {
        _remarksCtrl.clear();
        if (action == 'approved') {
          msg = isHindi ? "✅ निरीक्षण स्वीकृत (Approved) कर दिया गया है।" : "✅ Inspection approved successfully.";
        } else if (action == 'rejected') {
          msg = isHindi ? "❌ निरीक्षण अस्वीकृत (Rejected) कर दिया गया है।" : "❌ Inspection rejected.";
        } else {
          msg = isHindi ? "➡️ निरीक्षण अगले स्तर पर अग्रेषित (Forwarded) कर दिया गया है।" : "➡️ Inspection forwarded successfully.";
        }
      } else {
        msg = isHindi ? "⚠️ कार्रवाई विफल रही। कृपया पुनः प्रयास करें।" : "⚠️ Action failed. Please try again.";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildBottomActions(InspectionModel inspection, InspectionProvider provider, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        if (inspection.isDraft && (user?.isInspector == true || user?.isAdmin == true)) ...[
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _handleSubmit(inspection, provider),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text('${context.tr('submit_inspection_btn')} (${context.tr('submit')})'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          )),
        ] else ...[
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _showLanguageSelection(inspection),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(context.tr('pdf_report')),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _showLanguageSelection(inspection),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(context.tr('share')),
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(r.icon, size: 16, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(r.value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ),
            ),
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
            SnackBar(content: Text(context.tr('checkin_success')), backgroundColor: AppTheme.successColor),
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
          final isHindi = context.read<LanguageProvider>().isHindi;
          final distStr = result['distance_km']?.toStringAsFixed(2) ?? 'N/A';
          final msg = isHindi 
              ? '✅ चेक-आउट! दूरी: $distStr किमी' 
              : '✅ Checked out! Distance: $distStr km';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
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
        title: Text(context.tr('submit_inspection_confirm_title')),
        content: Text(context.tr('submit_inspection_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('submit'))),
        ],
      ),
    );
    if (confirm == true) {
      final success = await provider.submitInspection(inspection.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? context.tr('submit_success') : context.tr('submit_failed')),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showLanguageSelection(InspectionModel inspection) async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.read<LanguageProvider>().isHindi ? 'रिपोर्ट की भाषा चुनें' : 'Select Report Language',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Colors.blue),
              title: const Text('English (अंग्रेज़ी)'),
              onTap: () {
                Navigator.pop(context);
                _openPdfPreview(inspection, 'pdf_en');
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Colors.green),
              title: const Text('Hindi (हिन्दी)'),
              onTap: () {
                Navigator.pop(context);
                _openPdfPreview(inspection, 'pdf_hi');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPdfPreview(InspectionModel inspection, String format) {
    Navigator.pushNamed(
      context,
      '/reports/preview',
      arguments: {
        'inspectionId': inspection.id,
        'title': inspection.title,
        'format': format,
      },
    );
  }

  void _showOptions(InspectionModel inspection, UserModel? user) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.picture_as_pdf_rounded), title: Text(context.tr('generate_pdf')),
            onTap: () { Navigator.pop(context); _showLanguageSelection(inspection); }),
        ListTile(leading: const Icon(Icons.share_rounded), title: Text(context.tr('share')),
            onTap: () { Navigator.pop(context); _showLanguageSelection(inspection); }),
        if (inspection.panchayat?.latitude != null)
          ListTile(
            leading: const Icon(Icons.map_rounded),
            title: Text(context.tr('view_on_map')),
            onTap: () {
              Navigator.pop(context);
              final lat = inspection.panchayat!.latitude!;
              final lng = inspection.panchayat!.longitude!;
              launchUrl(Uri.parse('https://maps.google.com/?q=$lat,$lng'));
            },
          ),
        if (user?.isAdmin == true)
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(context.tr('delete_inspection'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(inspection);
            },
          ),
      ]),
    ));
  }

  Future<void> _confirmDelete(InspectionModel inspection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('delete_confirm_title')),
        content: Text(context.tr('delete_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(context.tr('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        final provider = context.read<InspectionProvider>();
        final ok = await provider.deleteInspection(inspection.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? context.tr('delete_success') : context.tr('delete_failed')),
              backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
            ),
          );
          if (ok) {
            Navigator.pop(context); // Go back to list
          }
        }
      }
    }
  }

  String _getStatusLabel(String status) {
    return context.tr(status);
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  String _formatDateTime(DateTime dt) => '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildApprovalHistoryCard(List<ApprovalModel> approvals) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('approval_history'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: approvals.length,
            itemBuilder: (context, idx) {
              final a = approvals[idx];
              final actionLabel = _getApprovalActionLabel(a.action);
              final statusColor = _getApprovalActionColor(a.action);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${context.tr('level')}: ${a.level}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            actionLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('officer')}: ${a.approver?.nameHindi ?? a.approver?.name ?? context.tr('unknown_officer')} (${a.approver?.designation ?? 'N/A'})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (a.remarks != null && a.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${context.tr('remarks')}: ${a.remarks}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('date')}: ${_formatDateTime(a.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getApprovalActionLabel(String action) {
    return context.tr(action);
  }

  Color _getApprovalActionColor(String action) {
    switch (action) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'forwarded':
        return AppTheme.primaryColor;
      default:
        return Colors.orange;
    }
  }
}

class _InfoRow {
  final IconData icon;
  final String label, value;
  _InfoRow(this.icon, this.label, this.value);
}
