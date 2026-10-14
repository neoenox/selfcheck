import 'package:flutter/material.dart';

import '../domain/scan_state.dart';
import 'scan_screen_controller.dart';
import 'widgets/manual_price_sheet.dart';
import 'widgets/price_context_badges.dart';
import 'widgets/result_card.dart';
import 'widgets/scan_overlay.dart';

/// Main scan screen - camera preview with state-driven overlay and result card.
class ScanScreen extends StatefulWidget {
  final ScanScreenController controller;
  final Widget cameraPreview;

  const ScanScreen({
    super.key,
    required this.controller,
    this.cameraPreview = const SizedBox.shrink(),
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    widget.controller.addListener(_onStateChanged);
    widget.controller.init();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  Future<void> _openManualPriceSheet(BuildContext context) async {
    if (!widget.controller.beginManualEntry()) return;
    ManualSaveOutcome? outcome;
    try {
      outcome = await showManualPriceSheet(context, widget.controller);
    } finally {
      widget.controller.endManualEntry();
    }
    if (outcome != null &&
        outcome.saved &&
        !outcome.janKnown &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('バーコードをスキャンすると自動で保存されます')));
    }
  }

  Future<void> _openCorrectionSheet(
    BuildContext context,
    int currentPrice,
  ) async {
    await showManualPriceSheet(
      context,
      widget.controller,
      initialPriceYen: currentPrice,
      initialEntry: widget.controller.resultPriceContext,
      onSaveEntry: (entry) => widget.controller.correctLatestPrice(
        priceYen: entry.priceYen,
        isTaxInclusive: entry.isTaxInclusive,
        isSaleVisible: entry.isSaleVisible,
        isMemberPriceVisible: entry.isMemberPriceVisible,
        isCouponPriceVisible: entry.isCouponPriceVisible,
        isBulkDiscount: entry.isBulkDiscount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.uiState;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.cameraPreview,
          if (state.isScanning) IgnorePointer(child: _buildScanGuide()),
          ScanOverlay(scanState: state.scanState),
          if (state.isShowingResult && state.comparisonResult != null)
            _buildResultOverlay(context, state),
          _buildTopBar(state),
          _buildBottomControls(state),
        ],
      ),
    );
  }

  Widget _buildScanGuide() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.3 + (_pulseController.value * 0.3);
        return Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: opacity),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ScanScreenUiState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (state.isScanning)
                IconButton(
                  onPressed: () => widget.controller.cancelScan(),
                  icon: const Icon(Icons.close, color: Colors.white),
                )
              else
                const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  '自分値スキャン',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(ScanScreenUiState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isError && state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.hasTransientWarning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.warningMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.scanState == ScanState.waitingPrice)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'バーコード認識済み ▶ 価格安定化待ち',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              if (state.isScanning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: () => _openManualPriceSheet(context),
                    child: const Text(
                      '価格を手入力',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
              if (state.canStartScan) _buildScanButton(),
              if (state.isShowingResult) ...[
                const SizedBox(height: 8),
                Text(
                  'スキャン完了',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () => widget.controller.startScan(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: const Icon(Icons.qr_code_scanner, size: 36, color: Colors.white),
      ),
    );
  }

  Widget _buildResultOverlay(BuildContext context, ScanScreenUiState state) {
    // DraggableScrollableSheet requires bounded height constraints, so it is
    // placed as a direct Stack child (loose bounded constraints) rather than
    // inside a bottom-anchored Positioned, which would give it an infinite
    // height and fail layout.
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(top: 8),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (state.comparisonResult != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PriceContextBadges(
                    isSaleVisible:
                        widget.controller.resultPriceContext?.isSaleVisible,
                    isMemberPriceVisible: widget
                        .controller
                        .resultPriceContext
                        ?.isMemberPriceVisible,
                    isCouponPriceVisible: widget
                        .controller
                        .resultPriceContext
                        ?.isCouponPriceVisible,
                    isBulkDiscount:
                        widget.controller.resultPriceContext?.isBulkDiscount,
                  ),
                ),
              ResultCard(
                result: state.comparisonResult!,
                janCode: state.janCode,
                onDismiss: () => widget.controller.dismissResult(),
                onScanAgain: () {
                  widget.controller.dismissResult();
                  widget.controller.startScan();
                },
                onCorrectPrice: () {
                  final currentPrice = state.comparisonResult?.currentPrice;
                  if (currentPrice != null) {
                    _openCorrectionSheet(context, currentPrice);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
