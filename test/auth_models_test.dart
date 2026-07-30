import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/models/auth_tokens.dart';
import 'package:saobracaj/auth/models/viewer.dart';
import 'package:saobracaj/auth/state_management/auth_cubit.dart';
import 'package:saobracaj/theme/theme_cubit.dart';

void main() {
  group('AuthTokens.fromJson', () {
    test('разбирает токены и флаг authenticated из ответа сервера', () {
      final tokens = AuthTokens.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'authenticated': false,
      });
      expect(tokens.accessToken, 'a');
      expect(tokens.refreshToken, 'r');
      expect(tokens.authenticated, isFalse);
    });

    test('по умолчанию authenticated = true, если поле отсутствует', () {
      final tokens = AuthTokens.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
      });
      expect(tokens.authenticated, isTrue);
    });
  });

  group('Viewer.fromJson', () {
    test('разбирает профиль и список прав', () {
      final viewer = Viewer.fromJson({
        'id': '42',
        'email': 'user@example.com',
        'permissions': ['registered', 'read_users'],
      });
      expect(viewer.id, '42');
      expect(viewer.email, 'user@example.com');
      expect(viewer.permissions, ['registered', 'read_users']);
    });

    test('пустой список прав при отсутствии поля', () {
      final viewer = Viewer.fromJson({'id': '1', 'email': 'a@b.c'});
      expect(viewer.permissions, isEmpty);
    });
  });

  group('AuthState', () {
    test('copyWith очищает viewer при clearViewer', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        viewer: Viewer(id: '1', email: 'a@b.c', permissions: []),
      );
      final next = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearViewer: true,
      );
      expect(next.viewer, isNull);
      expect(next.isAuthenticated, isFalse);
    });
  });

  group('ThemeState', () {
    test('seedColor соответствует выбранному акценту', () {
      const state = ThemeState(accentIndex: 1, mode: ThemeMode.dark);
      expect(state.seedColor, kAppAccents[1].color);
    });

    test('copyWith меняет только режим темы', () {
      const state = ThemeState(accentIndex: 2, mode: ThemeMode.system);
      final next = state.copyWith(mode: ThemeMode.light);
      expect(next.accentIndex, 2);
      expect(next.mode, ThemeMode.light);
    });
  });
}
