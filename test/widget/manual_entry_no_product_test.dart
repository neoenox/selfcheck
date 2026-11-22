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

const _nearPriceRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('manual entry offered in noProduct (#87 follow-up)', () {
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

    testWidgets('noProduct still offers the manual entry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ScanScreen(controller: controller)),
      );
      await tester.pump();
      controller.startScan();
      await _settle(tester);

      // Price-only OCR stabilizes without a barcode: JAN-unknown path.
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: _nearPriceRegion,
            rawTexts: ['398'],
          ),
        ]);
        await _settle(tester);
      }

      expect(find.text('バーコードが見つかりません'), findsOneWidget);
      // Regression: the button was hidden because it only rendered while
      // isScanning (scanning/waitingPrice). It must stay available here.
      expect(find.text('価格を手入力'), findsOneWidget);

      await tester.tap(find.text('価格を手入力'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

class _ControllableBarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

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

  void addFrame(List<PriceCandidate> frame) => _controller.add(frame);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
