import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/correct_price_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Issue #90 integration: history counts and median before/after correction.
///
/// Seeds three spaced observations, corrects one amount+type, then verifies:
/// the invalidated row is retained for audit, valid count is unchanged,
/// and the median is recomputed from the corrected set.
Future<void> insertObservationsSpaced(
  PriceRepository repo, {
  required String productId,
  required List<int> prices,
  double confidence = 0.9,
}) async {
  final baseTime = DateTime.now().subtract(
    Duration(minutes: prices.length * 6 + 30),
  );
  for (var i = 0; i < prices.length; i++) {
    await repo.insertObservationWithDate(
      productId: productId,
      priceYen: prices[i],
      priceConfidence: confidence,
      observedAt: baseTime.add(Duration(minutes: i * 6)),
    );
  }
}

void main() {
  group('price correction history (issue #90)', () {
    late PriceRepository repository;
    late CorrectPriceUseCase correctUseCase;
    late CompareUseCase compareUseCase;

    setUp(() async {
      repository = await createTestRepository();
      correctUseCase = CorrectPriceUseCase(repository);
      compareUseCase = CompareUseCase(repository);
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'correction keeps audit row, preserves valid count, recomputes median',
      () async {
        final product = await repository.createProvisionalProduct(
          '4901234567890',
        );
        await insertObservationsSpaced(
          repository,
          productId: product.id,
          prices: [100, 200, 300],
        );

        Future<List<int>> validPrices() async {
          final observations = await repository.getValidObservations(
            productId: product.id,
            since: DateTime.now().subtract(const Duration(days: 180)),
            limit: 12,
          );
          final prices = observations.map((o) => o.priceYen).toList()
            ..sort();
          return prices;
        }

        expect(await validPrices(), [100, 200, 300]);

        final before = await compareUseCase.compare(
          currentPriceYen: 250,
          productId: product.id,
          currentConfidence: 0.9,
          skipInsert: true,
        );
        expect(before.baselineMedianYen, 200);

        final target = (await repository.getValidObservations(
          productId: product.id,
          since: DateTime.now().subtract(const Duration(days: 180)),
          limit: 12,
        )).singleWhere((o) => o.priceYen == 100);

        final corrected = await correctUseCase.correct(
          observationId: target.id,
          correctedPriceYen: 1000,
          isTaxInclusive: true,
          isSaleVisible: true,
        );

        expect(corrected.priceYen, 1000);
        expect(corrected.productId, product.id);
        expect(corrected.isValid, isTrue);
        expect(corrected.isSaleVisible, isTrue);

        // Audit: the old row still exists but is invalid.
        final oldRow = await repository.findObservationById(target.id);
        expect(oldRow, isNotNull);
        expect(oldRow!.isValid, isFalse);

        // Valid count unchanged (3 before, 3 after); invalid row excluded.
        expect(await validPrices(), [200, 300, 1000]);

        final after = await compareUseCase.compare(
          currentPriceYen: 250,
          productId: product.id,
          currentConfidence: 0.9,
          skipInsert: true,
        );
        expect(after.baselineMedianYen, 300);

        // Duplicate prevention still correct: the retired price no longer
        // counts, the corrected price does.
        expect(
          await repository.isDuplicate(
            productId: product.id,
            priceYen: 100,
            observedAt: DateTime.now(),
          ),
          isFalse,
        );
        expect(
          await repository.isDuplicate(
            productId: product.id,
            priceYen: 1000,
            observedAt: DateTime.now(),
          ),
          isTrue,
        );
      },
    );
  });
}
