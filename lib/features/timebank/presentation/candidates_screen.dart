// مطور 3
// فيجما: المرشحون للمساعدة - ذاكر وعلّم

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class CandidatePeer {
  final String id;
  final String name;
  final String initials;
  final double rating;
  final int reviewsCount;
  final int matchScore;
  final String availableSlot;
  final String location;
  final String note;

  const CandidatePeer({
    required this.id,
    required this.name,
    required this.initials,
    required this.rating,
    required this.reviewsCount,
    required this.matchScore,
    required this.availableSlot,
    required this.location,
    required this.note,
  });
}

class CandidatesScreen extends StatelessWidget {
  const CandidatesScreen({super.key});

  final List<CandidatePeer> _candidates = const [
    CandidatePeer(
      id: 'p1',
      name: 'عمر خالد',
      initials: 'ع.خ',
      rating: 4.9,
      reviewsCount: 14,
      matchScore: 94,
      availableSlot: 'اليوم • 1:30 ظهراً (60 دقيقة)',
      location: 'معمل 3 أو مكتبة الكلية',
      note: 'متمكن في الجبر الخطي والتحويلات الخطية، وحصل على امتياز في المادة.',
    ),
    CandidatePeer(
      id: 'p2',
      name: 'سارة علي',
      initials: 'س.ع',
      rating: 4.8,
      reviewsCount: 9,
      matchScore: 88,
      availableSlot: 'غداً • 11:00 صباحاً (45 دقيقة)',
      location: 'ساحة الكلية • قاعة الاستذكار',
      note: 'شرحت لـ 9 زملاء سابقاً بتقييم ممتاز.',
    ),
    CandidatePeer(
      id: 'p3',
      name: 'محمود يوسف',
      initials: 'م.ي',
      rating: 4.7,
      reviewsCount: 6,
      matchScore: 82,
      availableSlot: 'بعد غد • 2:00 ظهراً (60 دقيقة)',
      location: 'معمل الحاسب الآلي',
      note: 'شرح مبسط مع حل مسائل الامتحانات السابقة.',
    ),
  ];

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
          'المرشحون للمساعدة 🎯',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: _candidates.length,
          itemBuilder: (context, index) {
            final peer = _candidates[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: match badge & Peer info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'تطابق ${peer.matchScore}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                peer.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '(${peer.reviewsCount} جلسة)',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${peer.rating}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.star_rounded, size: 16, color: AppColors.pointsAmber),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              peer.initials,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    peer.note,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            peer.availableSlot,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Button "اعرض واحجز" -> /booking
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/booking'),
                      icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        'اعرض واحجز الجلسة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
