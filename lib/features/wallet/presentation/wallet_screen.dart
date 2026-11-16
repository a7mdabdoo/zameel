// مطور 1
// فيجما: محفظتي - ذاكر وعلّم (الربط الحي بالرصيد والعملات من Firestore)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/application/timebank_pure_logic.dart';
import '../../timebank/data/timebank_repository.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final availableCoins = (userDoc?['timeCoins'] as num?)?.toInt() ?? 2;

    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(userId));
    final learnerSessions = learnerSessionsAsync.value ?? [];
    final heldCoins = TimeBankPureLogic.calculateHeldCoins(learnerSessions);
    final totalCoins = availableCoins + heldCoins;

    final transactionsAsync = ref.watch(userTransactionsStreamProvider(userId));
    final transactions = transactionsAsync.value ?? [];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardTheme.color,
        elevation: 0,
        title: Text(
          'محفظة الوقت 🪙',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main balance card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F6F6B), Color(0xFF134E4B)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'إجمالي رصيد محفظة الوقت',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Icon(Icons.monetization_on_rounded, size: 36, color: AppColors.pointsAmber),
                        const SizedBox(width: 8),
                        Text(
                          '$totalCoins',
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'عملات وقت',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // تفصيل الرصيد المتاح والرصيد المعلق
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF34D399),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'الرصيد المتاح',
                                      style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$availableCoins عملة',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'جاهز للحجز الفوري',
                                  style: TextStyle(fontSize: 10, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 44,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.pointsAmber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'الرصيد المعلق',
                                      style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$heldCoins عملة',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'محتجز في الضمان',
                                  style: TextStyle(fontSize: 10, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'الرصيد المتاح يعادل ${(availableCoins * 60 / 60).toStringAsFixed(0)} ساعة تعلّم مجانية مع زملائك',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              if (heldCoins > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pointsAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.pointsAmber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, size: 20, color: AppColors.pointsAmber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'لديك $heldCoins عملة محتجزة في الضمان لجلسات قيد الانتظار أو التأكيد أو النزاع. ستُحرر للمعلم أو تُسترد تلقائياً بحسب مسار كل جلسة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons (إنفاق أو كسب)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/need-help'),
                      icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'طلب مساعدة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/create-offer'),
                      icon: Icon(Icons.arrow_upward_rounded, color: primaryColor, size: 18),
                      label: Text(
                        'تقديم شرح (+1)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Transactions history
              Text(
                'سجل المعاملات (${transactions.length} حركات) 📜',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 12),

              if (transactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد حركات مسجلة بعد',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'عند حجز جلسة أو تقديم شرح لزميلك، ستظهر تفاصيل كل حركة وتحديثات الرصيد هنا بدقة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...transactions.map((tx) {
                  return _buildTransactionItem(
                    context: context,
                    title: tx.title,
                    date: tx.date,
                    amount: '${tx.isNegative ? '-' : '+'}${tx.amount} عملة',
                    isNegative: tx.isNegative,
                    icon: tx.icon,
                  );
                }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required BuildContext context,
    required String title,
    required String date,
    required String amount,
    required bool isNegative,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;
    final successColor = isDark ? AppColors.darkPrimary : AppColors.deepSage;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNegative
                  ? AppColors.error.withValues(alpha: 0.1)
                  : (isDark ? AppColors.darkPrimary.withValues(alpha: 0.15) : AppColors.sage.withValues(alpha: 0.2)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isNegative ? AppColors.error : successColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: textTertiary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isNegative ? AppColors.error : successColor,
            ),
          ),
        ],
      ),
    );
  }
}
