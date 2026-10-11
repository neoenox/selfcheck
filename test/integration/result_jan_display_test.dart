import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';

void main() {
  test('completed scan exposes JAN to UI and reset clears it', () async {
    final repository = await createTestRepository();
    final barcodeAdapter = _BarcodeAdapter();
    final priceAdapter = _PriceAdapter();
    final coordinator = ScanCoordinator(
      repository: repository,
      compareUseCase: CompareUseCase(repository),
      barcodeAdapter: barcodeAdapter,
      priceAdapter: priceAdapter,
    );
    final controller = ScanScreenController(coordinator: coordinator)..init();

    addTearDown(() async {
      controller.dispose();
      coordinator.dispose();
      await barcodeAdapter.dispose();
      await priceAdapter.dispose();
      repository.dispose();
    });

    const jan = '4901234567890';
    const price = 398;

    controller.startScan();
    final waitingPrice = coordinator.stateStream.firstWhere(
      (state) => state == ScanState.waitingPrice,
    );
    barcodeAdapter.add(
      const BarcodeCandidate(
        barcode: jan,
        format: BarcodeFormat.ean13,
        confidence: 0.95,
        region: Rect(left: 0, top: 0, right: 100, bottom: 50),
      ),
    );
    await waitingPrice.timeout(const Duration(seconds: 2));

    final resultState = coordinator.stateStream.firstWhere(
      (state) => state == ScanState.result,
    );
    for (var i = 0; i < 3; i++) {
      priceAdapter.add(
        const PriceCandidate(
          priceYen: price,
          confidence: 0.9,
          region: Rect(left: 0, top: 50, right: 100, bottom: 100),
          rawTexts: ['¥398'],
        ),
      );
    }

    await resultState.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);

    expect(controller.uiState.scanState, ScanState.result);
    expect(controller.uiState.currentPriceYen, price);
    expect(controller.uiState.janCode, jan);
    expect(coordinator.resultJanCode, jan);

    controller.dismissResult();

    expect(controller.uiState.scanState, ScanState.idle);
    expect(controller.uiState.janCode, isNull);
    expect(coordinator.resultJanCode, isNull);
  });
}

class _BarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) => _controller.add(candidate);

  @override
  void pause() {}

  @override
  void resume() {}

  Future<void> dispose() => _controller.close();
}

class _PriceAdapter implements PriceOcrAdapter {
  final _controller = StreamController<List<PriceCandidate>>.broadcast();

  @override
  Stream<List<PriceCandidate>> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add([candidate]);

  @override
  void pause() {}

  @override
  void resume() {}

  Future<void> dispose() => _controller.close();
}
