import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/comparison_result.dart';
import '../domain/scan_state.dart';
import '../infrastructure/price_repository.dart';
import '../infrastructure/price_stabilizer.dart';
import 'compare_use_case.dart';

/// ScanCoordinator manages the scanning session lifecycle.
///
/// Emits state changes via [stateStream] and comparison results via
/// [resultStream]. A scan session owns exactly one barcode subscription and one
/// price subscription. Session generations prevent stale async callbacks from a
/// cancelled or completed session from mutating the next session.
class ScanCoordinator {
  final PriceRepository _repository;
  final CompareUseCase _compareUseCase;
  final PriceStabilizer _stabilizer;
  final BarcodeRecognizerAdapter _barcodeAdapter;
  final PriceOcrAdapter _priceAdapter;

  ScanState _state = ScanState.idle;
  int _sessionGeneration = 0;

  /// Last error message (cleared on next successful scan start).
  String? _lastError;
  String? get lastError => _lastError;

  /// JAN associated with the most recently completed comparison result.
  String? _resultJanCode;
  String? get resultJanCode => _resultJanCode;

  /// Cached barcode candidate while waiting for a stable price.
  BarcodeCandidate? _pendingBarcode;

  final StreamController<ScanState> _stateController =
      StreamController<ScanState>.broadcast();
  final StreamController<ComparisonResult> _resultController =
      StreamController<ComparisonResult>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  Stream<ScanState> get stateStream => _stateController.stream;
  Stream<ComparisonResult> get resultStream => _resultController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  ScanState get currentState => _state;

  StreamSubscription<BarcodeCandidate>? _barcodeSubscription;
  StreamSubscription<PriceCandidate>? _priceSubscription;

  ScanCoordinator({
    required this._repository,
    required this._compareUseCase,
    PriceStabilizer? stabilizer,
    required this._barcodeAdapter,
    required this._priceAdapter,
  }) : _stabilizer = stabilizer ?? PriceStabilizer();

  void startScan() {
    if (_state != ScanState.idle && _state != ScanState.error) return;

    _sessionGeneration++;
    final generation = _sessionGeneration;

    _cancelSubscriptions();
    _resetRecognitionContext();
    _resultJanCode = null;
    _barcodeAdapter.resume();
    _priceAdapter.resume();

    _state = ScanState.scanning;
    _lastError = null;
    _stateController.add(_state);

    _barcodeSubscription = _barcodeAdapter.results.listen(
      (barcode) {
        if (!_isCurrentSession(generation)) return;
        try {
          _onBarcodeDetected(barcode, generation);
        } catch (error, stackTrace) {
          _handleAdapterError('バーコード処理エラー', error, stackTrace, generation);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_isCurrentSession(generation)) return;
        _handleAdapterError('バーコード認識ストリームエラー', error, stackTrace, generation);
      },
    );

    _priceSubscription = _priceAdapter.results.listen(
      (price) {
        if (!_isCurrentSession(generation)) return;
        try {
          unawaited(_onPriceDetected(price, generation));
        } catch (error, stackTrace) {
          _handleAdapterError('価格OCR処理エラー', error, stackTrace, generation);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_isCurrentSession(generation)) return;
        _handleAdapterError('価格OCRストリームエラー', error, stackTrace, generation);
      },
    );
  }

  void cancelScan() {
    _transitionToIdle();
  }

  /// Reset a completed/error session so the UI can start another scan.
  void resetToIdle() {
    _transitionToIdle();
  }

  void _transitionToIdle() {
    _sessionGeneration++;
    _cancelSubscriptions();
    _resetRecognitionContext();
    _resultJanCode = null;
    _barcodeAdapter.pause();
    _priceAdapter.pause();
    _lastError = null;
    _state = ScanState.idle;
    _stateController.add(_state);
  }

  void _onBarcodeDetected(BarcodeCandidate barcode, int generation) {
    if (!_isCurrentSession(generation) || _state != ScanState.scanning) return;

    _barcodeAdapter.pause();
    _priceAdapter.pause();

    final stablePrice = _stabilizer.stablePrice;
    final stableCandidate = _stabilizer.stableCandidate;
    if (stablePrice != null &&
        stableCandidate != null &&
        regionsAreSafelyAssociated(barcode.region, stableCandidate.region)) {
      unawaited(
        _compare(
          barcode,
          stablePrice,
          _stabilizer.stableConfidence,
          generation,
        ),
      );
      return;
    }

    _pendingBarcode = barcode;
    if (stablePrice != null) {
      _stabilizer.reset();
    }
    _state = ScanState.waitingPrice;
    _stateController.add(_state);
    _priceAdapter.resume();
  }

