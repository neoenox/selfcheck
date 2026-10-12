import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// ProductIdentity table - JAN/GTIN as primary identifier
///
/// Drift generates ProductIdentity data class from this table definition.
class ProductIdentitys extends Table {
  @override
  String get tableName => 'product_identity';

  TextColumn get id => text()();
  TextColumn get jan => text().unique()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// PriceObservation table - price records with context booleans
///
/// Drift generates PriceObservation data class from this table definition.
/// Includes v0.2 price context booleans for future extensibility.
class PriceObservations extends Table {
  @override
  String get tableName => 'price_observation';

  TextColumn get id => text()();
  TextColumn get productId => text().references(ProductIdentitys, #id)();
  IntColumn get priceYen => integer()();
  DateTimeColumn get observedAt => dateTime()();
  RealColumn get priceConfidence => real()();
  BoolColumn get isValid => boolean().withDefault(const Constant(true))();
  TextColumn get duplicateKey => text()();

  // v0.2 price context booleans (nullable for future extensibility)
  BoolColumn get isSaleVisible => boolean().nullable()();
  BoolColumn get isMemberPriceVisible => boolean().nullable()();
  BoolColumn get isCouponPriceVisible => boolean().nullable()();
  BoolColumn get isBulkDiscount => boolean().nullable()();

  /// True when the price was entered manually by the user instead of OCR.
  /// Null for observations recorded before manual entry existed.
  BoolColumn get isManualEntry => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {duplicateKey},
  ];
}

@DriftDatabase(tables: [ProductIdentitys, PriceObservations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA user_version = 3;');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS product_stats;');

        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_sale_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_member_price_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_coupon_price_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_bulk_discount INTEGER DEFAULT NULL;',
        );

