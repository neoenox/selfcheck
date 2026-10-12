import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repository usage contract (issue #90 follow-up).
///
/// Data-integrity verification found NO production bypass around
/// [CorrectPriceUseCase]: `correctObservation` is only reachable via the
/// use-case, `invalidateObservation` is only called inside the
/// `AppDatabase.correctObservation` transaction, `insertObservation` is only
/// called by `CompareUseCase` for new observations, and
/// `insertObservationWithDate` has no production callers (test helper only).
/// Validation (1-99,999 yen, tax-inclusive only) lives solely in the use-case,
/// so a future caller reaching the repository/database directly could corrupt
/// history (e.g. non-strict `insertOrIgnore` + duplicate-key lookup silently
/// returning a different row that shares the 5-minute bucket).
///
/// This test scans `lib/` and fails if any hand-written file outside the
/// allowlist below references these methods, forcing future correction UI
/// (currently unwired) to route through `CorrectPriceUseCase`.
void main() {
  group('repository usage contract (issue #90)', () {
    test('no production bypass around CorrectPriceUseCase', () {
      final lib = Directory('lib');
      expect(
        lib.existsSync(),
        isTrue,
        reason: 'expected to run from the package root',
      );

      const allowlist = {
        'correctObservation': {
          'lib/application/correct_price_use_case.dart',
          'lib/infrastructure/price_repository.dart',
          'lib/infrastructure/price_repository_impl.dart',
          'lib/infrastructure/database/app_database.dart',
        },
        'invalidateObservation': {
          'lib/infrastructure/database/app_database.dart',
        },
        'insertObservation': {
          'lib/application/compare_use_case.dart',
          'lib/infrastructure/price_repository.dart',
          'lib/infrastructure/price_repository_impl.dart',
          'lib/infrastructure/database/app_database.dart',
        },
        'insertObservationWithDate': {
          'lib/infrastructure/price_repository.dart',
          'lib/infrastructure/price_repository_impl.dart',
          'lib/infrastructure/database/app_database.dart',
        },
      };

      final patterns = {
        for (final name in allowlist.keys)
          // `insertObservation` must not match `insertObservationWithDate`:
          // the next char after the name must be `(` (modulo whitespace).
          name: RegExp('$name\\s*\\('),
      };

      final violations = <String>[];
      final files =
          lib
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              // Generated Drift code cannot contain hand-written bypasses.
              .where((f) => !f.path.endsWith('.g.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(files, isNotEmpty, reason: 'expected Dart sources under lib/');

      for (final file in files) {
        final path = file.path.replaceAll('\\', '/');
        final code = _stripComments(file.readAsStringSync()).split('\n');
        for (final entry in patterns.entries) {
          if (allowlist[entry.key]!.contains(path)) continue;
          for (var i = 0; i < code.length; i++) {
            if (entry.value.hasMatch(code[i])) {
              violations.add('$path:${i + 1}: ${entry.key}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'production bypass detected; route corrections through '
            'CorrectPriceUseCase:\n${violations.join('\n')}',
      );
    });
  });
}

String _stripComments(String source) {
  var stripped = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return stripped
      .split('\n')
      .map((line) {
        final index = line.indexOf('//');
        return index < 0 ? line : line.substring(0, index);
      })
      .join('\n');
}
