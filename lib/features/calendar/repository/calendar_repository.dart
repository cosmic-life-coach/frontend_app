/// The bridge to the user's Google Calendar (via our backend, never
/// directly). Three jobs: detect the not-yet-connected state (backend 409),
/// hand the OAuth consent URL to the browser, and list a day's events.
library;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/api/api_providers.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(dioProvider)),
);

/// One calendar event, as the backend returns it.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    this.start,
    this.end,
    this.description,
  });

  final String title;
  final String? start;
  final String? end;
  final String? description;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        title: json['title'] as String? ?? '(no title)',
        start: json['start'] as String?,
        end: json['end'] as String?,
        description: json['description'] as String?,
      );
}

/// The screen's three possible worlds.
sealed class CalendarResult {
  const CalendarResult();
}

/// Google Calendar connected; here are the events (possibly none).
final class CalendarEvents extends CalendarResult {
  const CalendarEvents(this.events);
  final List<CalendarEvent> events;
}

/// User hasn't completed the OAuth consent yet (backend 409).
final class CalendarNotConnected extends CalendarResult {
  const CalendarNotConnected();
}

class CalendarRepository {
  const CalendarRepository(this._dio);

  final Dio _dio;

  /// Events for [date] (YYYY-MM-DD, defaults to today server-side).
  Future<CalendarResult> listEvents({String? date}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/calendar/events',
        queryParameters: {if (date != null) 'date': date},
      );
      return CalendarEvents([
        for (final e in res.data ?? [])
          CalendarEvent.fromJson(e as Map<String, dynamic>),
      ]);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return const CalendarNotConnected();
      rethrow;
    }
  }

  /// Google's consent URL; the app opens it in the external browser and the
  /// backend's redirect handler stores the tokens.
  Future<String> getConnectUrl() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/api/v1/calendar/oauth/url');
    return res.data!['authorization_url'] as String;
  }
}
