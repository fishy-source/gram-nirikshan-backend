// Inspection List Screen with filter chips and search

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/inspection_provider.dart';
import '../../../data/models/models.dart';
import 'inspection_detail_screen.dart';

class InspectionListScreen extends StatefulWidget {
  const InspectionListScreen({super.key});

  @override
  State<InspectionListScreen> createState() => _InspectionListScreenState();
}

class _InspectionListScreenState extends State<InspectionListScreen> {
  final _scrollController = ScrollController();
  String? _selectedStatus;

  final _statuses = [
    (null, 'सभी', Icons.list_rounded),
    ('draft', 'मसौदा', Icons.edit_rounded),
    ('submitted', 'जमा', Icons.send_rounded),
    ('verified', 'सत्यापित', Icons.verified_rounded),
    ('approved', 'स्वीकृत', Icons.check_circle_rounded),
    ('rejected', 'अस्वीकृत', Icons.cancel_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspections(refresh: true);
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        context.read<InspectionProvider>().loadInspections();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('निरीक्षण सूची'),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: _showSearch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/inspections/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('नया निरीक्षण'),
        backgroundColor: AppTheme.accentColor,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: Consumer<InspectionProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.inspections.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.inspections.isEmpty) {
                  return _buildEmpty();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.inspections.length + (provider.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == provider.inspections.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    return _buildInspectionCard(context, provider.inspections[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _statuses.map((s) {
            final isSelected = _selectedStatus == s.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(children: [
                  Icon(s.$3, size: 14, color: isSelected ? Colors.white : Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(s.$2),
                ]),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedStatus = s.$1);
                  context.read<InspectionProvider>().setFilter(s.$1);
                },
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInspectionCard(BuildContext context, InspectionModel inspection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => InspectionDetailScreen(inspectionId: inspection.id),
        )),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(inspection.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(inspection.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.badge_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(inspection.inspectionId, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              if (inspection.panchayat != null)
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    '${inspection.panchayat!.name}, ${inspection.panchayat!.district}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ]),
              if (inspection.inspectionType != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.category_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(inspection.inspectionType!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_formatDate(inspection.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  Row(children: [
                    const Icon(Icons.photo_library_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${inspection.photos.length} फ़ोटो', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (inspection.isCheckedIn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(children: [
                          Icon(Icons.location_on_rounded, size: 10, color: AppTheme.successColor),
                          SizedBox(width: 2),
                          Text('चेक-इन', style: TextStyle(fontSize: 10, color: AppTheme.successColor, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.statusBgColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getStatusLabel(String status) {
    const m = {'draft': 'मसौदा', 'submitted': 'जमा', 'verified': 'सत्यापित', 'approved': 'स्वीकृत', 'rejected': 'अस्वीकृत'};
    return m[status] ?? status;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('कोई निरीक्षण नहीं', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('नया निरीक्षण बनाने के लिए + बटन दबाएं', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  void _showSearch() {
    showSearch(context: context, delegate: _InspectionSearchDelegate());
  }
}

class _InspectionSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'निरीक्षण खोजें...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    final inspections = context.read<InspectionProvider>().inspections
        .where((i) => i.title.toLowerCase().contains(query.toLowerCase()) ||
                      i.inspectionId.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inspections.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(inspections[i].title),
        subtitle: Text(inspections[i].inspectionId),
        onTap: () => close(context, inspections[i].id),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
