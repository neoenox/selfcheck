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

  Future<PriceObservation?> findObservationById(String id);

  /// Correct an already-saved observation: invalidate the old row (kept for
  /// audit) and save the corrected amount+type as a new valid row.
  Future<PriceObservation> correctObservation({
    required String observationId,
    required int correctedPriceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
    DateTime? correctedAt,
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

  void dispose();
}
