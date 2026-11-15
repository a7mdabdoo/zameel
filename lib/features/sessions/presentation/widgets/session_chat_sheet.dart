import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
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
  final List<SessionMessageModel> _localPending = [];
  bool _isSending = false;

  final List<String> _quickChips = [
    '📍 أنا في قاعة الاستذكار بالكلية',
    '💻 معايا اللابتوب ومجهز الشيت',
    '⏳ 5 دقائق وأكون عندك',
    '👍 تمام متفقين وفي انتظارك',
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
                      SnackBar(content: Text(v ? 'تم التحقق من بريدك بنجاح! يمكنك إرسال الرسائل الآن 🎉' : 'لم يتم التأكيد بعد، يرجى مراجعة بريدك 📩')),
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

    setState(() {
      _isSending = true;
      _localPending.add(message);
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تم حفظ الرسالة محلياً. لمزامنتها مع زميلك، تأكد من نشر قواعد Firestore في لوحة Firebase Console.'),
            duration: Duration(seconds: 4),
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
    final streamMessages = messagesAsync.value ?? [];

    final idSet = streamMessages.map((m) => m.id).toSet();
    final messages = [...streamMessages];
    for (final p in _localPending) {
      if (!idSet.contains(p.id)) {
        messages.add(p);
      }
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final effectiveChips = <String>[..._quickChips];
    if (widget.session.mode == 'online' && widget.session.meetingUrl != null && widget.session.meetingUrl!.isNotEmpty) {
      effectiveChips.insert(0, '🔗 رابط الاجتماع: ${widget.session.meetingUrl}');
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              borderRadius: BorderRadius.circular(2),
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
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  children: [
                    Text(
                      'محادثة تنسيق اللقاء 💬',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'مع الزميل: ${widget.peerName} • ${widget.session.courseName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(height: 16, color: AppColors.hairline),

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
                          const Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'تواصل مع زميلك لتحديد مكان التجمع الدقيق في الكلية أو الاتفاق على موعد البدء.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
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
                            color: isMe ? AppColors.primary : Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              bottomRight: isMe ? const Radius.circular(16) : const Radius.circular(4),
                            ),
                            border: Border.all(
                              color: isMe ? Colors.transparent : AppColors.hairline,
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
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                  label: Text(chip, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.hairline),
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
              border: const Border(top: BorderSide(color: AppColors.hairline)),
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
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 20),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
