import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final focusDndServiceProvider = Provider<FocusDndService>((ref) {
  return FocusDndService();
});

class FocusDndService {
  static const MethodChannel _channel = MethodChannel('zameel/dnd');

  bool _isDndActive = false;
  bool get isDndActive => _isDndActive;

  /// فحص هل إذن عدم الإزعاج ممنوح على نظام أندرويد
  Future<bool> hasPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final isGranted = await _channel.invokeMethod<bool>('isNotificationPolicyAccessGranted');
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
      await _channel.invokeMethod('gotoPolicySettings');
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
        // filter: 2 = Priority
        final success = await _channel.invokeMethod<bool>('setInterruptionFilter', {'filter': 2});
        return success ?? false;
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
        // filter: 1 = All (Normal)
        await _channel.invokeMethod('setInterruptionFilter', {'filter': 1});
      }
    } catch (e) {
      debugPrint('Error disabling DND: $e');
    }
  }
}
