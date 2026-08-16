import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/subscription/models/subscription_models.dart';
import 'package:saobracaj/subscription/presentation/payment_slip_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ответ бэкенда на заказ с уплатницей — как его отдаёт `Order.payment`.
Map<String, dynamic> _orderJson({bool withPayment = true}) => {
  'id': 'o1',
  'userId': 'u1',
  'userEmail': 'user@example.com',
  'sku': 'basic_12m',
  'tariffKind': 'BASIC',
  'months': 12,
  'amountRsd': 3490,
  'status': 'PENDING',
  'referenceDisplay': '82-00001234',
  'createdAt': '2026-08-16T10:00:00Z',
  'paymentDueAt': '2026-08-30T10:00:00Z',
  'paidAt': null,
  'payment': withPayment
      ? {
          'payer': 'user@example.com',
          'purpose': 'Saobraćaj pretplata 82-00001234',
          'payeeName': 'Gleb Klimov PR',
          'payeeAddress': 'Beograd',
          'paymentCode': '289',
          'currency': 'RSD',
          'amountRsd': 3490,
          'amountDisplay': '3.490,00',
          'payeeAccount': '265-0000000123456-78',
          'model': '97',
          'reference': '8200001234',
          'referenceDisplay': '82-00001234',
          'ipsQrText':
              'K:PR|V:01|C:1|R:265000000012345678|N:Gleb Klimov PR\r\nBeograd|I:RSD3490,00|SF:289|S:Saobraćaj pretplata 82-00001234|RO:978200001234',
          'ipsQrUrl':
              'https://api.saobracaj.gleb.at/billing/orders/o1/ips-qr.png',
        }
      : null,
};

Future<void> _pump(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Уплатница заказа', () {
    test('заказ разбирает уплатницу, а без неё payment == null', () {
      final order = Order.fromJson(_orderJson());
      final slip = order.payment!;
      expect(slip.payeeAccount, '265-0000000123456-78');
      expect(slip.amountDisplay, '3.490,00');
      expect(slip.model, '97');
      expect(slip.referenceDisplay, '82-00001234');
      expect(slip.payeeLine, 'Gleb Klimov PR, Beograd');
      expect(slip.ipsQrText, startsWith('K:PR|V:01|C:1|R:265000000012345678|'));
      expect(order.userEmail, 'user@example.com');

      final bare = Order.fromJson(_orderJson(withPayment: false));
      expect(bare.payment, isNull);
      expect(bare.isPending, isTrue);
    });

    testWidgets('виджет показывает все поля бланка и QR', (tester) async {
      final order = Order.fromJson(_orderJson());
      await _pump(tester, PaymentSlipView(slip: order.payment!));

      expect(find.text('265-0000000123456-78'), findsOneWidget);
      expect(find.text('3.490,00'), findsOneWidget);
      expect(find.text('82-00001234'), findsOneWidget);
      expect(find.text('Gleb Klimov PR, Beograd'), findsOneWidget);
      // Сербские подписи бланка — человек ищет именно их в форме банка.
      expect(find.text('Рачун примаоца'), findsOneWidget);
      expect(find.text('Позив на број (одобрење)'), findsOneWidget);
      // QR рисуется на устройстве из текста IPS.
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('компактный вид — без QR и подсказки', (tester) async {
      final order = Order.fromJson(_orderJson());
      await _pump(tester, PaymentSlipView(slip: order.payment!, compact: true));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('82-00001234'), findsOneWidget);
    });
  });
}
