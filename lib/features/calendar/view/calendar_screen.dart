/// The Calendar & Remedies screen. Three worlds, one screen: not yet
/// connected (invitation + Google consent flow in the browser), connected
/// with events (today's agenda list), or connected and free (empty state).
///
/// TODO(design): the "daily remedy task flow" UI — Vinay will provide the
/// design; this screen currently shows the calendar half only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/cosmic_theme.dart';
import '../repository/calendar_repository.dart';

/// Today's events (or the not-connected marker); re-fetched on refresh.
final calendarEventsProvider = FutureProvider.autoDispose<CalendarResult>(
  (ref) => ref.watch(calendarRepositoryProvider).listEvents(),
);

class CalendarScreen extends HookConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final result = ref.watch(calendarEventsProvider);
    final connecting = useState(false);

    /// Open Google's consent page in the browser; user returns and refreshes.
    Future<void> connect() async {
      connecting.value = true;
      try {
        final url =
            await ref.read(calendarRepositoryProvider).getConnectUrl();
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        appLogger.e('calendar: connect failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start Google sign-in.')),
          );
        }
      } finally {
        connecting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title:
            const Text('Calendar & Remedies', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(calendarEventsProvider),
            icon: Icon(Icons.refresh_rounded, color: cosmic.muted, size: 20),
          ),
        ],
      ),
      body: result.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: cosmic.gold)),
        error: (e, _) => _Message(
          text: e.toString(),
          action: 'Retry',
          onAction: () => ref.invalidate(calendarEventsProvider),
        ),
        data: (data) => switch (data) {
          CalendarNotConnected() => _Message(
              text:
                  'Connect Google Calendar so your daily guidance can flow around your real schedule.',
              action: connecting.value ? 'Opening…' : 'Connect Google Calendar',
              onAction: connecting.value ? null : connect,
              footnote:
                  'After approving in the browser, come back and tap refresh.',
            ),
          CalendarEvents(:final events) when events.isEmpty => const _Message(
              text: 'A clear sky today — no events on your calendar.',
            ),
          CalendarEvents(:final events) => ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, i) =>
                  _EventTile(event: events[i], cosmic: cosmic),
            ),
        },
      ),
    );
  }
}

/// Centered message with optional action button (empty/error/connect states).
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.action,
    this.onAction,
    this.footnote,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: cosmic.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cosmic.gold,
                  side: BorderSide(color: cosmic.gold.withValues(alpha: 0.6)),
                ),
                child: Text(action!),
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 12),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: cosmic.muted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One agenda row: time column + title/description card.
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.cosmic});

  final CalendarEvent event;
  final CosmicTokens cosmic;

  /// "2026-07-05T09:00:00+05:30" -> "09:00"; all-day dates pass through.
  String _time(String? iso) {
    if (iso == null) return '—';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _time(event.start),
              style: TextStyle(fontSize: 13, color: cosmic.gold),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cosmic.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cosmic.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 14)),
                  if (event.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cosmic.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
