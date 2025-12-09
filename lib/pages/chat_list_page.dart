import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../services/chat_service.dart';
import '../constants/app_colors.dart';
import '../widgets/profile_picture_placeholder.dart';
import '../widgets/profile_picture_widget.dart';
import 'chat_detail_page.dart';
import 'start_chat_page.dart';

/// Fix common email typos (e.g., gamil -> gmail)
String _fixEmailTypo(String email) {
  if (email.contains('@gamil.com')) {
    return email.replaceAll('@gamil.com', '@gmail.com');
  }
  return email;
}

/// Get user name from users collection if not available in participantNames
Future<String> _getUserNameFromUsers(String userId, String existingName) async {
  // Always fetch from users collection to get the latest name
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      final userData = userDoc.data() ?? {};
      // Prioritize fullName first (matches customer profile), then name, then customerName, then email
      final name =
          (userData['fullName'] as String?) ??
          (userData['name'] as String?) ??
          (userData['customerName'] as String?) ??
          (userData['email'] as String?);

      // If we got a valid name from Firebase, use it (even if it's email)
      if (name != null && name.isNotEmpty) {
        // Fix email typos if the name is an email address
        if (name.contains('@')) {
          return _fixEmailTypo(name);
        }
        return name;
      }
    }
  } catch (e) {
    debugPrint('Error fetching user name for $userId: $e');
    // Fallback to existing name if fetch fails
  }
  // Only use existingName if it's not empty and not "Unknown"
  if (existingName.isNotEmpty && existingName != 'Unknown') {
    // Fix email typos if the existing name is an email address
    if (existingName.contains('@')) {
      return _fixEmailTypo(existingName);
    }
    return existingName;
  }
  // Last resort: try to get email from userId if available
  return 'Unknown';
}

/// Get profile picture URL from users collection
/// Checks profilePic (primary) and profileImageUrl (backward compatibility)
Future<String?> _getUserProfilePic(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final userData = userDoc.data() ?? {};
    // Priority: profilePic (primary) > profileImageUrl (backward compatibility)
    final profilePicUrl =
        userData['profilePic'] as String? ??
        userData['profileImageUrl'] as String?;
    return (profilePicUrl != null && profilePicUrl.isNotEmpty)
        ? profilePicUrl
        : null;
  } catch (e) {
    return null;
  }
}

class ChatListPage extends StatelessWidget {
  final bool showBackButton;

