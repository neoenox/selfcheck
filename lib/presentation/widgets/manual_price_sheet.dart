import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/scan_coordinator.dart';
import '../scan_screen_controller.dart';

/// Result of the manual price sheet.
class ManualSaveOutcome {
  const ManualSaveOutcome({required this.saved, required this.janKnown});

  final bool saved;
  final bool janKnown;
}

enum _PriceKind { regular, sale, member, coupon, bulk }

String _priceKindLabel(_PriceKind kind) => switch (kind) {
  _PriceKind.regular => '通常',
  _PriceKind.sale => '特売',
  _PriceKind.member => '会員',
  _PriceKind.coupon => 'クーポン',
  _PriceKind.bulk => 'まとめ割',
};

/// Shows the manual price entry sheet.
///
/// The sheet itself is the pre-save confirmation: it displays the pending
/// JAN (when recognized), the entered amount, and its price type before the
/// user taps save. Returns the save outcome, or null when dismissed.
Future<ManualSaveOutcome?> showManualPriceSheet(
  BuildContext context,
  ScanScreenController controller, {
  int? initialPriceYen,
  ManualPriceEntry? initialEntry,
  Future<bool> Function(ManualPriceEntry entry)? onSaveEntry,
}) {
  return showModalBottomSheet<ManualSaveOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _ManualPriceForm(
        controller: controller,
        initialPriceYen: initialPriceYen,
        initialEntry: initialEntry,
        onSaveEntry: onSaveEntry,
      ),
    ),
  );
}

class _ManualPriceForm extends StatefulWidget {
  const _ManualPriceForm({
    required this.controller,
    this.initialPriceYen,
    this.initialEntry,
    this.onSaveEntry,
  });

  final ScanScreenController controller;
  final int? initialPriceYen;
  final ManualPriceEntry? initialEntry;

  /// Overrides the default submit path (used for price correction).
  final Future<bool> Function(ManualPriceEntry entry)? onSaveEntry;

  @override
  State<_ManualPriceForm> createState() => _ManualPriceFormState();
}

class _ManualPriceFormState extends State<_ManualPriceForm> {
  late final TextEditingController _priceController = TextEditingController(
    text: widget.initialPriceYen?.toString() ?? '',
  );
  late _PriceKind _kind = widget.initialEntry?.isBulkDiscount == true
      ? _PriceKind.bulk
      : widget.initialEntry?.isCouponPriceVisible == true
      ? _PriceKind.coupon
      : widget.initialEntry?.isMemberPriceVisible == true
      ? _PriceKind.member
      : widget.initialEntry?.isSaleVisible == true
      ? _PriceKind.sale
      : _PriceKind.regular;
  bool _isTaxInclusive = true;
  String? _submitError;
  bool _saving = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  int? get _parsedPrice => int.tryParse(_priceController.text);

  bool get _priceValid {
    final value = _parsedPrice;
    return value != null && value >= 1 && value <= 99999;
  }

  bool get _canSave => !_saving && _priceValid && _isTaxInclusive;

  void _save() async {
    final value = _parsedPrice;
    if (value == null || !_canSave) return;
    setState(() {
      _saving = true;
      _submitError = null;
    });

    final entry = ManualPriceEntry(
      priceYen: value,
      isTaxInclusive: _isTaxInclusive,
      isSaleVisible: _kind == _PriceKind.sale ? true : null,
      isMemberPriceVisible: _kind == _PriceKind.member ? true : null,
      isCouponPriceVisible: _kind == _PriceKind.coupon ? true : null,
      isBulkDiscount: _kind == _PriceKind.bulk ? true : null,
    );
    bool ok;
    try {
      final save = widget.onSaveEntry;
      ok = save != null
          ? await save(entry)
          : widget.controller.submitManualPrice(
              priceYen: entry.priceYen,
              isTaxInclusive: entry.isTaxInclusive,
              isSaleVisible: entry.isSaleVisible,
              isMemberPriceVisible: entry.isMemberPriceVisible,
              isCouponPriceVisible: entry.isCouponPriceVisible,
              isBulkDiscount: entry.isBulkDiscount,
            );
    } catch (_) {
      ok = false;
    }
    // The user may dismiss the sheet while a correction is being persisted.
    // Never call setState or Navigator after its State has been disposed.
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _submitError = '保存できませんでした。スキャン状態を確認してください。';
      });
      return;
    }
    Navigator.of(context).pop(
      ManualSaveOutcome(
        saved: true,
        janKnown: widget.controller.pendingJanCode != null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.onSaveEntry == null ? '価格を手入力' : '価格を訂正',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final jan = widget.onSaveEntry == null
                    ? widget.controller.pendingJanCode
                    : widget.controller.uiState.janCode;
                return Text(
                  jan == null ? 'バーコード未読取：保存は読取後に自動実行されます' : '保存先JAN：$jan',
                  style: TextStyle(
                    color: jan == null ? Colors.orange : Colors.green.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                labelText: '価格（円）',
                suffixText: '円',
                errorText: _priceController.text.isEmpty || _priceValid
                    ? null
                    : '1〜99,999の金額を入力してください',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {
                _submitError = null;
              }),
            ),
            const SizedBox(height: 10),
            const Text('価格の種類', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              children: _PriceKind.values.map((kind) {
                return ChoiceChip(
                  label: Text(_priceKindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text('税区分', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('税込'),
                  selected: _isTaxInclusive,
                  onSelected: (_) => setState(() => _isTaxInclusive = true),
                ),
                ChoiceChip(
                  label: const Text('税抜'),
                  selected: !_isTaxInclusive,
                  onSelected: (_) => setState(() => _isTaxInclusive = false),
                ),
              ],
            ),
            if (!_isTaxInclusive)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '税抜価格は保存できません。税込価格を入力してください。',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('保存する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
