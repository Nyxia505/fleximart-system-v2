import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../constants/app_colors.dart';
import 'chat_detail_page.dart';
import 'start_chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
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
                
                // Sort by lastMessageTime (client-side since we removed orderBy)
                chats.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>?;
                  final bData = b.data() as Map<String, dynamic>?;
                  final aTime = aData != null ? (aData['lastMessageTime'] as Timestamp?) : null;
                  final bTime = bData != null ? (bData['lastMessageTime'] as Timestamp?) : null;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Descending
                });

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chatDoc = chats[index];
                    final chatData = chatDoc.data() as Map<String, dynamic>;
                    final participants =
                        (chatData['participants'] as List<dynamic>?) ?? [];
                    final participantNames =
                        Map<String, dynamic>.from(chatData['participantNames'] ?? {});
                    final unreadCount =
                        Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
                    final lastMessage = chatData['lastMessage'] as String?;
                    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
                    final chatId = chatDoc.id;

                    // Get other participant
                    final otherUserId = participants.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => currentUserId,
                    ) as String;
                    final otherUserName = participantNames[otherUserId] ?? 'Unknown';

                    // Get unread count for current user
                    final userUnreadCount = (unreadCount[currentUserId] ?? 0) as int;

                    return _buildChatTile(
                      context,
                      chatId,
                      otherUserId,
                      otherUserName,
                      lastMessage,
                      lastMessageTime,
                      userUnreadCount,
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
    int unreadCount,
  ) {
    String timeText = 'Now';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final messageTime = lastMessageTime.toDate();
      final difference = now.difference(messageTime);

      if (difference.inDays == 0) {
        timeText = '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        timeText = 'Yesterday';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d ago';
      } else {
        timeText = '${messageTime.day}/${messageTime.month}/${messageTime.year}';
      }
    }

    return InkWell(
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
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.secondary,
              child: Text(
                otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
    );
  }
}

