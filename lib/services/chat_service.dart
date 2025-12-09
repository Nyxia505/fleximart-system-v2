import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get or create a chat conversation between two users
  /// Returns the chat document ID
  Future<String> getOrCreateChat(
    String otherUserId,
    String otherUserName,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Check if chat already exists between these two users
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var chatDoc in existingChats.docs) {
      final chatData = chatDoc.data();
      final participants = (chatData['participants'] as List<dynamic>?) ?? [];
      if (participants.contains(otherUserId)) {
        return chatDoc.id; // Return existing chat ID
      }
    }

    // Create new chat using .add()
    final chatRef = await _firestore.collection('chats').add({
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });

    // Update participant names
    final currentUserName = await _getUserName(currentUserId);
    await chatRef.update({
      'participantNames': {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },
      'unreadCount': {currentUserId: 0, otherUserId: 0},
    });

    return chatRef.id;
  }

  /// Send a message to a chat room
  ///
  /// This function:
  /// - Uses FieldValue.serverTimestamp() for timestamps
  /// - Accepts senderId, receiverId, text, and chatId
  /// - Automatically ensures the chatId document exists in chats collection
  /// - Writes messages to /chats/chatId/messages
  ///
  /// Parameters:
  /// - [senderId]: The UID of the message sender
  /// - [receiverId]: The UID of the message receiver
  /// - [text]: The message text content
  /// - [chatId]: The chat room ID (can be generated using makeChatId())
  /// - [replyToMessageId]: Optional ID of the message being replied to
  /// - [replyToText]: Optional text of the message being replied to
  /// - [replyToSenderId]: Optional sender ID of the message being replied to
  ///
  /// Throws:
  /// - Exception if text is empty or null
  Future<void> sendMessage(
    String senderId,
    String receiverId,
    String text,
    String chatId, {
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
  }) async {
    // Validate input
    if (text.trim().isEmpty) {
      throw Exception('Message text cannot be empty');
    }

    // Ensure chat document exists in 'chats' collection (not 'chat_rooms')
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      // Create the chat document if it doesn't exist
      await chatRef.set({
        'participants': [senderId, receiverId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {senderId: 0, receiverId: 1},
      }, SetOptions(merge: true));
    }

    // Build message data
    final messageData = <String, dynamic>{
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add reply fields if replying to a message
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      messageData['replyToMessageId'] = replyToMessageId;
      if (replyToText != null) {
        messageData['replyToText'] = replyToText;
      }
      if (replyToSenderId != null) {
        messageData['replyToSenderId'] = replyToSenderId;
      }
    }

    // Add message to messages subcollection
    await chatRef.collection('messages').add(messageData);

    // Update chat document with last message and unread count
    final chatData = chatDoc.data() ?? {};
    final unreadCount = Map<String, dynamic>.from(
      chatData['unreadCount'] ?? {},
    );
    for (var participant
        in (chatData['participants'] as List<dynamic>? ?? [])) {
      if (participant != senderId) {
        unreadCount[participant] = (unreadCount[participant] ?? 0) + 1;
      }
    }

    await chatRef.update({
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    });
  }

  /// Get messages stream for a chat (real-time)
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Send an image message (works on both web and mobile)
  ///
  /// Creates a message document with:
  /// - senderId, receiverId
  /// - message: '' (empty for images)
  /// - imageUrl: download URL
  /// - type: 'image'
  /// - createdAt / timestamp
  Future<void> sendImageMessage(
    String chatId,
    Uint8List imageBytes,
    String fileName,
    String receiverId,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Upload to Firebase Storage using putData (works on both web and mobile)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = 'chat_${timestamp}_$fileName';
    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(chatId)
        .child(storageFileName);

    // Upload with timeout (120 seconds for large files and slow connections)
    try {
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Wait for upload to complete with timeout
      await uploadTask.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          // Cancel the upload task if it times out
          try {
            uploadTask.cancel();
          } catch (_) {
            // Ignore cancellation errors
          }
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );
    } catch (e) {
      // Re-throw with more context
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout') ||
          errorStr.contains('deadline exceeded')) {
        throw Exception(
          'Upload timeout. Please check your internet connection.',
        );
      } else if (errorStr.contains('permission') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('403')) {
        throw Exception(
          'Permission denied. Please check Firebase Storage rules.',
        );
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      } else if (errorStr.contains('cancel')) {
        throw Exception('Upload cancelled.');
      }
      // Re-throw original error with context
      throw Exception('Upload failed: ${e.toString()}');
    }

    // Get download URL with timeout
    String downloadUrl;
    try {
      downloadUrl = await ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Failed to get image URL. Please try again.');
        },
      );
    } catch (e) {
      // If we can't get the URL, try to delete the uploaded file
      try {
        await ref.delete();
      } catch (_) {
        // Ignore deletion errors
      }
      if (e.toString().contains('timeout')) {
        throw Exception('Failed to get image URL. Please try again.');
      }
      rethrow;
    }

    // Create message with imageUrl
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'receiverId': receiverId,
          'text': '',
          'message': '',
          'imageUrl': downloadUrl,
          'type': 'image',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update chat document with placeholder last message
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};
    final participants = (chatData['participants'] as List<dynamic>?) ?? [];
    final unreadCount = Map<String, dynamic>.from(
      chatData['unreadCount'] ?? {},
    );
    for (var participant in participants) {
      if (participant != currentUserId) {
        unreadCount[participant] = (unreadCount[participant] ?? 0) + 1;
      }
    }
    await chatRef.update({
      'lastMessage': '[Photo]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    });
  }

  /// Get all chats for the current user (real-time)
  Stream<QuerySnapshot> getChatsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    // Use a simpler query that doesn't require composite index
    // We'll filter and sort client-side if needed
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots();
  }

  /// Mark messages as read in a chat
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Reset unread count for current user
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final chatData = chatDoc.data() ?? {};
    final unreadCount = Map<String, dynamic>.from(
      chatData['unreadCount'] ?? {},
    );
    unreadCount[currentUserId] = 0;

    await chatRef.update({'unreadCount': unreadCount});
  }

  /// Get the other participant's info from a chat
  Future<Map<String, dynamic>> getOtherParticipant(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final participants = (chatData['participants'] as List<dynamic>?) ?? [];
    final participantNames = Map<String, dynamic>.from(
      chatData['participantNames'] ?? {},
    );

    final otherUserId =
        participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => currentUserId,
            )
            as String;

    // Get name from participantNames first, then fallback to users collection
    String otherUserName = participantNames[otherUserId] ?? '';
    if (otherUserName.isEmpty || otherUserName == 'Unknown') {
      otherUserName = await _getUserName(otherUserId);
    }

    return {'userId': otherUserId, 'userName': otherUserName};
  }

  /// Fix common email typos (e.g., gamil -> gmail)
  String _fixEmailTypo(String email) {
    if (email.contains('@gamil.com')) {
      return email.replaceAll('@gamil.com', '@gmail.com');
    }
    return email;
  }

  /// Get user name from users collection
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        // Prioritize fullName first (matches customer profile), then name, then customerName, then email
        final name = (userData['fullName'] as String?) ??
            (userData['name'] as String?) ??
            (userData['customerName'] as String?) ??
            (userData['email'] as String?) ??
            'Unknown';
        // Fix email typos if the name is an email address
        if (name.contains('@')) {
          return _fixEmailTypo(name);
        }
        return name;
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Get unread count for current user
  Future<int> getUnreadCount(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final unreadCount = Map<String, dynamic>.from(
      chatData['unreadCount'] ?? {},
    );
    return (unreadCount[currentUserId] ?? 0) as int;
  }

  /// Get total unread count across all chats
  Stream<int> getTotalUnreadCount() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCount = Map<String, dynamic>.from(
              data['unreadCount'] ?? {},
            );
            total += (unreadCount[currentUserId] ?? 0) as int;
          }
          return total;
        });
  }

  /// Delete a message from a chat
  ///
  /// Parameters:
  /// - [chatId]: The chat room ID
  /// - [messageId]: The ID of the message to delete
  /// - [senderId]: The UID of the user trying to delete (must be the sender)
  ///
  /// Throws:
  /// - Exception if user is not the sender or message doesn't exist
  Future<void> deleteMessage(
    String chatId,
    String messageId,
    String senderId,
  ) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) {
      throw Exception('Message not found');
    }

    final messageData = messageDoc.data() ?? {};
    final messageSenderId = messageData['senderId'] as String?;

    // Only allow deletion if the user is the sender
    if (messageSenderId != senderId) {
      throw Exception('You can only delete your own messages');
    }

    // Delete the message
    await messageRef.delete();

    // Update chat's last message if this was the last message
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesSnapshot = await chatRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (messagesSnapshot.docs.isNotEmpty) {
      final lastMessage = messagesSnapshot.docs.first.data();
      final lastMessageText = lastMessage['text'] as String? ?? '';
      final lastMessageType = lastMessage['type'] as String?;
      
      await chatRef.update({
        'lastMessage': lastMessageType == 'image' ? '[Photo]' : lastMessageText,
        'lastMessageTime': lastMessage['createdAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // No messages left, update to empty
      await chatRef.update({
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Delete a chat conversation
  ///
  /// This deletes:
  /// - All messages in the chat subcollection
  /// - The chat document itself
  /// - Associated images from Storage (if any)
  ///
  /// Parameters:
  /// - [chatId]: The chat room ID to delete
  /// - [userId]: The UID of the user trying to delete (must be a participant)
  ///
  /// Throws:
  /// - Exception if user is not a participant or chat doesn't exist
  Future<void> deleteChat(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      throw Exception('Chat not found');
    }
    
    final chatData = chatDoc.data() ?? {};
    final participants = (chatData['participants'] as List<dynamic>?) ?? [];
    
    // Verify user is a participant
    if (!participants.contains(userId)) {
      throw Exception('You can only delete conversations you are part of');
    }
    
    // Delete all messages in the chat
    final messagesRef = chatRef.collection('messages');
    final messagesSnapshot = await messagesRef.get();
    
    // Delete images from Storage if any
    final storage = FirebaseStorage.instance;
    final batch = _firestore.batch();
    
    for (var messageDoc in messagesSnapshot.docs) {
      final messageData = messageDoc.data();
      final imageUrl = messageData['imageUrl'] as String?;
      
      // Delete image from Storage if it exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          // Extract the path from the URL
          final uri = Uri.parse(imageUrl);
          final pathSegments = uri.pathSegments;
          // Firebase Storage URLs have format: /v0/b/{bucket}/o/{path}
          // We need to extract the path after 'o/'
          final pathIndex = pathSegments.indexOf('o');
          if (pathIndex != -1 && pathIndex < pathSegments.length - 1) {
            final storagePath = pathSegments.sublist(pathIndex + 1).join('/');
            final decodedPath = Uri.decodeComponent(storagePath);
            await storage.ref(decodedPath).delete();
          }
        } catch (e) {
          // Log error but continue deleting other messages
          debugPrint('Error deleting image from Storage: $e');
        }
      }
      
      // Add message deletion to batch
      batch.delete(messageDoc.reference);
    }
    
    // Delete the chat document
    batch.delete(chatRef);
    
    // Commit all deletions
    await batch.commit();
  }

  /// Generate a consistent chatId from two UIDs
  ///
  /// This ensures the same chatId is generated regardless of the order
  /// of the UIDs (customer and staff will get the same chatId).
  ///
  /// Example:
  /// - makeChatId('uid1', 'uid2') returns 'uid1_uid2'
  /// - makeChatId('uid2', 'uid1') returns 'uid1_uid2' (same result)
  static String makeChatId(String uid1, String uid2) {
    // Sort UIDs alphabetically to ensure consistent chatId
    final sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }
}
