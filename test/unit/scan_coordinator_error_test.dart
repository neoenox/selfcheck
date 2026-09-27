import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';

void main() {
  group('ScanCoordinator error handling', () {
    late ScanCoordinator coordinator;
    late PriceRepository repository;

    setUp(() async {
      repository = await createTestRepository();
    });

    tearDown(() {
      coordinator.dispose();
      repository.dispose();
    });

    test(
      'DB failure during compare emits error state, not stuck in comparing',
      () async {
        final brokenRepo = _BrokenRepository(repository);
        final compareUseCase = CompareUseCase(brokenRepo);

        final barcodeCtrl = StreamController<BarcodeCandidate>();
        final priceCtrl = StreamController<PriceCandidate>();

        coordinator = ScanCoordinator(
          repository: brokenRepo,
          compareUseCase: compareUseCase,
          barcodeAdapter: _StreamBarcodeAdapter(barcodeCtrl.stream),
          priceAdapter: _StreamPriceAdapter(priceCtrl.stream),
        );

        final states = <ScanState>[];
        final errors = <String?>[];
        coordinator.stateStream.listen(states.add);
        coordinator.errorStream.listen(errors.add);

        coordinator.startScan();

        // Emit barcode first → enters waitingPrice
        barcodeCtrl.add(
          const BarcodeCandidate(
            barcode: '4901234567890',
            format: BarcodeFormat.ean13,
            confidence: 0.95,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
        expect(states.last, ScanState.waitingPrice);

        // Now emit 3 identical prices → stabilizer triggers → _compare called
        for (var i = 0; i < 3; i++) {
          priceCtrl.add(
            const PriceCandidate(
              priceYen: 398,
              confidence: 0.9,
              region: Rect(left: 0, top: 50, right: 100, bottom: 100),
              rawTexts: ['398'],
            ),
          );
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await Future.delayed(const Duration(milliseconds: 200));

        // Should end up in error state
        expect(states, contains(ScanState.error));
        expect(states, isNot(contains(ScanState.result)));
        expect(errors, isNotEmpty);
        expect(errors.last, 'ストレージ容量が不足しています。');
        expect(errors.last, isNot(contains('Exception')));
        expect(errors.last, isNot(contains('disk full')));

        await barcodeCtrl.close();
        await priceCtrl.close();
      },
    );

    test('startScan works from error state (retry)', () async {
      // First attempt: broken repo
      final barcodeCtrl1 = StreamController<BarcodeCandidate>();
      final priceCtrl1 = StreamController<PriceCandidate>();

      final brokenRepo = _BrokenRepository(repository);
      coordinator = ScanCoordinator(
        repository: brokenRepo,
        compareUseCase: CompareUseCase(brokenRepo),
        barcodeAdapter: _StreamBarcodeAdapter(barcodeCtrl1.stream),
        priceAdapter: _StreamPriceAdapter(priceCtrl1.stream),
      );

      final states1 = <ScanState>[];
      coordinator.stateStream.listen(states1.add);

      coordinator.startScan();
      barcodeCtrl1.add(
        const BarcodeCandidate(
          barcode: '4901234567890',
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 20));
      for (var i = 0; i < 3; i++) {
        priceCtrl1.add(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 50, right: 100, bottom: 100),
            rawTexts: ['398'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states1.last, ScanState.error);
      await barcodeCtrl1.close();
      await priceCtrl1.close();
      coordinator.dispose();

      // Second attempt: working repo → should succeed
      final barcodeCtrl2 = StreamController<BarcodeCandidate>();
      final priceCtrl2 = StreamController<PriceCandidate>();

      final coordinator2 = ScanCoordinator(
        repository: repository,
        compareUseCase: CompareUseCase(repository),
        barcodeAdapter: _StreamBarcodeAdapter(barcodeCtrl2.stream),
        priceAdapter: _StreamPriceAdapter(priceCtrl2.stream),
      );

      final states2 = <ScanState>[];
      coordinator2.stateStream.listen(states2.add);

      coordinator2.startScan();
      barcodeCtrl2.add(
        const BarcodeCandidate(
          barcode: '4901234567890',
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 20));
      for (var i = 0; i < 3; i++) {
        priceCtrl2.add(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 50, right: 100, bottom: 100),
            rawTexts: ['398'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states2, contains(ScanState.result));
      await barcodeCtrl2.close();
      await priceCtrl2.close();
      coordinator2.dispose();
    });

    test('adapter stream error does not crash the state machine', () async {
      final compareUseCase = CompareUseCase(repository);
      final errorController = StreamController<PriceCandidate>();

      coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(const Stream.empty()),
        priceAdapter: _StreamPriceAdapter(errorController.stream),
      );

      final errors = <String?>[];
      coordinator.errorStream.listen(errors.add);

      coordinator.startScan();

      // Emit an error through the price adapter stream
      errorController.addError(Exception('Camera disconnected'));
      await Future.delayed(const Duration(milliseconds: 100));

      // Error should be captured, state machine should not crash
      expect(errors, isNotEmpty);

      // State should still be scanning (adapter errors are transient)
      expect(coordinator.currentState, ScanState.scanning);

      await errorController.close();
    });
    test(
      'lastError is set after failure and cleared on next scan start',
      () async {
        final brokenRepo = _BrokenRepository(repository);
        final compareUseCase = CompareUseCase(brokenRepo);

        final barcodeCtrl = StreamController<BarcodeCandidate>.broadcast();
        final priceCtrl = StreamController<PriceCandidate>.broadcast();

        coordinator = ScanCoordinator(
          repository: brokenRepo,
          compareUseCase: compareUseCase,
          barcodeAdapter: _StreamBarcodeAdapter(barcodeCtrl.stream),
          priceAdapter: _StreamPriceAdapter(priceCtrl.stream),
        );

        coordinator.startScan();
        barcodeCtrl.add(
          const BarcodeCandidate(
            barcode: '4901234567890',
            format: BarcodeFormat.ean13,
            confidence: 0.95,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
        for (var i = 0; i < 3; i++) {
          priceCtrl.add(
            const PriceCandidate(
              priceYen: 398,
              confidence: 0.9,
              region: Rect(left: 0, top: 50, right: 100, bottom: 100),
              rawTexts: ['398'],
            ),
          );
          await Future.delayed(const Duration(milliseconds: 20));
        }
        await Future.delayed(const Duration(milliseconds: 200));

        // After failure, lastError should be set
        expect(coordinator.lastError, isNotNull);
        expect(coordinator.lastError, isNot(contains('Exception')));
        expect(coordinator.currentState, ScanState.error);

        // Starting a new scan clears lastError
        coordinator.startScan();
        expect(coordinator.lastError, isNull);

        await barcodeCtrl.close();
        await priceCtrl.close();
      },
    );

    test('error message is user-friendly, not raw exception text', () async {
      final brokenRepo = _BrokenRepository(repository);
      final compareUseCase = CompareUseCase(brokenRepo);

      final barcodeCtrl = StreamController<BarcodeCandidate>();
      final priceCtrl = StreamController<PriceCandidate>();

      coordinator = ScanCoordinator(
        repository: brokenRepo,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(barcodeCtrl.stream),
        priceAdapter: _StreamPriceAdapter(priceCtrl.stream),
      );

      final errors = <String?>[];
      coordinator.errorStream.listen(errors.add);

      coordinator.startScan();
      barcodeCtrl.add(
        const BarcodeCandidate(
          barcode: '4901234567890',
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 20));
      for (var i = 0; i < 3; i++) {
        priceCtrl.add(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 50, right: 100, bottom: 100),
            rawTexts: ['398'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // Error message should be user-friendly Japanese
      expect(errors, isNotEmpty);
      expect(errors.last, isNotNull);
      expect(errors.last, isNot(contains('Exception')));
      expect(errors.last, isNot(contains('disk full')));
      expect(errors.last, isNot(contains('Stack')));

      await barcodeCtrl.close();
      await priceCtrl.close();
    });
  });
}

/// PriceRepository that throws on insertObservation (simulates DB failure)
class _BrokenRepository implements PriceRepository {
  final PriceRepository _inner;
  _BrokenRepository(this._inner);

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async => false;

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
  }) async {
    throw Exception(
      'SqliteException(13): database or disk is full, SQLITE_FULL',
    );
  }

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
  }) async {
    throw Exception(
      'SqliteException(13): database or disk is full, SQLITE_FULL',
    );
  }

  @override
  void dispose() => _inner.dispose();
}

/// Stream-based adapter (for manual control in tests)
class _StreamBarcodeAdapter implements BarcodeRecognizerAdapter {
  final Stream<BarcodeCandidate> _stream;
  _StreamBarcodeAdapter(this._stream);

  @override
  Stream<BarcodeCandidate> get results => _stream;

  @override
  void pause() {}

  @override
  void resume() {}
}

class _StreamPriceAdapter implements PriceOcrAdapter {
  final Stream<PriceCandidate> _stream;
  _StreamPriceAdapter(this._stream);

  @override
  Stream<PriceCandidate> get results => _stream;

  @override
  void pause() {}

  @override
  void resume() {}
}
