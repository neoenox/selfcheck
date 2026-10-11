import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);
const _nearPriceRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _barcodeRegion,
);

PriceCandidate _price(int value) => PriceCandidate(
  priceYen: value,
  confidence: 0.9,
  region: _nearPriceRegion,
  rawTexts: ['$value'],
);

Future<void> _flush([int milliseconds = 100]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('ScanCoordinator transient warnings', () {
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

    test('transient adapter error warns without stopping the scan', () async {
      final warnings = <String?>[];
      final errors = <String?>[];
      coordinator.warningStream.listen(warnings.add);
      coordinator.errorStream.listen(errors.add);

      coordinator.startScan();
      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();

      expect(warnings, isNotEmpty);
      expect(warnings.last, contains('価格OCRストリームエラー'));
      expect(coordinator.currentState, ScanState.scanning);
      expect(coordinator.lastWarning, isNotNull);
      // errorStream keeps receiving the message for existing listeners.
      expect(errors, isNotEmpty);
    });

    test('transient error during waitingPrice keeps waiting', () async {
      final warnings = <String?>[];
      coordinator.warningStream.listen(warnings.add);

      coordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);

      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(warnings, isNotEmpty);
      expect(coordinator.lastWarning, isNotNull);
    });

    test('successful barcode after warning clears the warning', () async {
      final warnings = <String?>[];
      coordinator.warningStream.listen(warnings.add);

      coordinator.startScan();
      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();
      expect(coordinator.lastWarning, isNotNull);

      barcodeAdapter.add(_barcode);
      await _flush();

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(coordinator.lastWarning, isNull);
      expect(warnings.last, isNull);
    });

    test('successful price reading after warning clears the warning', () async {
      final warnings = <String?>[];
      coordinator.warningStream.listen(warnings.add);

      coordinator.startScan();
      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();
      expect(coordinator.lastWarning, isNotNull);

      priceAdapter.add(_price(398));
      await _flush();

      expect(coordinator.lastWarning, isNull);
      expect(warnings.last, isNull);
    });

    test('fatal permission error moves to error immediately', () async {
      final warnings = <String?>[];
      final errors = <String?>[];
      final states = <ScanState>[];
      coordinator.warningStream.listen(warnings.add);
      coordinator.errorStream.listen(errors.add);
      coordinator.stateStream.listen(states.add);

      coordinator.startScan();
      priceAdapter.addError(Exception('Permission denied: camera access'));
      await _flush();

      expect(coordinator.currentState, ScanState.error);
      expect(states, contains(ScanState.error));
      expect(errors, isNotEmpty);
      expect(errors.last, contains('カメラの権限'));
      // A fatal error is not a transient warning.
      expect(warnings, isEmpty);
      expect(coordinator.lastWarning, isNull);
    });

    test('CameraAccessDenied is treated as a fatal permission error', () async {
      final errors = <String?>[];
      coordinator.errorStream.listen(errors.add);

      coordinator.startScan();
      barcodeAdapter.addError(
        Exception('CameraAccessDenied: access denied without prompt'),
      );
      await _flush();

      expect(coordinator.currentState, ScanState.error);
      expect(errors.last, contains('カメラの権限'));
    });

    test('next scan start clears a previous warning', () async {
      coordinator.startScan();
      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();
      expect(coordinator.lastWarning, isNotNull);

      coordinator.cancelScan();
      expect(coordinator.lastWarning, isNull);

      coordinator.startScan();
      expect(coordinator.lastWarning, isNull);
      expect(coordinator.currentState, ScanState.scanning);
    });

    test('fatal error during compare cannot flip back to result', () async {
      final delayed = _DelayedRepository(repository);
      final slowCoordinator = ScanCoordinator(
        repository: delayed,
        compareUseCase: CompareUseCase(delayed),
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
      );
      addTearDown(slowCoordinator.dispose);

      final states = <ScanState>[];
      final results = <int>[];
      slowCoordinator.stateStream.listen(states.add);
      slowCoordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      slowCoordinator.startScan();
      barcodeAdapter.add(_barcode);
      await _flush();
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(398));
        await _flush(30);
      }
      // The compare is now in flight (slow product lookup).
      expect(slowCoordinator.currentState, ScanState.comparing);

      priceAdapter.addError(Exception('Permission denied: camera access'));
      await _flush(500);

      expect(slowCoordinator.currentState, ScanState.error);
      expect(states, contains(ScanState.error));
      expect(states, isNot(contains(ScanState.result)));
      expect(results, isEmpty);
    });
  });
}

class _ControllableBarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) => _controller.add(candidate);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

class _ControllablePriceAdapter implements PriceOcrAdapter {
  final _controller = StreamController<PriceCandidate>.broadcast();

  @override
  Stream<PriceCandidate> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add(candidate);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

/// Repository delaying product lookup so a compare stays in flight.
class _DelayedRepository implements PriceRepository {
  final PriceRepository _inner;
  _DelayedRepository(this._inner);

  @override
  Future<ProductIdentity?> findProductByJan(String jan) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _inner.findProductByJan(jan);
  }

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
  }) => _inner.insertObservation(
    productId: productId,
    priceYen: priceYen,
    priceConfidence: priceConfidence,
    isSaleVisible: isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount,
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
  }) => _inner.insertObservationWithDate(
    productId: productId,
    priceYen: priceYen,
    priceConfidence: priceConfidence,
    observedAt: observedAt,
    isSaleVisible: isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount,
  );

  @override
  void dispose() => _inner.dispose();
}
