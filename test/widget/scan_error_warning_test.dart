import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);
const _nearPriceRegion = Rect(left: 0, top: 50, right: 100, bottom: 100);

const _barcode = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 0.95,
  region: _barcodeRegion,
);

PriceCandidate _price(int value) => PriceCandidate(
  priceYen: value,
  confidence: 0.9,
  region: _nearPriceRegion,
  rawTexts: ['$value'],
);

/// Advances fake-async time (fires timers/stream events) and rebuilds.
/// Plain [Future.delayed] never completes inside testWidgets, so time must
/// be advanced explicitly with [WidgetTester.pump].
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('ScanScreen transient warnings', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;
    late ScanScreenController controller;

    setUp(() async {
      repository = await createTestRepository();
      barcodeAdapter = _ControllableBarcodeAdapter();
      priceAdapter = _ControllablePriceAdapter();
      coordinator = ScanCoordinator(
        repository: repository,
        compareUseCase: CompareUseCase(repository),
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
      );
      controller = ScanScreenController(coordinator: coordinator);
    });

    tearDown(() async {
      controller.dispose();
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    Widget buildTestApp() {
      return MaterialApp(home: ScanScreen(controller: controller));
    }

    testWidgets('shows a warning while scanning continues', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      controller.startScan();
      await _settle(tester);
      expect(find.text('認識中...'), findsOneWidget);

      priceAdapter.addError(Exception('ML Kit busy'));
      await _settle(tester);

      expect(find.textContaining('価格OCRストリームエラー'), findsOneWidget);
      // The scan keeps running: no error overlay, still recognizing.
      expect(find.text('認識中...'), findsOneWidget);
      expect(find.text('エラーが発生しました'), findsNothing);
    });

    testWidgets('shows a warning while waiting for a price', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      controller.startScan();
      await _settle(tester);
      barcodeAdapter.add(_barcode);
      await _settle(tester);
      expect(find.text('バーコード認識済み ▶ 価格安定化待ち'), findsOneWidget);

      priceAdapter.addError(Exception('ML Kit busy'));
      await _settle(tester);

      expect(find.textContaining('価格OCRストリームエラー'), findsOneWidget);
      expect(find.text('バーコード認識済み ▶ 価格安定化待ち'), findsOneWidget);
    });

    testWidgets('warning disappears after recognition recovers', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      controller.startScan();
      await _settle(tester);
      priceAdapter.addError(Exception('ML Kit busy'));
      await _settle(tester);
      expect(find.textContaining('価格OCRストリームエラー'), findsOneWidget);

      barcodeAdapter.add(_barcode);
      await _settle(tester);

      expect(find.textContaining('価格OCRストリームエラー'), findsNothing);
      expect(find.text('バーコード認識済み ▶ 価格安定化待ち'), findsOneWidget);
    });
  });

  group('ScanScreen compare failures', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;
    late ScanScreenController controller;

    setUp(() async {
      repository = await createTestRepository();
      barcodeAdapter = _ControllableBarcodeAdapter();
      priceAdapter = _ControllablePriceAdapter();
      final broken = _BrokenRepository(repository);
      coordinator = ScanCoordinator(
        repository: broken,
        compareUseCase: CompareUseCase(broken),
        barcodeAdapter: barcodeAdapter,
        priceAdapter: priceAdapter,
      );
      controller = ScanScreenController(coordinator: coordinator);
    });

    tearDown(() async {
      controller.dispose();
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    testWidgets('shows the error message when compare fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ScanScreen(controller: controller)),
      );
      await tester.pump();

      controller.startScan();
      await _settle(tester);
      barcodeAdapter.add(_barcode);
      await _settle(tester);
      for (var i = 0; i < 3; i++) {
        priceAdapter.add(_price(398));
        await _settle(tester);
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('エラーが発生しました'), findsOneWidget);
      expect(find.text('ストレージ容量が不足しています。'), findsOneWidget);
    });
  });
}

class _ControllableBarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) => _controller.add(candidate);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

class _ControllablePriceAdapter implements PriceOcrAdapter {
  final _controller = StreamController<PriceCandidate>.broadcast();

  @override
  Stream<PriceCandidate> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add(candidate);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

/// Repository that throws SQLITE_FULL on observation inserts.
class _BrokenRepository implements PriceRepository {
  final PriceRepository _inner;
  _BrokenRepository(this._inner);

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async => false;

  @override
  Future<ProductIdentity?> findProductByJan(String jan) =>
      _inner.findProductByJan(jan);

  @override
  Future<ProductIdentity> createProvisionalProduct(String jan) =>
      _inner.createProvisionalProduct(jan);

  @override
  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  }) => _inner.getValidObservations(
    productId: productId,
    since: since,
    limit: limit,
  );

  @override
  Future<PriceObservation> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    throw Exception(
      'SqliteException(13): database or disk is full, SQLITE_FULL',
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
  }) async {
    throw Exception(
      'SqliteException(13): database or disk is full, SQLITE_FULL',
    );
  }

  @override
  void dispose() => _inner.dispose();
}
