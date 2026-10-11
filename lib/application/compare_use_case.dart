import '../domain/comparison_result.dart';
import '../infrastructure/price_repository.dart';

/// Raised when a comparison is cancelled before its persistence boundary.
class ComparisonCancelledException implements Exception {
  const ComparisonCancelledException();
}

/// CompareUseCase - compares current price against historical median
class CompareUseCase {
  final PriceRepository _repository;

  CompareUseCase(this._repository);

  /// Compare current price against stored observations
  ///
  /// When [skipInsert] is true, the current observation is NOT saved to the
  /// database. Use this when the caller already determined this is a duplicate
  /// and wants to show the comparison without inflating the observation count.
  /// Price context flags (including [isManualEntry]) are recorded with the
  /// observation so manual entries stay distinguishable from OCR readings.
  Future<ComparisonResult> compare({
    required int currentPriceYen,
    required String productId,
    required double currentConfidence,
    bool skipInsert = false,
    bool Function()? isSessionValid,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) async {
    // Fetch historical observations first (before inserting current)
    final since = DateTime.now().subtract(
      const Duration(days: ComparisonPolicy.validObservationDays),
    );
    final observations = await _repository.getValidObservations(
      productId: productId,
      since: since,
      limit: ComparisonPolicy.maxObservationsForMedian,
    );

    // Cancellation can happen while the historical query is in flight. Check
    // again at the commit boundary so a cancelled session cannot persist.
    if (isSessionValid != null && !isSessionValid()) {
      throw const ComparisonCancelledException();
    }

    // Save current observation (unless caller says it's a duplicate)
    if (!skipInsert) {
      await _repository.insertObservation(
        productId: productId,
        priceYen: currentPriceYen,
        priceConfidence: currentConfidence,
        isSaleVisible: isSaleVisible,
        isMemberPriceVisible: isMemberPriceVisible,
        isCouponPriceVisible: isCouponPriceVisible,
        isBulkDiscount: isBulkDiscount,
        isManualEntry: isManualEntry,
      );
    }

    if (observations.isEmpty) {
      return ComparisonResult.firstPrice(
        currentPriceYen,
        isManualEntry: isManualEntry ?? false,
      );
    }

    final prices = observations.map((o) => o.priceYen).toList()..sort();
    final median = _medianYen(prices);

    if (observations.length < 3) {
      return ComparisonResult.historyShort(
        currentPrice: currentPriceYen,
        lastPrice: median,
        observationCount: observations.length,
        isManualEntry: isManualEntry ?? false,
      );
    }

    final diffYen = currentPriceYen - median;
    final diffRate = median > 0 ? diffYen / median : 0.0;
    final label = ComparisonPolicy.labelForDiffRate(diffRate);

    return ComparisonResult.withBaseline(
      currentPrice: currentPriceYen,
      baselineMedianYen: median,
      diffYen: diffYen,
      diffRate: diffRate,
      label: label,
      observationCount: observations.length,
      isManualEntry: isManualEntry ?? false,
    );
  }

  /// Returns the mathematical median rounded to the nearest whole yen.
  ///
  /// For an even number of observations, the midpoint of the two center values
  /// is used. A .5 yen midpoint rounds up because prices are non-negative.
  int _medianYen(List<int> sortedPrices) {
    final middle = sortedPrices.length ~/ 2;
    if (sortedPrices.length.isOdd) {
      return sortedPrices[middle];
    }

    final lower = sortedPrices[middle - 1];
    final upper = sortedPrices[middle];
    return ((lower + upper) / 2).round();
  }
}
