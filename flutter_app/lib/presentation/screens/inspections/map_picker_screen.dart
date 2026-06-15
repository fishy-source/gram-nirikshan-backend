import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/language_provider.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _address = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      _getAddressFromLatLng(_selectedLocation!);
      _isLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _getAddressFromLatLng(_selectedLocation!);
      
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedLocation!, zoom: 18, tilt: 60, bearing: 45),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedLocation!, zoom: 18, tilt: 60, bearing: 45),
        ),
      );
    }
  }

  void _onCameraIdle() {
    if (_selectedLocation != null) {
      _getAddressFromLatLng(_selectedLocation!);
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLocation = position.target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isHindi = lang.isHindi;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'स्थान चुनें' : 'Select Location'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(26.8467, 80.9462), // Default to UP
                    zoom: 18,
                    tilt: 60,
                    bearing: 45,
                  ),
                  mapType: MapType.satellite,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),
          
          // Center Marker
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35), // Offset for pin height
              child: Icon(Icons.location_pin, size: 40, color: Colors.red),
            ),
          ),
          
          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address.isNotEmpty ? _address : (isHindi ? 'स्थान प्राप्त कर रहा है...' : 'Fetching location...'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedLocation != null) {
                        Navigator.pop(context, {
                          'latitude': _selectedLocation!.latitude,
                          'longitude': _selectedLocation!.longitude,
                          'address': _address,
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isHindi ? 'यह स्थान पुष्टि करें' : 'Confirm this location',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
