/// Widget tests for the auth screen — rendering and busy-state behavior,
/// with the auth repository faked so no Firebase is touched.
library;

import 'package:cosmic_coach/core/theme/cosmic_theme.dart';
import 'package:cosmic_coach/features/auth/repository/auth_repository.dart';
import 'package:cosmic_coach/features/auth/view/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Fake that records calls; completes after a short delay so the busy
/// (loading) state is observable in tests.
class FakeAuthRepository implements AuthRepository {
  final calls = <String>[];

  Future<void> _record(String name) async {
    calls.add(name);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> signInWithGoogle() => _record('google');

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _record('email:$email');

  @override
  Future<void> createAccount(String email, String password) =>
      _record('create:$email');

  @override
  Future<void> sendPasswordReset(String email) => _record('reset:$email');

  @override
  Future<void> signOut() => _record('signOut');
}

Widget _wrap(FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(theme: cosmicDarkTheme(), home: const AuthScreen()),
  );
}

void main() {
  testWidgets('renders the doorway: title, Google button, fields, footer',
      (tester) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    expect(find.text('COSMIC COACH'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('ॐ'), findsOneWidget);
  });

  testWidgets('toggles into sign-up mode and back', (tester) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    await tester.tap(find.text('Create an account'));
    await tester.pump();
    expect(find.text('Create account'), findsOneWidget); // button relabeled
    expect(find.text('Forgot?'), findsNothing); // hidden in sign-up

    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pump();
    expect(find.text('Enter'), findsOneWidget);
  });

  testWidgets('email sign-in calls the repository and shows busy spinner',
      (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(
        find.byType(TextField).first, 'arjun@cosmos.app');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.text('Enter'));
    await tester.pump(); // busy state

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fake.calls, ['email:arjun@cosmos.app']);

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });
}
