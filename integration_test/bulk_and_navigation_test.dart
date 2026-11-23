// Stage 4 tests: doing things in bulk, and the awkward bits of navigation.
//
// The codelab's test covers the happy path. These try to drive the app more
// like someone actually using it would, scrolling around, tapping too fast and
// going back and forth, and check the favorites list stays right throughout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bulk operations', () {
    testWidgets('favoriting eight items in a loop lists all eight', (
      tester,
    ) async {
      await launchApp(tester);
      const items = [0, 1, 2, 3, 4, 5, 6, 7];

      for (final n in items) {
        await favoriteItem(tester, n);
        // Checking inside the loop rather than once at the end. If item 5 is
        // the one that breaks, the failure says item 5.
        expect(
          heartOf(n, Icons.favorite),
          findsOneWidget,
          reason: 'item $n should show a filled heart after being tapped',
        );
      }

      await openFavorites(tester);

      for (final n in items) {
        // Worth knowing: if the row is missing it's bringIntoView that blows
        // up, not the expect below. The expect is still doing something
        // though, findsOneWidget also catches a row that got drawn twice.
        await bringIntoView(tester, favoriteRow(n));
        expect(
          favoriteRow(n),
          findsOneWidget,
          reason: 'item $n should appear exactly once on the Favorites page',
        );
      }

      // And nothing extra. Without this check the test would still pass if the
      // page somehow listed items we never tapped.
      expect(
        favoriteRow(8),
        findsNothing,
        reason: 'item 8 was never favorited, so it must not be listed',
      );
    });

    testWidgets('removing every favorite in a loop ends at the empty state', (
      tester,
    ) async {
      await launchApp(tester);
      // Not 0,1,2,3,4 on purpose. If the code ever confused "position in the
      // list" with "item number", consecutive numbers would hide it, because
      // for 0,1,2,3,4 those two things are the same value.
      const items = [1, 3, 5, 7, 9];

      for (final n in items) {
        await favoriteItem(tester, n);
      }
      await openFavorites(tester);

      for (final n in items) {
        await bringIntoView(tester, removeButton(n));
        await tapAndSettle(tester, removeButton(n));
        expect(
          favoriteRow(n),
          findsNothing,
          reason: 'item $n should disappear from the list once removed',
        );
      }

      expect(find.text('No favorites added.'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('a fast double tap on one heart leaves the item unfavorited', (
      tester,
    ) async {
      await launchApp(tester);

      // No waiting between the taps. This is the impatient user, where the
      // second tap lands while the first snackbar is still sliding in.
      await tester.tap(homeHeart(0));
      await tester.pump();
      // Check the first tap actually did something. Without this the test
      // would still pass if neither tap registered, since a heart nobody
      // touched looks the same as one toggled twice. expect doesn't draw a
      // frame, so the two taps are still back to back.
      expect(heartOf(0, Icons.favorite), findsOneWidget);

      await tester.tap(homeHeart(0));
      await tester.pump();

      expect(heartOf(0, Icons.favorite_border), findsOneWidget);

      // Two taps means two snackbars queued up. Let them both finish.
      await waitForSnackBarsToClear(tester);
      await openFavorites(tester);
      expect(find.text('No favorites added.'), findsOneWidget);
    });
  });

  group('Navigation edge cases', () {
    testWidgets('repeated round trips between Home and Favorites keep state', (
      tester,
    ) async {
      await launchApp(tester);
      await favoriteItem(tester, 6);

      for (var trip = 1; trip <= 3; trip++) {
        await openFavorites(tester);
        expect(
          favoriteRow(6),
          findsOneWidget,
          reason: 'favorite lost on trip $trip',
        );

        await goBack(tester);
        expect(
          find.text('Testing Sample'),
          findsOneWidget,
          reason: 'did not land back on Home after trip $trip',
        );
      }

      expect(heartOf(6, Icons.favorite), findsOneWidget);
    });

    testWidgets('the Android system back button returns to Home', (
      tester,
    ) async {
      await launchApp(tester);
      await openFavorites(tester);
      expect(find.text('No favorites added.'), findsOneWidget);

      // This is the system back gesture, not the arrow in the app bar. It
      // arrives as a message from the platform and go_router handles it
      // through BackButtonDispatcher, a different path entirely. One can break
      // while the other still works, so both are worth a test.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('Testing Sample'), findsOneWidget);
      expect(find.text('No favorites added.'), findsNothing);
    });

    testWidgets('scroll position and favorite survive a trip to Favorites', (
      tester,
    ) async {
      await launchApp(tester);
      expect(homeHeart(80), findsNothing); // too far down to exist yet

      await favoriteItem(tester, 80);
      expect(
        homeLabel(0),
        findsNothing,
      ); // confirms we really did scroll away from the top

      await openFavorites(tester);
      expect(favoriteRow(80), findsOneWidget);

      await goBack(tester);

      // The home page is actually thrown away while the favorites page is on
      // top of it, I checked. The scroll position comes back because
      // ScrollPosition saves it into PageStorage and reads it again when the
      // list is rebuilt. So this is testing that the position is genuinely
      // saved and restored, not that the page sat there waiting.
      expect(find.text('Testing Sample'), findsOneWidget);
      expect(homeHeart(80), findsOneWidget);
      expect(heartOf(80, Icons.favorite), findsOneWidget);
      expect(homeLabel(0), findsNothing);
    });
  });
}
