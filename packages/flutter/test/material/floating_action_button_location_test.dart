// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Basic floating action button locations', () {
    testWidgets('still animates motion when the floating action button is null', (WidgetTester tester) async {
      await tester.pumpWidget(buildFrame(fab: null, location: null));

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(buildFrame(fab: null, location: FloatingActionButtonLocation.endFloat));

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(buildFrame(fab: null, location: FloatingActionButtonLocation.centerFloat));

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('moves fab from center to end and back', (WidgetTester tester) async {
      await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.endFloat));

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 356.0));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.centerFloat));

      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(400.0, 356.0));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.endFloat));

      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 356.0));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('moves to and from custom-defined positions', (WidgetTester tester) async {
      await tester.pumpWidget(buildFrame(location: const _StartTopFloatingActionButtonLocation()));

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(44.0, 56.0));

      await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.centerFloat));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(400.0, 356.0));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(buildFrame(location: const _StartTopFloatingActionButtonLocation()));

      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpAndSettle();

      expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(44.0, 56.0));
      expect(tester.binding.transientCallbackCount, 0);

    });

    group('interrupts in-progress animations without jumps', () {
      _GeometryListener geometryListener;
      ScaffoldGeometry geometry;
      _GeometryListenerState listenerState;
      Size previousRect;
      Iterable<double> previousRotations;

      // The maximum amounts we expect the fab width and height to change
      // during one step of a transition.
      const double maxDeltaWidth = 12.5;
      const double maxDeltaHeight = 12.5;

      // The maximum amounts we expect the fab icon to rotate during one step
      // of a transition.
      const double maxDeltaRotation = 0.09;

      // We'll listen to the Scaffold's geometry for any 'jumps' to detect
      // changes in the size and rotation of the fab.
      void setupListener(WidgetTester tester) {
        // Measure the delta in width and height of the fab, and check that it never grows
        // by more than the expected maximum deltas.
        void check() {
          geometry = listenerState.cache.value;
          final Size currentRect = geometry.floatingActionButtonArea?.size;
          // Measure the delta in width and height of the rect, and check that
          // it never grows by more than a safe amount.
          if (previousRect != null && currentRect != null) {
            final double deltaWidth = currentRect.width - previousRect.width;
            final double deltaHeight = currentRect.height - previousRect.height;
            expect(
              deltaWidth.abs(),
              lessThanOrEqualTo(maxDeltaWidth),
              reason: "The Floating Action Button's width should not change "
                  'faster than $maxDeltaWidth per animation step.\n'
                  'Prevous rect: $previousRect, current rect: $currentRect',
            );
            expect(
              deltaHeight.abs(),
              lessThanOrEqualTo(maxDeltaHeight),
              reason: "The Floating Action Button's width should not change "
                  'faster than $maxDeltaHeight per animation step.\n'
                  'Prevous rect: $previousRect, current rect: $currentRect',
            );
          }
          previousRect = currentRect;

          // Measure the delta in rotation.
          // Check that it never grows by more than a safe amount.
          //
          // Note that there may be multiple transitions all active at
          // the same time. We are concerned only with the closest one.
          final Iterable<RotationTransition> rotationTransitions = tester.widgetList(
            find.byType(RotationTransition),
          );
          final Iterable<double> currentRotations = rotationTransitions.map(
              (RotationTransition t) => t.turns.value);

          if (previousRotations != null && previousRotations.isNotEmpty
              && currentRotations != null && currentRotations.isNotEmpty
              && previousRect != null && currentRect != null) {
            final List<double> deltas = <double>[];
            for (final double currentRotation in currentRotations) {
              double minDelta;
              for (final double previousRotation in previousRotations) {
                final double delta = (previousRotation - currentRotation).abs();
                minDelta ??= delta;
                minDelta = min(delta, minDelta);
              }
              deltas.add(minDelta);
            }

            if (deltas.where((double delta) => delta < maxDeltaRotation).isEmpty) {
              fail("The Floating Action Button's rotation should not change "
                  'faster than $maxDeltaRotation per animation step.\n'
                  'Detected deltas were: $deltas\n'
                  'Previous values: $previousRotations, current values: $currentRotations\n'
                  'Prevous rect: $previousRect, current rect: $currentRect',);
            }
          }
          previousRotations = currentRotations;
        }

        listenerState = tester.state(find.byType(_GeometryListener));
        listenerState.geometryListenable.addListener(check);
      }

      setUp(() {
        // We create the geometry listener here, but it can only be set up
        // after it is pumped into the widget tree and a tester is
        // available.
        geometryListener = _GeometryListener();
        geometry = null;
        listenerState = null;
        previousRect = null;
        previousRotations = null;
      });

      testWidgets('moving the fab to centerFloat', (WidgetTester tester) async {
        // Create a scaffold with the fab at endFloat
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.endFloat, listener: geometryListener));
        setupListener(tester);

        // Move the fab to centerFloat'
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.centerFloat, listener: geometryListener));
        await tester.pumpAndSettle();
      });

      testWidgets('interrupting motion towards the StartTop location.', (WidgetTester tester) async {
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.centerFloat, listener: geometryListener));
        setupListener(tester);

        // Move the fab to the top start after creating the fab.
        await tester.pumpWidget(buildFrame(location: const _StartTopFloatingActionButtonLocation(), listener: geometryListener));
        await tester.pump(kFloatingActionButtonSegue ~/ 2);

        // Interrupt motion to move to the end float
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.endFloat, listener: geometryListener));
        await tester.pumpAndSettle();
      });

      testWidgets('interrupting entrance to remove the fab.', (WidgetTester tester) async {
        await tester.pumpWidget(buildFrame(fab: null, location: FloatingActionButtonLocation.centerFloat, listener: geometryListener));
        setupListener(tester);

        // Animate the fab in.
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.endFloat, listener: geometryListener));
        await tester.pump(kFloatingActionButtonSegue ~/ 2);

        // Remove the fab.
        await tester.pumpWidget(
          buildFrame(
            fab: null,
            location: FloatingActionButtonLocation.endFloat,
            listener: geometryListener,
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('interrupting entrance of a new fab.', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildFrame(
            fab: null,
            location: FloatingActionButtonLocation.endFloat,
            listener: geometryListener,
          ),
        );
        setupListener(tester);

        // Bring in a new fab.
        await tester.pumpWidget(buildFrame(location: FloatingActionButtonLocation.centerFloat, listener: geometryListener));
        await tester.pump(kFloatingActionButtonSegue ~/ 2);

        // Interrupt motion to move the fab.
        await tester.pumpWidget(
          buildFrame(
            location: FloatingActionButtonLocation.endFloat,
            listener: geometryListener,
          ),
        );
        await tester.pumpAndSettle();
      });
    });
  });

  testWidgets('Docked floating action button locations', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildFrame(
        location: FloatingActionButtonLocation.endDocked,
        bab: const SizedBox(height: 100.0),
        viewInsets: EdgeInsets.zero,
      ),
    );

    // Scaffold 800x600, FAB is 56x56, BAB is 800x100, FAB's center is
    // at the top of the BAB.
    expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 500.0));

    await tester.pumpWidget(
      buildFrame(
        location: FloatingActionButtonLocation.centerDocked,
        bab: const SizedBox(height: 100.0),
        viewInsets: EdgeInsets.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(400.0, 500.0));


    await tester.pumpWidget(
      buildFrame(
        location: FloatingActionButtonLocation.endDocked,
        bab: const SizedBox(height: 100.0),
        viewInsets: EdgeInsets.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 500.0));
  });

  testWidgets('Docked floating action button locations: no BAB, small BAB', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildFrame(
        location: FloatingActionButtonLocation.endDocked,
        viewInsets: EdgeInsets.zero,
      ),
    );
    expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 572.0));

    await tester.pumpWidget(
      buildFrame(
        location: FloatingActionButtonLocation.endDocked,
        bab: const SizedBox(height: 16.0),
        viewInsets: EdgeInsets.zero,
      ),
    );
    expect(tester.getCenter(find.byType(FloatingActionButton)), const Offset(756.0, 572.0));
  });

  testWidgets('Mini-start-top floating action button location', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          floatingActionButton: FloatingActionButton(onPressed: () { }, mini: true),
          floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
          body: Column(
            children: const <Widget>[
              ListTile(
                leading: CircleAvatar(),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getCenter(find.byType(FloatingActionButton)).dx, tester.getCenter(find.byType(CircleAvatar)).dx);
    expect(tester.getCenter(find.byType(FloatingActionButton)).dy, kToolbarHeight);
  });

  testWidgets('Start-top floating action button location LTR', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          floatingActionButton: const FloatingActionButton(onPressed: null),
          floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        ),
      ),
    );
    expect(tester.getRect(find.byType(FloatingActionButton)), rectMoreOrLessEquals(const Rect.fromLTWH(16.0, 28.0, 56.0, 56.0)));
  });

  testWidgets('End-top floating action button location RTL', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(),
            floatingActionButton: const FloatingActionButton(onPressed: null),
            floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byType(FloatingActionButton)), rectMoreOrLessEquals(const Rect.fromLTWH(16.0, 28.0, 56.0, 56.0)));
  });

  testWidgets('Start-top floating action button location RTL', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(),
            floatingActionButton: const FloatingActionButton(onPressed: null),
            floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byType(FloatingActionButton)), rectMoreOrLessEquals(const Rect.fromLTWH(800.0 - 56.0 - 16.0, 28.0, 56.0, 56.0)));
  });

  testWidgets('End-top floating action button location LTR', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          floatingActionButton: const FloatingActionButton(onPressed: null),
          floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        ),
      ),
    );
    expect(tester.getRect(find.byType(FloatingActionButton)), rectMoreOrLessEquals(const Rect.fromLTWH(800.0 - 56.0 - 16.0, 28.0, 56.0, 56.0)));
  });
}


