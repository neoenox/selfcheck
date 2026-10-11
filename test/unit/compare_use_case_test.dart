import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';

/// Insert N observations spaced 6 minutes apart to avoid duplicateKey collisions.
Future<void> insertObservationsSpaced(
  PriceRepository repo, {
  required String productId,
  required List<int> prices,
  double confidence = 0.9,
}) async {
  final baseTime = DateTime.now().subtract(
    Duration(minutes: prices.length * 6),
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
  group('CompareUseCase', () {
    late CompareUseCase useCase;
    late PriceRepository repository;

    setUp(() async {
      repository = await createTestRepository();
      useCase = CompareUseCase(repository);
    });

    tearDown(() {
      repository.dispose();
    });

    group('compare', () {
      test(
        'firstPrice - returns firstPrice status when no observations',
        () async {
          final product = await repository.createProvisionalProduct(
            '4901234567890',
          );

          final result = await useCase.compare(
            currentPriceYen: 500,
            productId: product.id,
            currentConfidence: 0.95,
          );

          expect(result.status, domain.ComparisonStatus.firstPrice);
          expect(result.currentPrice, 500);
        },
      );

      test(
        'historyShort - returns historyShort when 1-2 observations',
        () async {
          final product = await repository.createProvisionalProduct(
            '4901234567890',
          );

          await repository.insertObservation(
            productId: product.id,
            priceYen: 500,
            priceConfidence: 0.9,
          );

          final result = await useCase.compare(
            currentPriceYen: 500,
            productId: product.id,
            currentConfidence: 0.95,
          );

          expect(result.status, domain.ComparisonStatus.historyShort);
        },
      );

      test(
        'withBaseline - returns withBaseline when 3+ observations',
        () async {
          final product = await repository.createProvisionalProduct(
            '4901234567890',
          );

          for (var i = 0; i < 3; i++) {
            await repository.insertObservation(
              productId: product.id,
              priceYen: 500 + i * 10,
              priceConfidence: 0.9,
            );
          }

          final result = await useCase.compare(
            currentPriceYen: 500,
            productId: product.id,
            currentConfidence: 0.95,
          );

          expect(result.status, domain.ComparisonStatus.withBaseline);
          expect(result.baselineMedianYen, isNotNull);
          expect(result.label, isNotNull);
        },
      );

      test('even-count median averages the two center values', () async {
        final product = await repository.createProvisionalProduct(
          'EVEN_MEDIAN',
        );
        await insertObservationsSpaced(
          repository,
          productId: product.id,
          prices: [100, 200, 800, 900],
        );

        final result = await useCase.compare(
          currentPriceYen: 600,
          productId: product.id,
          currentConfidence: 0.95,
        );

        expect(result.status, domain.ComparisonStatus.withBaseline);
        expect(result.baselineMedianYen, 500);
        expect(result.diffYen, 100);
        expect(result.diffRate, closeTo(0.2, 0.000001));
        expect(result.label, domain.ComparisonLabel.expensive);
      });

      test('half-yen median rounds to the nearest whole yen', () async {
        final product = await repository.createProvisionalProduct(
          'HALF_MEDIAN',
        );
        await insertObservationsSpaced(
          repository,
          productId: product.id,
          prices: [100, 100, 101, 101],
        );

        final result = await useCase.compare(
          currentPriceYen: 101,
          productId: product.id,
          currentConfidence: 0.95,
        );

        expect(result.baselineMedianYen, 101);
      });

      test('inserts new observation by default', () async {
        final product = await repository.createProvisionalProduct(
          '4901234567890',
        );

        await useCase.compare(
          currentPriceYen: 500,
          productId: product.id,
          currentConfidence: 0.95,
        );

        final observations = await repository.getValidObservations(
          productId: product.id,
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 10,
        );

        expect(observations.length, 1);
        expect(observations.first.priceYen, 500);
      });

      test('skipInsert=true does NOT save a new observation', () async {
        final product = await repository.createProvisionalProduct(
          '4901234567890',
        );

        await insertObservationsSpaced(
          repository,
          productId: product.id,
          prices: [500, 500, 500],
        );

        final countBefore = (await repository.getValidObservations(
          productId: product.id,
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 10,
        )).length;

        final result = await useCase.compare(
          currentPriceYen: 500,
          productId: product.id,
          currentConfidence: 0.95,
          skipInsert: true,
        );

        final countAfter = (await repository.getValidObservations(
          productId: product.id,
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 10,
        )).length;

        expect(countAfter, countBefore);
        expect(countAfter, 3);
        expect(result.status, domain.ComparisonStatus.withBaseline);
        expect(result.observationCount, 3);
      });

      test('skipInsert=true still returns correct comparison', () async {
        final product = await repository.createProvisionalProduct(
          '4901234567890',
        );

        await insertObservationsSpaced(
          repository,
          productId: product.id,
          prices: [500, 500, 500, 500, 500],
        );

        final result = await useCase.compare(
          currentPriceYen: 450,
          productId: product.id,
          currentConfidence: 0.95,
          skipInsert: true,
        );

        expect(result.status, domain.ComparisonStatus.withBaseline);
        expect(result.baselineMedianYen, 500);
        expect(result.diffYen, -50);
        expect(result.label, domain.ComparisonLabel.veryCheap);
      });

      test(
        'does not insert when the session is cancelled before saving',
        () async {
          final product = await repository.createProvisionalProduct(
            'CANCEL_BEFORE_INSERT',
          );
          final observationsReady = Completer<void>();
          final gatedRepository = _GatedObservationsRepository(
            repository,
            observationsReady,
          );
          var sessionIsActive = true;

          final comparison = CompareUseCase(gatedRepository).compare(
            currentPriceYen: 500,
            productId: product.id,
            currentConfidence: 0.95,
            isSessionValid: () => sessionIsActive,
          );

          await Future<void>.delayed(Duration.zero);
          sessionIsActive = false;
          observationsReady.complete();
          await expectLater(
            comparison,
            throwsA(isA<ComparisonCancelledException>()),
          );

          final observations = await repository.getValidObservations(
            productId: product.id,
            since: DateTime.now().subtract(const Duration(days: 30)),
            limit: 10,
          );
          expect(observations, isEmpty);
        },
      );
    });
  });

  group('ComparisonResult', () {
    test('firstPrice creates result with correct values', () {
      final result = domain.ComparisonResult.firstPrice(500);
      expect(result.status, domain.ComparisonStatus.firstPrice);
      expect(result.currentPrice, 500);
      expect(result.observationCount, 0);
    });

    test('historyShort creates result with correct values', () {
      final result = domain.ComparisonResult.historyShort(
        currentPrice: 550,
        lastPrice: 500,
        observationCount: 2,
      );
      expect(result.status, domain.ComparisonStatus.historyShort);
      expect(result.observationCount, 2);
    });

    test('withBaseline creates result with correct values', () {
      final result = domain.ComparisonResult.withBaseline(
        currentPrice: 550,
        baselineMedianYen: 500,
        diffYen: 50,
        diffRate: 0.1,
        label: domain.ComparisonLabel.slightlyExpensive,
        observationCount: 5,
      );
      expect(result.status, domain.ComparisonStatus.withBaseline);
      expect(result.baselineMedianYen, 500);
      expect(result.label, domain.ComparisonLabel.slightlyExpensive);
    });
  });

  group('ComparisonPolicy', () {
    test('labelForDiffRate returns correct labels', () {
      expect(
        domain.ComparisonPolicy.labelForDiffRate(-0.15),
        domain.ComparisonLabel.veryCheap,
      );
      expect(
        domain.ComparisonPolicy.labelForDiffRate(-0.08),
        domain.ComparisonLabel.cheap,
      );
      expect(
        domain.ComparisonPolicy.labelForDiffRate(0.0),
        domain.ComparisonLabel.normal,
      );
      expect(
        domain.ComparisonPolicy.labelForDiffRate(0.08),
        domain.ComparisonLabel.slightlyExpensive,
      );
      expect(
        domain.ComparisonPolicy.labelForDiffRate(0.15),
        domain.ComparisonLabel.expensive,
      );
    });
  });
}

class _GatedObservationsRepository implements PriceRepository {
  _GatedObservationsRepository(this._delegate, this._observationsReady);

  final PriceRepository _delegate;
  final Completer<void> _observationsReady;

  @override
  Future<ProductIdentity?> findProductByJan(String jan) =>
      _delegate.findProductByJan(jan);

  @override
  Future<ProductIdentity> createProvisionalProduct(String jan) =>
      _delegate.createProvisionalProduct(jan);

  @override
  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  }) async {
    final observations = await _delegate.getValidObservations(
      productId: productId,
      since: since,
      limit: limit,
    );
    await _observationsReady.future;
    return observations;
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
  }) => _delegate.insertObservation(
    productId: productId,
    priceYen: priceYen,
    priceConfidence: priceConfidence,
    isSaleVisible: isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount,
    isManualEntry: isManualEntry,
  );

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) => _delegate.isDuplicate(
    productId: productId,
    priceYen: priceYen,
    observedAt: observedAt,
  );

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
  }) => _delegate.insertObservationWithDate(
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

  @override
  void dispose() {}
}
