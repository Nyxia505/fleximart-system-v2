import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

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
  ///
  /// Throws:
  /// - Exception if text is empty or null
  Future<void> sendMessage(
    String senderId,
    String receiverId,
    String text,
    String chatId,
  ) async {
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

    // Add message to messages subcollection
    await chatRef.collection('messages').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

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

  /// Get user name from users collection
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      return userData['fullName'] ?? userData['email'] ?? 'Unknown';
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
