import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);
const _nearRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);
const _farRegion = Rect(left: 600, top: 600, right: 700, bottom: 650);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _barcodeRegion,
);

/// One frame holding a distant higher-ranked price and the nearby price,
/// as parsePriceCandidates ranks them (tax-inclusive first).
List<PriceCandidate> _mixedFrame() => const [
  PriceCandidate(
    priceYen: 298,
    confidence: 0.9,
    region: _farRegion,
    rawTexts: ['税込298円'],
  ),
  PriceCandidate(
    priceYen: 398,
    confidence: 0.9,
    region: _nearRegion,
    rawTexts: ['398'],
  ),
];

List<PriceCandidate> _farOnlyFrame() => const [
  PriceCandidate(
    priceYen: 298,
    confidence: 0.9,
    region: _farRegion,
    rawTexts: ['税込298円'],
  ),
];

Future<void> _flush([int milliseconds = 30]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('ScanCoordinator nearby price selection', () {
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

    test('selects the nearby price over a higher-ranked distant one', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);

      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame(_mixedFrame());
        await _flush();
      }
      await _flush(100);

      expect(coordinator.currentState, ScanState.result);
      expect(results, [398]);

      final product = await repository.findProductByJan(_barcode.barcode);
      expect(product, isNotNull);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(observations.map((o) => o.priceYen), [398]);
    });

    test('keeps waiting when no stable candidate is associated', () async {
      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);

      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame(_farOnlyFrame());
        await _flush();
      }
      await _flush(100);

      expect(coordinator.currentState, isNot(ScanState.result));
      expect(await repository.findProductByJan(_barcode.barcode), isNull);
    });

    test(
      'multi-candidate frames without a barcode lead to noProduct',
      () async {
        coordinator.startScan();

        for (var i = 0; i < 3; i++) {
          priceAdapter.addFrame(_mixedFrame());
          await _flush();
        }

        expect(coordinator.currentState, ScanState.noProduct);
      },
    );

    test('empty frames never stabilize or save', () async {
      const jan = '4901234567890';
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);

      // Ambiguous OCR frames yield no candidates upstream; even if empty
      // frames reach the coordinator they must not stabilize or save.
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame(const []);
        await _flush();
      }

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(results, isEmpty);
      expect(await repository.findProductByJan(jan), isNull);
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
