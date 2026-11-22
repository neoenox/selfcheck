import '../domain/scan_state.dart';

final RegExp _pricePattern = RegExp(
  r'(?<![0-9])(?:[¥￥]\s*)?([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?(?![0-9])',
);
final RegExp _barePriceLinePattern = RegExp(
  r'^\s*(?:[0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})\s*$',
);
final RegExp _unitPriceAfterUnitPattern = RegExp(
  r'(?:[0-9]+\s*(?:g|kg|ml|l|個|本|枚|袋|パック))'
  r'\s*(?:当たり|あたり|当り|につき)\s*[:：]?\s*'
  r'(?:[（(]?\s*(?:税込(?:価格)?|総額|支払総額|税抜(?:き|価格)?|税別|本体価格)\s*[）)]?\s*)?'
  r'(?:[¥￥]\s*)?'
  r'(?:[0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?',
  caseSensitive: false,
);
final RegExp _unitPriceSlashPattern = RegExp(
  r'(?:[（(]?\s*(?:税込(?:価格)?|総額|支払総額|税抜(?:き|価格)?|税別|本体価格)\s*[）)]?\s*)?'
  r'(?:[¥￥]\s*)?'
  r'(?:[0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?'
  r'\s*(?:[（(]?\s*(?:税込(?:価格)?|総額|支払総額|税抜(?:き|価格)?|税別|本体価格)\s*[）)]?\s*)?'
  r'[/／]\s*[0-9]+\s*(?:g|kg|ml|l|個|本|枚|袋|パック)',
  caseSensitive: false,
);
final RegExp _taxInclusiveAfterPattern = RegExp(
  r'(?:税込(?:価格)?|総額|支払総額)\s*[:：]?\s*(?:[¥￥]\s*)?'
  r'([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})(?:\s*円)?',
);
final RegExp _taxInclusiveBeforePattern = RegExp(
  r'(?:[¥￥]\s*)?([0-9]{1,3}(?:[,，][0-9]{3})+|[0-9]{1,5})'
  r'(?:\s*円)?\s*[（(]?\s*(?:税込(?:価格)?|総額|支払総額)\s*[）)]?',
);
final RegExp _taxExclusiveContextPattern = RegExp(r'(?:税抜(?:き|価格)?|税別|本体価格)');

/// Price-context markers such as regular vs. sale/member prices.
///
/// When these markers coexist with two or more distinct price values in one
/// OCR result, choosing automatically would risk persisting the wrong price
/// (e.g. the regular price instead of the sale price). Such ambiguous
/// results fail closed. Tax markers (税込/税抜/本体価格) are intentionally
/// excluded: tax-inclusive preference already handles those combinations.
final RegExp _priceContextPattern = RegExp(
  r'(通常(?:価格)?|定価|特売|特価|セール|SALE|売出し?|会員(?:価格)?'
  r'|クーポン|まとめ割|割引|お買[いっ]得|奉仕品|大特価|激安)',
  caseSensitive: false,
);

/// Parses a plausible retail price from OCR text without guessing values.
///
/// Explicit unit-price segments are removed before candidate ranking so a
/// product price can still be recognized when OCR groups both values into one
/// text line. A unit-price-only line becomes empty and therefore fails closed.
/// Explicit tax-inclusive totals are preferred because they represent the
/// consumer-facing amount paid. Explicit tax-exclusive-only lines fail closed.
/// Currency-marked candidates are otherwise preferred. A bare number is
/// accepted only when the whole remaining OCR line is numeric, preventing text
/// such as "在庫 12" from being treated as a price. Among equally ranked
/// candidates, the larger OCR region wins.
///
/// Ambiguous multi-price results fail closed: when price-context markers
/// (regular/sale/member, see [_priceContextPattern]) coexist with two or more
/// distinct price values, no price is returned so a wrong amount can never
/// stabilize into the persisted history.
PriceCandidate? parsePriceText(Iterable<({String text, Rect region})> lines) {
  if (_hasDetachedTaxLabel(lines)) return null;
  final candidates = _extractCandidates(lines);
  if (candidates.isEmpty) return null;
  if (_isAmbiguousPriceContext(lines, candidates)) return null;
  _ParsedPrice? best;
  for (final candidate in candidates) {
    if (_isBetterCandidate(candidate, best)) {
      best = candidate;
    }
  }

  if (best == null) return null;
  return PriceCandidate(
    priceYen: best.value,
    confidence: best.confidence,
    region: best.region,
    rawTexts: [best.rawText],
  );
}

