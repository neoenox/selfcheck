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
        MaterialApp(home: Scaffold(body: ResultCard(result: result))),
      );
      await tester.pump();

      expect(find.text('手入力'), findsOneWidget);
    });

    testWidgets('OCR save hides 手入力 marker', (tester) async {
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ResultCard(result: result))),
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
  });
}
