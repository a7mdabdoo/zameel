import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/data/timebank_repository.dart';

class SessionChatScreen extends ConsumerStatefulWidget {
  final TimeBankSessionModel session;

  const SessionChatScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  int _lastMessagesCount = 0;

  final List<String> _quickChips = [
    'أنا في قاعة الاستذكار بالكلية',
    'معي الحاسوب ومستعد للبدء',
    'خمس دقائق وأكون متواجداً',
    'تمام، في انتظارك',
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatSessionId = widget.session.id;
  }

  @override
  void dispose() {
    if (NotificationService.activeChatSessionId == widget.session.id) {
      NotificationService.activeChatSessionId = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final profileAsync = ref.read(userProfileStreamProvider);
    final senderName = profileAsync.value?.data()?['name'] as String? ?? user.displayName ?? 'زميل';

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 4)}';
    final message = SessionMessageModel(
      id: msgId,
      senderId: user.uid,
      senderName: senderName,
      text: clean,
      createdAt: DateTime.now(),
    );

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref.read(timeBankRepositoryProvider).sendSessionMessage(widget.session.id, message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الرسالة: $e'),
            backgroundColor: context.tokens.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentUserId = ref.watch(authServiceProvider).currentUser?.uid ?? '';
    final isTeacher = currentUserId == widget.session.teacherId;
    final peerName = isTeacher ? widget.session.learnerName : widget.session.teacherName;

    final messagesAsync = ref.watch(sessionMessagesStreamProvider(widget.session.id));

    // استماع للتحديثات وإرسال إشعار محلي إذا وصلت رسالة جديدة من الطرف الآخر
    ref.listen<AsyncValue<List<SessionMessageModel>>>(
      sessionMessagesStreamProvider(widget.session.id),
      (prev, next) {
        next.whenData((messages) {
          if (messages.length > _lastMessagesCount) {
            final latestMsg = messages.last;
            if (latestMsg.senderId != currentUserId && _lastMessagesCount > 0) {
              ref.read(notificationServiceProvider).showChatMessageNotification(
                    senderName: latestMsg.senderName,
                    messageText: latestMsg.text,
                    sessionId: widget.session.id,
                  );
            }
            _lastMessagesCount = messages.length;
            _scrollToBottom();
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tokens.brandContainer,
              child: Text(
                peerName.isNotEmpty ? peerName.substring(0, 1) : 'ز',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tokens.brand),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.session.courseName} • ${widget.session.isGroupSession ? "جلسة جماعية" : (isTeacher ? "المتعلّم" : "المعلم")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textMedium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.session.meetingUrl != null && widget.session.meetingUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                tooltip: 'رابط الاجتماع',
                icon: Icon(Icons.videocam_rounded, color: tokens.brand),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('رابط جلسة الشرح'),
                      content: SelectableText(widget.session.meetingUrl!),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          IconButton(
            tooltip: 'تفاصيل الجلسة',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              if (isTeacher) {
                context.push('/session-teacher', extra: widget.session);
              } else {
                context.push('/session-learner', extra: widget.session);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // شريط حالة الجلسة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: tokens.surfaceAlt,
              child: Row(
                children: [
                  Icon(
                    widget.session.mode == 'online' ? Icons.laptop_mac_rounded : Icons.location_on_rounded,
                    size: 16,
                    color: tokens.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.session.mode == 'online' ? 'جلسة أونلاين' : widget.session.location,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.brandContainer,
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: Text(
                      widget.session.time,
                      style: TextStyle(fontSize: 11, color: tokens.brand, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الرسائل
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('خطأ في تحميل الرسائل: $err', style: TextStyle(color: tokens.danger)),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 52, color: tokens.textLow),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ابدأ المحادثة لتنسيق تفاصيل اللقاء والموضوعات',
                            style: TextStyle(fontSize: 12, color: tokens.textMedium),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId;
                      final timeStr = DateFormat('hh:mm a', 'ar').format(msg.createdAt);

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? tokens.brand : tokens.surfaceAlt,
                            borderRadius: BorderRadius.only(
                              topLeft: AppRadii.bubbleRadius,
                              topRight: AppRadii.bubbleRadius,
                              bottomLeft: isMe ? AppRadii.bubbleRadius : AppRadii.bubbleNipRadius,
                              bottomRight: isMe ? AppRadii.bubbleNipRadius : AppRadii.bubbleRadius,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.brand,
                                  ),
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isMe ? tokens.onBrand : tokens.textHigh,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? tokens.onBrand.withValues(alpha: 0.7) : tokens.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // الردود السريعة
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickChips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ActionChip(
                    label: Text(
                      _quickChips[i],
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: tokens.surfaceAlt,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                    onPressed: () => _sendMessage(_quickChips[i]),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // حقل إرسال الرسالة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.chipRadius,
                      ),
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك لزميلك...',
                          hintStyle: TextStyle(fontSize: 13, color: tokens.textMedium),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: AppRadii.chipRadius,
                    onTap: _isSending ? null : () => _sendMessage(_textController.text),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: tokens.brand,
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
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