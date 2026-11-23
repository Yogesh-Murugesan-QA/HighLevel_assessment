// Stage 4: measuring how smoothly the list scrolls.
//
// Run this with flutter drive, not flutter test:
//
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/scroll_perf.dart \
//     --profile --no-dds -d emulator-5554
//
// Both flags are needed.
//
//   --profile  timing a debug build tells you nothing, debug builds are slow
//              on purpose because of all the extra checks.
//   --no-dds   traceAction talks straight to the VM Service. By default another
//              service sits on that port, and you get a confusing
//              "connection refused" error instead.
//
// The file is called scroll_perf.dart rather than scroll_perf_test.dart so that
// a normal `flutter test integration_test` run skips it. That run doesn't give
// traceAction a VM Service to talk to, so it would fail there anyway.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testing_app/main.dart';

void main() {
  // Hold on to the binding. traceAction is on the binding, not on tester.
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling the 100-item list stays smooth', (tester) async {
    await tester.pumpWidget(const TestingApp());
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;

    // Anything that happens inside here gets recorded and sent back to the
    // driver, filed under the name given in reportKey.
    await binding.traceAction(() async {
      for (var i = 0; i < 5; i++) {
        await tester.fling(list, const Offset(0, -400), 4000);
        await tester.pumpAndSettle();
        await tester.fling(list, const Offset(0, 400), 4000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scroll_timeline');
  });
}
