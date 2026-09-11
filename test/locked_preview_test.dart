import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/subscription/presentation/paywall.dart';

/// Превью под пейволлом режется на клиенте по тому же правилу, что и на
/// бэкенде (`preview_of` в `comments/model.rs`): первый абзац, не длиннее
/// 220 символов, обрезка по последнему пробелу и многоточие, если что-то
/// отброшено. Это страховка от полной копии конспекта из кэша: под размытием
/// не должно оказаться больше, чем отдал бы сервер.
void main() {
  test('короткий одноабзацный текст остаётся как есть', () {
    expect(lockedPreviewOf('  Правило простое.  '), 'Правило простое.');
    expect(lockedPreviewOf(''), '');
  });

  test('от многоабзацного текста остаётся первый абзац с многоточием', () {
    expect(
      lockedPreviewOf('Первый абзац.\n\nВторой абзац.\n\nТретий.'),
      'Первый абзац.…',
    );
  });

  test('длинный абзац режется по последнему пробелу до 220 символов', () {
    final long = List.filled(100, 'слово').join(' ');
    final preview = lockedPreviewOf(long);
    expect(preview.endsWith('…'), isTrue);
    expect(preview.runes.length, lessThanOrEqualTo(lockedPreviewChars + 1));
    // Обрезано по границе слова: перед многоточием — целое слово, не обрубок.
    expect(preview, endsWith('слово…'));
    expect(preview.contains(' …'), isFalse);
  });

  test('символы считаются по кодовым точкам, а не по байтам', () {
    // 220 кириллических букв без пробелов ещё влезают целиком.
    final exact = 'я' * lockedPreviewChars;
    expect(lockedPreviewOf(exact), exact);
    // 221-я уже нет: пробела нет, режем по лимиту.
    final over = 'я' * (lockedPreviewChars + 1);
    expect(lockedPreviewOf(over), '${'я' * lockedPreviewChars}…');
  });
}
