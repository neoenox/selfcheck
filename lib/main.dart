import 'dart:async';

import 'package:flutter/material.dart';

import 'application/compare_use_case.dart';
import 'application/scan_coordinator.dart';
import 'infrastructure/camera_recognition_pipeline.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/price_repository.dart';
import 'infrastructure/price_repository_impl.dart';
import 'presentation/camera_unavailable_view.dart';
import 'presentation/scan_screen.dart';
import 'presentation/scan_screen_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SelfCheckApp());
}

class SelfCheckApp extends StatelessWidget {
  const SelfCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自分値',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const ScanScreenEntry(),
    );
  }
}

/// Entry point that wires the device-local camera/recognition pipeline.
class ScanScreenEntry extends StatefulWidget {
  const ScanScreenEntry({super.key});

  @override
  State<ScanScreenEntry> createState() => _ScanScreenEntryState();
}

class _ScanScreenEntryState extends State<ScanScreenEntry>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  late final PriceRepository _repository;
  late final CompareUseCase _compareUseCase;
  late final CameraRecognitionPipeline _cameraPipeline;
  late final ScanCoordinator _coordinator;
  late final ScanScreenController _controller;

  Future<void>? _cameraRecoveryTask;
  Future<void>? _cameraSuspendTask;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _database = AppDatabase();
    _repository = PriceRepositoryImpl(_database);
    _compareUseCase = CompareUseCase(_repository);
    _cameraPipeline = CameraRecognitionPipeline();
    _coordinator = ScanCoordinator(
      repository: _repository,
      compareUseCase: _compareUseCase,
      barcodeAdapter: CameraBarcodeAdapter(_cameraPipeline),
      priceAdapter: CameraPriceOcrAdapter(_cameraPipeline),
    );
    _controller = ScanScreenController(coordinator: _coordinator);
    unawaited(_ensureCameraReady());
  }

  Future<void> _ensureCameraReady() async {
    final suspendTask = _cameraSuspendTask;
    if (suspendTask != null) {
      try {
        await suspendTask;
      } on Object {
        // CameraRecognitionPipeline already exposes/logs the relevant failure.
      }
    }

    final activeRecovery = _cameraRecoveryTask;
    if (activeRecovery != null) {
      try {
        await activeRecovery;
      } on Object {
        // Join the existing attempt. A later explicit retry may start a new one.
      }
      if (_cameraPipeline.isReady || _cameraPipeline.isCameraActive) {
        return;
      }
      // A suspend invalidated that recovery. Continue with a fresh foreground
      // recovery instead of leaving the preview in a permanent loading state.
    }

    if (_cameraPipeline.isReady) return;

    late final Future<void> recoveryTask;
    recoveryTask = _cameraPipeline.resumeCamera().whenComplete(() {
      if (identical(_cameraRecoveryTask, recoveryTask)) {
        _cameraRecoveryTask = null;
      }
    });
    _cameraRecoveryTask = recoveryTask;

    try {
      await recoveryTask;
    } on Object {
      // CameraUnavailableView keeps the failure visible and offers an explicit
      // retry after permission changes or transient camera failures.
    }
  }

  void _suspendCamera() {
    if (_cameraSuspendTask != null) return;

    late final Future<void> suspendTask;
    suspendTask = _cameraPipeline.suspendCamera().whenComplete(() {
      if (identical(_cameraSuspendTask, suspendTask)) {
        _cameraSuspendTask = null;
      }
    });
    _cameraSuspendTask = suspendTask;
    unawaited(suspendTask);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureCameraReady());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _coordinator.cancelScan();
      _suspendCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _coordinator.dispose();
    _cameraPipeline.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScanScreen(
      controller: _controller,
      cameraPreview: AnimatedBuilder(
        animation: Listenable.merge([_cameraPipeline, _controller]),
        builder: (context, _) {
          if (_cameraPipeline.initializationError != null) {
            return CameraUnavailableView(onRetry: _ensureCameraReady);
          }
          return CameraPreviewSurface(
            pipeline: _cameraPipeline,
            selectedJan: _controller.selectedJan,
            onBarcodeSelected: _controller.selectBarcode,
          );
        },
      ),
    );
  }
}