        await customStatement('PRAGMA user_version = 2;');
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_manual_entry INTEGER DEFAULT NULL;',
        );

        await customStatement('PRAGMA user_version = 3;');
      }
    },
    beforeOpen: (details) async {
      // SQLite does not enforce declared foreign keys unless explicitly enabled
      // on every connection. Keep the existing schema/data intact and reject new
      // orphan observations from this point forward.
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  // ========== ProductIdentity CRUD ==========

  Future<ProductIdentity?> findProductByJan(String jan) async {
    return (select(
      productIdentitys,
    )..where((t) => t.jan.equals(jan))).getSingleOrNull();
  }

  Future<ProductIdentity> insertProvisionalProduct(String jan) async {
    final now = DateTime.now();
    final id = 'prod-$jan-${now.microsecondsSinceEpoch}';

    final entity = ProductIdentitysCompanion.insert(
      id: id,
      jan: jan,
      createdAt: now,
      updatedAt: now,
    );

    await into(productIdentitys).insert(entity);

    return ProductIdentity(id: id, jan: jan, createdAt: now, updatedAt: now);
  }

  Future<void> updateProductDisplayName(String id, String name) async {
    await (update(productIdentitys)..where((t) => t.id.equals(id))).write(
      ProductIdentitysCompanion(
        displayName: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ========== PriceObservation CRUD ==========

  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
    bool excludeCurrent = false,
  }) async {
    final query = select(priceObservations)
      ..where((t) => t.productId.equals(productId))
      ..where((t) => t.isValid.equals(true))
      ..where((t) => t.observedAt.isBiggerThanValue(since))
      ..orderBy([(t) => OrderingTerm.desc(t.observedAt)])
      ..limit(limit);

    return await query.get();
  }

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
    final now = DateTime.now();
    return _insertObservation(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      observedAt: now,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
      isManualEntry: isManualEntry,
    );
  }

  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async {
    final windowStart = observedAt.subtract(const Duration(minutes: 5));

    // A duplicate window is relative to the candidate observation time, not to
    // fixed wall-clock buckets. This catches boundary cases such as 10:04:59 ->
    // 10:05:01 while still ignoring future observations when historical test
    // data is inserted out of chronological order.
    final duplicate =
        await (select(priceObservations)
              ..where((t) => t.productId.equals(productId))
              ..where((t) => t.priceYen.equals(priceYen))
              ..where((t) => t.isValid.equals(true))
              ..where((t) => t.observedAt.isBiggerOrEqualValue(windowStart))
              ..where((t) => t.observedAt.isSmallerOrEqualValue(observedAt))
              ..orderBy([(t) => OrderingTerm.desc(t.observedAt)])
              ..limit(1))
            .getSingleOrNull();

    return duplicate != null;
  }

  Future<void> invalidateObservation(String id) async {
    final observation = await (select(
      priceObservations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (observation == null || !observation.isValid) return;

    // Retain the invalid row for audit/history while freeing the active unique
    // duplicate slot so a corrected observation can be stored in the same
    // five-minute bucket. Including the immutable row id keeps this idempotent
    // and collision-resistant without a schema migration.
    final retiredDuplicateKey =
        '${observation.duplicateKey}:invalid:${observation.id}';
    await (update(priceObservations)..where((t) => t.id.equals(id))).write(
      PriceObservationsCompanion(
        isValid: const Value(false),
        duplicateKey: Value(retiredDuplicateKey),
      ),
    );
  }

  Future<PriceObservation?> findObservationById(String id) async {
    return (select(
      priceObservations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Correct an already-saved observation (issue #90).
  ///
  /// Invalidates the original row (kept for audit, never hard-deleted) and
  /// inserts the corrected amount+type as a new valid row. The retired
  /// duplicate slot is freed by [invalidateObservation] so the correction can
  /// reuse the same five-minute bucket. Throws [StateError] when the target
  /// is missing or already invalid.
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
  }) async {
    return transaction(() async {
      final original = await (select(
        priceObservations,
      )..where((t) => t.id.equals(observationId))).getSingleOrNull();
      if (original == null) {
        throw StateError('Price observation not found: $observationId');
      }
      if (!original.isValid) {
        throw StateError('Price observation already invalid: $observationId');
      }

      await invalidateObservation(observationId);

      var observedAt = correctedAt ?? DateTime.now();
      // Guard the derived row id against colliding with the retained
      // original when the same price is re-saved at the same instant.
      if (correctedPriceYen == original.priceYen &&
          observedAt.microsecondsSinceEpoch ==
              original.observedAt.microsecondsSinceEpoch) {
        observedAt = observedAt.add(const Duration(microseconds: 1));
      }

      return _insertObservation(
        productId: original.productId,
        priceYen: correctedPriceYen,
        priceConfidence: priceConfidence,
        observedAt: observedAt,
        isSaleVisible: isSaleVisible,
        isMemberPriceVisible: isMemberPriceVisible,
        isCouponPriceVisible: isCouponPriceVisible,
        isBulkDiscount: isBulkDiscount,
        isManualEntry: isManualEntry,
        strict: true,
      );
    });
  }

  /// Insert an observation with a specific observedAt date (for testing).
  /// Allows creating observations in the past to test time-window filtering.
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
    return _insertObservation(
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

  Future<PriceObservation> _insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
    bool? isManualEntry,
    bool strict = false,
  }) async {
    final id = 'obs-$productId-${observedAt.microsecondsSinceEpoch}-$priceYen';
    final duplicateKey =
        '$productId:$priceYen:${observedAt.millisecondsSinceEpoch ~/ (5 * 60 * 1000)}';

    final entity = PriceObservationsCompanion.insert(
      id: id,
      productId: productId,
      priceYen: priceYen,
      observedAt: observedAt,
      priceConfidence: priceConfidence,
      duplicateKey: duplicateKey,
      isSaleVisible: Value(isSaleVisible),
      isMemberPriceVisible: Value(isMemberPriceVisible),
      isCouponPriceVisible: Value(isCouponPriceVisible),
      isBulkDiscount: Value(isBulkDiscount),
      isManualEntry: Value(isManualEntry),
    );

    // duplicateKey remains a last-resort same-bucket concurrency guard. The
    // production duplicate decision is the rolling-window query in isDuplicate.
    // Any other constraint failure must not be reported as a successful insert.
    // Correction (strict:true, issue #90) uses abort-on-conflict plus a
    // primary-key lookup: looking a correction up by bucketed duplicateKey
    // could silently return a different valid row sharing the same bucket,
    // committing with the original already invalidated. Any conflict must
    // throw so the surrounding correction transaction rolls back. Normal
    // inserts keep the tolerant insertOrIgnore behaviour relied on by
    // CompareUseCase duplicate flows.
    if (strict) {
      await into(priceObservations).insert(entity);

      final persisted = await (select(
        priceObservations,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (persisted == null) {
        throw StateError('Price observation insert was not persisted');
      }
      return persisted;
    }

    await into(
      priceObservations,
    ).insert(entity, mode: InsertMode.insertOrIgnore);

    final persisted = await (select(
      priceObservations,
    )..where((t) => t.duplicateKey.equals(duplicateKey))).getSingleOrNull();
    if (persisted == null) {
      throw StateError('Price observation insert was not persisted');
    }
    return persisted;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'selfcheck.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
