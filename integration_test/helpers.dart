// Shared finders and steps used by the integration tests.
//
// Note the name: helpers.dart, not helpers_test.dart. `flutter test` only picks
// up files ending in _test.dart, so naming it this way stops the runner from
// treating it as a test file with no tests in it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_app/main.dart';

// Starts the app from scratch. Every test calls this, so nothing one test
// favorites can leak into the next one.
Future<void> launchApp(WidgetTester tester) async {
  await tester.pumpWidget(const TestingApp());
  await tester.pumpAndSettle(); // let the first screen finish building
}

// Finders for the widgets we touch.
//
// The app already puts keys on these (Key('icon_0') and so on), so we look them
// up by key rather than by the text they show. Text changes when someone
// rewords a label or adds a translation. Keys don't.

Finder homeHeart(int n) => find.byKey(ValueKey('icon_$n'));

Finder homeLabel(int n) => find.byKey(ValueKey('text_$n'));

Finder favoriteRow(int n) => find.byKey(ValueKey('favorites_text_$n'));

Finder removeButton(int n) => find.byKey(ValueKey('remove_icon_$n'));

// The heart icon inside item n's button, either the filled or the outlined one.
// It has to be scoped to that button. find.byIcon(Icons.favorite) on its own
// would match every filled heart on the screen, not just the one we mean.
Finder heartOf(int n, IconData icon) =>
    find.descendant(of: homeHeart(n), matching: find.byIcon(icon));

// Waits until there is no snackbar on screen.
//
// You'd expect pumpAndSettle(Duration(seconds: 1)) to do this. It doesn't, and
// that cost me a while. The duration is the size of each step it takes, not how
// long it waits, and it stops as soon as nothing is animating. A snackbar sits
// there for a second on a timer, and a timer isn't an animation, so
// pumpAndSettle can come back while the snackbar is still up.
//
// That matters because Flutter queues snackbars. If one is still showing, the
// next one lines up behind it, so a test looking for the new message finds the
// old one and fails.
//
// Rather than guess at timings, just keep looking until it's gone.
Future<void> waitForSnackBarsToClear(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await tester.pumpAndSettle();
  final deadline = DateTime.now().add(timeout);
  while (find.byType(SnackBar).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('A snackbar was still on screen after $timeout.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

// Taps something and waits for the snackbar it causes to appear and go away,
// so the next step starts from a quiet screen.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await waitForSnackBarsToClear(tester);
}

// Taps the Favorites button in the home page's app bar.
Future<void> openFavorites(WidgetTester tester) async {
  await tester.tap(find.text('Favorites'));
  await tester.pumpAndSettle();
}

// Goes back using the arrow in the app bar.
Future<void> goBack(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

// Scrolls something into view if it isn't on screen already.
//
// ListView.builder only builds the rows near the visible area, so a finder for
// a row further down genuinely finds nothing until you scroll to it. That's not
// a timing problem and pumping more won't help.
//
// Doing this instead of assuming "the first few rows fit on screen" is also
// what keeps these tests working on a smaller phone.
Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  // scrollUntilVisible stops once the widget exists, which can still leave it a
  // few pixels off screen. ensureVisible finishes the job, otherwise a tap can
  // land on nothing.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

// Scrolls to item n on the home page and favorites it.
Future<void> favoriteItem(WidgetTester tester, int n) async {
  await bringIntoView(tester, homeHeart(n));
  await tapAndSettle(tester, homeHeart(n));
}
