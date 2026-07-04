/// The app's map. go_router declares every destination and one rule:
/// nobody enters without signing in — unauthenticated users are redirected
/// to `/auth`, and signed-in users landing on `/auth` bounce to `/home`.
///
/// Screens are placeholders until their feature phases are approved and
/// implemented; each phase replaces one placeholder with the real view.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/view/auth_screen.dart';
import '../logging/app_logger.dart';

/// Route names used across the app — never hardcode path strings in widgets.
abstract final class Routes {
  static const auth = '/auth';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
}

/// Build the router. `authStream` lets go_router re-evaluate redirects the
/// moment Firebase auth state changes (sign-in/out flips the whole app).
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: _AuthNotifier(),
    redirect: (context, state) {
      final signedIn = FirebaseAuth.instance.currentUser != null;
      final goingToAuth = state.matchedLocation == Routes.auth;

      if (!signedIn && !goingToAuth) return Routes.auth;
      if (signedIn && goingToAuth) return Routes.home;
      return null;
    },
    observers: [_LoggingObserver()],
    routes: [
      GoRoute(path: Routes.auth, builder: (_, __) => const AuthScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const _Placeholder('Home')),
      GoRoute(path: Routes.profile, builder: (_, __) => const _Placeholder('Vedic Profile')),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const _Placeholder('Edit Profile')),
    ],
  );
}

/// Bridges Firebase's auth stream into a [Listenable] for go_router.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

/// Every navigation is a sentence in the app's story — log it.
class _LoggingObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    appLogger.i('route -> ${route.settings.name ?? route.settings}');
  }
}

/// Temporary stand-in until each feature phase lands its real screen.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('$label — coming in its phase')));
  }
}
