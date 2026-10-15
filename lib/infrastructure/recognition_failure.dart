import 'package:flutter/services.dart';

enum RecognitionStage {
  image('カメラ画像の変換'),
  barcode('バーコード認識'),
  price('価格の文字認識'),
  result('認識結果の処理');

  const RecognitionStage(this.label);
  final String label;
}

/// Bounded diagnostics for on-device recognition, without image contents,
/// recognized text, platform details, or a stack trace.
class RecognitionFailure implements Exception {
  const RecognitionFailure({
    required this.stage,
    required this.cause,
    required this.imageDescription,
  });

  final RecognitionStage stage;
  final Object cause;
  final String imageDescription;

  String get diagnosticSummary {
    final error = cause;
    final code = error is PlatformException
        ? error.code
        : '${error.runtimeType}';
    final message = error is PlatformException ? error.message ?? '' : '';
    return '${_ascii(code, 48)}: ${_ascii(message, 180)} '
        '[${_ascii(imageDescription, 80)}]';
  }

  String get displayMessage =>
      '${stage.label}でエラーが発生しました。\n確認用: $diagnosticSummary';

  static String _ascii(String value, int limit) {
    final printable = value.replaceAll(RegExp(r'[^\x20-\x7e]'), '?');
    return printable.length > limit ? printable.substring(0, limit) : printable;
  }

  // Retain the cause for existing fatal permission-error classification.
  @override
  String toString() => '${stage.name}: $cause';
}
