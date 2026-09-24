import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/jwt.dart';

/// Локальный разбор токенов бэкенда: срок жизни (`exp`) и владелец (`sub`).
/// Подпись здесь не проверяется — сервер остаётся единственной инстанцией,
/// которая решает, годится ли токен.

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
}

void main() {
  test('владелец токена — claim sub', () {
    expect(jwtSubject(_jwt({'sub': 'user-1'})), 'user-1');
    expect(jwtSubject(_jwt({'sub': 'user-1', 'email': 'a@b.c'})), 'user-1');
  });

  test('нечитаемый токен владельца не даёт', () {
    expect(jwtSubject(null), isNull);
    expect(jwtSubject(''), isNull);
    expect(jwtSubject('не токен'), isNull);
    expect(jwtSubject('a.b.c'), isNull);
    expect(jwtSubject(_jwt({'email': 'a@b.c'})), isNull);
    expect(jwtSubject(_jwt({'sub': ''})), isNull);
    expect(jwtSubject(_jwt({'sub': 42})), isNull);
  });

  test('срок жизни по-прежнему читается', () {
    final exp = DateTime.utc(2030, 1, 1);
    expect(
      jwtExpiry(_jwt({'exp': exp.millisecondsSinceEpoch ~/ 1000})),
      exp,
    );
    expect(jwtExpiry(_jwt({'sub': 'user-1'})), isNull);
    expect(isJwtExpired(_jwt({'exp': 0})), isTrue);
    expect(isJwtExpired(null), isTrue);
  });
}
