import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/recognition_failure.dart';

void main() {
  test('reports the failing stage and native error without USB logs', () {
    final failure = RecognitionFailure(
      stage: RecognitionStage.barcode,
      cause: PlatformException(code: '14', message: 'Failed to load model'),
      imageDescription: '640x480 format=17 planes=1 bytes=460800',
    );

    expect(failure.displayMessage, contains('バーコード認識'));
    expect(failure.displayMessage, contains('14: Failed to load model'));
    expect(failure.displayMessage, contains('640x480'));
  });

  test('distinguishes OCR failure from barcode failure', () {
    final failure = RecognitionFailure(
      stage: RecognitionStage.price,
      cause: StateError('recognizer unavailable'),
      imageDescription: '640x480',
    );
    expect(failure.displayMessage, contains('価格の文字認識'));
    expect(failure.displayMessage, contains('StateError'));
  });

  test('bounds native messages and keeps diagnostics ASCII', () {
    final failure = RecognitionFailure(
      stage: RecognitionStage.image,
      cause: PlatformException(
        code: 'bad\ncode',
        message: '${String.fromCharCode(0x1f600)}\n${'x' * 1000}',
        details: 'must not appear',
      ),
      imageDescription: '640x480',
    );
    expect(failure.diagnosticSummary.length, lessThan(320));
    expect(
      failure.diagnosticSummary.codeUnits.every((c) => c >= 32 && c <= 126),
      isTrue,
    );
    expect(failure.diagnosticSummary, isNot(contains('must not appear')));
  });
}
