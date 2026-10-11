import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';

const _region = Rect(left: 0, top: 0, right: 100, bottom: 50);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _region,
);

PriceCandidate _price(int value) => PriceCandidate(
  priceYen: value,
  confidence: 0.9,
  region: _region,
  rawTexts: ['$value'],
);

Future<void> _flush([int milliseconds = 30]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('Scan session lifecycle regressions', () {
    late PriceRepository repository;
    late _TestBarcodeAdapter barcodeAdapter;
    late _TestPriceAdapter priceAdapter;
    late ScanCoordinator coordinator;

    setUp(() async {
      repository = await createTestRepository();
      barcodeAdapter = _TestBarcodeAdapter();
      priceAdapter = _TestPriceAdapter();
      coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: CompareUseCase(repository),
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
      );
    });

    tearDown(() async {
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    test('does not compare a price that has not stabilized', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      priceAdapter.add(_price(398));
      await _flush();

      barcodeAdapter.add(_barcode);
      await _flush();

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(results, isEmpty);

      priceAdapter.add(_price(398));
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(results, isEmpty);

      priceAdapter.add(_price(398));
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      expect(results, [398]);
    });

    test(
      'clears a price-only result before accepting the next barcode',
      () async {
        coordinator.startScan();

        for (var i = 0; i < 3; i++) {
          priceAdapter.add(_price(398));
          await _flush();
        }

        expect(coordinator.currentState, ScanState.noProduct);
        await _flush(550);
        expect(coordinator.currentState, ScanState.scanning);

        barcodeAdapter.add(_barcode);
        await _flush();

        expect(coordinator.currentState, ScanState.waitingPrice);
      },
    );

    test('result dismissal allows a real second scan session', () async {
      final controller = ScanScreenController(coordinator: coordinator)..init();
      addTearDown(controller.dispose);

      controller.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(398));
        await _flush();
      }
      await _flush(100);

      expect(controller.uiState.scanState, ScanState.result);

      controller.dismissResult();
      expect(coordinator.currentState, ScanState.idle);
      expect(controller.uiState.scanState, ScanState.idle);

      controller.startScan();
      // Coordinator state changes synchronously; controller state is delivered
      // through the broadcast state stream on the next event-loop turn.
      expect(coordinator.currentState, ScanState.scanning);
      await _flush();
      expect(controller.uiState.scanState, ScanState.scanning);

      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(399));
        await _flush();
      }
      await _flush(100);

      expect(controller.uiState.scanState, ScanState.result);
      expect(controller.uiState.currentPriceYen, 399);
    });

    test('cancelled session events cannot mutate the next state', () async {
      coordinator.startScan();
      expect(barcodeAdapter.resultsGetterCount, 1);
      expect(priceAdapter.resultsGetterCount, 1);

      coordinator.cancelScan();
      expect(coordinator.currentState, ScanState.idle);

      barcodeAdapter.add(_barcode);
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(398));
      }
      await _flush(100);

      expect(coordinator.currentState, ScanState.idle);

      coordinator.startScan();
      expect(coordinator.currentState, ScanState.scanning);
      expect(barcodeAdapter.resultsGetterCount, 2);
      expect(priceAdapter.resultsGetterCount, 2);
    });
  });
}

class _TestBarcodeAdapter implements BarcodeRecognizerAdapter {
  final StreamController<BarcodeCandidate> _controller =
      StreamController<BarcodeCandidate>.broadcast();
  bool _paused = false;
  int resultsGetterCount = 0;

  @override
  Stream<BarcodeCandidate> get results {
    resultsGetterCount++;
    return _controller.stream.where((event) => !_paused);
  }

  void add(BarcodeCandidate candidate) => _controller.add(candidate);

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> close() => _controller.close();
}

class _TestPriceAdapter implements PriceOcrAdapter {
  final StreamController<List<PriceCandidate>> _controller =
      StreamController<List<PriceCandidate>>.broadcast();
  bool _paused = false;
  int resultsGetterCount = 0;

  @override
  Stream<List<PriceCandidate>> get results {
    resultsGetterCount++;
    return _controller.stream.where((event) => !_paused);
  }

  void add(PriceCandidate candidate) => _controller.add([candidate]);

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> close() => _controller.close();
}
