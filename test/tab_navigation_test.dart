import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushtrial/shared/widgets/navigation/tab_navigation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _items = [
  TabNavItem(icon: LucideIcons.house, label: 'Home'),
  TabNavItem(icon: LucideIcons.badgeCheck, label: 'Tap history'),
  TabNavItem(icon: LucideIcons.calendarDays, label: 'Calendar'),
  TabNavItem(icon: LucideIcons.user, label: 'Profile'),
];

Widget _host({
  required int index,
  required ValueChanged<int> onChanged,
  bool collapsed = false,
}) {
  return ShadApp(
    home: Scaffold(
      bottomNavigationBar: TabNavigation(
        items: _items,
        currentIndex: index,
        onChanged: onChanged,
        accent: const Color(0xFFD71920),
        collapsed: collapsed,
      ),
    ),
  );
}

final _pill = find.byKey(const ValueKey('tab_navigation_pill'));

void main() {
  testWidgets('shows every tab and reports taps', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(_host(index: 0, onChanged: (i) => tapped = i));

    for (final item in _items) {
      expect(find.text(item.label), findsOneWidget);
    }
    await tester.tap(find.text('Calendar'));
    expect(tapped, 2);
  });

  testWidgets('fits a narrow phone at large text scale without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
        child: _host(index: 1, onChanged: (_) {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('morphs to a smaller icons-only pill and back', (tester) async {
    await tester.pumpWidget(_host(index: 0, onChanged: (_) {}));
    final fullWidth = tester.getSize(_pill).width;
    final fullHeight = tester.getSize(_pill).height;

    await tester.pumpWidget(_host(index: 0, onChanged: (_) {}, collapsed: true));
    await tester.pump(const Duration(milliseconds: 120));
    final midWidth = tester.getSize(_pill).width;
    expect(midWidth, lessThan(fullWidth)); // already shrinking
    await tester.pumpAndSettle();

    final compact = tester.getSize(_pill);
    expect(compact.width, lessThan(fullWidth * 0.7));
    expect(compact.height, lessThan(fullHeight));
    expect(tester.takeException(), isNull);

    // Icons stay tappable while collapsed.
    var tapped = -1;
    await tester.pumpWidget(_host(index: 0, onChanged: (i) => tapped = i, collapsed: true));
    await tester.tap(find.byIcon(LucideIcons.user));
    expect(tapped, 3);

    await tester.pumpWidget(_host(index: 0, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill).width, closeTo(fullWidth, 0.5));
  });

  testWidgets('keeps a constant footprint while morphing, so the page behind never re-lays out',
      (tester) async {
    await tester.pumpWidget(_host(index: 0, onChanged: (_) {}));
    final slot = tester.getSize(find.byType(TabNavigation));

    await tester.pumpWidget(_host(index: 0, onChanged: (_) {}, collapsed: true));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(TabNavigation)), slot);
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TabNavigation)), slot);
  });
}
