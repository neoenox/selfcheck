import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/correct_price_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Issue #90 unit: invalid corrections (out-of-range, tax-excluded) are
/// rejected and leave the stored history untouched.
void main() {
  group('CorrectPriceUseCase validation (issue #90)', () {
    late PriceRepository repository;
    late CorrectPriceUseCase useCase;

    setUp(() async {
      repository = await createTestRepository();
      useCase = CorrectPriceUseCase(repository);
    });

    tearDown(() {
      repository.dispose();
    });

    Future<String> seedOneObservation() async {
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );
      final observation = await repository.insertObservation(
        productId: product.id,
        priceYen: 500,
        priceConfidence: 0.9,
      );
      return observation.id;
    }

    Future<int> validCountFor(String observationId) async {
      final row = await repository.findObservationById(observationId);
      final observations = await repository.getValidObservations(
        productId: row!.productId,
        since: DateTime.now().subtract(const Duration(days: 180)),
        limit: 12,
      );
      return observations.length;
    }

    test('rejects zero price without touching history', () async {
      final id = await seedOneObservation();
      await expectLater(
        () => useCase.correct(
          observationId: id,
          correctedPriceYen: 0,
          isTaxInclusive: true,
        ),
        throwsArgumentError,
      );
      expect((await repository.findObservationById(id))!.isValid, isTrue);
      expect(await validCountFor(id), 1);
    });

    test('rejects price above 99,999 without touching history', () async {
      final id = await seedOneObservation();
      await expectLater(
        () => useCase.correct(
          observationId: id,
          correctedPriceYen: 100000,
          isTaxInclusive: true,
        ),
        throwsArgumentError,
      );
      expect((await repository.findObservationById(id))!.isValid, isTrue);
      expect(await validCountFor(id), 1);
    });

    test('rejects tax-excluded correction without touching history', () async {
      final id = await seedOneObservation();
      await expectLater(
        () => useCase.correct(
          observationId: id,
          correctedPriceYen: 450,
          isTaxInclusive: false,
        ),
        throwsArgumentError,
      );
      expect((await repository.findObservationById(id))!.isValid, isTrue);
      expect(await validCountFor(id), 1);
    });
  });
}
