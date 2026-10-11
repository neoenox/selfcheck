import 'package:drift/native.dart';
import 'database/app_database.dart';
import 'price_repository.dart';

/// PriceRepository implementation using Drift database
class PriceRepositoryImpl implements PriceRepository {
  final AppDatabase _database;

  PriceRepositoryImpl(this._database);

  @override
  Future<ProductIdentity?> findProductByJan(String jan) async {
    return await _database.findProductByJan(jan);
  }

  @override
  Future<ProductIdentity> createProvisionalProduct(String jan) async {
    return await _database.insertProvisionalProduct(jan);
  }

  @override
  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  }) async {
    return await _database.getValidObservations(
      productId: productId,
      since: since,
      limit: limit,
    );
  }

  @override
  Future<PriceObservation> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
  }) async {
    return await _database.insertObservation(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
      isManualEntry: isManualEntry,
    );
  }

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async {
    return await _database.isDuplicate(
      productId: productId,
      priceYen: priceYen,
      observedAt: observedAt,
    );
  }

  @override
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
  }) async {
    return await _database.insertObservationWithDate(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      observedAt: observedAt,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
      isManualEntry: isManualEntry,
    );
  }

  @override
  Future<void> invalidateObservation(String id) =>
      _database.invalidateObservation(id);

  @override
  void dispose() {
    _database.close();
  }
}

/// Create a PriceRepositoryImpl backed by an in-memory SQLite database.
/// Use this in tests to get the same SQL behavior as production.
Future<PriceRepositoryImpl> createTestRepository() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final now = DateTime.now();

  // AC-05/AC-11 predate foreign-key enforcement and intentionally use stable
  // product IDs to focus on duplicate-window and first-price behavior. Seed
  // only those parent rows in the test-only database so the acceptance tests
  // exercise production FK semantics instead of relying on orphan fixtures.
  for (final fixture in const {
    'prod-1': 'TEST_AC05_PRODUCT_1',
    'prod-2': 'TEST_AC05_PRODUCT_2',
    'brand-new-product': 'TEST_AC11_FIRST_PRICE',
  }.entries) {
    await db
        .into(db.productIdentitys)
        .insert(
          ProductIdentitysCompanion.insert(
            id: fixture.key,
            jan: fixture.value,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  return PriceRepositoryImpl(db);
}
