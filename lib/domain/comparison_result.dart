/// 自分値比較結果
class ComparisonResult {
  final int currentPrice;
  final int? baselineMedianYen; // 自分値（都度計算）
  final int? diffYen; // 差額
  final double? diffRate; // 差率
  final ComparisonLabel? label; // ラベル
  final int observationCount; // 観測数
  final ComparisonStatus status;

  /// True when the compared price was entered manually (#89 marker).
  final bool isManualEntry;

  const ComparisonResult({
    required this.currentPrice,
    this.baselineMedianYen,
    this.diffYen,
    this.diffRate,
    this.label,
    required this.observationCount,
    required this.status,
    this.isManualEntry = false,
  });

  /// 初回価格（履歴なし）
  factory ComparisonResult.firstPrice(
    int currentPrice, {
    bool isManualEntry = false,
  }) {
    return ComparisonResult(
      currentPrice: currentPrice,
      observationCount: 0,
      status: ComparisonStatus.firstPrice,
      isManualEntry: isManualEntry,
    );
  }

  /// 履歴不足（3件未満）
  factory ComparisonResult.historyShort({
    required int currentPrice,
    required int lastPrice,
    required int observationCount,
    bool isManualEntry = false,
  }) {
    return ComparisonResult(
      currentPrice: currentPrice,
      baselineMedianYen: lastPrice,
      diffYen: currentPrice - lastPrice,
      diffRate: lastPrice > 0 ? (currentPrice - lastPrice) / lastPrice : 0.0,
      label: ComparisonPolicy.labelForDiffRate(
        lastPrice > 0 ? (currentPrice - lastPrice) / lastPrice : 0.0,
      ),
      observationCount: observationCount,
      status: ComparisonStatus.historyShort,
      isManualEntry: isManualEntry,
    );
  }

  /// 正常比較（3件以上）
  factory ComparisonResult.withBaseline({
    required int currentPrice,
    required int baselineMedianYen,
    required int diffYen,
    required double diffRate,
    required ComparisonLabel label,
    required int observationCount,
    bool isManualEntry = false,
  }) {
    return ComparisonResult(
      currentPrice: currentPrice,
      baselineMedianYen: baselineMedianYen,
      diffYen: diffYen,
      diffRate: diffRate,
      label: label,
      observationCount: observationCount,
      status: ComparisonStatus.withBaseline,
      isManualEntry: isManualEntry,
    );
  }

  @override
  String toString() =>
      'ComparisonResult(current: ¥$currentPrice, baseline: ¥$baselineMedianYen, '
      'diff: ¥$diffYen, label: $label)';
}

/// 比較ステータス
enum ComparisonStatus {
  firstPrice, // 初回価格（履歴なし）
  historyShort, // 履歴不足（3件未満）
  withBaseline, // 正常比較
}

/// 比較ラベル
enum ComparisonLabel {
  veryCheap, // かなり安い（<= -10%）
  cheap, // 安い（-10% < x <= -5%）
  normal, // いつも通り（-5% < x < +5%）
  slightlyExpensive, // 少し高い（+5% <= x < +10%）
  expensive, // 高い（>= +10%）
}

/// 比較ポリシー
class ComparisonPolicy {
  /// 差率からラベルを判定
  static ComparisonLabel labelForDiffRate(double diffRate) {
    if (diffRate <= -0.10) {
      return ComparisonLabel.veryCheap;
    } else if (diffRate <= -0.05) {
      return ComparisonLabel.cheap;
    } else if (diffRate < 0.05) {
      return ComparisonLabel.normal;
    } else if (diffRate < 0.10) {
      return ComparisonLabel.slightlyExpensive;
    } else {
      return ComparisonLabel.expensive;
    }
  }

  /// ラベルの表示テキスト
  static String labelText(ComparisonLabel label) {
    switch (label) {
      case ComparisonLabel.veryCheap:
        return 'かなり安い';
      case ComparisonLabel.cheap:
        return '安い';
      case ComparisonLabel.normal:
        return 'いつも通り';
      case ComparisonLabel.slightlyExpensive:
        return '少し高い';
      case ComparisonLabel.expensive:
        return '高い';
    }
  }

  /// 有効な観測期間（日）
  static const int validObservationDays = 180;

  /// 中央値計算に使用する最大観測数
  static const int maxObservationsForMedian = 12;

  /// 重複防止ウィンドウ（分）
  static const int duplicateWindowMinutes = 5;
}
