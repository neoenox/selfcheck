import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml_barcode;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../application/scan_coordinator.dart';
import '../domain/scan_state.dart';
import 'price_text_parser.dart';
import 'recognition_failure_policy.dart';

/// Owns the live camera and on-device ML Kit recognizers.
///
/// Frames are processed in memory only. This class never calls takePicture,
/// never writes camera bytes to disk, and keeps at most one ML inference in
/// flight to avoid unbounded frame queues.
class CameraRecognitionPipeline extends ChangeNotifier {
  CameraRecognitionPipeline()
    : _barcodeScanner = ml_barcode.BarcodeScanner(
        formats: const [
          ml_barcode.BarcodeFormat.ean13,
          ml_barcode.BarcodeFormat.ean8,
        ],
      ),
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

  final ml_barcode.BarcodeScanner _barcodeScanner;
  final TextRecognizer _textRecognizer;
  final StreamController<BarcodeCandidate> _barcodeResults =
      StreamController<BarcodeCandidate>.broadcast();
  final StreamController<List<PriceCandidate>> _priceResults =
      StreamController<List<PriceCandidate>>.broadcast();

  CameraController? _cameraController;
  CameraDescription? _camera;
  bool _barcodeEnabled = false;
  bool _priceEnabled = false;
  bool _processing = false;
  bool _disposed = false;
  bool _cameraActive = true;
  int _cameraGeneration = 0;
  Object? _initializationError;
  final RecognitionFailurePolicy _recognitionFailurePolicy =
      RecognitionFailurePolicy();
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<BarcodeCandidate> get barcodeResults => _barcodeResults.stream;
  Stream<List<PriceCandidate>> get priceResults => _priceResults.stream;
  CameraController? get cameraController => _cameraController;
  bool get isReady => _cameraController?.value.isInitialized ?? false;
  bool get isCameraActive => _cameraActive;
  Object? get initializationError => _initializationError;

  Future<void> initialize() async {
    if (_disposed || !_cameraActive || isReady) return;

    final generation = ++_cameraGeneration;
    CameraController? controller;
    try {
      _initializationError = null;
      final cameras = await availableCameras();
      if (!_isCurrentCameraOperation(generation)) return;
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _cameraController = controller;

      await controller.initialize();
      if (!_isCurrentCameraOperation(generation)) {
        if (identical(_cameraController, controller)) {
          _cameraController = null;
        }
        await _disposeCameraController(controller);
        return;
      }

      await controller.startImageStream(
        (image) => _onCameraImage(image, generation),
      );
      if (!_isCurrentCameraOperation(generation)) {
        if (identical(_cameraController, controller)) {
          _cameraController = null;
        }
        await _disposeCameraController(controller);
        return;
      }

      notifyListeners();
    } on Object catch (error) {
      if (controller != null) {
        if (identical(_cameraController, controller)) {
          _cameraController = null;
        }
        await _disposeCameraController(controller);
      }

      if (!_disposed && _cameraActive && generation == _cameraGeneration) {
        _initializationError = error;
        notifyListeners();
        rethrow;
      }
    }
  }

  /// Releases the camera while keeping the on-device recognizers alive.
  Future<void> suspendCamera() async {
    if (_disposed) return;
    _cameraActive = false;
    _cameraGeneration++;

    final controller = _cameraController;
    _cameraController = null;
    notifyListeners();
    if (controller != null) {
      await _disposeCameraController(controller);
    }
  }

  /// Re-acquires the camera after the app returns to the foreground.
  Future<void> resumeCamera() async {
    if (_disposed) return;
    _cameraActive = true;
    await initialize();
  }

  bool _isCurrentCameraOperation(int generation) =>
      !_disposed && _cameraActive && generation == _cameraGeneration;

