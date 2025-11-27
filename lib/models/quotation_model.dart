import 'package:cloud_firestore/cloud_firestore.dart';

/// Quotation Model
/// 
/// Maps Firestore document data to a Quotation object
class Quotation {
  final String id;
  final String customerId; // customer UID (primary field)
  final String? userId; // legacy support
  final String? staffId; // staff UID (optional until assigned)
  final String? adminId; // admin UID (optional)
  final String? message; // optional message
  final String status; // "pending", "in_progress", "done"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Customer and product information
  final String? customerName;
  final String? customerEmail;
  final String? productId;
  final String? productName;
  final String? productImage;
  final String? productPrice;
  final String? glassType;
  final String? aluminumType;
  final double? length;
  final double? width;
  final String? notes;
  final String? windowImageUrl;
  final String? imageUrl; // Uploaded reference image URL
  
  // Address fields
  final String? phoneNumber;
  final String? completeAddress;
  final String? landmark;
  final String? mapLink;
  
  // Pricing fields
  final double? estimatedPrice; // nullable
  final String? priceNote; // nullable
  final double? adminTotalPrice; // Admin-set total price
  final List<Map<String, dynamic>>? items; // Array of items with prices

  Quotation({
    required this.id,
    required this.customerId,
    this.userId,
    this.staffId,
    this.adminId,
    this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerEmail,
    this.productId,
    this.productName,
    this.productImage,
    this.productPrice,
    this.glassType,
    this.aluminumType,
    this.length,
    this.width,
    this.notes,
    this.windowImageUrl,
    this.imageUrl,
    this.phoneNumber,
    this.completeAddress,
    this.landmark,
    this.mapLink,
    this.estimatedPrice,
    this.priceNote,
    this.adminTotalPrice,
    this.items,
  });

  /// Create Quotation from Firestore document
  factory Quotation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Support both customerId (new) and userId (legacy)
    final customerId = data['customerId'] as String? ?? 
                       data['userId'] as String? ?? 
                       '';
    
    return Quotation(
      id: doc.id,
      customerId: customerId,
      userId: data['userId'] as String?, // keep for legacy support
      staffId: data['staffId'] as String?,
      adminId: data['adminId'] as String?,
      message: data['message'] as String?,
      status: (data['status'] as String? ?? 'pending').toLowerCase(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      customerName: data['customerName'] as String?,
      customerEmail: data['customerEmail'] as String?,
      productId: data['productId'] as String?,
      productName: data['productName'] as String?,
      productImage: data['productImage'] as String?,
      productPrice: data['productPrice'] as String?,
      glassType: data['glassType'] as String?,
      aluminumType: data['aluminumType'] as String?,
      length: (data['length'] as num?)?.toDouble(),
      width: (data['width'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      windowImageUrl: data['windowImageUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      completeAddress: data['completeAddress'] as String?,
      landmark: data['landmark'] as String?,
      mapLink: data['mapLink'] as String?,
      estimatedPrice: (data['estimatedPrice'] as num?)?.toDouble(),
      priceNote: data['priceNote'] as String?,
      adminTotalPrice: (data['adminTotalPrice'] as num?)?.toDouble(),
      items: data['items'] != null 
          ? List<Map<String, dynamic>>.from(data['items'] as List)
          : null,
    );
  }

  /// Convert Quotation to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      if (userId != null) 'userId': userId, // legacy support
      if (staffId != null) 'staffId': staffId,
      if (adminId != null) 'adminId': adminId,
      if (message != null) 'message': message,
      'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (customerName != null) 'customerName': customerName,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      if (productImage != null) 'productImage': productImage,
      if (productPrice != null) 'productPrice': productPrice,
      if (glassType != null) 'glassType': glassType,
      if (aluminumType != null) 'aluminumType': aluminumType,
      if (length != null) 'length': length,
      if (width != null) 'width': width,
      if (notes != null) 'notes': notes,
      if (windowImageUrl != null) 'windowImageUrl': windowImageUrl,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (phoneNumber != null && phoneNumber.toString().isNotEmpty) 'phoneNumber': phoneNumber.toString(),
      if (completeAddress != null) 'completeAddress': completeAddress,
      if (landmark != null) 'landmark': landmark,
      if (mapLink != null) 'mapLink': mapLink,
      if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
      if (priceNote != null) 'priceNote': priceNote,
      if (adminTotalPrice != null) 'adminTotalPrice': adminTotalPrice,
      if (items != null) 'items': items,
    };
  }
}

