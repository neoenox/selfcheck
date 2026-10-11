import '../domain/scan_state.dart';

/// PriceStabilizer - detects stable price readings across OCR frames.
///
/// Each frame contributes its ranked price candidates via [submitFrame]
/// ([submit] treats one candidate as a single-candidate frame). A value is
/// stable only when it appears in every one of the last three frames, so a
/// nearby price can stabilize alongside a higher-ranked distant price and
/// the JAN-associated candidate can then be selected. Callers that persist
/// or compare prices must use the stable candidates.
class PriceStabilizer {
  final List<List<PriceCandidate>> _frames = [];
  int? _currentPrice;
  double _confidence = 0.0;
  List<PriceCandidate> _stableCandidates = const [];

  /// Submit a price candidate and return true if any value is stable.
  ///
  /// [currentPrice] always reflects the latest OCR candidate, while
  /// [stablePrice] is populated only after three consecutive frames
  /// containing the value. Callers that persist or compare prices must use
  /// [stablePrice]. This is equivalent to [submitFrame] with one candidate.
  bool submit(PriceCandidate candidate) => submitFrame([candidate]);

  /// Submit one frame's ranked candidates; true when any value is stable.
  ///
  /// Empty frames (e.g. ambiguous OCR rejected upstream) are ignored and
  /// leave the current stability untouched.
  bool submitFrame(List<PriceCandidate> candidates) {
    if (candidates.isEmpty) return _stableCandidates.isNotEmpty;

    // De-duplicate by value, keeping the top-ranked candidate per value.
    final seen = <int>{};
    final unique = <PriceCandidate>[];
    for (final candidate in candidates) {
      if (seen.add(candidate.priceYen)) unique.add(candidate);
    }

    _currentPrice = unique.first.priceYen;
    _confidence = unique.first.confidence;
    _frames.add(unique);
    if (_frames.length > 5) {
      _frames.removeAt(0);
    }

    _stableCandidates = _computeStable();
    return _stableCandidates.isNotEmpty;
  }

  List<PriceCandidate> _computeStable() {
    if (_frames.length < 3) return const [];
    final recent = _frames.sublist(_frames.length - 3);

    final common = recent.first.map((c) => c.priceYen).toSet();
    for (final frame in recent.skip(1)) {
      common.retainAll(frame.map((c) => c.priceYen));
    }
    if (common.isEmpty) return const [];

    // Latest region per stable value, ordered by latest-frame rank.
    return [
      for (final candidate in recent.last)
        if (common.contains(candidate.priceYen)) candidate,
    ];
  }

  /// Latest OCR candidate value, regardless of stability.
  int? get currentPrice => _currentPrice;

  /// Confidence of the latest OCR candidate.
  double get confidence => _confidence;

  /// Top-ranked value that passed the three-frame stability requirement.
  int? get stablePrice =>
      _stableCandidates.isEmpty ? null : _stableCandidates.first.priceYen;

  /// Confidence associated with [stablePrice].
  double get stableConfidence =>
      _stableCandidates.isEmpty ? 0.0 : _stableCandidates.first.confidence;

  /// Candidate, including its image region, that produced [stablePrice].
  PriceCandidate? get stableCandidate =>
      _stableCandidates.isEmpty ? null : _stableCandidates.first;

  /// Every value stable across the last three frames, in latest-frame rank
  /// order, each carrying its most recent image region.
  List<PriceCandidate> get stableCandidates =>
      List.unmodifiable(_stableCandidates);

  void reset() {
    _frames.clear();
    _currentPrice = null;
    _confidence = 0.0;
    _stableCandidates = const [];
  }
}
