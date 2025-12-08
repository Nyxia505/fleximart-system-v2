import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/map_service.dart';
import '../services/order_service.dart';

/// Delivery Map Screen
/// Shows all delivery locations on a map for staff/admin
class DeliveryMapScreen extends StatefulWidget {
  final String? statusFilter;

  const DeliveryMapScreen({
    super.key,
    this.statusFilter,
  });

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final MapController _mapController = MapController();
  final OrderService _orderService = OrderService();
  String _selectedStatusFilter = 'all';
  String? _selectedOrderId;

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
    _selectedStatusFilter = widget.statusFilter ?? 'all';
    
    // Center map on Oroquieta City
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController.move(
        LatLng(MapService.oroquietaLatitude, MapService.oroquietaLongitude),
        12.0, // Zoom to show entire city
      );
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _getMarkerColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Colors.orange;
      case 'paid':
      case 'confirmed':
        return Colors.blue;
      case 'processing':
      case 'preparing':
        return Colors.purple;
      case 'shipped':
      case 'out_for_delivery':
        return Colors.cyan;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getMarkerIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Icons.pending;
      case 'paid':
      case 'confirmed':
        return Icons.check_circle;
      case 'processing':
      case 'preparing':
        return Icons.build;
      case 'shipped':
      case 'out_for_delivery':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
      case 'refunded':
        return Icons.cancel;
      default:
        return Icons.location_on;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_payment':
        return 'Pending Payment';
      case 'paid':
        return 'Paid';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'preparing':
        return 'Preparing';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return status ?? 'Unknown';
    }
  }

  Future<void> _openDirections(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
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

  void _showOrderDetails(Map<String, dynamic> orderData, String orderId) {
    setState(() {
      _selectedOrderId = orderId;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Order info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getMarkerColor(orderData['status'] as String?)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getMarkerIcon(orderData['status'] as String?),
                    color: _getMarkerColor(orderData['status'] as String?),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusLabel(orderData['status'] as String?),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getMarkerColor(orderData['status'] as String?),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),
            
            // Customer info
            if (orderData['customerName'] != null) ...[
              _buildInfoRow(Icons.person, 'Customer', orderData['customerName'] as String),
              const SizedBox(height: 12),
            ],
            
            // Address
            if (orderData['completeAddress'] != null ||
                orderData['deliveryInfo'] != null) ...[
              _buildInfoRow(
                Icons.location_on,
                'Address',
                orderData['completeAddress'] as String? ??
                    (orderData['deliveryInfo'] as Map<String, dynamic>?)?['address'] as String? ??
                    'No address',
              ),
              const SizedBox(height: 12),
            ],
            
            // Phone
            if (orderData['phoneNumber'] != null ||
                (orderData['deliveryInfo'] as Map<String, dynamic>?)?.containsKey('phone') == true) ...[
              _buildInfoRow(
                Icons.phone,
                'Phone',
                orderData['phoneNumber'] as String? ??
                    ((orderData['deliveryInfo'] as Map<String, dynamic>?)?['phone'] as String?) ??
                    'No phone',
              ),
              const SizedBox(height: 12),
            ],
            
            // Coordinates
            if (orderData['latitude'] != null && orderData['longitude'] != null) ...[
              _buildInfoRow(
                Icons.my_location,
                'Coordinates',
                '${orderData['latitude']}, ${orderData['longitude']}',
              ),
              const SizedBox(height: 16),
            ],
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (orderData['latitude'] != null &&
                          orderData['longitude'] != null) {
                        _openDirections(
                          (orderData['latitude'] as num).toDouble(),
                          (orderData['longitude'] as num).toDouble(),
                        );
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Locations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Status filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                dropdownColor: AppColors.primary,
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_list, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Orders')),
                  DropdownMenuItem(value: 'pending_payment', child: Text('Pending Payment')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatusFilter = value ?? 'all';
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _orderService.getAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading orders: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No orders found'),
            );
          }

          // Filter orders by status and get those with coordinates
          final orders = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Filter by status
            if (_selectedStatusFilter != 'all') {
              final status = (data['status'] as String?)?.toLowerCase() ?? '';
              if (status != _selectedStatusFilter.toLowerCase()) {
                return false;
              }
            }
            
            // Only include orders with coordinates
            return data['latitude'] != null && data['longitude'] != null;
          }).toList();

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _selectedStatusFilter == 'all'
                        ? 'No orders with delivery locations found'
                        : 'No orders with this status have delivery locations',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Create markers
          final markers = orders.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = (data['latitude'] as num).toDouble();
            final lng = (data['longitude'] as num).toDouble();
            final status = data['status'] as String?;
            final color = _getMarkerColor(status);
            final icon = _getMarkerIcon(status);
            final isSelected = _selectedOrderId == doc.id;

            return Marker(
              point: LatLng(lat, lng),
              width: isSelected ? 50 : 40,
              height: isSelected ? 50 : 40,
              child: GestureDetector(
                onTap: () => _showOrderDetails(data, doc.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: isSelected ? 8 : 4,
                        spreadRadius: isSelected ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSelected ? 32 : 28,
                  ),
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              // Flutter Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    MapService.oroquietaLatitude,
                    MapService.oroquietaLongitude,
                  ),
                  initialZoom: 12.0,
                  minZoom: 10.0,
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

                  // Order markers
                  MarkerLayer(markers: markers),
                ],
              ),

              // Legend
              Positioned(
                top: 16,
                left: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem('Pending', Colors.orange),
                        _buildLegendItem('Paid', Colors.blue),
                        _buildLegendItem('Processing', Colors.purple),
                        _buildLegendItem('Shipped', Colors.cyan),
                        _buildLegendItem('Delivered', Colors.green),
                        _buildLegendItem('Cancelled', Colors.red),
                      ],
                    ),
                  ),
                ),
              ),

              // Order count badge
              Positioned(
                top: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${orders.length} ${orders.length == 1 ? 'Location' : 'Locations'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
