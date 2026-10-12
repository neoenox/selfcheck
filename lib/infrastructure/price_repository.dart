import 'database/app_database.dart';

/// PriceRepository interface for price observation storage
abstract class PriceRepository {
  Future<ProductIdentity?> findProductByJan(String jan);
  Future<ProductIdentity> createProvisionalProduct(String jan);
  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  });
  Future<PriceObservation> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  });
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  });

  /// Insert an observation with a specific observedAt date.
  /// Use for testing time-window filtering with past dates.
  Future<PriceObservation> insertObservationWithDate({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  });

  /// Retire an observation without deleting it (audit history is kept).
  /// Retiring frees the duplicate slot so a corrected observation for the
  /// same bucket can be stored.
  Future<void> invalidateObservation(String id);

  /// Atomically replace the observation [oldId] with corrected values.
  /// Either both the retirement and the insert happen, or neither does.
  Future<PriceObservation> replaceObservation({
    required String oldId,
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  });

  void dispose();
}
