import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_text_parser.dart';

const _barcodeRegion = Rect(left: 0, top: 0, right: 100, bottom: 50);

Future<void> _flush([int milliseconds = 100]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('Ambiguous prices never persist', () {
    late PriceRepository repository;
    late _ControllableBarcodeAdapter barcodeAdapter;
    late _ControllablePriceAdapter priceAdapter;
    late ScanCoordinator coordinator;

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
    });

    tearDown(() async {
      coordinator.dispose();
      repository.dispose();
      await barcodeAdapter.close();
      await priceAdapter.close();
    });

    test('three ambiguous frames produce no price and no save', () async {
      const jan = '4901234567890';
      final results = <int>[];
      coordinator.resultStream.listen(
        (result) => results.add(result.currentPrice),
      );

      coordinator.startScan();
      barcodeAdapter.add(
        const BarcodeCandidate(
          barcode: jan,
          format: BarcodeFormat.ean13,
          confidence: 0.95,
          region: _barcodeRegion,
        ),
      );
      await _flush();
      expect(coordinator.currentState, ScanState.waitingPrice);

      // The production pipeline only emits a PriceCandidate when
      // parsePriceText returns non-null. Ambiguous frames yield null, so
      // nothing is submitted to the stabilizer across all three frames.
      for (var i = 0; i < 3; i++) {
        final parsed = parsePriceText([
          (
            text: '通常 398円 特売 298円',
            region: const Rect(left: 0, top: 50, right: 100, bottom: 100),
          ),
        ]);
        expect(parsed, isNull);
        await _flush();
      }

      expect(coordinator.currentState, ScanState.waitingPrice);
      expect(results, isEmpty);
      expect(await repository.findProductByJan(jan), isNull);
    });
  });
}

class _ControllableBarcodeAdapter implements BarcodeRecognizerAdapter {
  final _controller = StreamController<BarcodeCandidate>.broadcast();

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) => _controller.add(candidate);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}

class _ControllablePriceAdapter implements PriceOcrAdapter {
  final _controller = StreamController<List<PriceCandidate>>.broadcast();

  @override
  Stream<List<PriceCandidate>> get results => _controller.stream;

  void add(PriceCandidate candidate) => _controller.add([candidate]);
  Future<void> close() => _controller.close();

  @override
  void pause() {}

  @override
  void resume() {}
}
