import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../constants/app_colors.dart';
import '../widgets/profile_picture_placeholder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'dart:typed_data';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ImagePicker _picker = ImagePicker();
  String? _otherUserProfilePic;

  // Reply context
  String? _replyingToMessageId;
  String? _replyingToText;
  String? _replyingToSenderId;
  String? _replyingToSenderName;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsRead(widget.chatId);
    });
    // Load profile picture
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      final userData = userDoc.data() ?? {};
      // Priority: profilePic (primary) > profileImageUrl (backward compatibility)
      final profilePicUrl =
          userData['profilePic'] as String? ??
          userData['profileImageUrl'] as String?;
      if (mounted) {
        setState(() {
          _otherUserProfilePic =
              (profilePicUrl != null && profilePicUrl.isNotEmpty)
              ? profilePicUrl
              : null;
        });
      }
    } catch (e) {
      // Ignore errors, will show initial instead
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to send messages'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await _chatService.sendMessage(
        currentUserId!,
        widget.otherUserId,
        text,
        widget.chatId,
        replyToMessageId: _replyingToMessageId,
        replyToText: _replyingToText,
        replyToSenderId: _replyingToSenderId,
      );
      _messageController.clear();
      _clearReplyContext();

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearReplyContext() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToText = null;
      _replyingToSenderId = null;
      _replyingToSenderName = null;
    });
  }

  void _setReplyContext(
    String messageId,
    String text,
    String senderId,
    String senderName,
  ) {
    setState(() {
      _replyingToMessageId = messageId;
      _replyingToText = text;
      _replyingToSenderId = senderId;
      _replyingToSenderName = senderName;
    });
    // Focus on text field
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    if (currentUserId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(
        widget.chatId,
        messageId,
        currentUserId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    bool dialogShown = false;

    try {
      ImageSource source = ImageSource.gallery;

      // On web: only gallery is supported; on mobile: let user choose camera or gallery
      if (!kIsWeb) {
        final ImageSource? selectedSource = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );

        if (selectedSource == null) return;
        source = selectedSource;
      }

      // Pick image from selected source FIRST (before showing loading)
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 60, // Reduced quality for faster uploads
        maxWidth: 1024, // Slightly larger but still compressed
        maxHeight: 1024,
      );

      // If user cancelled, just return (no loading dialog was shown)
      if (picked == null) return;

      // NOW show loading indicator (after image is picked)
      if (!mounted) return;

      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      // Read image as bytes (works on both web and mobile)
      final Uint8List imageBytes = await picked.readAsBytes();

      // Check file size (max 5MB)
      if (imageBytes.length > 5 * 1024 * 1024) {
        throw Exception(
          'Image too large. Maximum size is 5MB. Please choose a smaller image.',
        );
      }

      // If image is still large (> 2MB), show warning but allow
      if (imageBytes.length > 2 * 1024 * 1024) {
        // Show a brief warning that upload may take longer
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Large image detected. Upload may take a moment...',
              ),
              backgroundColor: AppColors.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Send image message (timeout is handled in the service)
      await _chatService.sendImageMessage(
        widget.chatId,
        imageBytes,
        picked.name,
        widget.otherUserId,
      );

      // Close loading dialog
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📸 Image sent successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Make sure to close loading dialog if it was shown
      if (mounted && dialogShown) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        } catch (_) {
          // Ignore if dialog wasn't actually shown
        }
      }

      if (!mounted) return;

      // Show user-friendly error message
      String errorMessage = 'Failed to send image';
      final errorText = e.toString().toLowerCase();

      if (errorText.contains('timeout')) {
        errorMessage = 'Upload timeout. Please check your internet connection.';
      } else if (errorText.contains('permission') ||
          errorText.contains('unauthorized')) {
        errorMessage =
            'Permission denied. Please check Firebase Storage rules.';
      } else if (errorText.contains('network') ||
          errorText.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorText.contains('too large')) {
        errorMessage = 'Image too large. Maximum size is 5MB.';
      } else {
        // Extract the actual error message if it's an Exception
        final errorStr = e.toString();
        if (errorStr.contains('Exception: ')) {
          errorMessage = errorStr.split('Exception: ').last;
        } else {
          errorMessage = errorStr;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(errorMessage, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
            onPressed: () => _pickAndSendImage(),
          ),
        ),
      );
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _otherUserProfilePic != null && _otherUserProfilePic!.isNotEmpty
                ? CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(_otherUserProfilePic!),
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image load error by clearing the profile pic
                      if (mounted) {
                        setState(() {
                          _otherUserProfilePic = null;
                        });
                      }
                    },
                  )
                : const CompactProfilePicturePlaceholder(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                // Show error if connection failed
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load messages',
                          style: const TextStyle(
                            color: Color(0xFF1D3B53),
                          ), // Dark blue for better contrast
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: Text(
                            'Retry',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Only show loading on initial load
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  );
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
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData =
                        messageDoc.data() as Map<String, dynamic>;
                    final senderId = messageData['senderId'] as String?;
                    final text = messageData['text'] as String? ?? '';
                    // Check multiple possible field names for image URL
                    String? imageUrl =
                        (messageData['imageUrl'] as String?) ??
                        (messageData['image_url'] as String?) ??
                        (messageData['photoUrl'] as String?) ??
                        (messageData['photo_url'] as String?);

                    // Clean up the URL - remove any whitespace
                    if (imageUrl != null) {
                      imageUrl = imageUrl.trim();
                      if (imageUrl.isEmpty) {
                        imageUrl = null;
                      }
                    }

                    // Also check if text contains a URL (for backward compatibility)
                    final textUrl =
                        text.isNotEmpty &&
                            (text.startsWith('http://') ||
                                text.startsWith('https://'))
                        ? text.trim()
                        : null;
                    final finalImageUrl = imageUrl ?? textUrl;

                    // Debug: Print image URL if available
                    if (kDebugMode && finalImageUrl != null) {
                      debugPrint('📸 Chat image URL: $finalImageUrl');
                    }
                    final timestamp = messageData['createdAt'] as Timestamp?;
                    final isMe = senderId == currentUserId;
                    final messageId = messageDoc.id;

                    // Get reply context
                    final replyToMessageId =
                        messageData['replyToMessageId'] as String?;
                    final replyToText = messageData['replyToText'] as String?;
                    final replyToSenderId =
                        messageData['replyToSenderId'] as String?;

                    return _buildMessageBubble(
                      finalImageUrl != null && finalImageUrl == text
                          ? ''
                          : text,
                      finalImageUrl,
                      timestamp,
                      isMe,
                      index < messages.length - 1
                          ? (messages[index + 1].data()
                                as Map<String, dynamic>)['senderId']
                          : null,
                      messageId: messageId,
                      replyToMessageId: replyToMessageId,
                      replyToText: replyToText,
                      replyToSenderId: replyToSenderId,
                    );
                  },
                );
              },
            ),
          ),
          // Reply Preview (if replying)
          if (_replyingToMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingToSenderId == currentUserId
                              ? 'You'
                              : (_replyingToSenderName ?? 'User'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToText ?? '',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _clearReplyContext,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          // Message Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo, color: Colors.black54),
                      onPressed: _pickAndSendImage,
                      tooltip: 'Send photo',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _replyingToMessageId != null
                              ? 'Type a reply...'
                              : 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.secondary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String text,
    String? imageUrl,
    Timestamp? timestamp,
    bool isMe,
    String? nextSenderId, {
    String? messageId,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
  }) {
    // Check if text is actually a URL (for backward compatibility)
    final isTextUrl =
        text.isNotEmpty &&
        (text.startsWith('http://') || text.startsWith('https://'));
    final displayText = (isTextUrl && imageUrl != null && imageUrl.isNotEmpty)
        ? ''
        : text;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: messageId != null
            ? () => _showMessageOptions(messageId, text, isMe)
            : null,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Show sender name for received messages (not your own)
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  widget.otherUserName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: hasImage && displayText.isEmpty
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.secondary
                          : AppColors.dashboardBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply context (if this message is a reply)
                        if (replyToMessageId != null &&
                            replyToText != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: (isMe ? Colors.white : Colors.grey[300])
                                  ?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? Colors.white70
                                      : AppColors.secondary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyToSenderId == currentUserId
                                      ? 'You'
                                      : widget.otherUserName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Colors.white70
                                        : AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyToText.length > 50
                                      ? '${replyToText.substring(0, 50)}...'
                                      : replyToText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Image bubble - clickable photo (responsive)
                        if (hasImage)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate responsive image size
                              // Use 70% of message bubble max width, but cap between min and max
                              final screenWidth = MediaQuery.of(context).size.width;
                              final messageMaxWidth = screenWidth * 0.75;
                              final imageMaxWidth = messageMaxWidth * 0.95; // 95% of bubble width
                              
                              // Responsive sizing: smaller on mobile, larger on web/tablet
                              final responsiveWidth = kIsWeb 
                                  ? imageMaxWidth.clamp(200.0, 400.0) // Web: 200-400px
                                  : imageMaxWidth.clamp(200.0, 350.0); // Mobile: 200-350px
                              
                              final responsiveHeight = responsiveWidth * 1.2; // Maintain aspect ratio
                              
                              return GestureDetector(
                                onTap: () => _showFullImage(imageUrl),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: responsiveWidth,
                                    maxHeight: responsiveHeight,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          width: responsiveWidth,
                                          fit: BoxFit.contain, // Changed from cover to contain for better display
                                          headers: const {
                                            'Cache-Control': 'max-age=31536000',
                                          },
                                          cacheWidth: (responsiveWidth * 2).round().clamp(200, 800),
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              width: responsiveWidth,
                                              height: responsiveHeight * 0.7,
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value:
                                                      loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                      : null,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : AppColors.secondary,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                if (kDebugMode) {
                                                  debugPrint(
                                                    '❌ Image load error: $error',
                                                  );
                                                  debugPrint(
                                                    '📸 Image URL: $imageUrl',
                                                  );
                                                }
                                                return Container(
                                                  width: responsiveWidth,
                                                  height: responsiveHeight * 0.7,
                                                  color: Colors.grey[200],
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.broken_image,
                                                        size: 48,
                                                        color: Colors.grey[400],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Failed to load image',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Tap to retry',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey[500],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                        ),
                                        // Photo indicator overlay
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(
                                                20,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.photo,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        // Text message
                        if (displayText.isNotEmpty) ...[
                          if (hasImage) const SizedBox(height: 8),
                          Text(
                            displayText,
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
                if (isMe) const SizedBox(width: 8),
              ],
            ),
            // Show timestamp below message
            if (timestamp != null)
              Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                ),
                child: Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(
    String messageId,
    String messageText,
    bool isMyMessage,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.secondary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // Get sender name for reply - if it's my message, use "You", otherwise use other user's name
                final senderName = isMyMessage ? 'You' : widget.otherUserName;
                final senderId = isMyMessage
                    ? currentUserId
                    : widget.otherUserId;
                _setReplyContext(
                  messageId,
                  messageText,
                  senderId ?? '',
                  senderName,
                );
              },
            ),
            if (isMyMessage && currentUserId != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show tapped image in a full-screen dialog
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        padding: const EdgeInsets.all(48),
                        color: Colors.black87,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(48),
                        color: Colors.black87,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              imageUrl,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 32,
                right: 16,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
