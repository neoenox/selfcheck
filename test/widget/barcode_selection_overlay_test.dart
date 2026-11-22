import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart' as domain;
import 'package:selfcheck_jibun_check/presentation/widgets/barcode_selection_overlay.dart';

void main() {
  testWidgets(
    'visible barcode boxes select the tapped JAN in portrait preview',
    (tester) async {
      String? selected;
      const frame = domain.RecognitionFrame(
        imageWidth: 480,
        imageHeight: 640,
        prices: [],
        barcodes: [
          domain.BarcodeCandidate(
            barcode: '4901234567890',
            format: domain.BarcodeFormat.ean13,
            confidence: 1,
            region: domain.Rect(left: 40, top: 160, right: 200, bottom: 220),
          ),
          domain.BarcodeCandidate(
            barcode: '4901234567891',
            format: domain.BarcodeFormat.ean13,
            confidence: 1,
            region: domain.Rect(left: 260, top: 160, right: 420, bottom: 220),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 320,
                child: BarcodeSelectionOverlay(
                  frame: frame,
                  onSelected: (jan) => selected = jan,
                ),
              ),
            ),
          ),
        ),
      );
      final first = find.byKey(const ValueKey('barcode-4901234567890'));
      final second = find.byKey(const ValueKey('barcode-4901234567891'));
      expect(tester.getRect(second).left - tester.getRect(first).left, 110);
      await tester.tap(second);
      expect(selected, '4901234567891');
      expect(tester.takeException(), isNull);
    },
  );
}
