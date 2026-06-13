import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/language_provider.dart';
import '../../../data/models/models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<InspectionModel>> _inspectionsByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspections(refresh: true).then((_) {
        _groupInspections();
      });
    });
  }

  void _groupInspections() {
    final inspections = context.read<InspectionProvider>().inspections;
    final Map<DateTime, List<InspectionModel>> grouped = {};

    for (final ins in inspections) {
      if (ins.inspectionDate != null) {
        // Strip out time part of DateTime for grouping
        final date = DateTime(ins.inspectionDate!.year, ins.inspectionDate!.month, ins.inspectionDate!.day);
        if (grouped[date] == null) {
          grouped[date] = [];
        }
        grouped[date]!.add(ins);
      }
    }

    setState(() {
      _inspectionsByDate.clear();
      _inspectionsByDate.addAll(grouped);
    });
  }

  List<InspectionModel> _getInspectionsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _inspectionsByDate[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedInspections = _getInspectionsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(context.tr('inspection_calendar'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Table Calendar Card
          Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TableCalendar<InspectionModel>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                locale: context.watch<LanguageProvider>().isHindi ? 'hi_IN' : 'en_US',
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: _getInspectionsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
              ),
            ),
          ),

          // Selected day heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  _selectedDay == null
                      ? context.tr('select_date_prompt')
                      : '${context.tr('inspections')} - ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selected day inspections list
          Expanded(
            child: selectedInspections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(context.tr('no_inspections_on_date'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedInspections.length,
                    itemBuilder: (context, index) {
                      final ins = selectedInspections[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            ins.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                context.read<LanguageProvider>().isHindi 
                                    ? 'ग्राम पंचायत: ${ins.panchayat?.nameHindi ?? ins.panchayat?.name ?? "N/A"}' 
                                    : 'Gram Panchayat: ${ins.panchayat?.name ?? ins.panchayat?.nameHindi ?? "N/A"}',
                              ),
                              const SizedBox(height: 2),
                              Text('ID: ${ins.inspectionId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(ins.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr(ins.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(ins.status),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/inspections/detail',
                              arguments: ins.id,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'submitted':
      case 'verified':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }
}
