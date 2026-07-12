# Firebase Analytics events

All events go through `lib/core/analytics/analytics_service.dart` --
nothing else in the app imports `firebase_analytics` directly.

| Event | Fired when | Parameters |
|---|---|---|
| `login` | A sign-in flow completes (`AuthViewModel._run`) | `method`: `google` \| `password` \| `password_signup` |
| `chat_message_sent` | `ChatBloc` accepts a non-blank message (typed or voice transcript) | -- |
| `voice_used` | The mic starts listening (`VoiceCubit.toggleListening`) | -- |
| `profile_saved` | `ProfileViewModel.save` succeeds | -- |
| `screen_view` | Automatic -- `FirebaseAnalyticsObserver` is registered as a go_router `NavigatorObserver` in `app_router.dart`, so every route push logs one | `screen_name`, `screen_class` (set by the Firebase SDK) |

## Why this design

`AnalyticsService` never throws. `_instance` resolves
`FirebaseAnalytics.instance` lazily and caches a permanent "unavailable"
state the first time that fails (no default Firebase app -- e.g. a plain
`flutter test` run, or a build where `flutterfire configure` hasn't been
run yet). Every public method routes through `_log`, which also wraps the
actual `logEvent` call in a try/catch. Net effect: analytics can never be
the reason a feature breaks, and blocs/view models can construct a default
`AnalyticsService()` with no ceremony in both production and tests.

Blocs (`ChatBloc`, `VoiceCubit`) take an `AnalyticsService` as an optional
constructor parameter instead of reading a Riverpod provider -- they're
plain Blocs/Cubits with no `ref`. `home_screen.dart` reads
`analyticsServiceProvider` once and passes the same instance into both.

## Adding a new event

1. Add a `logX()` method to `AnalyticsService`.
2. Call it from wherever the action happens -- prefer the
   ViewModel/Bloc/repository layer over the widget, same as existing
   events, so it's covered by unit tests instead of only widget tests.
3. Add a row to the table above.
