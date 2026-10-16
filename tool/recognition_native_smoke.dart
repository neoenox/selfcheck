// Run on Android with --release. This alternate entry point is a native
// regression probe, not the application entry point used for Play releases.
// Release-mode markers are intentionally written to Android logcat.
// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const _jan = '4901234567894';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Recognition smoke test'))),
  );
  final scanner = BarcodeScanner(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
  try {
    final bytes = await _fixture();
    for (final rotation in [
      InputImageRotation.rotation0deg,
      InputImageRotation.rotation90deg,
      InputImageRotation.rotation270deg,
    ]) {
      final image = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: const Size(640, 480),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: 640,
        ),
      );
      final barcodes = await scanner.processImage(image);
      if (!barcodes.any((barcode) => barcode.rawValue == _jan)) {
        throw StateError('EAN-13 was not decoded at ${rotation.name}');
      }
      final text = await recognizer.processImage(image);
      if (!text.text.contains('398') || !text.text.contains('税込')) {
        throw StateError('Japanese price was not decoded at ${rotation.name}');
      }
      // This explicit marker also works with asserts disabled in release mode.
      print('SELFCHECK_NATIVE_SMOKE PASS ${rotation.name} JAN=$_jan price=398');
    }
    print('SELFCHECK_NATIVE_SMOKE ALL_PASS');
  } catch (error, trace) {
    print('SELFCHECK_NATIVE_SMOKE FAIL $error\n$trace');
  } finally {
    await scanner.close();
    await recognizer.close();
  }
}

Future<Uint8List> _fixture() async {
  const left = [
    '0001101',
    '0011001',
    '0010011',
    '0111101',
    '0100011',
    '0110001',
    '0101111',
    '0111011',
    '0110111',
    '0001011',
  ];
  const alternate = [
    '0100111',
    '0110011',
    '0011011',
    '0100001',
    '0011101',
    '0111001',
    '0000101',
    '0010001',
    '0001001',
    '0010111',
  ];
  // The leading digit 4 selects the LGLLGG parity pattern.
  const parity = 'LGLLGG';
  var modules = '101';
  for (var i = 1; i <= 6; i++) {
    final digit = int.parse(_jan[i]);
    modules += parity[i - 1] == 'L' ? left[digit] : alternate[digit];
  }
  modules += '01010';
  for (var i = 7; i < 13; i++) {
    modules += left[int.parse(_jan[i])]
        .split('')
        .map((b) => b == '0' ? '1' : '0')
        .join();
  }
  modules += '101';
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  final paint = Paint()..color = Colors.black;
  for (var i = 0; i < modules.length; i++) {
    if (modules[i] == '1') {
      canvas.drawRect(Rect.fromLTWH(100 + i * 4.0, 60, 4, 200), paint);
    }
  }
  final text = TextPainter(
    text: const TextSpan(
      text: '税込 398円',
      style: TextStyle(color: Colors.black, fontSize: 44),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, const Offset(130, 320));
  text.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(640, 480);
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bytes = Uint8List(640 * 480 * 3 ~/ 2)
    ..fillRange(640 * 480, 640 * 480 * 3 ~/ 2, 128);
  for (var i = 0; i < 640 * 480; i++) {
    bytes[i] = 16 + (pixels.getUint8(i * 4) * 219 ~/ 255);
  }
  image.dispose();
  picture.dispose();
  return bytes;
}
