import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/result_card.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/price_context_badges.dart';

void main() {
  late PriceRepository repository;
  late CompareUseCase compareUseCase;
  late ScanCoordinator coordinator;
  late ScanScreenController controller;

  setUp(() async {
    repository = await createTestRepository();
    compareUseCase = CompareUseCase(repository);
    coordinator = ScanCoordinator(
      repository: repository,
      compareUseCase: compareUseCase,
      barcodeAdapter: _StubBarcodeAdapter(),
      priceAdapter: _StubPriceOcrAdapter(),
    );
    controller = ScanScreenController(coordinator: coordinator);
  });

  tearDown(() {
    controller.dispose();
    coordinator.dispose();
    repository.dispose();
  });

  Widget buildTestApp({Widget? child}) {
    return MaterialApp(home: child ?? ScanScreen(controller: controller));
  }

  group('ScanScreen', () {
    testWidgets('shows idle overlay initially', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester
          .pump(); // Use pump() not pumpAndSettle() to avoid animation timeout

      expect(find.text('タップしてスキャン開始'), findsOneWidget);
      expect(find.text('自分値スキャン'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
    });

    testWidgets('shows scan button in idle state', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
    });
  });

  group('ResultCard', () {
    testWidgets('shows firstPrice result correctly', (tester) async {
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text('¥398'), findsOneWidget);
      expect(find.text('初めての記録です'), findsOneWidget);
    });

    testWidgets('shows withBaseline result correctly', (tester) async {
      final result = domain.ComparisonResult.withBaseline(
        currentPrice: 398,
        baselineMedianYen: 450,
        diffYen: -52,
        diffRate: -0.1156,
        label: domain.ComparisonLabel.veryCheap,
        observationCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text('¥398'), findsOneWidget);
      expect(find.text('かなり安い'), findsOneWidget);
      expect(find.text('自分値: ¥450'), findsOneWidget);
      expect(find.text('過去の値段と比較'), findsOneWidget);
      expect(find.text('5件の履歴'), findsOneWidget);
    });

    testWidgets('shows correct color for expensive label', (tester) async {
      final result = domain.ComparisonResult.withBaseline(
        currentPrice: 600,
        baselineMedianYen: 500,
        diffYen: 100,
        diffRate: 0.2,
        label: domain.ComparisonLabel.expensive,
        observationCount: 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text('高い'), findsOneWidget);
      expect(find.text('▲▲'), findsOneWidget);
    });

    testWidgets('shows janCode when provided', (tester) async {
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(result: result, janCode: '4901234567890'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4901234567890'), findsOneWidget);
    });

    testWidgets('dismiss button calls onDismiss', (tester) async {
      bool dismissed = false;
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(result: result, onDismiss: () => dismissed = true),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('閉じる'));
      expect(dismissed, true);
    });

    testWidgets('scan button calls onScanAgain', (tester) async {
      bool scanAgain = false;
      final result = domain.ComparisonResult.firstPrice(398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(
              result: result,
              onScanAgain: () => scanAgain = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('スキャン'));
      expect(scanAgain, true);
    });
  });

  group('LabelColors', () {
    test('symbolForLabel returns correct symbols', () {
      expect(
        LabelColors.symbolForLabel(domain.ComparisonLabel.veryCheap),
        '▼▼',
      );
      expect(LabelColors.symbolForLabel(domain.ComparisonLabel.cheap), '▼');
      expect(LabelColors.symbolForLabel(domain.ComparisonLabel.normal), '─');
      expect(
        LabelColors.symbolForLabel(domain.ComparisonLabel.slightlyExpensive),
        '▲',
      );
      expect(
        LabelColors.symbolForLabel(domain.ComparisonLabel.expensive),
        '▲▲',
      );
      expect(LabelColors.symbolForLabel(null), '');
    });
  });

  group('PriceContextBadges', () {
    testWidgets('shows no badges when all null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PriceContextBadges())),
      );
      await tester.pump();

      expect(find.byType(PriceContextBadges), findsOneWidget);
      expect(find.text('SALE'), findsNothing);
      expect(find.text('会員価格'), findsNothing);
    });

    testWidgets('shows SALE badge when isSaleVisible is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PriceContextBadges(isSaleVisible: true)),
        ),
      );
      await tester.pump();

      expect(find.text('SALE'), findsOneWidget);
    });

    testWidgets('shows multiple badges when multiple flags true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceContextBadges(
              isSaleVisible: true,
              isMemberPriceVisible: true,
              isBulkDiscount: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SALE'), findsOneWidget);
      expect(find.text('会員価格'), findsOneWidget);
      expect(find.text('まとめ割'), findsOneWidget);
      expect(find.text('クーポン'), findsNothing);
    });
  });
}

/// Stub adapters for widget tests
class _StubBarcodeAdapter implements BarcodeRecognizerAdapter {
  @override
  Stream<BarcodeCandidate> get results => const Stream.empty();

  @override
  void pause() {}

  @override
  void resume() {}
}

class _StubPriceOcrAdapter implements PriceOcrAdapter {
  @override
  Stream<List<PriceCandidate>> get results => const Stream.empty();

  @override
  void pause() {}

  @override
  void resume() {}
}
