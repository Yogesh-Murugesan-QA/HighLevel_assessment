// This is the laptop half of the performance test. flutter drive runs this
// here while scroll_perf.dart runs on the phone. The phone sends its recording
// back and this turns it into readable numbers.
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;

      final timeline = driver.Timeline.fromJson(
        data['scroll_timeline'] as Map<String, dynamic>,
      );
      final summary = driver.TimelineSummary.summarize(timeline);

      // This writes two files into build/. The .timeline.json one is the raw
      // recording, which you can open in Chrome at chrome://tracing. The
      // .timeline_summary.json one is the useful bit: average, worst and
      // percentile times for building and drawing each frame.
      await summary.writeTimelineToFile(
        'scroll_timeline',
        pretty: true,
        includeSummary: true,
      );
    },
  );
}
