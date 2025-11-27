import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification Model
/// 
/// Maps Firestore document data to a Notification object
class NotificationModel {
  final String id;
  final String userId; // recipient UID
  final String? fromUserId; // sender UID (customer, staff, or admin)
  final String message;
  final String type; // "quotation", "quotation-update", etc.
  final String? quotationId;
  final bool read;
  final DateTime? createdAt;
  final String? title;

  NotificationModel({
    required this.id,
    required this.userId,
    this.fromUserId,
    required this.message,
    required this.type,
    this.quotationId,
    this.read = false,
    this.createdAt,
    this.title,
  });

  /// Create Notification from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      fromUserId: data['fromUserId'] as String?,
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      quotationId: data['quotationId'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      title: data['title'] as String?,
    );
  }

  /// Convert Notification to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (fromUserId != null) 'fromUserId': fromUserId,
      'message': message,
      'type': type,
      if (quotationId != null) 'quotationId': quotationId,
      'read': read,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (title != null) 'title': title,
    };
  }

  /// Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? fromUserId,
    String? message,
    String? type,
    String? quotationId,
    bool? read,
    DateTime? createdAt,
    String? title,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromUserId: fromUserId ?? this.fromUserId,
      message: message ?? this.message,
      type: type ?? this.type,
      quotationId: quotationId ?? this.quotationId,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
    );
  }
}