class _GeometryListener extends StatefulWidget {
  @override
  State createState() => _GeometryListenerState();
}

class _GeometryListenerState extends State<_GeometryListener> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: cache
    );
  }

  int numNotifications = 0;
  ValueListenable<ScaffoldGeometry> geometryListenable;
  _GeometryCachePainter cache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<ScaffoldGeometry> newListenable = Scaffold.geometryOf(context);
    if (geometryListenable == newListenable)
      return;

    if (geometryListenable != null)
      geometryListenable.removeListener(onGeometryChanged);

    geometryListenable = newListenable;
    geometryListenable.addListener(onGeometryChanged);
    cache = _GeometryCachePainter(geometryListenable);
  }

  void onGeometryChanged() {
    numNotifications += 1;
  }
}


// The Scaffold.geometryOf() value is only available at paint time.
// To fetch it for the tests we implement this CustomPainter that just
// caches the ScaffoldGeometry value in its paint method.
class _GeometryCachePainter extends CustomPainter {
  _GeometryCachePainter(this.geometryListenable) : super(repaint: geometryListenable);

  final ValueListenable<ScaffoldGeometry> geometryListenable;

  ScaffoldGeometry value;
  @override
  void paint(Canvas canvas, Size size) {
    value = geometryListenable.value;
  }

