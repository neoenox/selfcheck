import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/correct_price_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Issue #90 regression: atomicity, re-correction, boundaries, isolation.
void main() {
  group('price correction regression (issue #90)', () {
    late PriceRepository repository;
    late CorrectPriceUseCase useCase;
    late CompareUseCase compareUseCase;

    setUp(() async {
      repository = await createTestRepository();
      useCase = CorrectPriceUseCase(repository);
      compareUseCase = CompareUseCase(repository);
    });

    tearDown(() {
      repository.dispose();
    });

    int bucketOf(DateTime t) => t.millisecondsSinceEpoch ~/ (5 * 60 * 1000);

    Future<List<int>> validPrices(String productId) async {
      final observations = await repository.getValidObservations(
        productId: productId,
        since: DateTime.now().subtract(const Duration(days: 180)),
        limit: 12,
      );
      final prices = observations.map((o) => o.priceYen).toList()..sort();
      return prices;
    }

    test(
      'bucket collision correction fails atomically, preserving original',
      () async {
        final product = await repository.createProvisionalProduct(
          '4909999999999',
        );
        var base = DateTime(2026, 1, 1, 10, 2);
        while (bucketOf(base) !=
            bucketOf(base.add(const Duration(minutes: 2)))) {
          base = base.add(const Duration(minutes: 1));
        }
        final atA = base;
        final atB = base.add(const Duration(minutes: 1));
        final atCorr = base.add(const Duration(minutes: 2));
        expect(bucketOf(atA), bucketOf(atB));
        expect(bucketOf(atB), bucketOf(atCorr));

        final obsA = await repository.insertObservationWithDate(
          productId: product.id,
          priceYen: 500,
          priceConfidence: 0.9,
          observedAt: atA,
        );
        final obsB = await repository.insertObservationWithDate(
          productId: product.id,
          priceYen: 600,
          priceConfidence: 0.9,
          observedAt: atB,
        );

        await expectLater(
          () => useCase.correct(
            observationId: obsA.id,
            correctedPriceYen: 600,
            isTaxInclusive: true,
            correctedAt: atCorr,
          ),
          throwsA(isA<Exception>()),
        );

        final aAfter = await repository.findObservationById(obsA.id);
        expect(aAfter, isNotNull);
        expect(aAfter!.isValid, isTrue);
        final bAfter = await repository.findObservationById(obsB.id);
        expect(bAfter, isNotNull);
        expect(bAfter!.isValid, isTrue);
        // Fixed 2026-01-01 fixtures predate the default 180-day window, so
        // query with a wide window covering the fixtures.
        final valid = await repository.getValidObservations(
          productId: product.id,
          since: atA.subtract(const Duration(days: 1)),
          limit: 12,
        );
        final prices = valid.map((o) => o.priceYen).toList()..sort();
        expect(prices, [500, 600]);
      },
    );

    test('re-correcting same observation fails without side effects', () async {
      final product = await repository.createProvisionalProduct(
        '4901111111111',
      );
      final obs = await repository.insertObservation(
        productId: product.id,
        priceYen: 500,
        priceConfidence: 0.9,
      );

      final corrected = await useCase.correct(
        observationId: obs.id,
        correctedPriceYen: 600,
        isTaxInclusive: true,
      );
      expect(corrected.priceYen, 600);

      await expectLater(
        () => useCase.correct(
          observationId: obs.id,
          correctedPriceYen: 700,
          isTaxInclusive: true,
        ),
        throwsA(isA<StateError>()),
      );

      expect((await repository.findObservationById(obs.id))!.isValid, isFalse);
      expect(
        (await repository.findObservationById(corrected.id))!.isValid,
        isTrue,
      );
      expect(await validPrices(product.id), [600]);
    });

    test('consecutive corrections chain preserves count and median', () async {
      final product = await repository.createProvisionalProduct(
        '4902222222222',
      );
      final baseTime = DateTime.now().subtract(const Duration(minutes: 48));
      for (var i = 0; i < 3; i++) {
        await repository.insertObservationWithDate(
          productId: product.id,
          priceYen: [100, 200, 300][i],
          priceConfidence: 0.9,
          observedAt: baseTime.add(Duration(minutes: i * 6)),
        );
      }
      expect(await validPrices(product.id), [100, 200, 300]);

      final target = (await repository.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(days: 180)),
        limit: 12,
      )).singleWhere((o) => o.priceYen == 100);

      final first = await useCase.correct(
        observationId: target.id,
        correctedPriceYen: 1000,
        isTaxInclusive: true,
      );
      expect(await validPrices(product.id), [200, 300, 1000]);

      final second = await useCase.correct(
        observationId: first.id,
        correctedPriceYen: 150,
        isTaxInclusive: true,
      );
      expect(second.priceYen, 150);
      expect(await validPrices(product.id), [150, 200, 300]);

      expect(
        (await repository.findObservationById(target.id))!.isValid,
        isFalse,
      );
      expect(
        (await repository.findObservationById(first.id))!.isValid,
        isFalse,
      );
      expect(
        (await repository.findObservationById(second.id))!.isValid,
        isTrue,
      );

      final after = await compareUseCase.compare(
        currentPriceYen: 250,
        productId: product.id,
        currentConfidence: 0.9,
        skipInsert: true,
      );
      expect(after.baselineMedianYen, 200);
    });

    test('correcting missing id throws and leaves history unchanged', () async {
      final product = await repository.createProvisionalProduct(
        '4903333333333',
      );
      final obs = await repository.insertObservation(
        productId: product.id,
        priceYen: 500,
        priceConfidence: 0.9,
      );

      await expectLater(
        () => useCase.correct(
          observationId: 'non-existent-id',
          correctedPriceYen: 600,
          isTaxInclusive: true,
        ),
        throwsA(isA<StateError>()),
      );

      expect((await repository.findObservationById(obs.id))!.isValid, isTrue);
      expect(await validPrices(product.id), [500]);
    });

    test('boundary prices 1 and 99999 are accepted', () async {
      final product = await repository.createProvisionalProduct(
        '4904444444444',
      );
      final obsLow = await repository.insertObservation(
        productId: product.id,
        priceYen: 500,
        priceConfidence: 0.9,
      );
      final low = await useCase.correct(
        observationId: obsLow.id,
        correctedPriceYen: 1,
        isTaxInclusive: true,
      );
      expect(low.priceYen, 1);

      final obsHigh = await repository.insertObservation(
        productId: product.id,
        priceYen: 600,
        priceConfidence: 0.9,
      );
      final high = await useCase.correct(
        observationId: obsHigh.id,
        correctedPriceYen: 99999,
        isTaxInclusive: true,
      );
      expect(high.priceYen, 99999);
    });

    test('negative price rejected without touching history', () async {
      final product = await repository.createProvisionalProduct(
        '4905555555555',
      );
      final obs = await repository.insertObservation(
        productId: product.id,
        priceYen: 500,
        priceConfidence: 0.9,
      );

      await expectLater(
        () => useCase.correct(
          observationId: obs.id,
          correctedPriceYen: -5,
          isTaxInclusive: true,
        ),
        throwsArgumentError,
      );
      expect((await repository.findObservationById(obs.id))!.isValid, isTrue);
      expect(await validPrices(product.id), [500]);
    });

    test(
      'correction preserves product and leaves other product untouched',
      () async {
        final productA = await repository.createProvisionalProduct('JAN_A_REG');
        final productB = await repository.createProvisionalProduct('JAN_B_REG');
        final obsA = await repository.insertObservation(
          productId: productA.id,
          priceYen: 500,
          priceConfidence: 0.9,
        );
        await repository.insertObservation(
          productId: productB.id,
          priceYen: 800,
          priceConfidence: 0.9,
        );

        final corrected = await useCase.correct(
          observationId: obsA.id,
          correctedPriceYen: 700,
          isTaxInclusive: true,
        );

        expect(corrected.productId, productA.id);
        expect(await validPrices(productA.id), [700]);
        expect(await validPrices(productB.id), [800]);
      },
    );

    test('corrected history survives close and reopen (restart)', () async {
      final dir = await Directory.systemTemp.createTemp('sc90-restart-');
      final file = File('${dir.path}/selfcheck.sqlite');
      try {
        final db1 = AppDatabase.forTesting(
          NativeDatabase.createInBackground(file),
        );
        final repo1 = PriceRepositoryImpl(db1);
        final useCase1 = CorrectPriceUseCase(repo1);
        final product = await repo1.createProvisionalProduct('4906666666666');
        final productId = product.id;
        final obs = await repo1.insertObservation(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.9,
        );
        final corrected = await useCase1.correct(
          observationId: obs.id,
          correctedPriceYen: 650,
          isTaxInclusive: true,
        );
        expect(corrected.priceYen, 650);
        await db1.close();

        final db2 = AppDatabase.forTesting(
          NativeDatabase.createInBackground(file),
        );
        final repo2 = PriceRepositoryImpl(db2);
        try {
          final oldRow = await repo2.findObservationById(obs.id);
          expect(oldRow, isNotNull);
          expect(oldRow!.isValid, isFalse);
          final newRow = await repo2.findObservationById(corrected.id);
          expect(newRow, isNotNull);
          expect(newRow!.isValid, isTrue);
          expect(newRow.priceYen, 650);
          final valid = await repo2.getValidObservations(
            productId: productId,
            since: DateTime.now().subtract(const Duration(days: 180)),
            limit: 12,
          );
          expect(valid.map((o) => o.priceYen).toList(), [650]);
        } finally {
          await db2.close();
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
