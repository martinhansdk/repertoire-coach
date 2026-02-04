import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/services/error_reporter.dart';

void main() {
  // SupabaseService.isInitialized is false by default in the test
  // environment, so every call below exercises the early-return path.
  // The critical contract: report() must never throw, regardless of
  // what is passed in.  The actual Supabase insert path cannot be
  // exercised without a live project; it is covered by the internal
  // try/catch and by integration testing.

  group('ErrorReporter', () {
    test('report is a no-op when Supabase is not initialised', () {
      expect(
        () => ErrorReporter.report(
          Exception('test error'),
          stackTrace: StackTrace.empty,
          screen: 'test_screen',
        ),
        returnsNormally,
      );
    });

    test('report accepts null stackTrace and screen', () {
      expect(
        () => ErrorReporter.report(Exception('no context')),
        returnsNormally,
      );
    });

    test('report accepts non-Exception error objects', () {
      // Dart errors can be any Object (e.g. a plain String).
      expect(
        () => ErrorReporter.report('string error', screen: 'test'),
        returnsNormally,
      );
    });
  });
}
