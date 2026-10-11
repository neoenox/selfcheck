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

  /// Last transient recognition warning (kept while scanning continues).
  ///
  /// Adapter stream errors are transient by default: the scan session keeps
  /// running and the UI surfaces this warning without leaving the scanning
  /// state. Fatal adapter errors escalate to [ScanState.error] instead and
  /// are additionally reported through [lastError]/[errorStream].
  String? _lastWarning;
  String? get lastWarning => _lastWarning;

  /// JAN associated with the most recently completed comparison result.
  String? _resultJanCode;
  String? get resultJanCode => _resultJanCode;

  /// Cached barcode candidate while waiting for a stable price.
  BarcodeCandidate? _pendingBarcode;

  /// JAN awaiting a price, exposed so a manual entry can be confirmed
  /// against it before saving.
  String? get pendingJanCode => _pendingBarcode?.barcode;

  /// User-entered price awaiting comparison. Takes precedence over OCR
  /// candidates but never bypasses JAN association or persistence rules.
  ManualPriceEntry? _manualEntry;

  final StreamController<ScanState> _stateController =
      StreamController<ScanState>.broadcast();
  final StreamController<ComparisonResult> _resultController =
      StreamController<ComparisonResult>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();
  final StreamController<String?> _warningController =
      StreamController<String?>.broadcast();

  Stream<ScanState> get stateStream => _stateController.stream;
  Stream<ComparisonResult> get resultStream => _resultController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  /// Transient recognition warnings. Emitted while the scan session keeps
  /// running; a `null` event means a previously reported warning was cleared
  /// after recovery (or because the session ended).
  Stream<String?> get warningStream => _warningController.stream;

  ScanState get currentState => _state;

  StreamSubscription<BarcodeCandidate>? _barcodeSubscription;
  StreamSubscription<List<PriceCandidate>>? _priceSubscription;

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
    _manualEntry = null;
    _resultJanCode = null;
    _barcodeAdapter.resume();
    _priceAdapter.resume();

    _state = ScanState.scanning;
    _lastError = null;
    _lastWarning = null;
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
      (frame) {
        if (!_isCurrentSession(generation)) return;
        try {
          unawaited(_onPriceDetected(frame, generation));
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

  /// Corrects the latest saved observation for [jan] with user-entered values.
  ///
  /// Only available once a scan settled (result) or is idle: it must never
  /// interfere with an active recognition session. The previous latest
  /// observation is invalidated (kept for audit) before the corrected value
  /// is compared and saved, so the duplicate window cannot block the fix
  /// and the wrong amount leaves the baseline. Returns false when there is
  /// nothing to correct or the entry is invalid.
  Future<bool> correctLatestObservation({
    required String jan,
    required ManualPriceEntry entry,
  }) async {
    if (_state != ScanState.result && _state != ScanState.idle) return false;
    if (entry.priceYen < 1 || entry.priceYen > 99999 || !entry.isTaxInclusive) {
      return false;
    }

    final product = await _repository.findProductByJan(jan);
    if (product == null) return false;
    final observations = await _repository.getValidObservations(
      productId: product.id,
      since: DateTime.fromMillisecondsSinceEpoch(0),
      limit: 1,
    );
    if (observations.isEmpty) return false;

    await _repository.invalidateObservation(observations.first.id);

    final generation = _sessionGeneration;
    await _compare(
      BarcodeCandidate(
        barcode: jan,
        format: jan.length == 13
            ? BarcodeFormat.ean13
            : jan.length == 8
            ? BarcodeFormat.ean8
            : BarcodeFormat.unknown,
        confidence: entry.confidence,
        region: const Rect(left: 0, top: 0, right: 0, bottom: 0),
      ),
      entry.priceYen,
      entry.confidence,
      generation,
      isSaleVisible: entry.isSaleVisible,
      isMemberPriceVisible: entry.isMemberPriceVisible,
      isCouponPriceVisible: entry.isCouponPriceVisible,
      isBulkDiscount: entry.isBulkDiscount,
      isManualEntry: true,
    );
    return _isCurrentSession(generation) && _state == ScanState.result;
  }

  void cancelScan() {
    _transitionToIdle();
  }

  /// Submits a user-entered price for the current session.
  ///
  /// Accepted in scanning/waitingPrice/noProduct states with a valid amount
  /// (1–99,999 yen, tax-inclusive only). Tax-exclusive manual entries are
  /// rejected: without a known tax rate they cannot be converted, and saving
  /// them would corrupt the tax-inclusive history.
  ///
  /// When the barcode is already pending, comparison starts immediately.
  /// Otherwise the entry is cached and used as soon as a barcode arrives,
  /// taking precedence over later OCR candidates.
  bool submitManualPrice(ManualPriceEntry entry) {
    if (_state != ScanState.scanning &&
        _state != ScanState.waitingPrice &&
        _state != ScanState.noProduct) {
      return false;
    }
    if (entry.priceYen < 1 || entry.priceYen > 99999 || !entry.isTaxInclusive) {
      return false;
    }

    _manualEntry = entry;
    if (_state == ScanState.waitingPrice && _pendingBarcode != null) {
      final barcode = _pendingBarcode!;
      _manualEntry = null;
      unawaited(
        _compare(
          barcode,
          entry.priceYen,
          entry.confidence,
          _sessionGeneration,
          isSaleVisible: entry.isSaleVisible,
          isMemberPriceVisible: entry.isMemberPriceVisible,
          isCouponPriceVisible: entry.isCouponPriceVisible,
          isBulkDiscount: entry.isBulkDiscount,
          isManualEntry: true,
        ),
      );
    }
    return true;
  }

  /// Reset a completed/error session so the UI can start another scan.
  void resetToIdle() {
    _transitionToIdle();
  }

  void _transitionToIdle() {
    _sessionGeneration++;
    _cancelSubscriptions();
    _resetRecognitionContext();
    _manualEntry = null;
    _resultJanCode = null;
    _barcodeAdapter.pause();
    _priceAdapter.pause();
    _lastError = null;
    _clearWarning();
    _state = ScanState.idle;
    _stateController.add(_state);
  }

  void _onBarcodeDetected(BarcodeCandidate barcode, int generation) {
    if (!_isCurrentSession(generation) || _state != ScanState.scanning) return;

    _clearWarning();
    _barcodeAdapter.pause();
    _priceAdapter.pause();

    // A user-confirmed manual price wins over any OCR candidate.
    final manual = _manualEntry;
    if (manual != null) {
      _manualEntry = null;
      unawaited(
        _compare(
          barcode,
          manual.priceYen,
          manual.confidence,
          generation,
          isSaleVisible: manual.isSaleVisible,
          isMemberPriceVisible: manual.isMemberPriceVisible,
          isCouponPriceVisible: manual.isCouponPriceVisible,
          isBulkDiscount: manual.isBulkDiscount,
          isManualEntry: true,
        ),
      );
      return;
    }

    // Prefer the top-ranked stable candidate that is safely associated
    // with this JAN. A higher-ranked distant price (e.g. a neighboring
    // product's tax-inclusive total) must not shadow the nearby price.
    final associated = _stabilizer.stableCandidates
        .where((c) => regionsAreSafelyAssociated(barcode.region, c.region))
        .toList();
    if (associated.isNotEmpty) {
      final selected = associated.first;
      unawaited(
        _compare(barcode, selected.priceYen, selected.confidence, generation),
      );
      return;
    }

    _pendingBarcode = barcode;
    if (_stabilizer.stablePrice != null) {
      _stabilizer.reset();
    }
    _state = ScanState.waitingPrice;
    _stateController.add(_state);
    _priceAdapter.resume();
  }

  Future<void> _onPriceDetected(
    List<PriceCandidate> frame,
    int generation,
  ) async {
    if (!_isCurrentSession(generation)) return;
    if (_state != ScanState.scanning && _state != ScanState.waitingPrice) {
      return;
    }
    if (frame.isEmpty) return;

    // A readable price frame means recognition recovered; drop any stale
    // transient warning so it does not linger after recovery.
    _clearWarning();
    final isStable = _stabilizer.submitFrame(frame);
    if (!isStable) return;

    _barcodeAdapter.pause();
    _priceAdapter.pause();

    if (_state == ScanState.waitingPrice && _pendingBarcode != null) {
      // A user-confirmed manual price wins over any OCR candidate.
      final manual = _manualEntry;
      if (manual != null) {
        _manualEntry = null;
        await _compare(
          _pendingBarcode!,
          manual.priceYen,
          manual.confidence,
          generation,
          isSaleVisible: manual.isSaleVisible,
          isMemberPriceVisible: manual.isMemberPriceVisible,
          isCouponPriceVisible: manual.isCouponPriceVisible,
          isBulkDiscount: manual.isBulkDiscount,
          isManualEntry: true,
        );
        return;
      }
      // Select from the stable candidates associated with the pending JAN.
      // Rejecting a distant price must not hide an associated nearby one.
      final associated = _stabilizer.stableCandidates
          .where(
            (c) =>
                regionsAreSafelyAssociated(_pendingBarcode!.region, c.region),
          )
          .toList();
      if (associated.isEmpty) {
        // Keep the JAN pending, but discard this stable value. Saving an
        // unrelated product's price under the JAN is worse than retrying.
        _stabilizer.reset();
        _priceAdapter.resume();
        return;
      }
      final selected = associated.first;
      await _compare(
        _pendingBarcode!,
        selected.priceYen,
        selected.confidence,
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
    int generation, {
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) async {
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
        isSaleVisible: isSaleVisible,
        isMemberPriceVisible: isMemberPriceVisible,
        isCouponPriceVisible: isCouponPriceVisible,
        isBulkDiscount: isBulkDiscount,
        isManualEntry: isManualEntry,
      );
      if (!_isCurrentSession(generation)) return;

      _resultJanCode = barcode.barcode;
      _resultController.add(result);
      _cancelSubscriptions();
      _resetRecognitionContext();
      _clearWarning();
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

    _transitionToError(_friendlyErrorMessage(error));
  }

  /// Moves the session into [ScanState.error] with [message].
  ///
  /// The state event is emitted before the error event so UI listeners that
  /// clear stale messages on state transitions still display the new error.
  /// The session generation is invalidated so an in-flight compare (e.g. a
  /// fatal adapter error arriving mid-compare) cannot flip the error back
  /// to a result afterwards.
  void _transitionToError(String message) {
    _lastError = message;

    _sessionGeneration++;
    _cancelSubscriptions();
    _resetRecognitionContext();
    _clearWarning();
    _resultJanCode = null;
    _barcodeAdapter.pause();
    _priceAdapter.pause();
    _state = ScanState.error;
    _stateController.add(_state);
    _errorController.add(message);
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
    if (_isFatalAdapterError(error)) {
      // Fatal adapter errors (e.g. camera permission denied) can never
      // recover by retrying frames: stop the scan and surface the error
      // immediately through the same path as compare failures.
      _transitionToError(message);
      return;
    }

    // Transient adapter stream errors keep the current state/session so a
    // single bad frame does not stop the scan. The warning is surfaced
    // through warningStream (shown while scanning); errorStream keeps
    // receiving the message for backward compatibility with existing
    // error listeners.
    _lastError = message;
    _lastWarning = message;
    _errorController.add(message);
    _warningController.add(message);
  }

  /// Clears a previously reported transient warning, notifying UI listeners
  /// so a stale warning does not linger after recognition recovered.
  void _clearWarning() {
    if (_lastWarning == null) return;
    _lastWarning = null;
    if (!_warningController.isClosed) {
      _warningController.add(null);
    }
  }

  bool _isFatalAdapterError(Object error) {
    final text = error.toString();
    return text.contains('Permission denied') ||
        text.contains('CameraAccessDenied');
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
    if (text.contains('Permission denied') ||
        text.contains('CameraAccessDenied')) {
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
    _warningController.close();
  }
}

/// Adapter interfaces for barcode and price OCR.
abstract class BarcodeRecognizerAdapter {
  Stream<BarcodeCandidate> get results;
  void pause();
  void resume();
}

abstract class PriceOcrAdapter {
  /// One event per OCR frame, holding that frame's ranked price candidates.
  Stream<List<PriceCandidate>> get results;
  void pause();
  void resume();
}

/// Confidence recorded for user-confirmed manual prices.
///
/// OCR candidates carry estimator confidences (0.70–0.90); a manual entry was
/// verified by a human, so it is recorded at full confidence alongside
/// [ManualPriceEntry.isManualEntry].
const double kManualPriceConfidence = 1.0;

/// A user-entered price awaiting comparison.
///
/// [isTaxInclusive] must be true: tax-exclusive amounts cannot be converted
/// without a known rate, so they are rejected rather than saved.
class ManualPriceEntry {
  const ManualPriceEntry({
    required this.priceYen,
    this.confidence = kManualPriceConfidence,
    required this.isTaxInclusive,
    this.isSaleVisible,
    this.isMemberPriceVisible,
    this.isCouponPriceVisible,
    this.isBulkDiscount,
  });

  final int priceYen;
  final double confidence;
  final bool isTaxInclusive;
  final bool? isSaleVisible;
  final bool? isMemberPriceVisible;
  final bool? isCouponPriceVisible;
  final bool? isBulkDiscount;
}
