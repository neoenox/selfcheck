import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Schema upgrade: a v2-shaped database (without is_manual_entry) must
/// upgrade to v3 preserving existing observations.
void main() {
  group('Database migration v2 to v3', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('selfcheck_migrate');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('legacy observations survive the manual-entry upgrade', () async {
      const jan = '4901234567890';
      final file = File('${tempDir.path}/selfcheck.sqlite');

      // Session 1: create production-shaped data, then reshape the file to
      // the v2 schema (drop the new column, reset the version marker).
      final setup = AppDatabase.forTesting(NativeDatabase(file));
      final setupRepo = PriceRepositoryImpl(setup);
      final product = await setupRepo.createProvisionalProduct(jan);
      await setupRepo.insertObservation(
        productId: product.id,
        priceYen: 398,
        priceConfidence: 0.9,
      );
      await setup.customStatement(
        'ALTER TABLE price_observation DROP COLUMN is_manual_entry;',
      );
      await setup.customStatement('PRAGMA user_version = 2;');
      setup.close();

      // Session 2: reopening runs onUpgrade from version 2.
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      final upgradedRepo = PriceRepositoryImpl(upgraded);

      final versionRow = await upgraded
          .customSelect('PRAGMA user_version;')
          .getSingle();
      expect(versionRow.data.values.single, 3);

      final found = await upgradedRepo.findProductByJan(jan);
      expect(found, isNotNull);
      final observations = await upgradedRepo.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        limit: 10,
      );
      expect(observations.map((o) => o.priceYen), [398]);
      expect(observations.single.isManualEntry, isNull);

      // New manual entries record into the upgraded schema.
      await upgradedRepo.insertObservation(
        productId: product.id,
        priceYen: 350,
        priceConfidence: 1.0,
        isSaleVisible: true,
        isManualEntry: true,
      );
      final after = await upgradedRepo.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        limit: 10,
      );
      expect(after.map((o) => o.priceYen).toSet(), {398, 350});
      expect(
        after.where((o) => o.priceYen == 350).single.isManualEntry,
        isTrue,
      );
    });
  });
}
