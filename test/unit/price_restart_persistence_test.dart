import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Restart persistence: observations saved to the file-backed database must
/// still match after the database is closed and reopened (app restart).
void main() {
  group('Restart persistence', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('selfcheck_restart');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    PriceRepositoryImpl openRepository() {
      final file = File('${tempDir.path}/selfcheck.sqlite');
      return PriceRepositoryImpl(AppDatabase.forTesting(NativeDatabase(file)));
    }

    test('saved observations survive close and reopen', () async {
      const jan = '4901234567890';

      final firstSession = openRepository();
      final product = await firstSession.createProvisionalProduct(jan);
      await firstSession.insertObservation(
        productId: product.id,
        priceYen: 398,
        priceConfidence: 0.9,
      );
      firstSession.dispose();

      final secondSession = openRepository();
      addTearDown(secondSession.dispose);

      final reopened = await secondSession.findProductByJan(jan);
      expect(reopened, isNotNull);
      expect(reopened!.id, product.id);

      final observations = await secondSession.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        limit: 10,
      );
      expect(observations.map((o) => o.priceYen), [398]);
      expect(observations.single.priceConfidence, 0.9);
    });

    test('manual flags survive close and reopen', () async {
      const jan = '4901234567891';

      final firstSession = openRepository();
      final product = await firstSession.createProvisionalProduct(jan);
      await firstSession.insertObservation(
        productId: product.id,
        priceYen: 350,
        // B案 manual confidence (below the OCR range).
        priceConfidence: 0.5,
        isSaleVisible: true,
        isManualEntry: true,
      );
      firstSession.dispose();

      final secondSession = openRepository();
      addTearDown(secondSession.dispose);

      final observations = await secondSession.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        limit: 10,
      );
      expect(observations, hasLength(1));
      expect(observations.single.priceYen, 350);
      expect(observations.single.priceConfidence, 0.5);
      expect(observations.single.isSaleVisible, isTrue);
      expect(observations.single.isManualEntry, isTrue);
      expect(observations.single.isMemberPriceVisible, isNull);
    });
  });
}
