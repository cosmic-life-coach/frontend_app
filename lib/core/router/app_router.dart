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

import '../analytics/analytics_service.dart';
import '../../features/auth/view/auth_screen.dart';
import '../../features/calendar/view/calendar_screen.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/profile/view/edit_profile_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/splash/view/splash_screen.dart';
import '../logging/app_logger.dart';

/// Route names used across the app — never hardcode path strings in widgets.
abstract final class Routes {
  static const splash = '/splash';
  static const auth = '/auth';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const calendar = '/calendar';
}

/// Build the router. `authStream` lets go_router re-evaluate redirects the
/// moment Firebase auth state changes (sign-in/out flips the whole app).
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _AuthNotifier(),
    redirect: (context, state) {
      // The splash screen decides for itself when/where to go next (it
      // waits for a minimum duration AND for Firebase Auth to resolve) --
      // the auth gate below would otherwise redirect away from it the
      // instant sign-in state is known, cutting the animation short.
      if (state.matchedLocation == Routes.splash) return null;

      final signedIn = FirebaseAuth.instance.currentUser != null;
      final goingToAuth = state.matchedLocation == Routes.auth;

      if (!signedIn && !goingToAuth) return Routes.auth;
      if (signedIn && goingToAuth) return Routes.home;
      return null;
    },
    observers: [_LoggingObserver(), AnalyticsService().routeObserver],
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.auth, builder: (_, __) => const AuthScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(path: Routes.calendar, builder: (_, __) => const CalendarScreen()),
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