  Future<void> _disposeCameraController(CameraController controller) async {
    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on Object catch (error, stackTrace) {
      debugPrint('CameraRecognitionPipeline stop stream failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      await controller.dispose();
    } on Object catch (error, stackTrace) {
      debugPrint('CameraRecognitionPipeline dispose camera failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void enableBarcode() => _barcodeEnabled = true;
  void disableBarcode() => _barcodeEnabled = false;
  void enablePrice() => _priceEnabled = true;
  void disablePrice() => _priceEnabled = false;

  Future<void> _onCameraImage(CameraImage image, int generation) async {
    if (!_isCurrentCameraOperation(generation) ||
        _processing ||
        (!_barcodeEnabled && !_priceEnabled)) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastProcessed) < const Duration(milliseconds: 220)) {
      return;
    }
    _lastProcessed = now;
    _processing = true;
    var frameFailed = false;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null || !_isCurrentCameraOperation(generation)) {
        return;
      }

      if (_barcodeEnabled) {
        final barcodes = await _barcodeScanner.processImage(inputImage);
        if (!_isCurrentCameraOperation(generation) || !_barcodeEnabled) {
          return;
        }
        for (final barcode in barcodes) {
          final candidate = _toBarcodeCandidate(barcode);
          if (candidate != null && !_barcodeResults.isClosed) {
            _barcodeResults.add(candidate);
            break;
          }
        }
      }

      if (_priceEnabled && _isCurrentCameraOperation(generation)) {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        if (!_isCurrentCameraOperation(generation) || !_priceEnabled) {
          return;
        }
        final candidates = parsePriceCandidates(
          recognizedText.blocks.expand(
            (block) => block.lines.map(
              (line) => (
                text: line.text,
                region: Rect(
                  left: line.boundingBox.left,
                  top: line.boundingBox.top,
                  right: line.boundingBox.right,
                  bottom: line.boundingBox.bottom,
                ),
              ),
            ),
          ),
        );
        // Ambiguous or empty frames yield no candidates and are skipped, so
        // a guessed price can never enter stabilization.
        if (candidates.isNotEmpty && !_priceResults.isClosed) {
          _priceResults.add(candidates);
        }
      }
    } on Object catch (error, stackTrace) {
      frameFailed = true;
      debugPrint('CameraRecognitionPipeline frame failed: $error');
      debugPrint('$stackTrace');
      final shouldNotify = _recognitionFailurePolicy.recordFailure(
        fatal: _isFatalRecognitionError(error),
      );
      if (shouldNotify) {
        _publishRecognitionError(error, stackTrace);
      }
    } finally {
      if (!frameFailed) {
        _recognitionFailurePolicy.recordSuccess();
      }
      _processing = false;
    }
  }

  bool _isFatalRecognitionError(Object error) {
    if (error is CameraException) {
      return error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt';
    }
    return false;
  }

  void _publishRecognitionError(Object error, StackTrace stackTrace) {
    if (_barcodeEnabled && !_barcodeResults.isClosed) {
      _barcodeResults.addError(error, stackTrace);
    }
    if (_priceEnabled && !_priceResults.isClosed) {
      _priceResults.addError(error, stackTrace);
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _cameraController;
    if (camera == null || controller == null) return null;

    final rotation = _inputImageRotation(
      camera,
      controller.value.deviceOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final compensation = orientations[deviceOrientation];
    if (compensation == null) return null;

    final rotationCompensation =
        camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  BarcodeCandidate? _toBarcodeCandidate(ml_barcode.Barcode barcode) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || !RegExp(r'^\d+$').hasMatch(raw)) return null;

    final format = switch (barcode.format) {
      ml_barcode.BarcodeFormat.ean13 => BarcodeFormat.ean13,
      ml_barcode.BarcodeFormat.ean8 => BarcodeFormat.ean8,
      _ => BarcodeFormat.unknown,
    };
    if (format == BarcodeFormat.unknown) return null;
    if ((format == BarcodeFormat.ean13 && raw.length != 13) ||
        (format == BarcodeFormat.ean8 && raw.length != 8)) {
      return null;
    }

    final box = barcode.boundingBox;
    return BarcodeCandidate(
      barcode: raw,
      format: format,
      confidence: 1.0,
      region: Rect(
        left: box.left,
        top: box.top,
        right: box.right,
        bottom: box.bottom,
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cameraActive = false;
    _cameraGeneration++;
    _barcodeEnabled = false;
    _priceEnabled = false;

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(_disposeCameraController(controller));
    }
    unawaited(_barcodeScanner.close());
    unawaited(_textRecognizer.close());
    unawaited(_barcodeResults.close());
    unawaited(_priceResults.close());
    super.dispose();
  }
}

class CameraBarcodeAdapter implements BarcodeRecognizerAdapter {
  const CameraBarcodeAdapter(this.pipeline);
  final CameraRecognitionPipeline pipeline;

  @override
  Stream<BarcodeCandidate> get results => pipeline.barcodeResults;

  @override
  void pause() => pipeline.disableBarcode();

  @override
  void resume() => pipeline.enableBarcode();
}

class CameraPriceOcrAdapter implements PriceOcrAdapter {
  const CameraPriceOcrAdapter(this.pipeline);
  final CameraRecognitionPipeline pipeline;

  @override
  Stream<List<PriceCandidate>> get results => pipeline.priceResults;

  @override
  void pause() => pipeline.disablePrice();

  @override
  void resume() => pipeline.enablePrice();
}

class CameraPreviewSurface extends StatelessWidget {
  const CameraPreviewSurface({super.key, required this.pipeline});

  final CameraRecognitionPipeline pipeline;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pipeline,
      builder: (context, _) {
        final controller = pipeline.cameraController;
        if (controller != null && controller.value.isInitialized) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          );
        }

        if (pipeline.initializationError != null) {
          return const ColoredBox(
            color: Color(0xFF1A1A2E),
            child: Center(
              child: Icon(
                Icons.no_photography,
                size: 72,
                color: Colors.white30,
              ),
            ),
          );
        }

        return const ColoredBox(
          color: Color(0xFF1A1A2E),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
