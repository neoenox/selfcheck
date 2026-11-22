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

PriceCandidate _price(int value, [double confidence = 0.9]) => PriceCandidate(
  priceYen: value,
  confidence: confidence,
  region: _nearRegion,
  rawTexts: ['$value'],
);

const _manual = ManualPriceEntry(
  priceYen: 350,
  isTaxInclusive: true,
  isSaleVisible: true,
);

Future<void> _flush([int milliseconds = 30]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('manual price confidence (#87)', () {
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

    test('manual confidence is recorded below the OCR range', () {
      // OCR estimator range is 0.70 (bare) to 0.90 (currency/tax-inclusive).
      // Spec (#87) requires manual values at LOWERED confidence.
      expect(kManualPriceConfidence, lessThan(0.70));
      expect(kManualPriceConfidence, greaterThan(0.0));
      expect(
        const ManualPriceEntry(priceYen: 100, isTaxInclusive: true).confidence,
        kManualPriceConfidence,
      );
    });

    test(
      'manual save keeps lowered confidence with flag and SQLite roundtrip',
      () async {
        final results = <int>[];
        coordinator.resultStream.listen((r) => results.add(r.currentPrice));

        coordinator.startScan();
        barcodeAdapter.add(_barcode);
        await _flush();
        expect(coordinator.currentState, ScanState.waitingPrice);

        expect(coordinator.submitManualPrice(_manual), isTrue);
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
        expect(observations.single.priceConfidence, lessThan(0.70));
        expect(observations.single.isManualEntry, isTrue);
        expect(observations.single.isSaleVisible, isTrue);
      },
    );

    test('lowered confidence never flips manual-beats-OCR priority', () async {
      final results = <int>[];
      coordinator.resultStream.listen((r) => results.add(r.currentPrice));

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      // OCR candidate is stable-ready, but the explicit manual source flag
      // must win even though its confidence is lower than OCR 0.90.
      for (var i = 0; i < 2; i++) {
        priceAdapter.addFrame([_price(398)]);
        await _flush();
      }
      expect(coordinator.submitManualPrice(_manual), isTrue);
      await _flush(100);

      expect(results, [350]);
      final product = await repository.findProductByJan(_barcode.barcode);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(observations.single.priceYen, 350);
      expect(observations.single.isManualEntry, isTrue);
    });

    test(
      'manual entry is accepted in noProduct and completes on barcode',
      () async {
        final results = <int>[];
        coordinator.resultStream.listen((r) => results.add(r.currentPrice));

        coordinator.startScan();
        for (var i = 0; i < 3; i++) {
          priceAdapter.addFrame([_price(398)]);
          await _flush();
        }
        expect(coordinator.currentState, ScanState.noProduct);

        // The missing entry path: manual must be submittable while waiting
        // for a barcode after a price-only (JAN-unknown) cycle.
        expect(coordinator.submitManualPrice(_manual), isTrue);
        await _flush(600);
        expect(coordinator.currentState, ScanState.scanning);

        barcodeAdapter.add(_barcode);
        await _flush(100);

        expect(coordinator.currentState, ScanState.result);
        expect(results, [350]);

        final product = await repository.findProductByJan(_barcode.barcode);
        final observations = await repository.getValidObservations(
          productId: product!.id,
          since: DateTime.now().subtract(const Duration(minutes: 1)),
          limit: 10,
        );
        expect(observations.single.priceConfidence, lessThan(0.70));
        expect(observations.single.isManualEntry, isTrue);
      },
    );

    test(
      'median/compare/duplicate ignore confidence and keep working',
      () async {
        final product = await repository.createProvisionalProduct(
          '4901234567899',
        );
        await repository.insertObservation(
          productId: product.id,
          priceYen: 350,
          priceConfidence: kManualPriceConfidence,
          isManualEntry: true,
        );
        await repository.insertObservation(
          productId: product.id,
          priceYen: 398,
          priceConfidence: 0.9,
        );

        // Duplicate window keys on product+price+time, not confidence.
        expect(
          await repository.isDuplicate(
            productId: product.id,
            priceYen: 350,
            observedAt: DateTime.now(),
          ),
          isTrue,
        );

        final useCase = CompareUseCase(repository);
        final result = await useCase.compare(
          currentPriceYen: 450,
          productId: product.id,
          currentConfidence: 0.9,
        );
        // Median of {350, 398} is 374 regardless of the lowered manual
        // confidence; historyShort carries 2 observations.
        expect(result.baselineMedianYen, 374);
        expect(result.observationCount, 2);
      },
    );
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
