import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_push_result.freezed.dart';

/// Результат мутации `sendTestPush`.
///
/// [devices] — сколько устройств получателя бэкенд считает пригодными для
/// доставки (пуши включены и есть FCM-токен) на момент постановки в очередь.
/// Ноль означает, что уведомление приняли, но доставлять его некуда — самая
/// частая причина «тест не пришёл», поэтому число показывается на экране.
@freezed
abstract class TestPushResult with _$TestPushResult {
  const factory TestPushResult({
    required String email,
    required String userId,
    required int devices,
    required String notificationId,
  }) = _TestPushResult;

  const TestPushResult._();

  factory TestPushResult.fromJson(Map<String, dynamic> json) {
    return TestPushResult(
      email: json['email'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      devices: (json['devices'] as num?)?.toInt() ?? 0,
      notificationId: json['notificationId'] as String? ?? '',
    );
  }

  /// Есть ли куда доставлять: без пригодных устройств пуш просто не дойдёт.
  bool get hasDevices => devices > 0;
}
