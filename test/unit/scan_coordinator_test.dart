import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

void main() {
  group('ScanCoordinator', () {
    late ScanCoordinator coordinator;
    late CompareUseCase compareUseCase;
    late MockBarcodeRecognizerAdapter barcodeAdapter;
    late MockPriceOCRAdapter priceAdapter;
    late PriceRepository repository;

    setUp(() async {
      repository = await createTestRepository();
      compareUseCase = CompareUseCase(repository);

      barcodeAdapter = MockBarcodeRecognizerAdapter([
        BarcodeCandidate(
          barcode: '4901234567890',
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: Rect(left: 0, top: 0, right: 200, bottom: 100),
        ),
      ]);

      priceAdapter = MockPriceOCRAdapter([
        PriceCandidate(
          priceYen: 398,
          confidence: 0.9,
          region: Rect(left: 0, top: 100, right: 200, bottom: 150),
          rawTexts: ['¥398'],
        ),
      ]);

      coordinator = ScanCoordinator(
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
        repository: repository,
        compareUseCase: compareUseCase,
      );
    });

    tearDown(() {
      coordinator.dispose();
      repository.dispose();
    });

    test('initial state is idle', () {
      expect(coordinator.currentState, ScanState.idle);
    });

    test('startScan transitions to scanning state', () {
      coordinator.startScan();
      expect(coordinator.currentState, ScanState.scanning);
    });

    test('cancelScan returns to idle state', () {
      coordinator.startScan();
      coordinator.cancelScan();
      expect(coordinator.currentState, ScanState.idle);
    });
  });

  group('friendlyScanErrorMessage', () {
    test(
      'classifies SQLITE_FULL as storage exhaustion before generic SQLite',
      () {
        expect(
          friendlyScanErrorMessage(
            Exception(
              'SqliteException(13): database or disk is full SQLITE_FULL',
            ),
          ),
          'ストレージ容量が不足しています。',
        );
      },
    );

    test('keeps other SQLite failures as generic database errors', () {
      expect(
        friendlyScanErrorMessage(
          Exception('SqliteException: malformed database'),
        ),
        'データベースエラーが発生しました。もう一度お試しください。',
      );
    });
  });
}

/// Mock BarcodeRecognizerAdapter for testing
class MockBarcodeRecognizerAdapter implements BarcodeRecognizerAdapter {
  final List<BarcodeCandidate> _candidates;
  bool _paused = false;

  MockBarcodeRecognizerAdapter(this._candidates);

  @override
  Stream<BarcodeCandidate> get results async* {
    for (final candidate in _candidates) {
      if (_paused) {
        await Future.delayed(const Duration(milliseconds: 10));
        _paused = false;
      }
      yield candidate;
    }
  }

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;
}

/// Mock PriceOcrAdapter for testing
class MockPriceOCRAdapter implements PriceOcrAdapter {
  final List<PriceCandidate> _candidates;
  bool _paused = false;

  MockPriceOCRAdapter(this._candidates);

  @override
  Stream<PriceCandidate> get results async* {
    for (final candidate in _candidates) {
      if (_paused) {
        await Future.delayed(const Duration(milliseconds: 10));
        _paused = false;
      }
      yield candidate;
    }
  }

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;
}
