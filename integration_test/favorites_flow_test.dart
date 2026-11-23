// Stage 4 tests: flows the codelab doesn't cover.
// Each test starts the app fresh, so none of them share any state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Finders and steps live in helpers.dart, shared with the other test file.
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Home page', () {
    testWidgets('tapping the heart twice adds then removes the item', (
      tester,
    ) async {
      await launchApp(tester);
      expect(heartOf(0, Icons.favorite_border), findsOneWidget);

      await tester.tap(homeHeart(0));
      await tester.pump(); // one frame: snackbar is now visible
      expect(find.text('Added to favorites.'), findsOneWidget);
      expect(heartOf(0, Icons.favorite), findsOneWidget);

      // The first snackbar has to be gone before we tap again. Flutter queues
      // them, so if one is still showing the next waits behind it and we'd
      // still be looking at 'Added to favorites.' after the second tap.
      await waitForSnackBarsToClear(tester);
      expect(find.text('Added to favorites.'), findsNothing);

      await tester.tap(homeHeart(0));
      await tester.pump();
      expect(find.text('Removed from favorites.'), findsOneWidget);
      expect(heartOf(0, Icons.favorite_border), findsOneWidget);
    });

    testWidgets('an item far down the list can be scrolled to and favorited', (
      tester,
    ) async {
      await launchApp(tester);
      final item50 = homeHeart(50);
      expect(item50, findsNothing); // not built until scrolled into view

      // This used to call scrollUntilVisible directly, and it passed on Android
      // but failed on an iPhone 16 simulator. scrollUntilVisible stops once the
      // row has been built, which isn't the same as it being on screen. On the
      // shorter iOS screen (852 tall) the heart ended up at y=880, so the tap
      // landed past the bottom edge and did nothing. bringIntoView calls
      // ensureVisible afterwards, which fixes it on both.
      await bringIntoView(tester, item50);
      await tapAndSettle(tester, item50);
      expect(heartOf(50, Icons.favorite), findsOneWidget);

      await openFavorites(tester);
      expect(favoriteRow(50), findsOneWidget);
    });
  });

  group('Favorites page', () {
    testWidgets('shows the empty state when nothing is favorited', (
      tester,
    ) async {
      await launchApp(tester);
      await openFavorites(tester);

      expect(find.text('No favorites added.'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('lists favorites in the order they were added', (tester) async {
      await launchApp(tester);
      await tapAndSettle(tester, homeHeart(3));
      await tapAndSettle(tester, homeHeart(1));
      await openFavorites(tester);

      final first = tester.getTopLeft(favoriteRow(3));
      final second = tester.getTopLeft(favoriteRow(1));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('removing the last favorite shows the empty state', (
      tester,
    ) async {
      await launchApp(tester);
      await tapAndSettle(tester, homeHeart(4));
      await openFavorites(tester);

      await tapAndSettle(tester, removeButton(4));
      expect(favoriteRow(4), findsNothing);
      expect(find.text('No favorites added.'), findsOneWidget);
    });
  });

  group('Navigation and shared state', () {
    testWidgets('removing on Favorites updates the heart on Home', (
      tester,
    ) async {
      await launchApp(tester);
      await tapAndSettle(tester, homeHeart(2));
      await tapAndSettle(tester, homeHeart(5));
      await openFavorites(tester);

      await tapAndSettle(tester, removeButton(2));

      await tester.pageBack(); // the AppBar back button
      await tester.pumpAndSettle();

      expect(find.text('Testing Sample'), findsOneWidget);
      expect(heartOf(2, Icons.favorite_border), findsOneWidget);
      expect(heartOf(5, Icons.favorite), findsOneWidget);
    });
  });
}
