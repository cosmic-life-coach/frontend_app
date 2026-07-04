/// Screen 3 — the floating menu. A blurred scrim covers the home screen
/// while the glass panel slides in from the right (design: menuIn, fade +
/// 40px translate). Inside: the user's identity, appearance and
/// notification settings, doors to the Vedic Profile and Calendar &
/// Remedies, and the red-tinted Logout pinned to the bottom.
library;

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app.dart';
import '../../../core/notifications/push_token_registrar.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/cosmic_theme.dart';
import '../../auth/repository/auth_repository.dart';

/// Notifications master switch. Turning it ON (re-)registers this device's
/// FCM token with the backend so the daily 7:00 IST push arrives here.
/// TODO(backend): a DELETE /notifications/token endpoint so turning it OFF
/// actually stops the push server-side, not just on this device's UI.
final notificationsEnabledProvider = StateProvider<bool>((_) => true);

class FloatingMenu extends HookConsumerWidget {
  const FloatingMenu({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final slide = useAnimationController(
      duration: const Duration(milliseconds: 300),
    )..forward();

    String displayName;
    try {
      displayName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Cosmic Seeker';
    } catch (_) {
      displayName = 'Cosmic Seeker'; // no Firebase app (tests)
    }

    return Stack(
      children: [
        // --- Scrim: blur the world behind (design: blur 18px) ---
        GestureDetector(
          onTap: onClose,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: cosmic.scrim),
          ),
        ),
        // --- Panel sliding in from the right ---
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedBuilder(
            animation: slide,
            builder: (context, child) {
              final t = Curves.easeOut.transform(slide.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(40 * (1 - t), 0),
                  child: child,
                ),
              );
            },
            child: _MenuPanel(
              cosmic: cosmic,
              displayName: displayName,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuPanel extends ConsumerWidget {
  const _MenuPanel({
    required this.cosmic,
    required this.displayName,
    required this.onClose,
  });

  final CosmicTokens cosmic;
  final String displayName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifOn = ref.watch(notificationsEnabledProvider);

    return Container(
      width: 300,
      height: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cosmic.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cosmic.panelBorder),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Identity ---
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cosmic.gold.withValues(alpha: 0.2),
                  child: Text(
                    displayName.characters.first.toUpperCase(),
                    style: TextStyle(color: cosmic.gold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: cosmic.muted),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel('SETTINGS', cosmic: cosmic),
            const SizedBox(height: 12),
            // --- Appearance: Dark / Light pills (design toggle) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(fontSize: 13, color: cosmic.muted),
                ),
                Row(
                  children: [
                    _Pill(
                      label: 'Dark',
                      selected: themeMode == ThemeMode.dark,
                      cosmic: cosmic,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .state = ThemeMode.dark,
                    ),
                    const SizedBox(width: 6),
                    _Pill(
                      label: 'Light',
                      selected: themeMode == ThemeMode.light,
                      cosmic: cosmic,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .state = ThemeMode.light,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Notifications toggle (44x26 track, like the mockup) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(fontSize: 13, color: cosmic.muted),
                ),
                GestureDetector(
                  onTap: () {
                    final turningOn = !notifOn;
                    ref.read(notificationsEnabledProvider.notifier).state =
                        turningOn;
                    if (turningOn) {
                      // Fire-and-forget: token lands in Firestore and the
                      // daily push scheduler picks this device up again.
                      ref
                          .read(pushTokenRegistrarProvider)
                          .registerAfterSignIn();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    alignment: notifOn
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: notifOn
                          ? cosmic.gold.withValues(alpha: 0.6)
                          : cosmic.surface,
                      border: Border.all(color: cosmic.border),
                    ),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: cosmic.border),
            const SizedBox(height: 8),
            // --- Navigation rows ---
            _MenuRow(
              title: 'Vedic Profile',
              subtitle: 'Birth chart & placements',
              cosmic: cosmic,
              onTap: () {
                onClose();
                context.push(Routes.profile);
              },
            ),
            _MenuRow(
              title: 'Calendar & Remedies',
              subtitle: 'Daily remedy task flow',
              cosmic: cosmic,
              onTap: () {
                onClose();
                context.push(Routes.calendar);
              },
            ),
            const Spacer(),
            // --- Logout: red-tinted outline, pinned bottom (design) ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD67878),
                  backgroundColor: const Color(0x14D67878),
                  side: const BorderSide(color: Color(0x59D67878)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.cosmic});

  final String text;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, letterSpacing: 2, color: cosmic.muted),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.cosmic,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CosmicTokens cosmic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? cosmic.gold.withValues(alpha: 0.25) : cosmic.surface,
          border: Border.all(
            color: selected ? cosmic.gold : cosmic.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? cosmic.gold : cosmic.muted,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.subtitle,
    required this.cosmic,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final CosmicTokens cosmic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cosmic.muted),
                  ),
                ],
              ),
            ),
            Text('›', style: TextStyle(fontSize: 16, color: cosmic.muted)),
          ],
        ),
      ),
    );
  }
}
