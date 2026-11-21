import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/models/app_models.dart';
import '../../../auth/data/auth_service.dart';
import '../../../timebank/data/timebank_repository.dart';

class SessionChatSheet extends ConsumerStatefulWidget {
  final TimeBankSessionModel session;
  final String peerName;

  const SessionChatSheet({
    super.key,
    required this.session,
    required this.peerName,
  });

  static Future<void> show(BuildContext context, TimeBankSessionModel session, String peerName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SessionChatSheet(session: session, peerName: peerName),
    );
  }

  @override
  ConsumerState<SessionChatSheet> createState() => _SessionChatSheetState();
}

class _SessionChatSheetState extends ConsumerState<SessionChatSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  final List<String> _quickChips = [
    'أنا في قاعة الاستذكار بالكلية',
    'معي الحاسوب ومستعد للبدء',
    'خمس دقائق وأكون متواجداً',
    'تمام، في انتظارك',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    if (!user.emailVerified) {
      final nowVerified = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
      if (!nowVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يجب تأكيد بريدك الإلكتروني أولاً لإرسال الرسائل في المحادثة'),
              action: SnackBarAction(
                label: 'أنا أكدت بريدي',
                textColor: Colors.amber,
                onPressed: () async {
                  final v = await ref.read(authServiceProvider).reloadUserAndCheckVerified();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? 'تم التحقق من البريد الإلكتروني بنجاح.' : 'لم يتم التأكيد بعد، يرجى مراجعة البريد الإلكتروني.')),
                    );
                  }
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }
    }

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
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending message to firestore: $e');
      if (mounted) {
        _textController.text = clean;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الرسالة: $e'),
            backgroundColor: context.tokens.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final myUid = user?.uid ?? '';
    final messagesAsync = ref.watch(sessionMessagesStreamProvider(widget.session.id));
    final messages = [...(messagesAsync.value ?? [])];
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final effectiveChips = <String>[..._quickChips];
    if (widget.session.mode == 'online' && widget.session.meetingUrl != null && widget.session.meetingUrl!.isNotEmpty) {
      effectiveChips.insert(0, 'رابط الاجتماع: ${widget.session.meetingUrl}');
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: AppRadii.sheetTopRadius,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: AppRadii.chipRadius,
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  children: [
                    Text(
                      'محادثة تنسيق الجلسة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'مع الزميل: ${widget.peerName} • ${widget.session.courseName}',
                      style: TextStyle(fontSize: 12, color: context.tokens.textMedium),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded),
                  tooltip: 'فتح في شاشة كاملة',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/session-chat', extra: widget.session);
                  },
                ),
              ],
            ),
          ),
          Divider(height: 16, color: context.tokens.border),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تواصل مع زميلك لتحديد مكان التجمع الدقيق في الكلية أو الاتفاق على موعد البدء.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.tokens.textMedium, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == myUid;

                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isMe ? context.tokens.brand : context.tokens.surfaceAlt,
                            borderRadius: BorderRadius.only(
                              topLeft: AppRadii.bubbleRadius,
                              topRight: AppRadii.bubbleRadius,
                              bottomLeft: isMe ? AppRadii.bubbleNipRadius : AppRadii.bubbleRadius,
                              bottomRight: isMe ? AppRadii.bubbleRadius : AppRadii.bubbleNipRadius,
                            ),
                            border: Border.all(
                              color: isMe ? Colors.transparent : context.tokens.border,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                Text(
                                  msg.senderName,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.tokens.brand),
                                ),
                              Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Quick chips
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: effectiveChips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = effectiveChips[index];
                return ActionChip(
                  label: Text(chip, style: TextStyle(fontSize: 11)),
                  backgroundColor: context.tokens.surfaceAlt,
                  side: BorderSide(color: context.tokens.border),
                  onPressed: () => _sendMessage(chip),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: context.tokens.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك لـ ${widget.peerName}...',
                      hintStyle: TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: context.tokens.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: AppRadii.chipRadius, borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send_rounded, size: 20),
                  style: IconButton.styleFrom(backgroundColor: context.tokens.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}