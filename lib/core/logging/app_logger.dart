/// The app's narrator. Every meaningful event — route changes, API calls,
/// bloc transitions, SSE lifecycle — speaks through this single logger so
/// a debug session reads like a timeline, not a mystery.
///
/// Never use `print`; `avoid_print` is enforced by the linter.
library;

import 'package:logger/logger.dart';

/// Global logger instance. Levels:
///   debug   — chatty development detail (SSE chunks, widget rebuilds)
///   info    — user-visible milestones (signed in, message sent, route change)
///   warning — recoverable oddities (retry, token refresh, empty response)
///   error   — failures shown to the user or reported
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
