import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final focusDndServiceProvider = Provider<FocusDndService>((ref) {
  return FocusDndService();
});

class FocusDndService {
  bool _isDndActive = false;
  bool get isDndActive => _isDndActive;

  /// فحص هل إذن عدم الإزعاج ممنوح على نظام أندرويد
  Future<bool> hasPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final isGranted = await FlutterDnd.isNotificationPolicyAccessGranted;
      return isGranted ?? false;
    } catch (e) {
      debugPrint('Error checking DND permission: $e');
      return false;
    }
  }

  /// توجيه المستخدم لصفحة صلاحية عدم الإزعاج في إعدادات النظام
  Future<void> openDndSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      FlutterDnd.gotoPolicySettings();
    } catch (e) {
      debugPrint('Error opening DND settings: $e');
    }
  }

  /// تفعيل وضع عدم الإزعاج (DND / كتم الإشعارات)
  /// يعود بـ true إذا تم التفعيل على مستوى النظام، أو false إذا تم التفعيل الافتراضي/الداخلي فقط
  Future<bool> enableDnd() async {
    _isDndActive = true;
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final hasPerm = await hasPermission();
      if (hasPerm) {
        await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_PRIORITY);
        return true;
      }
    } catch (e) {
      debugPrint('Error enabling DND: $e');
    }
    return false;
  }

  /// إلغاء تفعيل وضع عدم الإزعاج وإرجاع التنبيهات للوضع الطبيعي
  Future<void> disableDnd() async {
    _isDndActive = false;
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final hasPerm = await hasPermission();
      if (hasPerm) {
        await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALL);
      }
    } catch (e) {
      debugPrint('Error disabling DND: $e');
    }
  }
}
