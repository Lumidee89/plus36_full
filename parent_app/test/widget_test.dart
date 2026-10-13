import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_parent/src/core/theme.dart';
import 'package:schoolos_parent/src/core/widgets/success_bottom_sheet.dart';
import 'package:schoolos_parent/src/features/onboarding/onboarding_screen.dart';
import 'package:schoolos_parent/src/features/children/selected_child.dart';

void main() {
  test('SchoolOS theme uses the website brand palette', () {
    final theme = schoolTheme();
    expect(theme.colorScheme.primary, AppColors.forest);
    expect(theme.colorScheme.secondary, AppColors.mint);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      startsWith('InstrumentSans'),
    );
  });

  test(
    'selected child follows the parent choice instead of the first child',
    () {
      final children = [
        {'id': 10, 'name': 'First Child'},
        {'id': 20, 'name': 'Second Child'},
      ];

      expect(selectedChild(children, 20)['name'], 'Second Child');
      expect(selectedChild(children, null)['name'], 'First Child');
    },
  );

  testWidgets('onboarding presents three pages and completes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: schoolTheme(),
        home: OnboardingScreen(onComplete: () async => completed = true),
      ),
    );

    expect(
      find.text("Your child's school life, all in one place"),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    await tester.pumpAndSettle();
    expect(
      find.text('Celebrate every step of their learning journey'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    await tester.pumpAndSettle();
    expect(
      find.text('Stay close to the school, wherever you are'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('success feedback is presented as a branded bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: schoolTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSuccessBottomSheet(
                context,
                title: 'Login successful',
                message: 'Your dashboard is ready.',
              ),
              child: const Text('Show success'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show success'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('success-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('success-animation')), findsOneWidget);
    expect(find.text('Login successful'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('success-sheet-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('success-bottom-sheet')), findsNothing);
  });
}
