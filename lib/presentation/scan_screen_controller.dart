import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/scan_coordinator.dart';
import '../domain/comparison_result.dart';
import '../domain/scan_state.dart';

/// UI-facing state for the scan screen
class ScanScreenUiState {
  final ScanState scanState;
  final String? janCode;
  final int? currentPriceYen;
  final ComparisonResult? comparisonResult;
  final bool isSaving;
  final String? errorMessage;

  /// Transient recognition warning shown while scanning continues.
  ///
  /// Unlike [errorMessage] (shown only in [ScanState.error]), this is
  /// displayed during [ScanState.scanning]/[ScanState.waitingPrice] so
  /// sustained camera/ML Kit failures are visible instead of leaving the
  /// user waiting on an endless "recognizing" indicator.
  final String? warningMessage;

  const ScanScreenUiState({
    this.scanState = ScanState.idle,
    this.janCode,
    this.currentPriceYen,
    this.comparisonResult,
    this.isSaving = false,
    this.errorMessage,
    this.warningMessage,
  });

  /// Sentinel distinguishing "not passed" from an explicit `null` (clear).
  static const _unchanged = Object();

  ScanScreenUiState copyWith({
    ScanState? scanState,
    String? janCode,
    int? currentPriceYen,
    ComparisonResult? comparisonResult,
    bool? isSaving,
    Object? errorMessage = _unchanged,
    Object? warningMessage = _unchanged,
  }) {
    return ScanScreenUiState(
      scanState: scanState ?? this.scanState,
      janCode: janCode ?? this.janCode,
      currentPriceYen: currentPriceYen ?? this.currentPriceYen,
      comparisonResult: comparisonResult ?? this.comparisonResult,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      warningMessage: warningMessage == _unchanged
          ? this.warningMessage
          : warningMessage as String?,
    );
  }

  /// Whether the scan button should be enabled
  bool get canStartScan =>
      scanState == ScanState.idle || scanState == ScanState.error;
  bool get isScanning =>
      scanState == ScanState.scanning || scanState == ScanState.waitingPrice;
  bool get isShowingResult => scanState == ScanState.result;
  bool get isError => scanState == ScanState.error;

  /// Whether a transient recognition warning should be shown.
  bool get hasTransientWarning =>
      warningMessage != null && !isError && isScanning;
}

/// ChangeNotifier that exposes scan screen state to widgets.
///
/// Scan state transitions are sourced from [ScanCoordinator]. The controller
/// does not optimistically invent a scanning state before the coordinator has
/// actually accepted a new session.
class ScanScreenController extends ChangeNotifier {
  final ScanCoordinator _coordinator;

  StreamSubscription<ScanState>? _stateSubscription;
  StreamSubscription<ComparisonResult>? _resultSubscription;
  StreamSubscription<String?>? _errorSubscription;
  StreamSubscription<String?>? _warningSubscription;

  ScanScreenUiState _uiState = const ScanScreenUiState();
  ScanScreenUiState get uiState => _uiState;

  ScanScreenController({required this._coordinator});

  /// Initialize and start listening to coordinator state/result/error streams.
  ///
  /// Safe to call more than once (e.g. the owning widget is recreated):
  /// previous subscriptions are cancelled first so events are never
  /// delivered twice.
  void init() {
    _stateSubscription?.cancel();
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _warningSubscription?.cancel();
    _stateSubscription = _coordinator.stateStream.listen((scanState) {
      _onScanStateChanged(scanState);
    });

    _resultSubscription = _coordinator.resultStream.listen((result) {
      _uiState = _uiState.copyWith(
        comparisonResult: result,
        janCode: _coordinator.resultJanCode,
        currentPriceYen: result.currentPrice,
      );
      notifyListeners();
    });

    _errorSubscription = _coordinator.errorStream.listen((message) {
      if (message != null) {
        _uiState = _uiState.copyWith(errorMessage: message);
        notifyListeners();
      }
    });

    _warningSubscription = _coordinator.warningStream.listen((message) {
      _uiState = _uiState.copyWith(warningMessage: message);
      notifyListeners();
    });
  }

  void _onScanStateChanged(ScanState state) {
    _uiState = _uiState.copyWith(
      scanState: state,
      errorMessage: null,
      warningMessage: null,
    );

    if (state == ScanState.result) {
      _uiState = _uiState.copyWith(isSaving: false);
    }

    notifyListeners();
  }

  /// Start a new scan session.
  void startScan() {
    if (!_uiState.canStartScan) return;
    _coordinator.startScan();
  }

  /// Cancel the current scan.
  void cancelScan() {
    _coordinator.cancelScan();
    _uiState = const ScanScreenUiState();
    notifyListeners();
  }

  /// Dismiss the result and return both UI and coordinator to idle.
  void dismissResult() {
    _coordinator.resetToIdle();
    _uiState = const ScanScreenUiState();
    notifyListeners();
  }

  /// JAN currently awaiting a price, if a barcode was already recognized.
  String? get pendingJanCode => _coordinator.pendingJanCode;

  /// Corrects the latest saved observation for the current JAN.
  /// Returns false when there is nothing to correct or the entry invalid.
  Future<bool> correctLatestPrice({
    String? janCode,
    required int priceYen,
    required bool isTaxInclusive,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) {
    final jan = janCode ?? _uiState.janCode;
    if (jan == null) return Future.value(false);
    return _coordinator.correctLatestObservation(
      jan: jan,
      entry: ManualPriceEntry(
        priceYen: priceYen,
        isTaxInclusive: isTaxInclusive,
        isSaleVisible: isSaleVisible,
        isMemberPriceVisible: isMemberPriceVisible,
        isCouponPriceVisible: isCouponPriceVisible,
        isBulkDiscount: isBulkDiscount,
      ),
    );
  }

  /// Submits a user-entered price. Returns false when the amount is invalid
  /// (empty/out of range/tax-exclusive) or no scan session can take it.
  bool submitManualPrice({
    required int priceYen,
    required bool isTaxInclusive,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) {
    return _coordinator.submitManualPrice(
      ManualPriceEntry(
        priceYen: priceYen,
        isTaxInclusive: isTaxInclusive,
        isSaleVisible: isSaleVisible,
        isMemberPriceVisible: isMemberPriceVisible,
        isCouponPriceVisible: isCouponPriceVisible,
        isBulkDiscount: isBulkDiscount,
      ),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _warningSubscription?.cancel();
    super.dispose();
  }
}
