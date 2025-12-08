import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

/// Order Map Screen
/// Shows delivery location for a single order
class OrderMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final String? orderId;
  final String? customerName;

  const OrderMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.orderId,
    this.customerName,
  });

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen> {
  final MapController _mapController = MapController();

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
    
    // Center map on delivery location
    Future.delayed(const Duration(milliseconds: 300), () {
      final location = LatLng(widget.latitude, widget.longitude);
      _mapController.move(location, 15.0); // Zoom level 15 for detailed view
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openDirections() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}',
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open directions'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orderId != null && widget.orderId!.length >= 8
              ? 'Order #${widget.orderId!.substring(0, 8).toUpperCase()}'
              : widget.orderId != null
                  ? 'Order #${widget.orderId!.toUpperCase()}'
                  : 'Delivery Location',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            tooltip: 'Get Directions',
            onPressed: _openDirections,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: location,
              initialZoom: 15.0,
              minZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              // Google Maps-style tile layer (using CartoDB Positron for Google-like appearance)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
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

              // Delivery location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: location,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Address info card
          if (widget.address != null || widget.customerName != null)
            Positioned(
              bottom: 16,
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
                      if (widget.customerName != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.customerName!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.address != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.address!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Divider(height: 1, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              'Latitude',
                              widget.latitude.toStringAsFixed(6),
                              Icons.my_location,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRow(
                              'Longitude',
                              widget.longitude.toStringAsFixed(6),
                              Icons.explore,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions),
                          label: const Text('Get Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
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

