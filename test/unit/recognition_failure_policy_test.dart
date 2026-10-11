import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/recognition_failure_policy.dart';

void main() {
  group('RecognitionFailurePolicy', () {
    test('notifies only after consecutive frame failures', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isTrue);
      expect(policy.recordFailure(), isFalse);
      expect(policy.consecutiveFailures, 4);
    });

    test('a successful frame resets the failure streak', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      policy.recordSuccess();

      expect(policy.consecutiveFailures, 0);
      expect(policy.recordFailure(), isFalse);
    });

    test('fatal failures notify immediately', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(fatal: true), isTrue);
      expect(policy.consecutiveFailures, 1);
    });

    test('re-notifies at intervals while failures continue', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse); // 1
      expect(policy.recordFailure(), isFalse); // 2
      expect(policy.recordFailure(), isTrue); // 3: first notification
      expect(policy.recordFailure(), isFalse); // 4: no flood
      expect(policy.recordFailure(), isFalse); // 5: no flood
      expect(policy.recordFailure(), isTrue); // 6: re-notification
      expect(policy.recordFailure(), isFalse); // 7
      expect(policy.recordFailure(), isFalse); // 8
      expect(policy.recordFailure(), isTrue); // 9: re-notification
    });

    test('success resets the streak and the next threshold notifies again', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isTrue);
      policy.recordSuccess();

      expect(policy.consecutiveFailures, 0);
      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(), isTrue);
    });

    test('fatal failure notifies even after non-fatal failures', () {
      final policy = RecognitionFailurePolicy(threshold: 3);

      expect(policy.recordFailure(), isFalse);
      expect(policy.recordFailure(fatal: true), isTrue);
    });

    test('supports a custom re-notification interval', () {
      final policy = RecognitionFailurePolicy(
        threshold: 2,
        renotifyInterval: 5,
      );

      expect(policy.recordFailure(), isFalse); // 1
      expect(policy.recordFailure(), isTrue); // 2: first notification
      for (var i = 0; i < 4; i++) {
        expect(policy.recordFailure(), isFalse); // 3..6: no flood
      }
      expect(policy.recordFailure(), isTrue); // 7: re-notification
    });
  });
}
