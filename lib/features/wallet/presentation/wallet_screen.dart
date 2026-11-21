// مطور 1
// فيجما: محفظتي - ذاكر وعلّم (الربط الحي بالرصيد والعملات من Firestore)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/state/app_state.dart';
import '../../auth/data/auth_service.dart';
import '../../timebank/application/timebank_pure_logic.dart';
import '../../timebank/data/timebank_repository.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    final availableCoins = ref.watch(userTimeCoinsProvider);

    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(userId));
    final learnerSessions = learnerSessionsAsync.value ?? [];
    final heldCoins = TimeBankPureLogic.calculateHeldCoins(learnerSessions);
    final totalCoins = availableCoins + heldCoins;

    final transactionsAsync = ref.watch(userTransactionsStreamProvider(userId));
    final transactions = transactionsAsync.value ?? [];

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: tokens.textHigh),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          'محفظة الوقت',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
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
                  color: tokens.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: tokens.brand.withValues(alpha: 0.3)),
                  boxShadow: tokens.floatingShadow,
                ),
                child: Column(
                  children: [
                    Text(
                      'إجمالي رصيد محفظة الوقت',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textMedium),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Icon(Icons.toll_rounded, size: 36, color: tokens.coin),
                        const SizedBox(width: 8),
                        Text(
                          '$totalCoins',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.bold,
                            color: tokens.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'عملات وقت',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textHigh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // تفصيل الرصيد المتاح والرصيد المعلق
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: AppRadii.controlRadius,
                        border: Border.all(color: tokens.border),
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
                                      decoration: BoxDecoration(
                                        color: tokens.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'الرصيد المتاح',
                                      style: TextStyle(fontSize: 12, color: tokens.textMedium, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$availableCoins عملة',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'جاهز للحجز الفوري',
                                  style: TextStyle(fontSize: 10, color: tokens.textLow),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 44,
                            color: tokens.border,
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
                                      decoration: BoxDecoration(
                                        color: tokens.coin,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'الرصيد المعلق',
                                      style: TextStyle(fontSize: 12, color: tokens.textMedium, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$heldCoins عملة',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textHigh),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'محتجز في الضمان',
                                  style: TextStyle(fontSize: 10, color: tokens.textLow),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.brandContainer.withValues(alpha: 0.35),
                        borderRadius: AppRadii.fullRadius,
                      ),
                      child: Text(
                        'الرصيد المتاح يعادل ${(availableCoins * 60 / 60).toStringAsFixed(0)} ساعة تعلّم مجانية مع زملائك',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.brand),
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
                    color: tokens.coin.withValues(alpha: 0.12),
                    borderRadius: AppRadii.controlRadius,
                    border: Border.all(color: tokens.coin.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 20, color: tokens.coin),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'لديك $heldCoins عملة محتجزة في الضمان لجلسات قيد الانتظار أو التأكيد أو النزاع. ستُحرر للمعلم أو تُسترد تلقائياً بحسب مسار كل جلسة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textHigh,
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
                      icon: Icon(Icons.arrow_downward_rounded, color: tokens.onBrand, size: 18),
                      label: Text(
                        'طلب مساعدة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: tokens.onBrand, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brand,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/create-offer'),
                      icon: Icon(Icons.arrow_upward_rounded, color: tokens.brand, size: 18),
                      label: Text(
                        'تقديم شرح (+1)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: tokens.brand, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.brand, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Transactions history
              Text(
                'سجل المعاملات (${transactions.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textHigh),
              ),
              const SizedBox(height: 12),

              if (transactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 54, color: tokens.textLow),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد حركات مسجلة بعد',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'عند حجز جلسة أو تقديم شرح لزميلك، ستظهر تفاصيل كل حركة وتحديثات الرصيد هنا بدقة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: tokens.textLow, height: 1.4),
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
    final tokens = context.tokens;
    final successColor = tokens.success;
    final dangerColor = tokens.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadii.controlRadius,
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNegative
                  ? tokens.dangerContainer
                  : tokens.successContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isNegative ? dangerColor : successColor,
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
                    color: tokens.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: tokens.textLow),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isNegative ? dangerColor : successColor,
            ),
          ),
        ],
      ),
    );
  }
}
