import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _host(Widget child, {double textScale = 1, Size size = const Size(360, 640)}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: ShadApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  _heroTests();

  testWidgets('PillToggle reports taps, is 44dp tall and fits 3 options on 360dp at 2x text',
      (tester) async {
    int? picked;
    await tester.pumpWidget(
      _host(
        PillToggle<int>(
          value: 0,
          options: const [
            (value: 0, label: 'All'),
            (value: 1, label: '1st Sem'),
            (value: 2, label: '2nd Sem'),
          ],
          onChanged: (v) => picked = v,
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('2nd Sem'));
    expect(picked, 2);
    expect(tester.getSize(find.byType(InkWell).first).height, greaterThanOrEqualTo(44));
  });

  testWidgets('ListRow is at least 48dp tall and taps', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(ListRow(title: 'Entry', onTap: () => tapped++)),
    );
    expect(tester.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(kTapTarget));
    await tester.tap(find.byType(ListRow));
    expect(tapped, 1);
  });

  testWidgets('ListRow with long text at 2x text scale does not overflow on a 360dp phone',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ListRow(
          title: 'A very long title that needs to wrap onto several lines on a small phone',
          subtitle: 'And a long subtitle that also needs to wrap without any overflow error',
          leading: Icon(LucideIcons.bell),
          trailing: StatusBadge('Pending', status: AppStatus.warning),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState and ErrorState render, Retry is reachable', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            const SizedBox(height: 300, child: EmptyState(title: 'Nothing here', message: 'Later.')),
            SizedBox(height: 360, child: ErrorState(onRetry: () => retried = true)),
          ],
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('every StatusBadge tone renders in light and dark', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(360, 640)),
          child: ShadApp(
            themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            theme: ShadThemeData(brightness: Brightness.light, colorScheme: const ShadRedColorScheme.light()),
            darkTheme: ShadThemeData(brightness: Brightness.dark, colorScheme: const ShadRedColorScheme.dark()),
            home: Scaffold(
              body: Column(
                children: [
                  for (final s in AppStatus.values) StatusBadge(s.name, status: s),
                ],
              ),
            ),
          ),
        ),
      );
      for (final s in AppStatus.values) {
        expect(find.text(s.name), findsOneWidget);
      }
    }
  });

  testWidgets('AppPage shows the title and a back target only when pushed', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 640)),
        child: ShadApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AppPage(title: 'Inner', children: [Text('body')])),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(LucideIcons.chevronLeft),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == kTapTarget && w.height == kTapTarget,
        ),
      ),
      findsOneWidget,
    );
  });
}

void _heroTests() {
  testWidgets('HeroCard with long figures at 2x text on a 360dp phone does not overflow',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const HeroCard(
          label: 'Total balance for the whole school year',
          icon: LucideIcons.wallet,
          value: 'PHP 1,234,567.89',
          pill: 'SY 2025-2026 · 1st Semester',
          captions: ['A student with a rather long full name Jr.', 'Grade 12 • Section Sampaguita'],
          stats: [(label: 'Total paid', value: 'PHP 999,999.00')],
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Total balance for the whole school year'), findsOneWidget);
  });

  testWidgets('HeroCard shows a progress bar and clamps out-of-range values', (tester) async {
    await tester.pumpWidget(
      _host(const HeroCard(label: 'Evaluation', value: '3 of 4', progress: 1.7)),
    );
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 1.0);
    expect(tester.takeException(), isNull);
  });
}
