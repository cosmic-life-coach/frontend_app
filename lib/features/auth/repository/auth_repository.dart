/// The keeper of the door. Wraps FirebaseAuth + GoogleSignIn behind one
/// interface so the view model never touches Firebase types directly —
/// which also makes it trivially fakeable in tests.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance, GoogleSignIn()),
);

class AuthRepository {
  const AuthRepository(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Google OAuth -> Firebase credential sign-in.
  /// Returns silently if the user dismisses the account picker.
  Future<void> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return; // user cancelled — not an error
    final googleAuth = await account.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  /// Classic email + password sign-in.
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// New account with email + password (Firebase signs the user in too).
  Future<void> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Password-reset email for the "Forgot?" link.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Sign out of both Firebase and Google (so account picker reappears).
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
