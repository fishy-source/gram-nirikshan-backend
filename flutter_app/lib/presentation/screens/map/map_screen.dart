import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/inspection_provider.dart';
import '../../../data/models/models.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  InspectionModel? _selectedInspection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspections(refresh: true).then((_) {
        _buildMarkers();
      });
    });
  }

  void _buildMarkers() {
    final inspections = context.read<InspectionProvider>().inspections;
    final Set<Marker> markers = {};

    for (final ins in inspections) {
      double? lat = ins.checkinLatitude;
      double? lng = ins.checkinLongitude;

      // Fallback to panchayat coordinates if check-in doesn't exist
      if (lat == null || lng == null) {
        lat = ins.panchayat?.latitude;
        lng = ins.panchayat?.longitude;
      }

      if (lat != null && lng != null) {
        // Choose color based on status
        BitmapDescriptor markerIcon;
        if (ins.status == 'approved') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        } else if (ins.status == 'rejected') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        } else if (ins.status == 'submitted' || ins.status == 'verified') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        } else {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        }

        markers.add(
          Marker(
            markerId: MarkerId(ins.id),
            position: LatLng(lat, lng),
            icon: markerIcon,
            infoWindow: InfoWindow(
              title: ins.inspectionId,
              snippet: ins.title,
            ),
            onTap: () {
              setState(() {
                _selectedInspection = ins;
              });
            },
          ),
        );
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_markers.isNotEmpty && _markers.first.position != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_markers.first.position, 12),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspections = context.watch<InspectionProvider>().inspections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('निरीक्षण नक्शा', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              zoom: 8.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Bottom card showing details of tapped marker
          if (_selectedInspection != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedInspection!.inspectionId,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _selectedInspection = null),
                          ),
                        ],
                      ),
                      Text(
                        _selectedInspection!.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ग्राम पंचायत: ${_selectedInspection!.panchayat?.nameHindi ?? _selectedInspection!.panchayat?.name ?? "N/A"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_selectedInspection!.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppConstants.statusLabels[_selectedInspection!.status] ?? _selectedInspection!.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_selectedInspection!.status),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/inspections/detail',
                                arguments: _selectedInspection!.id,
                              );
                            },
                            child: const Text('विवरण देखें', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
