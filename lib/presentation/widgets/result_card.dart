import 'package:flutter/material.dart';
import '../../domain/comparison_result.dart';

/// Color scheme for comparison labels
class LabelColors {
  static const veryCheap = Color(0xFF1B5E20); // Dark green
  static const veryCheapBg = Color(0xFFE8F5E9); // Light green
  static const cheap = Color(0xFF2E7D32); // Green
  static const cheapBg = Color(0xFFE8F5E9);
  static const normal = Color(0xFF424242); // Gray
  static const normalBg = Color(0xFFF5F5F5); // Light gray
  static const slightlyExpensive = Color(0xFFE65100); // Orange
  static const slightlyExpensiveBg = Color(0xFFFFF3E0);
  static const expensive = Color(0xFFB71C1C); // Red
  static const expensiveBg = Color(0xFFFFEBEE);

  static Color forLabel(ComparisonLabel? label) {
    switch (label) {
      case ComparisonLabel.veryCheap:
        return veryCheap;
      case ComparisonLabel.cheap:
        return cheap;
      case ComparisonLabel.normal:
        return normal;
      case ComparisonLabel.slightlyExpensive:
        return slightlyExpensive;
      case ComparisonLabel.expensive:
        return expensive;
      case null:
        return normal;
    }
  }

  static Color bgForLabel(ComparisonLabel? label) {
    switch (label) {
      case ComparisonLabel.veryCheap:
        return veryCheapBg;
      case ComparisonLabel.cheap:
        return cheapBg;
      case ComparisonLabel.normal:
        return normalBg;
      case ComparisonLabel.slightlyExpensive:
        return slightlyExpensiveBg;
      case ComparisonLabel.expensive:
        return expensiveBg;
      case null:
        return normalBg;
    }
  }

  /// Symbol for label (non-color indicator for accessibility)
  static String symbolForLabel(ComparisonLabel? label) {
    switch (label) {
      case ComparisonLabel.veryCheap:
        return '▼▼';
      case ComparisonLabel.cheap:
        return '▼';
      case ComparisonLabel.normal:
        return '─';
      case ComparisonLabel.slightlyExpensive:
        return '▲';
      case ComparisonLabel.expensive:
        return '▲▲';
      case null:
        return '';
    }
  }
}

/// Card that shows the price comparison result
class ResultCard extends StatelessWidget {
  final ComparisonResult result;
  final String? janCode;
  final VoidCallback? onDismiss;
  final VoidCallback? onScanAgain;

  const ResultCard({
    super.key,
    required this.result,
    this.janCode,
    this.onDismiss,
    this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          _buildPriceSection(context),
          if (result.baselineMedianYen != null) _buildDiffSection(),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LabelColors.bgForLabel(result.label),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            LabelColors.symbolForLabel(result.label),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: LabelColors.forLabel(result.label),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _headerText(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LabelColors.forLabel(result.label),
              ),
            ),
          ),
          if (janCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                janCode!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '¥${result.currentPrice}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          // Manual-entry marker (issue #89): shown only for hand-entered
          // prices. Teal is intentionally distinct from the SALE (red) /
          // member (blue) / coupon (orange) / bulk (purple) badge palette
          // so the markers coexist without visual clash.
          if (result.isManualEntry) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 14, color: Colors.teal.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '手入力',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result.label != null) ...[
            const SizedBox(height: 4),
            Text(
              ComparisonPolicy.labelText(result.label!),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LabelColors.forLabel(result.label),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffSection() {
    final diffText = result.diffYen != null
        ? '${result.diffYen! >= 0 ? '+' : ''}¥${result.diffYen}'
        : '';
    final rateText = result.diffRate != null
        ? '(${(result.diffRate! * 100).toStringAsFixed(1)}%)'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '自分値: ¥${result.baselineMedianYen}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Text(
            '$diffText $rateText',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: LabelColors.forLabel(result.label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Text(
            '${result.observationCount}件の履歴',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const Spacer(),
          TextButton(onPressed: onDismiss, child: const Text('閉じる')),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('スキャン'),
          ),
        ],
      ),
    );
  }

  String _headerText() {
    switch (result.status) {
      case ComparisonStatus.firstPrice:
        return '初めての記録です';
      case ComparisonStatus.historyShort:
        return '履歴を蓄積中';
      case ComparisonStatus.withBaseline:
        return '過去の値段と比較';
    }
  }
}
