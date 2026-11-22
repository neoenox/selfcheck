import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;
import 'package:selfcheck_jibun_check/presentation/widgets/price_context_badges.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/result_card.dart';

/// Regression tests for issue #89:
/// result screen must visually distinguish manually-entered prices.
void main() {
  group('Manual entry marker (issue #89)', () {
    testWidgets('manual save shows 手入力 marker', (tester) async {
      final result = domain.ComparisonResult.firstPrice(
        350,
        isManualEntry: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text('手入力'), findsOneWidget);
    });

    testWidgets('OCR save hides 手入力 marker', (tester) async {
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text('手入力'), findsNothing);
    });

    testWidgets('manual marker coexists with SALE/member badges', (
      tester,
    ) async {
      final result = domain.ComparisonResult.firstPrice(
        350,
        isManualEntry: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PriceContextBadges(
                  isSaleVisible: true,
                  isMemberPriceVisible: true,
                ),
                ResultCard(result: result),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('手入力'), findsOneWidget);
      expect(find.text('SALE'), findsOneWidget);
      expect(find.text('会員価格'), findsOneWidget);
    });

    testWidgets('marker shows for every manual status, hides for OCR', (
      tester,
    ) async {
      final manualCases = [
        domain.ComparisonResult.firstPrice(350, isManualEntry: true),
        domain.ComparisonResult.historyShort(
          currentPrice: 350,
          lastPrice: 360,
          observationCount: 1,
          isManualEntry: true,
        ),
        domain.ComparisonResult.withBaseline(
          currentPrice: 350,
          baselineMedianYen: 360,
          diffYen: -10,
          diffRate: -10 / 360,
          label: domain.ComparisonLabel.normal,
          observationCount: 5,
          isManualEntry: true,
        ),
      ];
      for (final result in manualCases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ResultCard(result: result)),
          ),
        );
        await tester.pump();
        expect(find.text('手入力'), findsOneWidget);
      }

      final ocr = domain.ComparisonResult.withBaseline(
        currentPrice: 398,
        baselineMedianYen: 360,
        diffYen: 38,
        diffRate: 38 / 360,
        label: domain.ComparisonLabel.expensive,
        observationCount: 5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: ocr)),
        ),
      );
      await tester.pump();
      expect(find.text('手入力'), findsNothing);
    });

    testWidgets('manual marker coexists with all price-context badges', (
      tester,
    ) async {
      final result = domain.ComparisonResult.firstPrice(
        350,
        isManualEntry: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PriceContextBadges(
                  isSaleVisible: true,
                  isMemberPriceVisible: true,
                  isCouponPriceVisible: true,
                  isBulkDiscount: true,
                ),
                ResultCard(result: result),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('手入力'), findsOneWidget);
      expect(find.text('SALE'), findsOneWidget);
      expect(find.text('会員価格'), findsOneWidget);
      expect(find.text('クーポン'), findsOneWidget);
      expect(find.text('まとめ割'), findsOneWidget);
    });

    testWidgets('no overflow across small screens and text scales', (
      tester,
    ) async {
      // ResultCard has no product-name field; the long-text risks are the
      // JAN code, header/diff/count texts, max price (99999) and the
      // footer buttons, so the matrix below stresses those instead.
      final results = [
        domain.ComparisonResult.firstPrice(99999, isManualEntry: true),
        domain.ComparisonResult.historyShort(
          currentPrice: 99999,
          lastPrice: 88888,
          observationCount: 2,
          isManualEntry: true,
        ),
        domain.ComparisonResult.withBaseline(
          currentPrice: 99999,
          baselineMedianYen: 88888,
          diffYen: 11111,
          diffRate: 11111 / 88888,
          label: domain.ComparisonLabel.expensive,
          observationCount: 12345,
          isManualEntry: true,
        ),
      ];
      final sizes = [
        (width: 320.0, height: 568.0, scale: 1.0),
        (width: 320.0, height: 568.0, scale: 1.5),
        (width: 320.0, height: 568.0, scale: 2.0),
        (width: 360.0, height: 640.0, scale: 2.0),
      ];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      for (final size in sizes) {
        tester.view.physicalSize = Size(size.width, size.height);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = size.scale;
        for (var i = 0; i < results.length; i++) {
          // Alternate callbacks on/off so both enabled and disabled
          // footer buttons are exercised.
          final withCallbacks = i.isEven;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PriceContextBadges(
                        isSaleVisible: true,
                        isMemberPriceVisible: true,
                        isCouponPriceVisible: true,
                        isBulkDiscount: true,
                      ),
                      ResultCard(
                        result: results[i],
                        janCode: '4901234567890',
                        onDismiss: withCallbacks ? () {} : null,
                        onScanAgain: withCallbacks ? () {} : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                'overflow at ${size.width}x${size.height} '
                'scale ${size.scale} case $i',
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason:
                'overflow after pump at ${size.width}x${size.height} '
                'scale ${size.scale} case $i',
          );

          expect(find.text('手入力'), findsOneWidget);
        }
      }
    });
  });
}
