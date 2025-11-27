import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../services/notification_service.dart';

/// Delivery Schedule Dialog
/// 
/// Allows admin/staff to schedule delivery/installation for an order
class DeliveryScheduleDialog extends StatefulWidget {
  final String orderId;
  final DocumentReference orderRef;
  final String customerId;

  const DeliveryScheduleDialog({
    super.key,
    required this.orderId,
    required this.orderRef,
    required this.customerId,
  });

  @override
  State<DeliveryScheduleDialog> createState() => _DeliveryScheduleDialogState();
}

class _DeliveryScheduleDialogState extends State<DeliveryScheduleDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedStaffId;
  String? _selectedStaffName;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingStaff = true;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      setState(() {
        _staffList = staffSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? data['fullName'] ?? 'Staff Member',
            'email': data['email'] ?? '',
          };
        }).toList();
        _isLoadingStaff = false;
      });
    } catch (e) {
      setState(() => _isLoadingStaff = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading staff: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a staff member'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine date and time into a single DateTime
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Update order document
      // Set status to "scheduled" and store delivery schedule info
      await widget.orderRef.update({
        'deliverySchedule': _formatDate(_selectedDate!) + ' ' + _selectedTime!.format(context),
        'deliveryDate': Timestamp.fromDate(_selectedDate!),
        'deliveryTime': _selectedTime!.hour.toString().padLeft(2, '0') +
            ':' +
            _selectedTime!.minute.toString().padLeft(2, '0'),
        'deliveryDateTime': Timestamp.fromDate(scheduledDateTime),
        'assignedStaff': _selectedStaffName, // Store assigned staff name
        'assignedStaffId': _selectedStaffId,
        'assignedStaffName': _selectedStaffName,
        'scheduleNote': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'scheduleStatus': 'scheduled',
        'status': 'scheduled', // Update main status to "scheduled"
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Format schedule string for notification
      final selectedSchedule = '${_formatDate(_selectedDate!)} at ${_selectedTime!.format(context)}';
      
      // Fetch productName from order data
      final orderDoc = await widget.orderRef.get();
      String? productName;
      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>?;
        if (orderData != null) {
          if (orderData['productName'] != null) {
            productName = orderData['productName'] as String?;
          } else if (orderData['items'] != null) {
            final items = orderData['items'] as List?;
            if (items != null && items.isNotEmpty) {
              final firstItem = items[0] as Map<String, dynamic>?;
              productName = firstItem?['productName'] as String?;
            }
          }
        }
      }
      final displayProductName = productName ?? 'order';
      
      // Send notification to customer using NotificationService
      final notificationService = NotificationService.instance;
      await notificationService.sendNotification(
        userId: widget.customerId,
        fromUserId: FirebaseAuth.instance.currentUser?.uid,
        title: 'Delivery Scheduled',
        message: 'Your delivery for $displayProductName is scheduled for $selectedSchedule.',
        type: 'delivery',
      );
      
      // Also create notification document in Firestore as specified
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.customerId,
        'type': 'delivery',
        'message': 'Your delivery is scheduled for $selectedSchedule with $_selectedStaffName.',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery schedule saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving schedule: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Set Delivery Schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Date',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedDate != null
                                      ? _formatDate(_selectedDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedDate != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Time Picker
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Time',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Select time',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedTime != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.access_time,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Staff Dropdown
                    if (_isLoadingStaff)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedStaffId,
                        decoration: InputDecoration(
                          labelText: 'Assign Staff',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        items: _staffList.map((staff) {
                          return DropdownMenuItem<String>(
                            value: staff['id'],
                            child: Text(staff['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStaffId = value;
                            _selectedStaffName = _staffList
                                .firstWhere((s) => s['id'] == value)['name'];
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    // Notes Field
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any special instructions or notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Schedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

