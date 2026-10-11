import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);
const _nearRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _barcodeRegion,
);

PriceCandidate _price(int value) => PriceCandidate(
  priceYen: value,
  confidence: 0.9,
  region: _nearRegion,
  rawTexts: ['$value'],
);

const _manualSale = ManualPriceEntry(
  priceYen: 350,
  isTaxInclusive: true,
  isSaleVisible: true,
);

Future<void> _flush([int milliseconds = 30]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('ScanCoordinator manual price entry', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;

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
    });

    tearDown(() async {
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    test(
      'manual price in waitingPrice compares and saves with flags',
      () async {
        final results = <int>[];
        coordinator.resultStream.listen(
          (result) => results.add(result.currentPrice),
        );

        coordinator.startScan();
        barcodeAdapter.add(_barcode);
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        expect(coordinator.submitManualPrice(_manualSale), isTrue);
        await _flush(100);

        expect(coordinator.currentState, ScanState.result);
        expect(results, [350]);

        final product = await repository.findProductByJan(_barcode.barcode);
        expect(product, isNotNull);
        final observations = await repository.getValidObservations(
          productId: product!.id,
          since: DateTime.now().subtract(const Duration(minutes: 1)),
          limit: 10,
        );
        expect(observations, hasLength(1));
        expect(observations.single.priceYen, 350);
        expect(observations.single.priceConfidence, kManualPriceConfidence);
        expect(observations.single.isSaleVisible, isTrue);
        expect(observations.single.isManualEntry, isTrue);
      },
    );

    test('manual price before barcode is used when barcode arrives', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);

      barcodeAdapter.add(_barcode);
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      expect(results, [350]);
    });

    test('manual price overrides a stable OCR price', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(398)]);
        await _flush();
      }
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      expect(results, [398]);

      // A second session: manual correction wins over the same OCR price.
      coordinator.resetToIdle();
      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      // The duplicate window would skip re-inserting 398; use sale-tagged
      // manual context so the observation path is exercised distinctly.
      expect(coordinator.submitManualPrice(_manualSale), isTrue);
      await _flush(100);

      expect(results, [398, 350]);
    });

    test('manual price survives the noProduct reset until barcode', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);

      // Stable OCR without a barcode cycles through noProduct and back.
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(398)]);
        await _flush();
      }
      expect(coordinator.currentState, ScanState.noProduct);
      await _flush(600);
      expect(coordinator.currentState, ScanState.scanning);

      barcodeAdapter.add(_barcode);
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      expect(results, [350]);
    });

    test('invalid manual entries are rejected without side effects', () async {
      coordinator.startScan();

      expect(
        coordinator.submitManualPrice(
          const ManualPriceEntry(priceYen: 0, isTaxInclusive: true),
        ),
        isFalse,
      );
      expect(
        coordinator.submitManualPrice(
          const ManualPriceEntry(priceYen: 100000, isTaxInclusive: true),
        ),
        isFalse,
      );
      expect(
        coordinator.submitManualPrice(
          const ManualPriceEntry(priceYen: 350, isTaxInclusive: false),
        ),
        isFalse,
      );
      expect(coordinator.currentState, ScanState.scanning);
      expect(coordinator.pendingJanCode, isNull);
    });

    test('manual entry is rejected outside a scan session', () async {
      expect(coordinator.submitManualPrice(_manualSale), isFalse);
    });

    test('cancel clears a cached manual entry', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);
      coordinator.cancelScan();

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(398)]);
        await _flush();
      }
      await _flush(100);

      // The cancelled manual entry must not leak into the new session.
      expect(results, [398]);
    });

    test('pendingJanCode exposes the barcode awaiting a price', () async {
      expect(coordinator.pendingJanCode, isNull);

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();

      expect(coordinator.pendingJanCode, _barcode.barcode);
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

  void addFrame(List<PriceCandidate> frame) => _controller.add(frame);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
