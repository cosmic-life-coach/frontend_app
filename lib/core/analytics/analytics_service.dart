/// Thin wrapper around Firebase Analytics.
///
/// Nothing else in the app imports `firebase_analytics` directly — Blocs,
/// ViewModels, and the router all go through this class instead. That
/// keeps two things true:
///   1. Business events (`login`, `chat_message_sent`, ...) are named in
///      exactly one place instead of scattered string literals.
///   2. A missing/unconfigured Firebase app (unit tests, `flutter test`
///      without `flutterfire configure` run) never crashes a feature —
///      every call degrades to a debug log line instead of throwing.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logging/app_logger.dart';

/// Riverpod accessor for widgets/ViewModels that already have a `ref`.
/// Blocs and Cubits (no `ref`) take an [AnalyticsService] directly in
/// their constructor instead -- see ChatBloc/VoiceCubit.
final analyticsServiceProvider = Provider<AnalyticsService>((_) => AnalyticsService());

class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics}) : _injected = analytics;

  final FirebaseAnalytics? _injected;
  FirebaseAnalytics? _resolved;
  bool _resolveFailed = false;

  /// Lazily resolves the real Firebase Analytics instance on first use, and
  /// remembers if that failed (no default Firebase app -- e.g. in a plain
  /// `flutter test` run) so we don't retry-and-log on every single event.
  FirebaseAnalytics? get _instance {
    if (_injected != null) return _injected;
    if (_resolveFailed) return null;
    try {
      return _resolved ??= FirebaseAnalytics.instance;
    } catch (e) {
      _resolveFailed = true;
      appLogger.d('analytics: no Firebase app available, events are no-ops ($e)');
      return null;
    }
  }

  Future<void> _log(String name, [Map<String, Object?>? parameters]) async {
    final analytics = _instance;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Analytics must never be why a feature breaks.
      appLogger.d('analytics: skipped "$name" ($e)');
    }
  }

  /// Standard Firebase `login` event -- fired once per successful sign-in.
  Future<void> logSignIn(String method) => _log('login', {'method': method});

  Future<void> logChatMessageSent() => _log('chat_message_sent');

  Future<void> logVoiceUsed() => _log('voice_used');

  Future<void> logProfileSaved() => _log('profile_saved');

  /// Feeds go_router's NavigatorObserver slot so every route push becomes
  /// an automatic `screen_view` event, no manual logging per screen needed.
  FirebaseAnalyticsObserver get routeObserver {
    final analytics = _instance;
    return FirebaseAnalyticsObserver(
      analytics: analytics ?? FirebaseAnalytics.instance,
    );
  }
}
