import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

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
  final _controller = StreamController<List<PriceCandidate>>.broadcast();

  @override
  Stream<List<PriceCandidate>> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add([candidate]);
  void addFrame(List<PriceCandidate> frame) => _controller.add(frame);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
