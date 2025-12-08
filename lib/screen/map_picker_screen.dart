import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/map_service.dart';

/// Map Picker Screen
/// Interactive Map for selecting delivery location in Oroquieta City using Flutter Map
class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedLocation = LatLng(
    MapService.oroquietaLatitude,
    MapService.oroquietaLongitude,
  );
  String _selectedAddress = 'Loading address...';
  double _latitude = MapService.oroquietaLatitude;
  double _longitude = MapService.oroquietaLongitude;
  bool _isLoadingAddress = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Oroquieta City boundary polygon points
  static final List<LatLng> _oroquietaBoundaryPoints = [
    LatLng(8.5800, 123.7000),
    LatLng(8.5900, 123.7500),
    LatLng(8.6000, 123.8000),
    LatLng(8.5900, 123.8500),
    LatLng(8.5800, 123.9000),
    LatLng(8.5500, 123.9000),
    LatLng(8.5000, 123.9000),
    LatLng(8.4500, 123.9000),
    LatLng(8.4000, 123.9000),
    LatLng(8.4000, 123.8500),
    LatLng(8.4000, 123.8000),
    LatLng(8.4000, 123.7500),
    LatLng(8.4000, 123.7000),
    LatLng(8.4500, 123.7000),
    LatLng(8.5000, 123.7000),
    LatLng(8.5500, 123.7000),
    LatLng(8.5800, 123.7000),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();

    // Listen to map movement
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        final newLocation = _clampToOroquietaBounds(
          event.camera.center.latitude,
          event.camera.center.longitude,
        );

        if (mounted) {
          setState(() {
            _selectedLocation = newLocation;
            _latitude = newLocation.latitude;
            _longitude = newLocation.longitude;
          });
        }
      }

      if (event is MapEventMoveEnd) {
        final newLocation = _clampToOroquietaBounds(
          event.camera.center.latitude,
          event.camera.center.longitude,
        );

        if (mounted) {
          setState(() {
            _selectedLocation = newLocation;
            _latitude = newLocation.latitude;
            _longitude = newLocation.longitude;
          });
          _updateAddress();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // Use initial location if provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      final lat = widget.initialLatitude!;
      final lng = widget.initialLongitude!;
      _selectedLocation = _clampToOroquietaBounds(lat, lng);
      _latitude = _selectedLocation.latitude;
      _longitude = _selectedLocation.longitude;
      _updateAddress();

      // Move map to location
      _mapController.move(_selectedLocation, 15.0);
    } else {
      // Use default Oroquieta City center with zoom 15 for barangay view
      _selectedLocation = LatLng(
        MapService.oroquietaLatitude,
        MapService.oroquietaLongitude,
      );
      _latitude = _selectedLocation.latitude;
      _longitude = _selectedLocation.longitude;
      _updateAddress();

      // Move map to default location
      _mapController.move(_selectedLocation, 15.0);
    }
  }

  LatLng _clampToOroquietaBounds(double latitude, double longitude) {
    final lat = latitude.clamp(MapService.minLatitude, MapService.maxLatitude);
    final lng = longitude.clamp(
      MapService.minLongitude,
      MapService.maxLongitude,
    );
    return LatLng(lat, lng);
  }

  Future<void> _updateAddress() async {
    setState(() => _isLoadingAddress = true);

    try {
      final address = await MapService.coordinatesToAddress(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = address ?? 'Oroquieta City';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Error updating address: $e');
      if (mounted) {
        setState(() {
          _selectedAddress = 'Oroquieta City';
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    final clamped = _clampToOroquietaBounds(point.latitude, point.longitude);

    setState(() {
      _selectedLocation = clamped;
      _latitude = clamped.latitude;
      _longitude = clamped.longitude;
    });

    // Move map to tapped location
    _mapController.move(clamped, _mapController.camera.zoom);
    _updateAddress();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      // Try multiple search variations for better results
      List<String> searchQueries = [];
      final trimmedQuery = query.trim();

      // Original query
      searchQueries.add(trimmedQuery);

      // With Oroquieta City
      if (!trimmedQuery.toLowerCase().contains('oroquieta')) {
        searchQueries.add('$trimmedQuery, Oroquieta City');
        searchQueries.add('$trimmedQuery, Oroquieta City, Philippines');
        searchQueries.add('$trimmedQuery, Misamis Occidental, Philippines');
        searchQueries.add('$trimmedQuery, Misamis Occidental');
      }

      // Try with barangay prefix variations
      final lowerQuery = trimmedQuery.toLowerCase();
      if (!lowerQuery.startsWith('barangay') &&
          !lowerQuery.startsWith('brgy') &&
          !lowerQuery.startsWith('brg') &&
          !lowerQuery.startsWith('bgy')) {
        searchQueries.add('Barangay $trimmedQuery');
        searchQueries.add('Barangay $trimmedQuery, Oroquieta City');
        searchQueries.add('Brgy $trimmedQuery');
        searchQueries.add('Brgy $trimmedQuery, Oroquieta City');
        searchQueries.add('Bgy $trimmedQuery, Oroquieta City');
      }

      // Try common barangay names in Oroquieta City
      final commonBarangays = [
        'Talairon',
        'Tabuc',
        'Poblacion',
        'Rizal',
        'Puntod',
        'Mansabay Bajo',
        'Mansabay Alto',
        'Mobod',
        'Canubay',
        'Dulapo',
        'Tuyabang Alto',
        'Tuyabang Bajo',
        'San Vicente Alto',
        'San Vicente Bajo',
        'Buntawan',
        'Buenavista',
        'Villaflor',
        'Molatuhan Alto',
        'Molatuhan Bajo',
        'Alegria',
        'Paypayan',
        'Dolipos Bajo',
        'Dolipos Alto',
        'Lopez Jaena',
        'Sibugon',
        'Lower Langcangan',
        'Upper Langcangan',
      ];

      // Check if query matches any common barangay (case-insensitive)
      for (String barangay in commonBarangays) {
        if (lowerQuery == barangay.toLowerCase() ||
            lowerQuery.contains(barangay.toLowerCase()) ||
            barangay.toLowerCase().contains(lowerQuery)) {
          searchQueries.add('Barangay $barangay, Oroquieta City');
          searchQueries.add('$barangay, Oroquieta City');
          searchQueries.add('$barangay, Oroquieta City, Philippines');
          break;
        }
      }

      LatLng? foundCoordinates;

      // Try each search query until one succeeds
      for (String searchQuery in searchQueries) {
        try {
          final coordinates = await MapService.addressToCoordinates(
            searchQuery,
          );
          if (coordinates != null) {
            foundCoordinates = coordinates;
            break; // Found a match, stop searching
          }
        } catch (e) {
          debugPrint('Search query "$searchQuery" failed: $e');
          continue; // Try next query
        }
      }

      if (foundCoordinates != null && mounted) {
        final clamped = _clampToOroquietaBounds(
          foundCoordinates.latitude,
          foundCoordinates.longitude,
        );

        setState(() {
          _selectedLocation = clamped;
          _latitude = clamped.latitude;
          _longitude = clamped.longitude;
        });

        // Move camera to searched location
        _mapController.move(clamped, 15.0);
        _updateAddress();

        // Clear search field on success
        _searchController.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location "$query" not found. Try searching for:\n• Barangay names (e.g., "Barangay Talairon")\n• Street names\n• Landmarks in Oroquieta City',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _confirmSelection() async {
    // Get detailed address
    final detailedAddress = await MapService.getDetailedAddress(
      _selectedLocation.latitude,
      _selectedLocation.longitude,
    );

    if (mounted) {
      Navigator.pop(context, {
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': _selectedAddress,
        'fullAddress': detailedAddress['fullAddress'] ?? _selectedAddress,
        'street': detailedAddress['street'] ?? '',
        'locality': detailedAddress['locality'] ?? 'Oroquieta City',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0, // Zoom level 15 for barangay view
              minZoom: 12.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) => _onMapTap(tapPosition, point),
            ),
            children: [
              // Google Maps-style tile layer (using CartoDB Positron for Google-like appearance)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.fleximart',
                maxZoom: 20,
              ),

              // Oroquieta City boundary polygon
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _oroquietaBoundaryPoints,
                    color: Colors.red.withOpacity(0.1),
                    borderColor: Colors.red,
                    borderStrokeWidth: 3,
                    isFilled: true,
                  ),
                ],
              ),

              // Selected location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Search bar at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search barangay, street, or landmark...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: _searchLocation,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    if (_isSearching)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.search),
                        color: AppColors.primary,
                        onPressed: () =>
                            _searchLocation(_searchController.text),
                        tooltip: 'Search',
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Address preview card
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLoadingAddress
                                ? 'Loading address...'
                                : _selectedAddress,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            'Latitude',
                            _latitude.toStringAsFixed(6),
                            Icons.my_location,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow(
                            'Longitude',
                            _longitude.toStringAsFixed(6),
                            Icons.explore,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                final position = await MapService.getCurrentLocation();
                if (position != null) {
                  final clamped = _clampToOroquietaBounds(
                    position.latitude,
                    position.longitude,
                  );
                  setState(() {
                    _selectedLocation = clamped;
                    _latitude = clamped.latitude;
                    _longitude = clamped.longitude;
                  });

                  _mapController.move(clamped, 15.0);
                  _updateAddress();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not get current location'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // Confirm button at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
