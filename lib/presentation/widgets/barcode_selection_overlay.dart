import 'package:flutter/material.dart';
import '../../domain/scan_state.dart';

/// Placed inside CameraPreview so image boxes use the same aspect ratio and
/// letterboxing as the live preview, including portrait rotation.
class BarcodeSelectionOverlay extends StatelessWidget {
  const BarcodeSelectionOverlay({
    super.key,
    required this.frame,
    required this.onSelected,
    this.selectedJan,
  });
  final RecognitionFrame frame;
  final ValueChanged<String> onSelected;
  final String? selectedJan;

  @override
  Widget build(BuildContext context) {
    if (frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final x = constraints.maxWidth / frame.imageWidth;
        final y = constraints.maxHeight / frame.imageHeight;
        final codes = {for (final code in frame.barcodes) code.barcode: code};
        return Stack(
          children: [
            for (final code in codes.values)
              Positioned(
                left: (code.region.left * x).clamp(0, constraints.maxWidth),
                top: (code.region.top * y).clamp(0, constraints.maxHeight),
                width: (code.region.width * x).clamp(1, constraints.maxWidth),
                height: (code.region.height * y).clamp(
                  48,
                  constraints.maxHeight,
                ),
                child: Semantics(
                  button: true,
                  label: 'バーコード ${code.barcode} を選択',
                  selected: code.barcode == selectedJan,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('barcode-${code.barcode}'),
                      onTap: () => onSelected(code.barcode),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: code.barcode == selectedJan
                                ? Colors.greenAccent
                                : Colors.amberAccent,
                            width: 3,
                          ),
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            code.barcode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