  @override
  bool shouldRepaint(_GeometryCachePainter oldDelegate) {
    return true;
  }
}

Widget buildFrame({
  FloatingActionButton fab = const FloatingActionButton(
    onPressed: null,
    child: Text('1'),
  ),
  FloatingActionButtonLocation location,
  _GeometryListener listener,
  TextDirection textDirection = TextDirection.ltr,
  EdgeInsets viewInsets = const EdgeInsets.only(bottom: 200.0),
  Widget bab,
}) {
  return Localizations(
    locale: const Locale('en', 'us'),
    delegates: const <LocalizationsDelegate<dynamic>>[
      DefaultWidgetsLocalizations.delegate,
      DefaultMaterialLocalizations.delegate,
    ],
    child: Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: MediaQueryData(viewInsets: viewInsets),
      child: Scaffold(
        appBar: AppBar(title: const Text('FabLocation Test')),
        floatingActionButtonLocation: location,
        floatingActionButton: fab,
        bottomNavigationBar: bab,
        body: listener,
      ),
    ),
  ));
}

class _StartTopFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _StartTopFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    double fabX;
    assert(scaffoldGeometry.textDirection != null);
    switch (scaffoldGeometry.textDirection) {
      case TextDirection.rtl:
        final double startPadding = kFloatingActionButtonMargin + scaffoldGeometry.minInsets.right;
        fabX = scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width - startPadding;
        break;
      case TextDirection.ltr:
        final double startPadding = kFloatingActionButtonMargin + scaffoldGeometry.minInsets.left;
        fabX = startPadding;
        break;
    }
    final double fabY = scaffoldGeometry.contentTop - (scaffoldGeometry.floatingActionButtonSize.height / 2.0);
    return Offset(fabX, fabY);
  }
}
