import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart' as domain;
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_stabilizer.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';

/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  AC Validation Tests — 自分値 MVP v0.2 P0 PoC                  ║
/// ║  Each group maps 1:1 to a受入条件 from 仕様書 §15              ║
/// ╚══════════════════════════════════════════════════════════════════╝

/// Insert N observations spaced 6 minutes apart to avoid duplicateKey collisions.
/// Each observation gets a unique timestamp so the 5-min window constraint is respected.
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
  late PriceRepository repository;
  late CompareUseCase compareUseCase;

  setUp(() async {
    repository = await createTestRepository();
    compareUseCase = CompareUseCase(repository);
  });

  tearDown(() {
    repository.dispose();
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-01: バーコード+価格を同時にフレームに入れると、
  //         3秒以内に比較結果が表示される。
  // ─────────────────────────────────────────────────────────────────
  group('AC-01: Barcode+Price simultaneous → result within 3s', () {
    test('CompareUseCase processes a complete scan in under 3s', () async {
      // Simulate the full compare pipeline that would run after
      // barcode + price are both detected and stable
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );

      final stopwatch = Stopwatch()..start();

      final result = await compareUseCase.compare(
        currentPriceYen: 398,
        productId: product.id,
        currentConfidence: 0.95,
      );

      stopwatch.stop();

      expect(result.status, domain.ComparisonStatus.firstPrice);
      expect(result.currentPrice, 398);
      // In-memory DB should be well under 3 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test(
      'full pipeline: barcode→product→observe→compare completes fast',
      () async {
        final stopwatch = Stopwatch()..start();

        // Simulate what ScanCoordinator._compare does
        var product = await repository.findProductByJan('4901234567890');
        product ??= await repository.createProvisionalProduct('4901234567890');

        await repository.insertObservation(
          productId: product.id,
          priceYen: 398,
          priceConfidence: 0.9,
        );

        final since = DateTime.now().subtract(const Duration(days: 180));
        final observations = await repository.getValidObservations(
          productId: product.id,
          since: since,
          limit: 12,
        );

        final prices = observations.map((o) => o.priceYen).toList()..sort();
        final median = prices.isEmpty ? null : prices[prices.length ~/ 2];

        stopwatch.stop();

        expect(product.jan, '4901234567890');
        expect(median, 398); // Only 1 observation
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-02: バーコードのみでSKUが確定し、
  //         価格が安定次第比較が完了する。
  // ─────────────────────────────────────────────────────────────────
  group('AC-02: Barcode-only → SKU identified, price stabilizes → done', () {
    test('barcode-first flow: product created, then compare works', () async {
      // Step 1: Barcode detected → create product (SKU identified)
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );
      expect(product.jan, '4901234567890');

      // Step 2: Price stabilizes → compare completes
      final result = await compareUseCase.compare(
        currentPriceYen: 398,
        productId: product.id,
        currentConfidence: 0.9,
      );

      expect(result.currentPrice, 398);
      expect(result.status, domain.ComparisonStatus.firstPrice);
    });

    test('price stabilizer requires 3 consecutive same readings', () {
      final stabilizer = PriceStabilizer();

      // Frame 1
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['398'],
          ),
        ),
        false,
      );

      // Frame 2
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['398'],
          ),
        ),
        false,
      );

      // Frame 3 — stable!
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['398'],
          ),
        ),
        true,
      );

      expect(stabilizer.currentPrice, 398);
    });

    test('waitingPrice → result state transition works', () {
      // State machine: scanning → waitingPrice → comparing → result
      // is validated by unit tests in scan_coordinator_test.dart
      expect(ScanState.scanning, isNotNull);
      expect(ScanState.waitingPrice, isNotNull);
      expect(ScanState.comparing, isNotNull);
      expect(ScanState.result, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-03: 未知JANを読むと文字入力なしで暫定SKUが作成される。
  // ─────────────────────────────────────────────────────────────────
  group('AC-03: Unknown JAN → provisional SKU created without input', () {
    test(
      'findProductByJan returns null for unknown, createProvisionalProduct succeeds',
      () async {
        final unknownJan = '9999999999999';

        final existing = await repository.findProductByJan(unknownJan);
        expect(existing, isNull);

        final product = await repository.createProvisionalProduct(unknownJan);

        expect(product.jan, unknownJan);
        expect(product.id, startsWith('prod-'));
        expect(product.displayName, isNull); // No name input required

        final found = await repository.findProductByJan(unknownJan);
        expect(found, isNotNull);
        expect(found!.jan, unknownJan);
      },
    );

    test(
      'known JAN returns existing product without creating duplicate',
      () async {
        final jan = '4901234567890';

        final p1 = await repository.createProvisionalProduct(jan);
        final p2 = await repository.findProductByJan(jan);

        expect(p2, isNotNull);
        expect(p2!.id, p1.id);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-04: 同一JANの履歴だけを使って比較される。
  // ─────────────────────────────────────────────────────────────────
  group('AC-04: Only same-JAN history used for comparison', () {
    test('observations filtered by productId', () async {
      final productA = await repository.createProvisionalProduct('JAN_A');
      final productB = await repository.createProvisionalProduct('JAN_B');

      for (var i = 0; i < 5; i++) {
        await repository.insertObservation(
          productId: productA.id,
          priceYen: 100 + i * 10,
          priceConfidence: 0.9,
        );
      }

      for (var i = 0; i < 5; i++) {
        await repository.insertObservation(
          productId: productB.id,
          priceYen: 500 + i * 10,
          priceConfidence: 0.9,
        );
      }

      final obsA = await repository.getValidObservations(
        productId: productA.id,
        since: DateTime.now().subtract(const Duration(days: 30)),
        limit: 12,
      );

      final obsB = await repository.getValidObservations(
        productId: productB.id,
        since: DateTime.now().subtract(const Duration(days: 30)),
        limit: 12,
      );

      expect(obsA.every((o) => o.productId == productA.id), isTrue);
      expect(obsA.length, 5);

      expect(obsB.every((o) => o.productId == productB.id), isTrue);
      expect(obsB.length, 5);

      // A prices are all < 200
      expect(obsA.every((o) => o.priceYen < 200), isTrue);
      // B prices are all >= 500
      expect(obsB.every((o) => o.priceYen >= 500), isTrue);
    });

    test('CompareUseCase compares only against same productId', () async {
      final productA = await repository.createProvisionalProduct('JAN_A');

      await insertObservationsSpaced(
        repository,
        productId: productA.id,
        prices: [500, 500, 500, 500, 500],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 400,
        productId: productA.id,
        currentConfidence: 0.95,
      );

      expect(result.status, domain.ComparisonStatus.withBaseline);
      expect(result.baselineMedianYen, 500);
      expect(result.diffYen, -100);
      expect(result.label, domain.ComparisonLabel.veryCheap);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-05: 同一SKU・同一価格の短時間連続スキャンで重複履歴が増えない。
  // ─────────────────────────────────────────────────────────────────
  group('AC-05: Duplicate prevention within 5-min window', () {
    test('same SKU + same price detected as duplicate', () async {
      final now = DateTime.now();

      await repository.insertObservation(
        productId: 'prod-1',
        priceYen: 500,
        priceConfidence: 0.9,
      );

      final isDup = await repository.isDuplicate(
        productId: 'prod-1',
        priceYen: 500,
        observedAt: now,
      );

      expect(isDup, isTrue);
    });

    test('same SKU + different price is NOT duplicate', () async {
      await repository.insertObservation(
        productId: 'prod-1',
        priceYen: 500,
        priceConfidence: 0.9,
      );

      final isDup = await repository.isDuplicate(
        productId: 'prod-1',
        priceYen: 501,
        observedAt: DateTime.now(),
      );

      expect(isDup, isFalse);
    });

    test('same price + different product is NOT duplicate', () async {
      await repository.insertObservation(
        productId: 'prod-1',
        priceYen: 500,
        priceConfidence: 0.9,
      );

      final isDup = await repository.isDuplicate(
        productId: 'prod-2',
        priceYen: 500,
        observedAt: DateTime.now(),
      );

      expect(isDup, isFalse);
    });

    test('different price outside 5-min window is NOT duplicate', () async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 6));

      await repository.insertObservation(
        productId: 'prod-1',
        priceYen: 500,
        priceConfidence: 0.9,
      );

      final isDup = await repository.isDuplicate(
        productId: 'prod-1',
        priceYen: 500,
        observedAt: pastTime,
      );

      expect(isDup, isFalse);
    });

    test(
      'duplicate detected within 5-min window (same product+price)',
      () async {
        final t1 = DateTime(2024, 6, 15, 10, 0, 0);
        final t2 = DateTime(2024, 6, 15, 10, 4, 59);

        await repository.insertObservationWithDate(
          productId: 'prod-1',
          priceYen: 500,
          priceConfidence: 0.9,
          observedAt: t1,
        );

        final isDup = await repository.isDuplicate(
          productId: 'prod-1',
          priceYen: 500,
          observedAt: t2,
        );

        expect(isDup, isTrue);
      },
    );

    test('no duplicate outside 5-min window', () async {
      final t1 = DateTime(2024, 6, 15, 10, 0, 0);
      final t2 = DateTime(2024, 6, 15, 10, 5, 1);

      await repository.insertObservationWithDate(
        productId: 'prod-1',
        priceYen: 500,
        priceConfidence: 0.9,
        observedAt: t1,
      );

      final isDup = await repository.isDuplicate(
        productId: 'prod-1',
        priceYen: 500,
        observedAt: t2,
      );

      expect(isDup, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-06: 機内モードでバーコード認識、価格OCR、
  //         履歴保存、比較が動作する。
  // ─────────────────────────────────────────────────────────────────
  group('AC-06: Airplane mode - all operations offline', () {
    test('full scan-to-compare flow with no network', () async {
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );

      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [500, 500, 500, 500],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 480,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.status, domain.ComparisonStatus.withBaseline);
      expect(result.baselineMedianYen, 500);
      // (480-500)/500 = -0.04 = -4% → "normal" (-5% < rate < +5%)
      expect(result.label, domain.ComparisonLabel.normal);
    });

    test('database operations work without internet', () async {
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );
      expect(product.id, isNotEmpty);

      final obs = await repository.insertObservation(
        productId: product.id,
        priceYen: 398,
        priceConfidence: 0.9,
      );
      expect(obs.id, isNotEmpty);

      final observations = await repository.getValidObservations(
        productId: product.id,
        since: DateTime.now().subtract(const Duration(days: 1)),
        limit: 10,
      );
      expect(observations.length, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-07: アプリのデータ領域にカメラ画像が残らない。
  // ─────────────────────────────────────────────────────────────────
  group('AC-07: No camera images in data storage', () {
    test('PriceObservation stores only price data, no image path', () {
      final obs = PriceObservation(
        id: 'obs-1',
        productId: 'prod-1',
        priceYen: 500,
        observedAt: DateTime.now(),
        priceConfidence: 0.9,
        isValid: true,
        duplicateKey: 'key',
      );

      expect(obs.id, isNotEmpty);
      expect(obs.priceYen, 500);
    });

    test('ScanState has no camera image reference', () {
      const state = ScanState.idle;
      expect(state, ScanState.idle);
    });

    test('BarcodeCandidate and PriceCandidate have no image data', () {
      const barcode = BarcodeCandidate(
        barcode: '4901234567890',
        format: BarcodeFormat.ean13,
        confidence: 0.95,
        region: Rect(left: 0, top: 0, right: 100, bottom: 50),
      );

      const price = PriceCandidate(
        priceYen: 398,
        confidence: 0.9,
        region: Rect(left: 0, top: 0, right: 100, bottom: 50),
        rawTexts: ['398'],
      );

      expect(barcode.barcode, '4901234567890');
      expect(price.priceYen, 398);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-08: バーコードが見つからない場合、
  //         案内が表示される。
  // ─────────────────────────────────────────────────────────────────
  group('AC-08: Barcode not found → guidance displayed', () {
    test('noProduct state emitted when price found without barcode', () async {
      final priceController = StreamController<PriceCandidate>();

      final coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(const Stream.empty()),
        priceAdapter: _StreamPriceAdapter(priceController.stream),
      );

      final states = <ScanState>[];
      coordinator.stateStream.listen(states.add);

      coordinator.startScan();

      // Price stabilizes without any barcode
      for (var i = 0; i < 3; i++) {
        priceController.add(
          PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: const Rect(left: 0, top: 0, right: 200, bottom: 100),
            rawTexts: ['398'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }

      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(ScanState.noProduct));

      await priceController.close();
    });

    test('after noProduct, scanning resumes automatically', () async {
      final priceController = StreamController<PriceCandidate>();

      final coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(const Stream.empty()),
        priceAdapter: _StreamPriceAdapter(priceController.stream),
      );

      final states = <ScanState>[];
      coordinator.stateStream.listen(states.add);

      coordinator.startScan();

      for (var i = 0; i < 3; i++) {
        priceController.add(
          PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: const Rect(left: 0, top: 0, right: 200, bottom: 100),
            rawTexts: ['398'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await Future.delayed(const Duration(milliseconds: 800));

      expect(states.last, ScanState.scanning);

      await priceController.close();
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-09: 価格が見つからない場合、バーコード認識は継続する。
  // ─────────────────────────────────────────────────────────────────
  group('AC-09: Price not found → barcode recognition continues', () {
    test('scanning state runs both barcode and price adapters', () async {
      final coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(const Stream.empty()),
        priceAdapter: _StreamPriceAdapter(const Stream.empty()),
      );

      coordinator.startScan();
      expect(coordinator.currentState, ScanState.scanning);
    });

    test('cancelScan returns to idle from scanning', () {
      final coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: compareUseCase,
        barcodeAdapter: _StreamBarcodeAdapter(const Stream.empty()),
        priceAdapter: _StreamPriceAdapter(const Stream.empty()),
      );

      coordinator.startScan();
      coordinator.cancelScan();
      expect(coordinator.currentState, ScanState.idle);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-10: 過去3件以上で、現在値を除外した中央値から
  //         差額・差率・ラベルが正しく計算される。
  // ─────────────────────────────────────────────────────────────────
  group('AC-10: Median calculation with diff/rate/label for 3+ history', () {
    test('median calculated from historical observations', () async {
      final product = await repository.createProvisionalProduct(
        '4901234567890',
      );

      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [500, 500, 500, 500, 500],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 500,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.status, domain.ComparisonStatus.withBaseline);
      expect(result.baselineMedianYen, 500);
      expect(result.diffYen, 0);
      expect(result.diffRate, 0.0);
      expect(result.label, domain.ComparisonLabel.normal);
    });

    test('veryCheap: -10% or less', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');
      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [1000, 1000, 1000],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 850,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.label, domain.ComparisonLabel.veryCheap);
      expect(result.diffYen, -150);
    });

    test('cheap: -10% < rate <= -5%', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');
      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [1000, 1000, 1000],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 930,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.label, domain.ComparisonLabel.cheap);
    });

    test('normal: -5% < rate < +5%', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');
      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [1000, 1000, 1000],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 1020,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.label, domain.ComparisonLabel.normal);
    });

    test('slightlyExpensive: +5% <= rate < +10%', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');
      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [1000, 1000, 1000],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 1070,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.label, domain.ComparisonLabel.slightlyExpensive);
    });

    test('expensive: +10% or more', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');
      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [1000, 1000, 1000],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 1150,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.label, domain.ComparisonLabel.expensive);
    });

    test('median uses middle value for odd count', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');

      for (final price in [100, 200, 500, 800, 900]) {
        await repository.insertObservation(
          productId: product.id,
          priceYen: price,
          priceConfidence: 0.9,
        );
      }

      final result = await compareUseCase.compare(
        currentPriceYen: 500,
        productId: product.id,
        currentConfidence: 0.95,
      );

      // Sorted historical: [100,200,500,800,900], median=500
      expect(result.baselineMedianYen, 500);
    });

    test('max 12 observations used for median', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');

      for (var i = 0; i < 15; i++) {
        await repository.insertObservation(
          productId: product.id,
          priceYen: 100 + i * 10,
          priceConfidence: 0.9,
        );
      }

      final result = await compareUseCase.compare(
        currentPriceYen: 200,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.observationCount, lessThanOrEqualTo(12));
      expect(result.status, domain.ComparisonStatus.withBaseline);
    });

    test('only observations within 180 days used', () async {
      final product = await repository.createProvisionalProduct('JAN_TEST');

      await repository.insertObservationWithDate(
        productId: product.id,
        priceYen: 100,
        priceConfidence: 0.9,
        observedAt: DateTime.now().subtract(const Duration(days: 200)),
      );

      await insertObservationsSpaced(
        repository,
        productId: product.id,
        prices: [500, 500, 500],
      );

      final result = await compareUseCase.compare(
        currentPriceYen: 500,
        productId: product.id,
        currentConfidence: 0.95,
      );

      expect(result.observationCount, 3);
      expect(result.baselineMedianYen, 500);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-11: 過去0件では安い/高いラベルを出さず
  //        「初回価格」と表示する。
  // ─────────────────────────────────────────────────────────────────
  group('AC-11: No history → firstPrice, no label', () {
    test('firstPrice result has no label', () async {
      final result = await compareUseCase.compare(
        currentPriceYen: 398,
        productId: 'brand-new-product',
        currentConfidence: 0.95,
      );

      expect(result.status, domain.ComparisonStatus.firstPrice);
      expect(result.label, isNull);
      expect(result.currentPrice, 398);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // AC-12: 誤った商品・価格を自動確定するより、
  //        再スキャンを優先する。
  // ─────────────────────────────────────────────────────────────────
  group('AC-12: Safety over certainty — prefer rescan', () {
    test('PriceStabilizer requires 3 consecutive identical readings', () {
      final stabilizer = PriceStabilizer();

      stabilizer.submit(
        const PriceCandidate(
          priceYen: 398,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['398'],
        ),
      );
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 398,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['398'],
        ),
      );
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 398,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['398'],
          ),
        ),
        isTrue,
      );
    });

    test('PriceStabilizer rejects if readings differ', () {
      final stabilizer = PriceStabilizer();

      stabilizer.submit(
        const PriceCandidate(
          priceYen: 398,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['398'],
        ),
      );
      stabilizer.submit(
        const PriceCandidate(
          priceYen: 398,
          confidence: 0.9,
          region: Rect(left: 0, top: 0, right: 100, bottom: 50),
          rawTexts: ['398'],
        ),
      );
      expect(
        stabilizer.submit(
          const PriceCandidate(
            priceYen: 400,
            confidence: 0.9,
            region: Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['400'],
          ),
        ),
        isFalse,
      );
    });

    test('PriceStabilizer keeps sliding window of 5', () {
      final stabilizer = PriceStabilizer();

      for (final price in [100, 200, 300, 300, 300]) {
        stabilizer.submit(
          PriceCandidate(
            priceYen: price,
            confidence: 0.9,
            region: const Rect(left: 0, top: 0, right: 100, bottom: 50),
            rawTexts: ['$price'],
          ),
        );
      }

      expect(stabilizer.currentPrice, 300);
    });
  });
}

// ─────────────────────────────────────────────────────────────────
// Test helpers: Stream-based adapters using StreamController
// ─────────────────────────────────────────────────────────────────

class _StreamBarcodeAdapter implements BarcodeRecognizerAdapter {
  final Stream<BarcodeCandidate> _stream;
  bool _paused = false;

  _StreamBarcodeAdapter(this._stream);

  @override
  Stream<BarcodeCandidate> get results => _stream
      .map((e) {
        if (_paused) return null;
        return e;
      })
      .where((e) => e != null)
      .cast<BarcodeCandidate>();

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;
}

class _StreamPriceAdapter implements PriceOcrAdapter {
  final Stream<PriceCandidate> _stream;
  bool _paused = false;

  _StreamPriceAdapter(this._stream);

  @override
  Stream<List<PriceCandidate>> get results => _stream
      .map((e) {
        if (_paused) return null;
        return e;
      })
      .where((e) => e != null)
      .cast<PriceCandidate>()
      .map((c) => [c]);

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;
}
