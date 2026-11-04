// مطور 3
// فيجما: حجز جلسة - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'تأكيد حجز الجلسة ✍️',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Teacher card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryContainer,
                      child: const Text('ع.خ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('عمر خالد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          SizedBox(height: 2),
                          Text('الفرقة الثانية • كلية الحاسبات والذكاء الاصطناعي', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: AppColors.pointsAmber),
                              SizedBox(width: 4),
                              Text('4.9 (14 جلسة ناجحة)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Session details card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.menu_book_rounded, 'المادة', 'الجبر الخطي (Linear Algebra)'),
                    const Divider(height: 20, color: AppColors.hairline),
                    _buildDetailRow(Icons.topic_outlined, 'الموضوع', 'الفضاءات المتجهة والتحويلات الخطية'),
                    const Divider(height: 20, color: AppColors.hairline),
                    _buildDetailRow(Icons.calendar_today_outlined, 'الموعد', 'اليوم • 1:30 ظهراً (60 دقيقة)'),
                    const Divider(height: 20, color: AppColors.hairline),
                    _buildDetailRow(Icons.location_on_outlined, 'المكان', 'معمل 3 • مبنى الكلية'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Time Coin deduction notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pointsAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.pointsAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.pointsAmber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تكلفة الجلسة: 1 عملة وقت', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF664700))),
                          SizedBox(height: 2),
                          Text('يتم حجز العملة كأمانة، وتتحول لحساب الزميل بعد تأكيد إتمام الجلسة.', style: TextStyle(fontSize: 12, color: Color(0xFF855D00))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Button "أرسل طلب الجلسة" -> /my-sessions
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال طلب الجلسة إلى عمر خالد بنجاح 🚀')),
                    );
                    context.push('/my-sessions');
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'أرسل طلب الجلسة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