  const ChatListPage({super.key, bool? showBackButton})
    : showBackButton = showBackButton ?? true;

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: showBackButton,
        actions: [
          // Start new chat button
          IconButton(
            icon: const Icon(Icons.add_comment),
            tooltip: 'Start New Chat',
            onPressed: () {
              // Get user role
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get()
                    .then((doc) {
                      final role = doc.data()?['role'] ?? 'customer';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StartChatPage(userRole: role),
                        ),
                      );
                    });
              }
            },
          ),
          // Show total unread count
          StreamBuilder<int>(
            stream: chatService.getTotalUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: currentUserId == null
          ? const Center(child: Text('Please log in to view messages'))
          : StreamBuilder<QuerySnapshot>(
              stream: chatService.getChatsStream(),
              builder: (context, snapshot) {
                final userId = currentUserId; // Non-null here
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Get user role
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .get()
                                  .then((doc) {
                                    final role =
                                        doc.data()?['role'] ?? 'customer';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StartChatPage(userRole: role),
                                      ),
                                    );
                                  });
                            }
                          },
                          icon: const Icon(Icons.add_comment),
                          label: const Text('Start New Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data!.docs;

                // Deduplicate chats: if multiple chats exist with the same other participant,
                // keep only the one with the most recent message
                final Map<String, QueryDocumentSnapshot> uniqueChats = {};

                for (var chatDoc in chats) {
                  final chatData = chatDoc.data() as Map<String, dynamic>;
                  final participants =
                      (chatData['participants'] as List<dynamic>?) ?? [];

                  // Get the other participant ID (not the current user)
                  final otherUserId =
                      participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => currentUserId,
                          )
                          as String;

                  // Use otherUserId as the key to deduplicate
                  if (!uniqueChats.containsKey(otherUserId)) {
                    uniqueChats[otherUserId] = chatDoc;
                  } else {
                    // Compare timestamps and keep the one with the most recent message
                    final existingChat = uniqueChats[otherUserId]!;
                    final existingData =
                        existingChat.data() as Map<String, dynamic>;
                    final existingTime =
                        existingData['lastMessageTime'] as Timestamp?;
                    final currentTime =
                        chatData['lastMessageTime'] as Timestamp?;

                    // Keep the chat with the more recent message, or the current one if existing has no message
                    if (currentTime != null) {
                      if (existingTime == null ||
                          currentTime.compareTo(existingTime) > 0) {
                        uniqueChats[otherUserId] = chatDoc;
                      }
                    }
                  }
                }

                // Convert back to list and sort by lastMessageTime
                final uniqueChatsList = uniqueChats.values.toList();
                uniqueChatsList.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>?;
                  final bData = b.data() as Map<String, dynamic>?;
                  final aTime = aData != null
                      ? (aData['lastMessageTime'] as Timestamp?)
                      : null;
                  final bTime = bData != null
                      ? (bData['lastMessageTime'] as Timestamp?)
                      : null;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Descending
                });

                return ListView.builder(
                  itemCount: uniqueChatsList.length,
                  itemBuilder: (context, index) {
                    final chatDoc = uniqueChatsList[index];
                    final chatData = chatDoc.data() as Map<String, dynamic>;
                    final participants =
                        (chatData['participants'] as List<dynamic>?) ?? [];
                    final participantNames = Map<String, dynamic>.from(
                      chatData['participantNames'] ?? {},
                    );
                    final unreadCount = Map<String, dynamic>.from(
                      chatData['unreadCount'] ?? {},
                    );
                    final lastMessage = chatData['lastMessage'] as String?;
                    final lastMessageTime =
                        chatData['lastMessageTime'] as Timestamp?;
                    final chatId = chatDoc.id;

                    // Get other participant
                    final otherUserId =
                        participants.firstWhere(
                              (id) => id != currentUserId,
                              orElse: () => currentUserId,
                            )
                            as String;
                    String otherUserName = participantNames[otherUserId] ?? '';

                    // Get unread count for current user
                    final userUnreadCount =
                        (unreadCount[currentUserId] ?? 0) as int;

                    // If name is missing, fetch from users collection
                    // Also fetch profile picture
                    return FutureBuilder<Map<String, dynamic>>(
                      future:
                          Future.wait([
                            _getUserNameFromUsers(otherUserId, otherUserName),
                            _getUserProfilePic(otherUserId),
                          ]).then(
                            (results) => {
                              'name': results[0],
                              'profilePic': results[1],
                            },
                          ),
                      builder: (context, snapshot) {
                        final displayName =
                            snapshot.data?['name'] ?? otherUserName;
                        final profilePicUrl =
                            snapshot.data?['profilePic'] as String?;
                        return _buildChatTile(
                          context,
                          chatId,
                          otherUserId,
                          displayName,
                          lastMessage,
                          lastMessageTime,
                          userUnreadCount,
                          profilePicUrl: profilePicUrl,
                          chatService: chatService,
                          currentUserId: userId,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    String chatId,
    String otherUserId,
    String otherUserName,
    String? lastMessage,
    Timestamp? lastMessageTime,
    int unreadCount, {
    String? profilePicUrl,
    required ChatService chatService,
    required String currentUserId,
  }) {
    String timeText = 'Now';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final messageTime = lastMessageTime.toDate();
      final difference = now.difference(messageTime);

      if (difference.inDays == 0) {
        timeText =
            '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        timeText = 'Yesterday';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d ago';
      } else {
        timeText =
            '${messageTime.day}/${messageTime.month}/${messageTime.year}';
      }
    }

    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: Text(
              'Are you sure you want to delete this conversation with $otherUserName? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) async {
        try {
          await chatService.deleteChat(chatId, currentUserId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conversation deleted'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting conversation: ${e.toString()}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailPage(
                chatId: chatId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar with profile picture
              profilePicUrl != null && profilePicUrl.isNotEmpty
                  ? ProfilePictureWidget(
                      imageUrl: profilePicUrl,
                      size: 56,
                      backgroundColor: AppColors.secondary,
                      placeholder: const CompactProfilePicturePlaceholder(
                        size: 56,
                      ),
                    )
                  : const CompactProfilePicturePlaceholder(size: 56),
              const SizedBox(width: 16),
              // Name and message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