/// Returns every ranked price candidate from OCR lines with positions.
///
/// The ranking matches [parsePriceText] (tax-inclusive first, then
/// currency-marked, then bare numbers; larger regions win ties), but all
/// candidates are kept so a JAN-associated nearby price can still be
/// selected after a higher-ranked distant price is rejected. Ambiguous
/// multi-price results fail closed to an empty list, exactly like
/// [parsePriceText] returns null, so ambiguity can never be bypassed by
/// picking another candidate.
List<PriceCandidate> parsePriceCandidates(
  Iterable<({String text, Rect region})> lines,
) {
  if (_hasDetachedTaxLabel(lines)) return [];
  final extracted = _extractCandidates(lines);
  if (extracted.isEmpty) return [];
  if (_isAmbiguousPriceContext(lines, extracted)) return [];

  final indexed = extracted.indexed.toList();
  indexed.sort((a, b) {
    final rank = _compareParsedPrice(a.$2, b.$2);
    if (rank != 0) return rank;
    return a.$1.compareTo(b.$1);
  });
  return [
    for (final entry in indexed)
      PriceCandidate(
        priceYen: entry.$2.value,
        confidence: entry.$2.confidence,
        region: entry.$2.region,
        rawTexts: [entry.$2.rawText],
      ),
  ];
}

// ML Kit can split a tax label from its amount into separate lines. Without
// a reliable association, bare/currency-marked values must not be auto-saved.
bool _hasDetachedTaxLabel(Iterable<({String text, Rect region})> lines) =>
    lines.any(
      (line) =>
          RegExp(r'税込|総額|税抜|税別|本体価格').hasMatch(line.text) &&
          !_pricePattern.hasMatch(line.text),
    );

int _compareParsedPrice(_ParsedPrice a, _ParsedPrice b) {
  if (a.priority != b.priority) return b.priority.compareTo(a.priority);
  if (a.confidence != b.confidence) {
    return b.confidence.compareTo(a.confidence);
  }
  return b.regionArea.compareTo(a.regionArea);
}

/// Returns true when price-context markers coexist with multiple distinct
/// values, meaning automatic selection would be a guess.
bool _isAmbiguousPriceContext(
  Iterable<({String text, Rect region})> lines,
  List<_ParsedPrice> candidates,
) {
  final distinctValues = candidates.map((c) => c.value).toSet();
  if (distinctValues.length < 2) return false;
  return lines.any((line) => _priceContextPattern.hasMatch(line.text));
}

/// Extracts every price candidate from OCR lines using the same ranking
/// inputs as [parsePriceText], without ambiguity filtering or best-pick.
List<_ParsedPrice> _extractCandidates(
  Iterable<({String text, Rect region})> lines,
) {
  final candidates = <_ParsedPrice>[];

  for (final line in lines) {
    final candidateText = _withoutExplicitUnitPrices(line.text).trim();
    if (candidateText.isEmpty) continue;

    final taxInclusive = _parseTaxInclusiveCandidate(
      text: candidateText,
      rawText: line.text,
      region: line.region,
    );
    if (taxInclusive != null) {
      candidates.add(taxInclusive);
      continue;
    }

    if (_taxExclusiveContextPattern.hasMatch(candidateText)) continue;

    for (final match in _pricePattern.allMatches(candidateText)) {
      final value = _parsePriceValue(match.group(1));
      if (value == null) continue;

      final matchedText = match.group(0) ?? '';
      final hasCurrencyMarker =
          matchedText.contains('¥') ||
          matchedText.contains('￥') ||
          matchedText.contains('円');
      if (!hasCurrencyMarker &&
          !_barePriceLinePattern.hasMatch(candidateText)) {
        continue;
      }

      candidates.add(
        _ParsedPrice(
          value: value,
          confidence: hasCurrencyMarker ? 0.90 : 0.70,
          priority: hasCurrencyMarker ? 2 : 1,
          region: line.region,
          rawText: line.text,
        ),
      );
    }
  }

  return candidates;
}

String _withoutExplicitUnitPrices(String text) {
  return text
      .replaceAll(_unitPriceAfterUnitPattern, ' ')
      .replaceAll(_unitPriceSlashPattern, ' ');
}

_ParsedPrice? _parseTaxInclusiveCandidate({
  required String text,
  required String rawText,
  required Rect region,
}) {
  for (final pattern in [
    _taxInclusiveAfterPattern,
    _taxInclusiveBeforePattern,
  ]) {
    final match = pattern.firstMatch(text);
    final value = _parsePriceValue(match?.group(1));
    if (value == null) continue;

    return _ParsedPrice(
      value: value,
      confidence: 0.90,
      priority: 3,
      region: region,
      rawText: rawText,
    );
  }
  return null;
}

int? _parsePriceValue(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll(RegExp(r'[,，]'), '');
  final value = int.tryParse(normalized);
  if (value == null || value < 1 || value > 99999) return null;
  return value;
}

bool _isBetterCandidate(_ParsedPrice candidate, _ParsedPrice? best) {
  if (best == null) return true;
  if (candidate.priority != best.priority) {
    return candidate.priority > best.priority;
  }
  if (candidate.confidence != best.confidence) {
    return candidate.confidence > best.confidence;
  }
  return candidate.regionArea > best.regionArea;
}

class _ParsedPrice {
  const _ParsedPrice({
    required this.value,
    required this.confidence,
    required this.priority,
    required this.region,
    required this.rawText,
  });

  final int value;
  final double confidence;
  final int priority;
  final Rect region;
  final String rawText;

  double get regionArea => region.width.abs() * region.height.abs();
}
