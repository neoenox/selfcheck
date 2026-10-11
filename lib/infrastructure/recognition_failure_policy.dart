/// Decides when repeated frame-level recognition failures are actionable.
///
/// A single failed frame is expected on a live camera stream. Callers should
/// publish the underlying error only when [recordFailure] returns true, or
/// when the failure is known to be fatal. Any successfully completed frame
/// resets the streak so transient camera/ML Kit failures can recover.
///
/// The first notification fires when [threshold] consecutive failures
/// accumulate. If failures continue without a successful frame, a repeat
/// notification fires every [renotifyInterval] additional failures so a
/// sustained outage stays visible without flooding listeners on every frame.
class RecognitionFailurePolicy {
  RecognitionFailurePolicy({this.threshold = 3, this.renotifyInterval = 3})
    : assert(threshold > 0, 'threshold must be positive'),
      assert(renotifyInterval > 0, 'renotifyInterval must be positive');

  final int threshold;
  final int renotifyInterval;
  int consecutiveFailures = 0;

  bool recordFailure({bool fatal = false}) {
    consecutiveFailures++;
    if (fatal) return true;
    if (consecutiveFailures == threshold) return true;
    if (consecutiveFailures > threshold &&
        (consecutiveFailures - threshold) % renotifyInterval == 0) {
      return true;
    }
    return false;
  }

  void recordSuccess() {
    consecutiveFailures = 0;
  }
}
