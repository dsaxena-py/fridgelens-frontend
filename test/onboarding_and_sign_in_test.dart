import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _page1 = 'See what you can make with the food you already have.';
const _page2 = 'Scan, then take a quick look.';
const _page3 = 'Cook with what you have.';

Future<void> _fillAndSubmit(WidgetTester tester, {String? name, required String email, required String password}) async {
  Future<void> type(String label, String text) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  if (name != null) await type('First name (optional)', name);
  await type('Email', email);
  await type('Password', password);
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  group('onboarding', () {
    testWidgets('walks through three pages and ends with account choices', (tester) async {
      final app = await pumpApp(tester);
      expect(find.text(_page1), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(_page2), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0)); // swiping works too
      await tester.pumpAndSettle();
      expect(find.text(_page3), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(app.prefs.getBool('onboarding_seen'), isTrue);

      await tester.tap(find.byTooltip('Back')); // back returns to onboarding
      await tester.pumpAndSettle();
      expect(find.text(_page3), findsOneWidget);
    });

    testWidgets('skip goes straight to sign in', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('is not shown again once seen', (tester) async {
      await pumpApp(tester, prefs: {'onboarding_seen': true});
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('fits a small phone with large text ($brightness)', (tester) async {
        await pumpApp(tester, size: const Size(320, 568), textScale: 2, brightness: brightness);
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(find.text(_page3), 100, scrollable: find.byType(Scrollable).at(1));
        expect(find.text(_page3), findsOneWidget);
        expect(tester.takeException(), isNull); // no overflow
      });
    }
  });

  group('sign in', () {
    testWidgets('validates the form before calling Supabase', (tester) async {
      final app = await pumpApp(tester, prefs: {'onboarding_seen': true});
      await _fillAndSubmit(tester, email: 'not-an-email', password: '');
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(app.auth.calls, isEmpty);
    });

    testWidgets('shows a clear message for a wrong password, then signs in', (tester) async {
      final app = await pumpApp(tester, prefs: {'onboarding_seen': true});
      await _fillAndSubmit(tester, email: 'cook@example.com', password: 'wrong');
      expect(find.text("That email and password don't match. Try again."), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget); // not colour alone

      await _fillAndSubmit(tester, email: 'cook@example.com', password: 'correct-horse');
      expect(find.text("You're signed in"), findsOneWidget);
      expect(find.text('cook@example.com'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(app.auth.signedIn, isFalse);
    });

    testWidgets('create account asks for 8+ characters and signs straight in', (tester) async {
      final app = await pumpApp(tester, prefs: {'onboarding_seen': true});
      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);

      await _fillAndSubmit(tester, name: 'Dhiransh', email: 'new@example.com', password: 'short');
      expect(find.text('Use at least 8 characters'), findsOneWidget);

      await _fillAndSubmit(tester, name: 'Dhiransh', email: 'new@example.com', password: 'long-enough');
      expect(app.auth.calls.last, 'signUp new@example.com Dhiransh');
      expect(find.text("You're signed in"), findsOneWidget);
    });

    testWidgets('when email confirmation is on, explains what to do next', (tester) async {
      await pumpApp(tester, prefs: {'onboarding_seen': true}, auth: FakeAuth(requireConfirmation: true));
      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester, email: 'new@example.com', password: 'long-enough');
      expect(find.text('Check your inbox for a confirmation link, then sign in here.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('fits a small phone with large text', (tester) async {
      await pumpApp(tester, prefs: {'onboarding_seen': true}, size: const Size(320, 568), textScale: 2);
      await tester.scrollUntilVisible(find.text('Create an account instead'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Create an account instead'));
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester, email: 'x', password: '');
      await tester.scrollUntilVisible(find.text('Enter your email address'), -200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('password can be shown and hidden', (tester) async {
      await pumpApp(tester, prefs: {'onboarding_seen': true});
      EditableText field() => tester.widget<EditableText>(
          find.descendant(of: find.widgetWithText(TextFormField, 'Password'), matching: find.byType(EditableText)));
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });
  });
}
