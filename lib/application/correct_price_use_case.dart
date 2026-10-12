import '../infrastructure/database/app_database.dart';
import '../infrastructure/price_repository.dart';

/// CorrectPriceUseCase - correct an already-saved price (issue #90).
///
/// Validation mirrors manual entry rules: amounts must be 1–99,999 yen and
/// tax-inclusive only. Tax-exclusive amounts cannot be converted without a
/// known rate, so they are rejected rather than saved. Invalid input throws
/// [ArgumentError] before touching stored history.
class CorrectPriceUseCase {
  final PriceRepository _repository;

  CorrectPriceUseCase(this._repository);

  Future<PriceObservation> correct({
    required String observationId,
    required int correctedPriceYen,
    required bool isTaxInclusive,
    double priceConfidence = 1.0,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
    DateTime? correctedAt,
  }) async {
    if (correctedPriceYen < 1 || correctedPriceYen > 99999) {
      throw ArgumentError.value(
        correctedPriceYen,
        'correctedPriceYen',
        'Must be 1-99,999 yen',
      );
    }
    if (!isTaxInclusive) {
      throw ArgumentError.value(
        isTaxInclusive,
        'isTaxInclusive',
        'Tax-exclusive corrections cannot be saved',
      );
    }

    return _repository.correctObservation(
      observationId: observationId,
      correctedPriceYen: correctedPriceYen,
      priceConfidence: priceConfidence,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
      isManualEntry: isManualEntry,
      correctedAt: correctedAt,
    );
  }
}
