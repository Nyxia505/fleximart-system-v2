import 'package:cloud_firestore/cloud_firestore.dart';

/// Order Model
/// 
/// Maps Firestore document data to an Order object
/// Matches the structure used in proceed_buy_screen.dart
class OrderModel {
  final String id;
  final String customerId;
  final String status; // to_pay, payment_review, for_site_visit, to_install, completed, delivered, cancelled
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool customerHasRated;
  
  // Optional fields
  final String? customerName;
  final String? customerEmail;
  final String? paymentProofUrl;
  final String? customerNotes;
  final double? shipping;
  final double? voucherDiscount;
  final String? voucherCode;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    required this.items,
    this.createdAt,
    this.updatedAt,
    this.customerHasRated = false,
    this.customerName,
    this.customerEmail,
    this.paymentProofUrl,
    this.customerNotes,
    this.shipping,
    this.voucherDiscount,
    this.voucherCode,
  });

  /// Create OrderModel from Firestore document
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      status: data['status'] as String? ?? 'to_pay',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      customerHasRated: data['customerHasRated'] as bool? ?? false,
      customerName: data['customerName'] as String?,
      customerEmail: data['customerEmail'] as String?,
      paymentProofUrl: data['paymentProofUrl'] as String?,
      customerNotes: data['customerNotes'] as String?,
      shipping: (data['shipping'] as num?)?.toDouble(),
      voucherDiscount: (data['voucherDiscount'] as num?)?.toDouble(),
      voucherCode: data['voucherCode'] as String?,
    );
  }

  /// Convert OrderModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'status': status,
      'totalAmount': totalAmount,
      'items': items,
      'customerHasRated': customerHasRated,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (customerName != null) 'customerName': customerName,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
      if (customerNotes != null) 'customerNotes': customerNotes,
      if (shipping != null) 'shipping': shipping,
      if (voucherDiscount != null) 'voucherDiscount': voucherDiscount,
      if (voucherCode != null) 'voucherCode': voucherCode,
    };
  }

  /// Create a copy of OrderModel with updated fields
  OrderModel copyWith({
    String? id,
    String? customerId,
    String? status,
    double? totalAmount,
    List<Map<String, dynamic>>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? customerHasRated,
    String? customerName,
    String? customerEmail,
    String? paymentProofUrl,
    String? customerNotes,
    double? shipping,
    double? voucherDiscount,
    String? voucherCode,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerHasRated: customerHasRated ?? this.customerHasRated,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      customerNotes: customerNotes ?? this.customerNotes,
      shipping: shipping ?? this.shipping,
      voucherDiscount: voucherDiscount ?? this.voucherDiscount,
      voucherCode: voucherCode ?? this.voucherCode,
    );
  }
}