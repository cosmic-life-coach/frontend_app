/// The auth screen's brain. Exposes one AsyncValue the view watches:
/// loading while a sign-in runs, error with a HUMAN message when Firebase
/// rejects, data(null) when idle/success (the router redirect handles
/// navigation the moment authStateChanges fires).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/push_token_registrar.dart';
import '../repository/auth_repository.dart';

final authViewModelProvider =
    AsyncNotifierProvider.autoDispose<AuthViewModel, void>(AuthViewModel.new);

class AuthViewModel extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {} // idle

  /// Run [action], translating FirebaseAuthException codes into copy a
  /// human can act on. On success, register the FCM token (fire-and-forget)
  /// and -- for actual sign-in/sign-up flows, not e.g. password reset --
  /// log the analytics event under [method].
  Future<void> _run(Future<void> Function() action, {String? method}) async {
    state = const AsyncLoading();
    try {
      await action();
      appLogger.i('auth: sign-in flow completed');
      // Device introduces itself to the backend for daily pushes.
      // ignore: unawaited_futures
      ref.read(pushTokenRegistrarProvider).registerAfterSignIn();
      if (method != null) {
        // ignore: unawaited_futures
        ref.read(analyticsServiceProvider).logSignIn(method);
      }
      state = const AsyncData(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncError(_friendly(e), st);
    } catch (e, st) {
      appLogger.e('auth: unexpected failure: $e');
      state = AsyncError('Sign-in failed. Please try again.', st);
    }
  }

  Future<void> signInWithGoogle() => _run(
        () => ref.read(authRepositoryProvider).signInWithGoogle(),
        method: 'google',
      );

  Future<void> signInWithEmail(String email, String password) => _run(
        () => ref.read(authRepositoryProvider).signInWithEmail(email, password),
        method: 'password',
      );

  Future<void> createAccount(String email, String password) => _run(
        () => ref.read(authRepositoryProvider).createAccount(email, password),
        method: 'password_signup',
      );

  Future<void> sendPasswordReset(String email) =>
      _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  /// Firebase error codes -> friendly copy shown in the snackbar.
  static String _friendly(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks invalid.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password is too weak — use at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Try again in a minute.',
        'network-request-failed' => 'No connection — check your internet.',
        _ => 'Sign-in failed (${e.code}). Please try again.',
      };
}
