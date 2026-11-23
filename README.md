# testing_app

My submission for stages 3 and 4 of the Flutter SDET challenge.

The app comes from the "How to test a Flutter app" codelab. It shows a list of
100 items. Tapping the heart on a row favorites it, and a second page lists
everything you've favorited so far. Both pages read from the same `Favorites`
object, so a change made on one page has to show up on the other.

Stage 3 was the codelab's own integration test, which is still here untouched.
Stage 4 is everything else: six more integration tests, a file of shared
helpers, and a separate test that measures scrolling performance.

I was new to Flutter testing when I started this, so I've written up the things
that confused me at the bottom. The snackbar one in particular took a while to
work out.

## What's where

```
lib/                       the app being tested (I didn't change it)
test/                      unit and widget tests from the codelab (7 tests)
integration_test/
  app_test.dart                   stage 3, the codelab's test
  favorites_flow_test.dart        stage 4, flows beyond the codelab
  bulk_and_navigation_test.dart   stage 4, loops and navigation
  helpers.dart                    shared finders and steps
  scroll_perf.dart                stage 4, the performance test
test_driver/
  perf_driver.dart                the other half of the performance test
```

Two files don't end in `_test.dart` and that's on purpose. `flutter test` only
picks up files ending that way, so `helpers.dart` gets treated as a library
instead of an empty test suite. `scroll_perf.dart` has to be excluded for a
different reason, explained below.

## Running the tests

```bash
flutter test                                  # 7 unit and widget tests, no device needed
flutter test integration_test -d <device>     # 13 integration tests, needs a device
flutter devices                               # to find your device id
```

I've run these on an Android emulator (Android 16) and on an iPhone 16
simulator. Both come out at 13 passing. Running on the second platform was
worth doing, see the third finding below.

The performance test is run differently, because it's really two programs. One
half runs on the phone and records what happened. The other half runs on your
laptop and turns that recording into numbers.

```bash
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_perf.dart \
  --profile --no-dds -d <device>
```

Both of those flags are needed. `--profile` because timing a debug build tells
you nothing useful, debug builds are slow on purpose. `--no-dds` because the
tracing code talks straight to the VM Service, and by default another service
sits on that port and blocks it. Leave it off and you get a connection refused
error that doesn't obviously explain itself.

## What the stage 4 tests check

In `favorites_flow_test.dart`:

- Tapping a heart twice adds the item and then removes it again
- An item far down the list (item 50) can be scrolled to and favorited
- The favorites page shows its empty message when nothing is favorited
- Favorites come out in the order you added them
- Removing the last favorite brings the empty message back
- Removing something on the favorites page updates the heart back on the home page

In `bulk_and_navigation_test.dart`:

- Favoriting eight items in a loop lists all eight, and nothing extra
- Removing five favorites in a loop ends up at the empty state
- Tapping one heart twice very fast leaves the item unfavorited
- Going back and forth between the two pages three times doesn't lose anything
- The Android back button gets you home, not just the arrow in the app bar
- Scrolling down to item 80, visiting favorites and coming back keeps your place

A few deliberate choices in there:

The loop test removes items 1, 3, 5, 7 and 9 rather than 0 through 4. If the
code ever mixed up "position in the list" with "item number", a run of
consecutive numbers would hide it, because for 0,1,2,3,4 those two things are
the same number.

The back button test uses `handlePopRoute()` instead of tapping the back arrow.
On Android most people use the system back gesture, and go_router handles that
through a completely different path than the arrow in the app bar. One can break
while the other still works.

The double tap test asserts after the first tap as well as after the second.
Without that middle check the test would still pass if neither tap did anything
at all, since an untouched heart looks the same as one that was toggled twice.

I used the keys the app already has (`icon_0`, `favorites_text_3` and so on)
rather than searching for text on screen, since text changes when wording or
translations change but keys don't.

## Performance numbers

The test flings the list up and down ten times while recording. Results land in
`build/scroll_timeline.timeline_summary.json`.

