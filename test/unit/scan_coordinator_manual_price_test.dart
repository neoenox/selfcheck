import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';
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

    test('repeated manual entry of the same price is de-duplicated', () async {
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      Future<List<int>> savedPrices() async {
        final product = await repository.findProductByJan(_barcode.barcode);
        expect(product, isNotNull);
        final observations = await repository.getValidObservations(
          productId: product!.id,
          since: DateTime.now().subtract(const Duration(minutes: 1)),
          limit: 10,
        );
        return [for (final o in observations) o.priceYen];
      }

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);
      await _flush(100);
      expect(results, [350]);
      expect(await savedPrices(), [350]);

      coordinator.resetToIdle();
      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);
      await _flush(100);

      expect(results, [350, 350]);
      expect(await savedPrices(), [350]);
    });
  });

  group('mixed price contexts in comparison', () {
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

    Future<domain.ComparisonResult> scanOcrPrice(int value) async {
      final done = coordinator.resultStream.first;
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(value)]);
        await _flush();
      }
      return done.timeout(const Duration(seconds: 2));
    }

    test('sale and regular observations share one baseline', () async {
      final results = <domain.ComparisonResult>[];
      coordinator.resultStream.listen(results.add);

      // Session 1: manual sale price, no history yet.
      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.submitManualPrice(_manualSale), isTrue);
      await _flush(100);
      expect(results.single.status, domain.ComparisonStatus.firstPrice);

      // Session 2: regular OCR price compares against the sale baseline.
      // Contexts intentionally share one baseline in the current design;
      // this test pins the arithmetic so a future context-aware change is
      // a deliberate spec change, not a silent drift.
      coordinator.resetToIdle();
      coordinator.startScan();
      final second = await scanOcrPrice(398);
      expect(second.status, domain.ComparisonStatus.historyShort);
      expect(second.baselineMedianYen, 350);
      expect(second.diffYen, 48);
      expect(second.label, domain.ComparisonLabel.expensive);

      // Session 3: median of sale + regular.
      coordinator.resetToIdle();
      coordinator.startScan();
      final third = await scanOcrPrice(450);
      expect(third.status, domain.ComparisonStatus.historyShort);
      expect(third.baselineMedianYen, 374);
      expect(third.observationCount, 2);

      // Session 4: full baseline across mixed contexts.
      coordinator.resetToIdle();
      coordinator.startScan();
      final fourth = await scanOcrPrice(500);
      expect(fourth.status, domain.ComparisonStatus.withBaseline);
      expect(fourth.baselineMedianYen, 398);
      expect(fourth.diffYen, 102);
      expect(fourth.label, domain.ComparisonLabel.expensive);

      final product = await repository.findProductByJan(_barcode.barcode);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(observations.map((o) => o.priceYen).toSet(), {350, 398, 450, 500});
      expect(
        observations.where((o) => o.priceYen == 350).single.isManualEntry,
        isTrue,
      );
    });
  });

  group('saved price correction', () {
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

    Future<void> saveOcrPrice(int value) async {
      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(value)]);
        await _flush();
      }
      await _flush(100);
      expect(coordinator.currentState, ScanState.result);
    }

    Future<List<int>> validPrices() async {
      final product = await repository.findProductByJan(_barcode.barcode);
      expect(product, isNotNull);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      return [for (final o in observations) o.priceYen];
    }

    test('corrects the latest observation and refreshes the result', () async {
      await saveOcrPrice(398);
      expect(await validPrices(), [398]);

      final ok = await coordinator.correctLatestObservation(
        jan: _barcode.barcode,
        entry: _manualSale,
      );

      expect(ok, isTrue);
      expect(coordinator.currentState, ScanState.result);
      expect(await validPrices(), [350]);

      final product = await repository.findProductByJan(_barcode.barcode);
      final observations = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(observations.single.isManualEntry, isTrue);
      expect(observations.single.isSaleVisible, isTrue);
    });

    test(
      'same-price correction reinserts despite the duplicate window',
      () async {
        await saveOcrPrice(398);

        final ok = await coordinator.correctLatestObservation(
          jan: _barcode.barcode,
          entry: const ManualPriceEntry(priceYen: 398, isTaxInclusive: true),
        );

        expect(ok, isTrue);
        expect(await validPrices(), [398]);
      },
    );

    test('invalid corrections are rejected without side effects', () async {
      await saveOcrPrice(398);

      expect(
        await coordinator.correctLatestObservation(
          jan: _barcode.barcode,
          entry: const ManualPriceEntry(priceYen: 0, isTaxInclusive: true),
        ),
        isFalse,
      );
      expect(
        await coordinator.correctLatestObservation(
          jan: _barcode.barcode,
          entry: const ManualPriceEntry(priceYen: 350, isTaxInclusive: false),
        ),
        isFalse,
      );
      expect(
        await coordinator.correctLatestObservation(
          jan: '0000000000000',
          entry: _manualSale,
        ),
        isFalse,
      );
      expect(await validPrices(), [398]);
    });

    test('correction is rejected during an active session', () async {
      coordinator.startScan();

      expect(
        await coordinator.correctLatestObservation(
          jan: _barcode.barcode,
          entry: _manualSale,
        ),
        isFalse,
      );
    });

    test('failed correction keeps the previous observation', () async {
      await saveOcrPrice(398);
      expect(await validPrices(), [398]);

      // The wrapper sees the real product and history but fails the
      // atomic replacement itself.
      final failing = _FailingReplaceRepository(repository);
      final failingCoordinator = ScanCoordinator(
        repository: failing,
        compareUseCase: CompareUseCase(failing),
        barcodeAdapter: _ControllableBarcodeAdapter(),
        priceAdapter: _ControllablePriceAdapter(),
      );
      addTearDown(failingCoordinator.dispose);

      final ok = await failingCoordinator.correctLatestObservation(
        jan: _barcode.barcode,
        entry: _manualSale,
      );

      expect(ok, isFalse);
      expect(await validPrices(), [398]);
    });

    test('unknown correction target cannot insert a new price', () async {
      await saveOcrPrice(398);
      final product = await repository.findProductByJan(_barcode.barcode);
      expect(product, isNotNull);

      await expectLater(
        repository.replaceObservation(
          oldId: 'missing-observation',
          productId: product!.id,
          priceYen: 350,
          priceConfidence: 0.6,
        ),
        throwsStateError,
      );
      expect(await validPrices(), [398]);
    });

    test('correction cannot retire a row belonging to another product', () async {
      await saveOcrPrice(398);
      final source = await repository.findProductByJan(_barcode.barcode);
      final original = (await repository.getValidObservations(
        productId: source!.id,
        since: DateTime.fromMillisecondsSinceEpoch(0),
        limit: 10,
      )).single;
      final other = await repository.createProvisionalProduct(
        '4902222222222',
      );

      await expectLater(
        repository.replaceObservation(
          oldId: original.id,
          productId: other.id,
          priceYen: 350,
          priceConfidence: 0.6,
        ),
        throwsStateError,
      );
      expect(await validPrices(), [398]);
      expect(
        await repository.getValidObservations(
          productId: other.id,
          since: DateTime.fromMillisecondsSinceEpoch(0),
          limit: 10,
        ),
        isEmpty,
      );
    });

    test('duplicate corrected price rolls back retirement of original', () async {
      await saveOcrPrice(398);
      final product = await repository.findProductByJan(_barcode.barcode);
      final original = (await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.fromMillisecondsSinceEpoch(0),
        limit: 10,
      )).single;
      await repository.insertObservation(
        productId: product.id,
        priceYen: 350,
        priceConfidence: 0.9,
      );

      // Existing valid price already owns the 350-yen duplicate slot.
      // A correction must fail, not retire 398 and return the 350 row.
      await expectLater(
        repository.replaceObservation(
          oldId: original.id,
          productId: product.id,
          priceYen: 350,
          priceConfidence: 0.6,
        ),
        throwsA(anything),
      );
      final after = await repository.getValidObservations(
        productId: product.id,
        since: DateTime.fromMillisecondsSinceEpoch(0),
        limit: 10,
      );
      expect(after.map((o) => o.priceYen).toSet(), {398, 350});
      expect(after.singleWhere((o) => o.id == original.id).isValid, isTrue);
    });

    test('correction never touches another product', () async {
      const otherJan = '4901111111111';
      const otherBarcode = BarcodeCandidate(
        barcode: otherJan,
        format: BarcodeFormat.ean13,
        confidence: 0.95,
        region: _barcodeRegion,
      );

      await saveOcrPrice(398);

      coordinator.resetToIdle();
      coordinator.startScan();
      barcodeAdapter.add(otherBarcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.addFrame([_price(450)]);
        await _flush();
      }
      await _flush(100);
      expect(coordinator.currentState, ScanState.result);

      final ok = await coordinator.correctLatestObservation(
        jan: _barcode.barcode,
        entry: _manualSale,
      );
      expect(ok, isTrue);

      Future<List<int>> pricesFor(String jan) async {
        final product = await repository.findProductByJan(jan);
        final observations = await repository.getValidObservations(
          productId: product!.id,
          since: DateTime.now().subtract(const Duration(minutes: 1)),
          limit: 10,
        );
        return [for (final o in observations) o.priceYen];
      }

      expect(await pricesFor(_barcode.barcode), [350]);
      expect(await pricesFor(otherJan), [450]);
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

/// Repository failing only the atomic replacement, to prove a failed
/// correction cannot lose the previous observation.
class _FailingReplaceRepository implements PriceRepository {
  final PriceRepository _inner;
  _FailingReplaceRepository(this._inner);

  @override
  Future<ProductIdentity?> findProductByJan(String jan) =>
      _inner.findProductByJan(jan);

  @override
  Future<ProductIdentity> createProvisionalProduct(String jan) =>
      _inner.createProvisionalProduct(jan);

  @override
  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  }) => _inner.getValidObservations(
    productId: productId,
    since: since,
    limit: limit,
  );

  @override
  Future<PriceObservation> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) => _inner.insertObservation(
    productId: productId,
    priceYen: priceYen,
    priceConfidence: priceConfidence,
    isSaleVisible: isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount,
    isManualEntry: isManualEntry,
  );

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) => _inner.isDuplicate(
    productId: productId,
    priceYen: priceYen,
    observedAt: observedAt,
  );

  @override
  Future<PriceObservation> insertObservationWithDate({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) => _inner.insertObservationWithDate(
    productId: productId,
    priceYen: priceYen,
    priceConfidence: priceConfidence,
    observedAt: observedAt,
    isSaleVisible: isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount,
    isManualEntry: isManualEntry,
  );

  @override
  Future<void> invalidateObservation(String id) =>
      _inner.invalidateObservation(id);

  @override
  Future<PriceObservation> replaceObservation({
    required String oldId,
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) async {
    throw Exception('simulated replace failure');
  }

  @override
  void dispose() => _inner.dispose();
}
