import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

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
  group('AC production-path validation', () {
    late PriceRepository repository;
    late _BarcodeAdapter barcodeAdapter;
    late _PriceAdapter priceAdapter;
    late ScanCoordinator coordinator;

    setUp(() async {
      repository = await createTestRepository();
      barcodeAdapter = _BarcodeAdapter();
      priceAdapter = _PriceAdapter();
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

    test(
      'AC-02 barcode-first waits for a stable price before result',
      () async {
        coordinator.startScan();

        barcodeAdapter.add(_barcode);
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        priceAdapter.add(_price(398));
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        priceAdapter.add(_price(398));
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        priceAdapter.add(_price(398));
        await _flush(100);
        expect(coordinator.currentState, ScanState.result);

        final product = await repository.findProductByJan(_barcode.barcode);
        expect(product, isNotNull);
        final observations = await repository.getValidObservations(
          productId: product!.id,
          since: DateTime.now().subtract(const Duration(minutes: 1)),
          limit: 10,
        );
        expect(observations.map((observation) => observation.priceYen), [398]);
      },
    );

    test('AC-12 rejects a transient wrong OCR value before barcode', () async {
      coordinator.startScan();

      priceAdapter.add(_price(999));
      await _flush();
      barcodeAdapter.add(_barcode);
      await _flush();

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(await repository.findProductByJan(_barcode.barcode), isNull);

      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(398));
        await _flush();
      }
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      final product = await repository.findProductByJan(_barcode.barcode);
      expect(product, isNotNull);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(observations, hasLength(1));
      expect(observations.single.priceYen, 398);
    });

    test('AC-08 price-only guidance cannot leak price into next JAN', () async {
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
      expect(await repository.findProductByJan(_barcode.barcode), isNull);
    });

    test(
      'does not save a stable price from a different product region',
      () async {
        coordinator.startScan();

        barcodeAdapter.add(_barcode);
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        const unrelatedRegion = Rect(
          left: 600,
          top: 600,
          right: 700,
          bottom: 650,
        );
        for (var i = 0; i < 3; i++) {
          priceAdapter.add(
            const PriceCandidate(
              priceYen: 999,
              confidence: 0.9,
              region: unrelatedRegion,
              rawTexts: ['¥999'],
            ),
          );
          await _flush();
        }

        await _flush(100);
        expect(coordinator.currentState, isNot(ScanState.result));
        expect(await repository.findProductByJan(_barcode.barcode), isNull);
      },
    );
  });
}

class _BarcodeAdapter implements BarcodeRecognizerAdapter {
  final StreamController<BarcodeCandidate> _controller =
      StreamController<BarcodeCandidate>.broadcast();
  bool _paused = false;

  @override
  Stream<BarcodeCandidate> get results =>
      _controller.stream.where((event) => !_paused);

  void add(BarcodeCandidate candidate) => _controller.add(candidate);

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> close() => _controller.close();
}

class _PriceAdapter implements PriceOcrAdapter {
  final StreamController<List<PriceCandidate>> _controller =
      StreamController<List<PriceCandidate>>.broadcast();
  bool _paused = false;

  @override
  Stream<List<PriceCandidate>> get results =>
      _controller.stream.where((event) => !_paused);

  void add(PriceCandidate candidate) => _controller.add([candidate]);

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> close() => _controller.close();
}