For 60fps you get about 16.7ms per frame, split between building the frame in
Dart and actually drawing it.

```
frame build    average 3.85ms   worst 30.67ms    2 of 55 frames over budget
drawing        average 16.73ms  worst 92.29ms   19 of 55 frames over budget
```

So the Dart side is fine and the drawing side is struggling. The honest caveat
is that this was measured on an emulator, where drawing is done in software and
is slow no matter what the app does. I'd want to re-run it on a real phone
before saying anything about the app itself.

I didn't add a pass/fail threshold for this. Without a trustworthy baseline a
threshold just fails randomly and people start ignoring it.

## Three things I found along the way

### A flaky test

One of the tests failed on my machine even though it had passed before. Rather
than assume I'd broken it with my own changes, I put the original version back
in a scratch file and ran it. It failed four times out of four, so the problem
was already there.

The line causing it was:

```dart
await tester.pumpAndSettle(const Duration(seconds: 1));
```

That reads like "wait one second", which is what I assumed too. It isn't. The
duration is how big a step to take between redraws, and the function stops as
soon as nothing is animating. A snackbar stays up for a second using a timer,
and a timer isn't an animation, so this returns while the snackbar is still on
screen.

That matters because Flutter queues snackbars. Showing a second one while the
first is still visible puts it in a queue behind it. So the test tapped again,
looked for the new message, and found the old one still sitting there.

Whether it passed came down to how much real time that line happened to use up,
which is why it worked on some runs and not others.

The fix was to stop guessing at timing and just watch for the thing I cared
about. `waitForSnackBarsToClear` in `helpers.dart` checks whether a snackbar is
on screen, waits a bit, and checks again, with a timeout so it fails loudly
instead of hanging.

### A race in the codelab's own test

While trying to use the Flutter Inspector I found you can run an integration
test like an app:

```bash
flutter run integration_test/app_test.dart -d <device>
```

That gives you DevTools and hot reload while the test drives the app, which is
genuinely useful when a finder isn't matching and you want to see the real
widget tree.

Running `app_test.dart` that way fails with `Found 0 widgets with key
[<'icon_0'>]`. The test calls `pumpWidget` and then taps straight away, but
`pumpWidget` only draws one frame and the list rows aren't there yet on that
first frame. Adding a single `pumpAndSettle()` fixes it, which I confirmed in a
copy of the file.

I left `app_test.dart` alone so it stays an honest record of what the codelab
produced. My own tests go through a `launchApp()` helper that settles after
`pumpWidget`, so they don't have the problem.

### A test that only worked because of the screen size

Once I had the suite green on Android I tried it on an iPhone 16 simulator. One
test failed there: the one that scrolls down to item 50 and favorites it.

It turned out not to be an iOS problem. The test was calling
`scrollUntilVisible` and then tapping straight away. That function stops as soon
as the row has been built, and built isn't the same as being on screen. The
iPhone screen is 852 pixels tall and the heart came to rest at 880, so it was
sitting 28 pixels below the bottom edge. The tap went nowhere. The Android
emulator I'd been using has a taller screen, so the row happened to fit and the
bug never showed up.

Flutter did warn about it, with "a call to tap() ... would not hit test on the
specified widget", but that's only a warning. The test carried on and failed a
line later on the assertion instead, so the error at the bottom of the output
pointed somewhere else. Worth reading the whole thing rather than the last bit.

The fix was to route it through the same `bringIntoView` helper the newer tests
use, which calls `ensureVisible` after scrolling. That was the one test still
doing its own scrolling, and it's the one that broke on a different screen.

The first two of these come down to the same mistake, assuming time has passed
instead of checking something actually happened. The third is the same idea in
space rather than time, assuming something is where you want it instead of
making sure.

## Things I didn't get to

- No accessibility checks, Flutter has `meetsGuideline` for contrast and tap target size
- No screenshots saved as evidence of a run
- Not set up in CI
- I test items 0, 50 and 80 but never item 99, the last one in the list
