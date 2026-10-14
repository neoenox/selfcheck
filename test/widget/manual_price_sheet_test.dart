import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/manual_price_sheet.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);
const _nearPriceRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _barcodeRegion,
);

/// Advances fake-async time (fires timers/stream events) and rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Manual price sheet', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;
    late ScanScreenController controller;

    setUp(() async {
      repository = await createTestRepository();
      barcodeAdapter = _ControllableBarcodeAdapter();
      priceAdapter = _ControllablePriceAdapter();
      coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: CompareUseCase(repository),
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
      );
      controller = ScanScreenController(coordinator: coordinator);
    });

    tearDown(() async {
      controller.dispose();
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    Widget buildTestApp() {
      return MaterialApp(home: ScanScreen(controller: controller));
    }

    Future<void> openSheet(WidgetTester tester) async {
      // Phone-like surface so the whole sheet fits without scrolling.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      controller.startScan();
      await _settle(tester);
      await tester.tap(find.text('価格を手入力'));
      // Let the bottom-sheet entrance animation finish so taps land.
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('saves a manually entered sale price', (tester) async {
      await openSheet(tester);
      barcodeAdapter.add(_barcode);
      await _settle(tester);

      expect(find.textContaining('保存先JAN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '350');
      await _settle(tester);
      await tester.tap(find.text('特売'));
      await _settle(tester);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await _settle(tester);
      await tester.tap(find.text('保存する'));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¥350'), findsOneWidget);
      expect(find.text('SALE'), findsOneWidget);
      await tester.tap(find.text('訂正'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('価格を訂正'), findsOneWidget);
      expect(find.textContaining('保存先JAN：${_barcode.barcode}'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '特売'))
            .selected,
        isTrue,
      );
    });

    testWidgets('save stays disabled for invalid input', (tester) async {
      await openSheet(tester);

      // Empty input: save button exists but is disabled.
      final saveButton = find.widgetWithText(FilledButton, '保存する');
      expect(saveButton, findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '350');
      await _settle(tester);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('tax-exclusive blocks saving with guidance', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '350');
      await _settle(tester);
      await tester.tap(find.text('税抜'));
      await _settle(tester);

      expect(find.text('税抜価格は保存できません。税込価格を入力してください。'), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, '保存する');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('barcode guidance appears when saving before JAN', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.textContaining('バーコード未読取'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '350');
      await _settle(tester);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await _settle(tester);
      await tester.tap(find.text('保存する'));
      await _settle(tester);

      expect(find.text('バーコードをスキャンすると自動で保存されます'), findsOneWidget);

      // Scanning continues; a later barcode completes the manual save.
      barcodeAdapter.add(_barcode);
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¥350'), findsOneWidget);
    });

    testWidgets('saved price can be corrected from the result', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      controller.startScan();
      await _settle(tester);

      barcodeAdapter.add(_barcode);
      await _settle(tester);
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: _nearPriceRegion,
            rawTexts: ['398'],
          ),
        );
        await _settle(tester);
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¥398'), findsOneWidget);

      await tester.tap(find.text('訂正'));
      await tester.pump(const Duration(milliseconds: 500));

      // The sheet opens prefilled with the saved price.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '398',
      );
      await tester.enterText(find.byType(TextField), '350');
      await _settle(tester);
      await tester.tap(find.text('特売'));
      await _settle(tester);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await _settle(tester);
      await tester.tap(find.text('保存する'));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('¥350'), findsOneWidget);
    });

    testWidgets('async correction disables a second save', (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showManualPriceSheet(
                  context,
                  controller,
                  initialPriceYen: 398,
                  onSaveEntry: (_) {
                    calls++;
                    return pending.future;
                  },
                ),
                child: const Text('訂正を開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('訂正を開く'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, '保存する');
      await tester.tap(saveButton);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      await tester.tap(saveButton);
      await tester.pump();
      expect(calls, 1);

      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('訂正を開く'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismissed correction ignores late failed callback', (
      tester,
    ) async {
      final pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showManualPriceSheet(
                  context,
                  controller,
                  initialPriceYen: 398,
                  onSaveEntry: (_) => pending.future,
                ),
                child: const Text('訂正を開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('訂正を開く'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存する'));
      await tester.pump();

      // Sheet may be dismissed by the route while the write is pending.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      pending.complete(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('correctLatestPrice without JAN returns false', () async {
      expect(
        await controller.correctLatestPrice(
          priceYen: 350,
          isTaxInclusive: true,
        ),
        isFalse,
      );
    });
  });
}

class _ControllableBarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) => _controller.add(candidate);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

class _ControllablePriceAdapter implements PriceOcrAdapter {
  final _controller = StreamController<List<PriceCandidate>>.broadcast();

  @override
  Stream<List<PriceCandidate>> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add([candidate]);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
