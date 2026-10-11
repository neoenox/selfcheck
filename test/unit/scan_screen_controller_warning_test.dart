import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';

const _region = Rect(left: 0, top: 0, right: 100, bottom: 50);

Future<void> _flush([int milliseconds = 100]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('ScanScreenUiState', () {
    test('copyWith can explicitly clear error and warning messages', () {
      const state = ScanScreenUiState(
        scanState: ScanState.scanning,
        errorMessage: 'old error',
        warningMessage: 'old warning',
      );

      final cleared = state.copyWith(
        scanState: ScanState.waitingPrice,
        errorMessage: null,
        warningMessage: null,
      );

      expect(cleared.scanState, ScanState.waitingPrice);
      expect(cleared.errorMessage, isNull);
      expect(cleared.warningMessage, isNull);
    });

    test('copyWith without message arguments preserves messages', () {
      const state = ScanScreenUiState(
        errorMessage: 'old error',
        warningMessage: 'old warning',
      );

      final kept = state.copyWith(scanState: ScanState.scanning);

      expect(kept.errorMessage, 'old error');
      expect(kept.warningMessage, 'old warning');
    });

    test('hasTransientWarning only while scanning with a warning', () {
      const scanning = ScanScreenUiState(
        scanState: ScanState.scanning,
        warningMessage: 'w',
      );
      const waiting = ScanScreenUiState(
        scanState: ScanState.waitingPrice,
        warningMessage: 'w',
      );
      const error = ScanScreenUiState(
        scanState: ScanState.error,
        warningMessage: 'w',
      );
      const idle = ScanScreenUiState(warningMessage: 'w');

      expect(scanning.hasTransientWarning, isTrue);
      expect(waiting.hasTransientWarning, isTrue);
      expect(error.hasTransientWarning, isFalse);
      expect(idle.hasTransientWarning, isFalse);
      expect(
        const ScanScreenUiState(
          scanState: ScanState.scanning,
        ).hasTransientWarning,
        isFalse,
      );
    });
  });

  group('ScanScreenController warnings', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;
    late ScanScreenController controller;

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
      controller = ScanScreenController(coordinator: coordinator)..init();
    });

    tearDown(() async {
      controller.dispose();
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    test('transient error surfaces as a warning while scanning', () async {
      controller.startScan();
      await _flush();

      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();

      expect(controller.uiState.scanState, ScanState.scanning);
      expect(controller.uiState.warningMessage, isNotNull);
      expect(controller.uiState.hasTransientWarning, isTrue);
      expect(controller.uiState.isError, isFalse);
    });

    test('warning is cleared after recognition recovers', () async {
      controller.startScan();
      await _flush();

      priceAdapter.addError(Exception('ML Kit busy'));
      await _flush();
      expect(controller.uiState.warningMessage, isNotNull);

      barcodeAdapter.add(
        const BarcodeCandidate(
          barcode: '4901234567890',
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: _region,
        ),
      );
      await _flush();

      expect(controller.uiState.scanState, ScanState.waitingPrice);
      expect(controller.uiState.warningMessage, isNull);
      expect(controller.uiState.hasTransientWarning, isFalse);
    });

    test('fatal error surfaces as an error state with a message', () async {
      controller.startScan();
      await _flush();

      priceAdapter.addError(Exception('Permission denied: camera access'));
      await _flush();

      expect(controller.uiState.scanState, ScanState.error);
      expect(controller.uiState.isError, isTrue);
      expect(controller.uiState.errorMessage, contains('カメラの権限'));
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
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