  Future<void> _onPriceDetected(PriceCandidate price, int generation) async {
    if (!_isCurrentSession(generation)) return;
    if (_state != ScanState.scanning && _state != ScanState.waitingPrice) {
      return;
    }

    final isStable = _stabilizer.submit(price);
    if (!isStable) return;

    _barcodeAdapter.pause();
    _priceAdapter.pause();

    if (_state == ScanState.waitingPrice && _pendingBarcode != null) {
      final stableCandidate = _stabilizer.stableCandidate;
      if (stableCandidate == null ||
          !regionsAreSafelyAssociated(
            _pendingBarcode!.region,
            stableCandidate.region,
          )) {
        // Keep the JAN pending, but discard this stable value. Saving an
        // unrelated product's price under the JAN is worse than retrying.
        _stabilizer.reset();
        _priceAdapter.resume();
        return;
      }
      await _compare(
        _pendingBarcode!,
        _stabilizer.stablePrice!,
        _stabilizer.stableConfidence,
        generation,
      );
      return;
    }

    _state = ScanState.noProduct;
    _stateController.add(_state);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_isCurrentSession(generation) || _state != ScanState.noProduct) return;

    // A stable price without a barcode must never leak into the next product.
    _resetRecognitionContext();
    _barcodeAdapter.resume();
    _priceAdapter.resume();
    _state = ScanState.scanning;
    _stateController.add(_state);
  }

  Future<void> _compare(
    BarcodeCandidate barcode,
    int priceYen,
    double confidence,
    int generation,
  ) async {
    if (!_isCurrentSession(generation)) return;

    _state = ScanState.comparing;
    _stateController.add(_state);

    try {
      var product = await _repository.findProductByJan(barcode.barcode);
      if (!_isCurrentSession(generation)) return;

      product ??= await _repository.createProvisionalProduct(barcode.barcode);
      if (!_isCurrentSession(generation)) return;

      final isDuplicate = await _repository.isDuplicate(
        productId: product.id,
        priceYen: priceYen,
        observedAt: DateTime.now(),
      );
      if (!_isCurrentSession(generation)) return;

      final result = await _compareUseCase.compare(
        currentPriceYen: priceYen,
        productId: product.id,
        currentConfidence: confidence,
        skipInsert: isDuplicate,
        isSessionValid: () => _isCurrentSession(generation),
      );
      if (!_isCurrentSession(generation)) return;

      _resultJanCode = barcode.barcode;
      _resultController.add(result);
      _cancelSubscriptions();
      _resetRecognitionContext();
      _barcodeAdapter.pause();
      _priceAdapter.pause();
      _state = ScanState.result;
      _stateController.add(_state);
    } on Exception catch (error, stackTrace) {
      if (_isCurrentSession(generation)) {
        _handleCompareError(error, stackTrace);
      }
    } on Error catch (error, stackTrace) {
      if (_isCurrentSession(generation)) {
        _handleCompareError(error, stackTrace);
      }
    }
  }

  void _handleCompareError(Object error, StackTrace stackTrace) {
    debugPrint('ScanCoordinator._compare failed: $error');
    debugPrint('$stackTrace');

    final message = _friendlyErrorMessage(error);
    _lastError = message;
    _errorController.add(message);

    _cancelSubscriptions();
    _resetRecognitionContext();
    _resultJanCode = null;
    _barcodeAdapter.pause();
    _priceAdapter.pause();
    _state = ScanState.error;
    _stateController.add(_state);
  }

  void _handleAdapterError(
    String context,
    Object error,
    StackTrace stackTrace,
    int generation,
  ) {
    if (!_isCurrentSession(generation)) return;

    debugPrint('ScanCoordinator adapter error ($context): $error');
    debugPrint('$stackTrace');

    final message = '$context: ${_friendlyErrorMessage(error)}';
    _lastError = message;
    _errorController.add(message);

    // Adapter stream errors can be transient. Keep the current state/session;
    // a fatal adapter implementation should close its stream or be surfaced by
    // a higher-level lifecycle owner.
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains('SQLITE_FULL') ||
        text.contains('database or disk is full') ||
        text.contains(' disk full')) {
      return 'ストレージ容量が不足しています。';
    }
    if (text.contains('SqliteException') || text.contains('database')) {
      return 'データベースエラーが発生しました。もう一度お試しください。';
    }
    if (text.contains('Permission denied')) {
      return 'カメラの権限が必要です。設定から許可してください。';
    }
    return '予期せぬエラーが発生しました。もう一度お試しください。';
  }

  bool _isCurrentSession(int generation) => generation == _sessionGeneration;

  void _resetRecognitionContext() {
    _stabilizer.reset();
    _pendingBarcode = null;
  }

  void _cancelSubscriptions() {
    final barcodeSubscription = _barcodeSubscription;
    final priceSubscription = _priceSubscription;
    _barcodeSubscription = null;
    _priceSubscription = null;

    if (barcodeSubscription != null) {
      unawaited(barcodeSubscription.cancel());
    }
    if (priceSubscription != null) {
      unawaited(priceSubscription.cancel());
    }
  }

  void dispose() {
    _sessionGeneration++;
    _cancelSubscriptions();
    _resetRecognitionContext();
    _resultJanCode = null;
    _stateController.close();
    _resultController.close();
    _errorController.close();
  }
}

/// Adapter interfaces for barcode and price OCR.
abstract class BarcodeRecognizerAdapter {
  Stream<BarcodeCandidate> get results;
  void pause();
  void resume();
}

abstract class PriceOcrAdapter {
  Stream<PriceCandidate> get results;
  void pause();
  void resume();
}
