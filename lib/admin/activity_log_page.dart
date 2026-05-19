import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../widgets/admin_feature_header.dart';
import '../widgets/user_profile_avatar.dart';

/// Set before opening Activity Log from dashboard (e.g. Register filter).
String? activityLogPendingActionFilter;

/// Activity Log Entry Model
class ActivityLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String actionType; // Register, Login, Logout
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ActivityLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.actionType,
    required this.description,
    required this.timestamp,
    this.metadata,
  });
}

/// Activity Log Page Widget
class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedActionType;

  @override
  void initState() {
    super.initState();
    if (activityLogPendingActionFilter != null) {
      _selectedActionType = activityLogPendingActionFilter;
      activityLogPendingActionFilter = null;
    }
  }

  final List<String> _actionTypes = [
    'All',
    'Register',
    'Login',
    'Logout',
    'Product Update',
    'Product Create',
    'Product Delete',
    'User Update',
    'Order Status Change',
  ];

  bool _isGeneratingTestData = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Generate test data for activity log
  Future<void> _generateTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to generate test data'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isGeneratingTestData = true;
    });

    try {
      final userId = user.uid;
      final userName = user.displayName ?? user.email ?? 'Admin User';
      final now = DateTime.now();

      // Generate test data with different timestamps (spread over the last 7 days)
      final testData = [
        // Register
        {
          'userId': userId,
          'userName': 'John Doe',
          'actionType': 'Register',
          'description': 'New user registered',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 6, hours: 2))),
          'metadata': {'email': 'john.doe@example.com'},
        },
        // Login
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Login',
          'description': 'User logged in',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 5, hours: 10))),
          'metadata': {'loginTime': now.subtract(const Duration(days: 5, hours: 10)).toIso8601String()},
        },
        // Logout
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Logout',
          'description': 'User logged out',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 5, hours: 8))),
          'metadata': {'logoutTime': now.subtract(const Duration(days: 5, hours: 8)).toIso8601String()},
        },
        // Product Create
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Product Create',
          'description': 'Created new product: Premium Window Frame',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 4, hours: 15))),
          'metadata': {
            'productId': 'prod_001',
            'productName': 'Premium Window Frame',
          },
        },
        // Product Update
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Product Update',
          'description': 'Updated Premium Window Frame - Price: ₱1,500.00 → ₱1,350.00',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 3, hours: 20))),
          'metadata': {
            'productId': 'prod_001',
            'productName': 'Premium Window Frame',
            'fieldChanged': 'Price',
            'oldValue': '₱1,500.00',
            'newValue': '₱1,350.00',
          },
        },
        // Product Delete
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Product Delete',
          'description': 'Deleted product: Old Model Door',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 2, hours: 5))),
          'metadata': {
            'productId': 'prod_002',
            'productName': 'Old Model Door',
          },
        },
        // User Update
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'User Update',
          'description': 'Updated Jane Smith - Role: customer → staff',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 1, hours: 12))),
          'metadata': {
            'targetUserId': 'user_001',
            'targetUserName': 'Jane Smith',
            'fieldChanged': 'Role',
            'oldValue': 'customer',
            'newValue': 'staff',
          },
        },
        // Order Status Change
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Order Status Change',
          'description': 'Order status changed: Pending → Processing (Customer: Mike Johnson)',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
          'metadata': {
            'orderId': 'order_001',
            'oldStatus': 'Pending',
            'newStatus': 'Processing',
            'customerName': 'Mike Johnson',
          },
        },
        // More recent activities
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Login',
          'description': 'User logged in',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
          'metadata': {'loginTime': now.subtract(const Duration(hours: 3)).toIso8601String()},
        },
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Product Create',
          'description': 'Created new product: Modern Sliding Door',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'metadata': {
            'productId': 'prod_003',
            'productName': 'Modern Sliding Door',
          },
        },
        {
          'userId': userId,
          'userName': userName,
          'actionType': 'Order Status Change',
          'description': 'Order status changed: Processing → Shipped (Customer: Sarah Williams)',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
          'metadata': {
            'orderId': 'order_002',
            'oldStatus': 'Processing',
            'newStatus': 'Shipped',
            'customerName': 'Sarah Williams',
          },
        },
      ];

      // Add all test data to Firestore
      final batch = FirebaseFirestore.instance.batch();
      for (var data in testData) {
        final docRef = FirebaseFirestore.instance.collection('activity_logs').doc();
        batch.set(docRef, data);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test data generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the list
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error generating test data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating test data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingTestData = false;
        });
      }
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedActionType = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  /// Get activity icon and color based on action type
  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'register':
        return Icons.person_add;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'product update':
        return Icons.edit;
      case 'product create':
        return Icons.add_circle;
      case 'product delete':
        return Icons.delete;
      case 'user update':
        return Icons.person_outline;
      case 'order status change':
        return Icons.sync;
      default:
        return Icons.history;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'register':
        return const Color(0xFF10B981); // Green
      case 'login':
        return const Color(0xFF3B82F6); // Blue
      case 'logout':
        return const Color(0xFF6B7280); // Gray
      case 'product update':
        return const Color(0xFF8B2E2E); // Dark maroon
      case 'product create':
        return const Color(0xFF10B981); // Green
      case 'product delete':
        return const Color(0xFFEF4444); // Red
      case 'user update':
        return const Color(0xFFF59E0B); // Amber
      case 'order status change':
        return const Color(0xFF6366F1); // Indigo
      default:
        return AppColors.textSecondary;
    }
  }

  /// Aggregate activities from multiple Firestore collections
  Future<List<ActivityLogEntry>> _getActivities() async {
    final List<ActivityLogEntry> activities = [];

    try {
      // Get user registrations from users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final createdAt = userData['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final name = (userData['name'] as String?) ??
              (userData['fullName'] as String?) ??
              (userData['customerName'] as String?) ??
              (userData['email'] as String?) ??
              'Unknown User';

          activities.add(ActivityLogEntry(
            id: 'register_${userDoc.id}',
            userId: userDoc.id,
            userName: name,
            actionType: 'Register',
            description: 'New user registered',
            timestamp: createdAt.toDate(),
            metadata: {'email': userData['email']},
          ));
        }
      }

      // Get all activities from activity_logs collection
      try {
        final activityLogsSnapshot = await FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .limit(500)
            .get();

        for (var logDoc in activityLogsSnapshot.docs) {
          final logData = logDoc.data();
          final timestamp = logData['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final actionType = logData['actionType'] as String? ?? 'Unknown';
            
            // Include all activity types
            activities.add(ActivityLogEntry(
              id: logDoc.id,
              userId: logData['userId'] as String? ?? '',
              userName: logData['userName'] as String? ?? 'Unknown User',
              actionType: actionType,
              description: logData['description'] as String? ?? '',
              timestamp: timestamp.toDate(),
              metadata: logData['metadata'] as Map<String, dynamic>?,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error loading activity logs: $e');
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
    }

    // Sort by timestamp (newest first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return activities;
  }

  List<ActivityLogEntry> _filterActivities(List<ActivityLogEntry> activities) {
    var filtered = activities;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((activity) {
        return activity.userName.toLowerCase().contains(query) ||
            activity.description.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by action type
    if (_selectedActionType != null && _selectedActionType != 'All') {
      filtered = filtered
          .where((activity) => activity.actionType == _selectedActionType)
          .toList();
    }

    // Filter by date range
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((activity) {
        // Convert activity timestamp to UTC and normalize to date only
        final activityUtc = activity.timestamp.toUtc();
        final activityDate = DateTime.utc(
          activityUtc.year,
          activityUtc.month,
          activityUtc.day,
        );

        bool matchesStart = true;
        bool matchesEnd = true;

        if (_startDate != null) {
          // Convert start date to UTC and normalize to date only (00:00:00 UTC)
          final startUtc = _startDate!.toUtc();
          final startDateOnly = DateTime.utc(
            startUtc.year,
            startUtc.month,
            startUtc.day,
          );
          // Activity date should be on or after start date
          matchesStart = activityDate.isAtSameMomentAs(startDateOnly) ||
              activityDate.isAfter(startDateOnly);
        }

        if (_endDate != null) {
          // Convert end date to UTC and normalize to date only (00:00:00 UTC)
          final endUtc = _endDate!.toUtc();
          final endDateOnly = DateTime.utc(
            endUtc.year,
            endUtc.month,
            endUtc.day,
          );
          // Add 1 day to make it inclusive (so activities on endDate are included)
          final endDateInclusive = endDateOnly.add(const Duration(days: 1));
          // Activity date should be before the next day (i.e., on or before endDate)
          matchesEnd = activityDate.isBefore(endDateInclusive);
        }

        return matchesStart && matchesEnd;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminFeatureHeader(
                    title: 'Activity Log',
                    subtitle: 'User sign-ups and system activity',
                    icon: Icons.history,
                    trailing: isMobile
                        ? null
                        : AdminFeatureHeader.primaryAction(
                            label: _isGeneratingTestData
                                ? 'Generating...'
                                : 'Add Test Data',
                            icon: Icons.add_circle_outline,
                            onPressed:
                                _isGeneratingTestData ? null : _generateTestData,
                          ),
                  ),
                  if (isMobile) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: AdminFeatureHeader.primaryAction(
                          label: _isGeneratingTestData
                              ? 'Generating...'
                              : 'Add Test Data',
                          icon: Icons.add_circle_outline,
                          onPressed:
                              _isGeneratingTestData ? null : _generateTestData,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 16,
                      12,
                      isMobile ? 12 : 16,
                      0,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFCD5656).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) ...[
                            _buildSearchField(),
                            const SizedBox(height: 12),
                            _buildMobileFilters(context),
                          ] else ...[
                            _buildDesktopFilters(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Timeline
          Expanded(
            child: FutureBuilder<List<ActivityLogEntry>>(
              future: _getActivities(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading activities',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data ?? [];
                final filteredActivities = _filterActivities(activities);

                // Add refresh functionality
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: filteredActivities.isEmpty
                      ? _buildEmptyState(activities.isEmpty)
                      : _buildTimeline(filteredActivities),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noActivities) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            noActivities
                ? 'No activities found'
                : 'No activities match your filters',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          if (noActivities) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isGeneratingTestData ? null : _generateTestData,
              icon: _isGeneratingTestData
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline, size: 18),
              label: Text(_isGeneratingTestData ? 'Generating...' : 'Generate Test Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dashboardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by user name or description...',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFilters(BuildContext context) {
    return Column(
      children: [
        // Action Type Dropdown
        Container(
          decoration: BoxDecoration(
            color: AppColors.dashboardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: _selectedActionType ?? 'All',
            isExpanded: true,
            underline: const SizedBox(),
            items: _actionTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedActionType = value == 'All' ? null : value;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        // Date Filters
        Row(
          children: [
            Expanded(
              child: _buildDateButton(
                context,
                'Start Date',
                _startDate,
                () => _selectStartDate(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDateButton(
                context,
                'End Date',
                _endDate,
                () => _selectEndDate(context),
              ),
            ),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(width: 8),
              _buildClearButton(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 12),
        // Action Type Dropdown
        Container(
          decoration: BoxDecoration(
            color: AppColors.dashboardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButton<String>(
            value: _selectedActionType ?? 'All',
            underline: const SizedBox(),
            items: _actionTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedActionType = value == 'All' ? null : value;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        // Date Filter Buttons
        Container(
          decoration: BoxDecoration(
            color: AppColors.dashboardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateButton(
                context,
                'Start Date',
                _startDate,
                () => _selectStartDate(context),
                isDesktop: true,
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.border,
              ),
              _buildDateButton(
                context,
                'End Date',
                _endDate,
                () => _selectEndDate(context),
                isDesktop: true,
              ),
              if (_startDate != null || _endDate != null) ...[
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.border,
                ),
                _buildClearButton(isDesktop: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    DateTime? date,
    VoidCallback onTap, {
    bool isDesktop = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isDesktop
            ? (label == 'Start Date'
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : (_startDate == null && _endDate == null
                    ? const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      )
                    : BorderRadius.zero))
            : BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: isDesktop ? 18 : 16,
                color: date != null
                    ? const Color(0xFFCD5656)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  date != null ? DateFormat('MMM d, y').format(date) : label,
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 12,
                    color: date != null
                        ? const Color(0xFFCD5656)
                        : AppColors.textSecondary,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton({bool isDesktop = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _clearFilters,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Icon(
            Icons.clear,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<ActivityLogEntry> activities) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return _buildTimelineItem(activities[index]);
      },
    );
  }

  bool _showProfileAvatar(ActivityLogEntry activity) {
    if (activity.userId.isEmpty) return false;
    switch (activity.actionType) {
      case 'Register':
      case 'Login':
      case 'Logout':
      case 'User Update':
        return true;
      default:
        return false;
    }
  }

  Widget _buildInlineLeading(ActivityLogEntry activity) {
    final actionColor = _getActionColor(activity.actionType);
    final actionIcon = _getActionIcon(activity.actionType);

    if (_showProfileAvatar(activity)) {
      return ClipOval(
        child: UserProfileAvatar(userId: activity.userId, size: 44),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: actionColor.withOpacity(0.35)),
      ),
      child: Icon(actionIcon, color: actionColor, size: 22),
    );
  }

  Widget _buildTimelineItem(ActivityLogEntry activity) {
    final actionColor = _getActionColor(activity.actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInlineLeading(activity),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        activity.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: actionColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activity.actionType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: actionColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy • hh:mm a')
                          .format(activity.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact recent registrations list for the admin dashboard overview.
class RecentRegistrationsList extends StatelessWidget {
  final int limit;
  final VoidCallback? onViewAll;

  const RecentRegistrationsList({
    super.key,
    this.limit = 5,
    this.onViewAll,
  });

  String _displayName(Map<String, dynamic> data) {
    return (data['fullName'] as String?) ??
        (data['name'] as String?) ??
        (data['customerName'] as String?) ??
        (data['email'] as String?) ??
        'Unknown';
  }

  DateTime? _signupDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final verifiedAt = data['verifiedAt'];
    if (verifiedAt is Timestamp) return verifiedAt.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load users',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        var docs = snapshot.data?.docs ?? [];
        docs = List.from(docs)
          ..sort((a, b) {
            final aDate = _signupDate(a.data() as Map<String, dynamic>);
            final bDate = _signupDate(b.data() as Map<String, dynamic>);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
        docs = docs.take(limit).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No registrations yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = _displayName(data);
                  final email = data['email'] as String? ?? '—';
                  final signupDate = _signupDate(data);
                  final dateLabel = signupDate != null
                      ? DateFormat('MMM d, yyyy • h:mm a').format(signupDate)
                      : 'Date unknown';

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          UserProfileAvatar(userId: doc.id, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: const Text('View activity log'),
              ),
          ],
        );
      },
    );
  }
}

