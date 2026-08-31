import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'rider_contact_modal.dart';

class RiderChatModal extends StatefulWidget {
  final String rideId;
  final String passengerName;
  final String passengerRating;
  final String? passengerPhone;
  final String? passengerAvatarUrl;

  static String? activeChatRideId;

  const RiderChatModal({
    super.key,
    required this.rideId,
    this.passengerName = 'Passenger',
    this.passengerRating = '5.0',
    this.passengerPhone,
    this.passengerAvatarUrl,
  });

  static void show(
    BuildContext context, {
    required String rideId,
    String passengerName = 'Passenger',
    String passengerRating = '5.0',
    String? passengerPhone,
    String? passengerAvatarUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RiderChatModal(
        rideId: rideId,
        passengerName: passengerName,
        passengerRating: passengerRating,
        passengerPhone: passengerPhone,
        passengerAvatarUrl: passengerAvatarUrl,
      ),
    );
  }

  @override
  State<RiderChatModal> createState() => _RiderChatModalState();
}

class _RiderChatModalState extends State<RiderChatModal> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<List<ChatMessageModel>> _messagesStream;
  bool _isSending = false;
  bool _isUploadingPhoto = false;
  DateTime? _lastSentAt;
  String? _lastSentText;
  int _lastMessageCount = 0;

  late String _passengerName;
  late String _passengerPhone;
  String? _passengerAvatarUrl;

  final List<String> _quickReplies = [
    '📍 I\'m at the pickup point',
    '🚗 In traffic (2 mins delay)',
    '🙋 I\'m outside near the entrance',
    '❓ Where are you waiting?',
    '👍 Got it, see you soon!',
  ];

  @override
  void initState() {
    super.initState();
    RiderChatModal.activeChatRideId = widget.rideId;
    _passengerName = widget.passengerName;
    _passengerPhone = widget.passengerPhone ?? '';
    _passengerAvatarUrl = widget.passengerAvatarUrl;
    _fetchPassengerInfoFromProfiles();
    _messagesStream = ChatService.streamMessages(widget.rideId);
    ChatService.markAsRead(widget.rideId);
  }

  Future<void> _fetchPassengerInfoFromProfiles() async {
    try {
      final rideData = await Supabase.instance.client
          .from('rides')
          .select('user_id, passenger_name, passenger_phone, passenger_avatar_url')
          .eq('id', widget.rideId)
          .maybeSingle();

      if (rideData != null) {
        String? phone = rideData['passenger_phone']?.toString();
        String? name = rideData['passenger_name']?.toString();
        String? avatar = rideData['passenger_avatar_url']?.toString();

        final userId = rideData['user_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final profileData = await Supabase.instance.client
              .from('profiles')
              .select('full_name, phone_number, avatar_url')
              .eq('id', userId)
              .maybeSingle();

          if (profileData != null) {
            final pPhone = profileData['phone_number']?.toString();
            final pName = profileData['full_name']?.toString();
            final pAvatar = profileData['avatar_url']?.toString();

            if (pPhone != null && pPhone.isNotEmpty) phone = pPhone;
            if (pName != null && pName.isNotEmpty) name = pName;
            if (pAvatar != null && pAvatar.isNotEmpty) avatar = pAvatar;
          }
        }

        if (mounted) {
          setState(() {
            if (phone != null && phone.isNotEmpty) _passengerPhone = phone;
            if (name != null && name.isNotEmpty) _passengerName = name;
            if (avatar != null && avatar.isNotEmpty) _passengerAvatarUrl = avatar;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching passenger info: $e');
    }
  }

  @override
  void dispose() {
    if (RiderChatModal.activeChatRideId == widget.rideId) {
      RiderChatModal.activeChatRideId = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      if (animate) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final String content = (quickText ?? _textController.text).trim();
    if (content.isEmpty || _isSending) return;

    // Prevent duplicate accidental click within 1.2s
    final now = DateTime.now();
    if (_lastSentText == content &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!).inMilliseconds < 1200) {
      return;
    }

    _lastSentText = content;
    _lastSentAt = now;

    if (quickText == null) {
      _textController.clear();
    }

    setState(() {
      _isSending = true;
    });

    await ChatService.sendMessage(
      rideId: widget.rideId,
      message: content,
      senderRole: 'driver',
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (photo == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      final bytes = await photo.readAsBytes();
      final success = await ChatService.sendImageMessage(
        rideId: widget.rideId,
        imageBytes: bytes,
        senderRole: 'driver',
      );

      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not send photo. Please try again.',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking or uploading photo: $e');
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send Photo (Encrypted)',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.textDark, size: 20),
              ),
              title: Text(
                'Take Photo with Camera',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.textDark, size: 20),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    final TransformationController transformController = TransformationController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            void zoomIn() {
              final currentScale = transformController.value.getMaxScaleOnAxis();
              final newScale = (currentScale * 1.4).clamp(0.8, 5.0);
              setDialogState(() {
                transformController.value = Matrix4.identity()..scale(newScale);
              });
            }

            void zoomOut() {
              final currentScale = transformController.value.getMaxScaleOnAxis();
              final newScale = (currentScale / 1.4).clamp(0.8, 5.0);
              setDialogState(() {
                transformController.value = Matrix4.identity()..scale(newScale);
              });
            }

            void resetZoom() {
              setDialogState(() {
                transformController.value = Matrix4.identity();
              });
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                // Interactive Image View
                InteractiveViewer(
                  transformationController: transformController,
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(40),
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Top Close Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),

                // Floating Compact Zoom Controls (Bottom Right)
                Positioned(
                  bottom: 46,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: zoomIn,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        Container(width: 14, height: 1, color: Colors.white24),
                        InkWell(
                          onTap: zoomOut,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        Container(width: 14, height: 1, color: Colors.white24),
                        InkWell(
                          onTap: resetZoom,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.restart_alt_rounded, color: Colors.white, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Helper Hint Pill
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pinch_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          'Pinch to zoom',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _callPassenger() {
    RiderContactModal.show(
      context,
      rideId: widget.rideId,
      passengerName: _passengerName,
      passengerRating: widget.passengerRating,
      phoneNumber: _passengerPhone.isNotEmpty ? _passengerPhone : (widget.passengerPhone ?? ''),
      passengerAvatarUrl: _passengerAvatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 10;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: keyboardHeight + safeBottomInset,
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Passenger Header with Phone Call & Close
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: ClipOval(
                  child: (widget.passengerAvatarUrl != null && widget.passengerAvatarUrl!.isNotEmpty)
                      ? Image.network(
                          widget.passengerAvatarUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 26,
                            color: AppColors.textDark,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 26,
                          color: AppColors.textDark,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.passengerName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.passengerRating} Rating',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Call Button
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: AppColors.textDark, size: 18),
                ),
                onPressed: _callPassenger,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // End-to-End Encryption Security Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'End-to-End Encrypted (AES-256)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 12),

          // Messages Stream List
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _buildEmptyChatState();
                }

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }

                return ListView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, isLast: index == messages.length - 1);
                  },
                );
              },
            ),
          ),

          // Uploading photo banner
          if (_isUploadingPhoto)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Encrypting and uploading photo to media_images...',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDark),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Quick Preset Reply Chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _quickReplies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final replyText = _quickReplies[index];
                return GestureDetector(
                  onTap: () => _sendMessage(replyText),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      replyText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Message Input Field Row with Photo Attach Button
          Row(
            children: [
              // Photo Attachment Button
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text Field
              Expanded(
                child: TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Message ${widget.passengerName.split(' ').first}...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              GestureDetector(
                onTap: () => _sendMessage(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.textDark,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, {bool isLast = false}) {
    final isMe = msg.isDriver;
    final timeStr = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
    final hasPhoto = msg.hasImage;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 2 : 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySubtle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
              ),
              child: ClipOval(
                child: (widget.passengerAvatarUrl != null && widget.passengerAvatarUrl!.isNotEmpty)
                    ? Image.network(
                        widget.passengerAvatarUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppColors.textDark,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: AppColors.textDark,
                      ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // If message has an image from private bucket
            if (hasPhoto && msg.imageUrl != null) ...[
              GestureDetector(
                onTap: () => _showFullScreenImage(msg.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg.imageUrl!,
                    width: 220,
                    height: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 220,
                        height: 150,
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 100,
                        color: Colors.black12,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'Photo unavailable',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            if (msg.message.isNotEmpty && (!hasPhoto || msg.message != '📷 Photo'))
              Text(
                msg.message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: AppColors.textDark.withValues(alpha: 0.6),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    color: msg.isRead ? Colors.blue.shade700 : AppColors.textDark.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat with ${widget.passengerName}',
              style: GoogleFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coordinate the pickup location or send photos and quick updates to your passenger.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
