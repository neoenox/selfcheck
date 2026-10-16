import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

const region = Rect(left: 0, top: 0, right: 100, bottom: 40);
const a = BarcodeCandidate(
  barcode: '4901234567890',
  format: BarcodeFormat.ean13,
  confidence: 1,
  region: region,
);
const b = BarcodeCandidate(
  barcode: '4901234567891',
  format: BarcodeFormat.ean13,
  confidence: 1,
  region: Rect(left: 400, top: 0, right: 500, bottom: 40),
);
const priceA = PriceCandidate(
  priceYen: 398,
  confidence: .9,
  region: Rect(left: 0, top: 40, right: 100, bottom: 80),
  rawTexts: ['398円'],
);
const priceB = PriceCandidate(
  priceYen: 999,
  confidence: .9,
  region: Rect(left: 400, top: 40, right: 500, bottom: 80),
  rawTexts: ['999円'],
);
Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  late PriceRepositoryImpl repository;
  late Frames adapter;
  late ScanCoordinator coordinator;
  setUp(() async {
    repository = await createTestRepository();
    adapter = Frames();
    coordinator = ScanCoordinator(
      repository: repository,
      compareUseCase: CompareUseCase(repository),
      barcodeAdapter: adapter,
      priceAdapter: Prices(),
    );
    coordinator.startScan();
  });
  tearDown(() async {
    coordinator.dispose();
    repository.dispose();
    await adapter.controller.close();
  });
  Future<void> frame(
    List<BarcodeCandidate> codes,
    List<PriceCandidate> prices,
  ) async {
    adapter.controller.add(
      RecognitionFrame(
        barcodes: codes,
        prices: prices,
        imageWidth: 640,
        imageHeight: 480,
      ),
    );
    await flush();
  }

  test(
    'multiple barcodes wait for a tap and save only the selected product',
    () async {
      for (var i = 0; i < 4; i++) {
        await frame([a, b], [priceA, priceB]);
      }
      expect(await repository.findProductByJan(a.barcode), isNull);
      expect(await repository.findProductByJan(b.barcode), isNull);
      expect(coordinator.selectBarcode(b.barcode), isTrue);
      for (var i = 0; i < 3; i++) {
        await frame([a, b], [priceA, priceB]);
      }
      await flush();
      expect(await repository.findProductByJan(a.barcode), isNull);
      final product = await repository.findProductByJan(b.barcode);
      final rows = await repository.getValidObservations(
        productId: product!.id,
        since: DateTime.now().subtract(const Duration(minutes: 1)),
        limit: 10,
      );
      expect(rows.single.priceYen, 999);
    },
  );
  test(
    'moving away from the selected barcode never saves a later price',
    () async {
      await frame([a], []);
      for (var i = 0; i < 4; i++) {
        await frame([], [priceA]);
      }
      expect(await repository.findProductByJan(a.barcode), isNull);
      for (var i = 0; i < 4; i++) {
        await frame([b], [priceB]);
      }
      expect(await repository.findProductByJan(a.barcode), isNull);
    },
  );
  test('empty or ambiguous frames break price stabilization', () async {
    await frame([a], [priceA]);
    await frame([a], [priceA]);
    await frame([a], []);
    await frame([a], [priceA]);
    expect(await repository.findProductByJan(a.barcode), isNull);
  });
  test('a barcode absent from the current image cannot be tapped', () async {
    await frame([a, b], []);
    await frame([a], []);
    expect(coordinator.selectBarcode(b.barcode), isFalse);
  });
  test('OCR cannot save while the manual form is open', () async {
    expect(coordinator.beginManualEntry(), isTrue);
    for (var i = 0; i < 4; i++) {
      await frame([a], [priceA]);
    }
    expect(await repository.findProductByJan(a.barcode), isNull);
    expect(
      coordinator.submitManualPrice(
        const ManualPriceEntry(priceYen: 350, isTaxInclusive: true),
      ),
      isTrue,
    );
    coordinator.endManualEntry();
    await flush();
    final product = await repository.findProductByJan(a.barcode);
    final rows = await repository.getValidObservations(
      productId: product!.id,
      since: DateTime.now().subtract(const Duration(minutes: 1)),
      limit: 10,
    );
    expect(rows.single.priceYen, 350);
  });
}

class Frames implements FrameBarcodeRecognizerAdapter {
  final controller = StreamController<RecognitionFrame>.broadcast();
  @override
  Stream<RecognitionFrame> get frames => controller.stream;
  @override
  Stream<BarcodeCandidate> get results => const Stream.empty();
  @override
  void pause() {}
  @override
  void resume() {}
}

class Prices implements PriceOcrAdapter {
  @override
  Stream<List<PriceCandidate>> get results => const Stream.empty();
  @override
  void pause() {}
  @override
  void resume() {}
}
