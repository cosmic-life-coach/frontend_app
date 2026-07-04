/// Screen 4 — the Vedic Profile. The headline ("Vrishchika Lagna · Ruled
/// by Mars"), the Birth Details card, the Core Placements 2-column grid,
/// the South-Indian lagna chart, and Gemini's interpretation — all served
/// by one view model. No profile yet? The screen becomes an invitation to
/// enter birth details.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/cosmic_theme.dart';
import '../../../core/theme/starfield_painter.dart';
import '../model/user_profile.dart';
import '../view_model/profile_view_model.dart';
import 'lagna_chart.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final sky = useAnimationController(duration: const Duration(seconds: 6))
      ..repeat();
    final profile = ref.watch(profileViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Vedic Profile', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: () => context.push(Routes.editProfile),
            icon: Icon(Icons.edit_outlined, color: cosmic.muted, size: 20),
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: sky,
            builder: (_, __) => CustomPaint(
              painter: StarfieldPainter(
                t: sky.value,
                starColor: const Color(0xFFEDE7FB),
                nebula1: const Color(0x477848C4),
                nebula2: const Color(0x334068C4),
              ),
            ),
          ),
          profile.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: cosmic.gold)),
            error: (e, _) => _ErrorState(
              message: e.toString(),
              onRetry: () =>
                  ref.read(profileViewModelProvider.notifier).reload(),
            ),
            data: (data) => data == null
                ? _NoProfileYet(cosmic: cosmic)
                : _ProfileBody(profile: data, cosmic: cosmic),
          ),
        ],
      ),
    );
  }
}

/// First run: no birth details saved — invite instead of erroring.
class _NoProfileYet extends StatelessWidget {
  const _NoProfileYet({required this.cosmic});

  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ॐ',
                style: GoogleFonts.notoSerifDevanagari(
                    fontSize: 48, color: cosmic.om)),
            const SizedBox(height: 16),
            Text(
              'Your chart awaits',
              style: TextStyle(fontSize: 18, color: cosmic.gold),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your birth date, time and place to reveal your Vedic profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: cosmic.muted),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.push(Routes.editProfile),
              style: OutlinedButton.styleFrom(
                foregroundColor: cosmic.gold,
                side: BorderSide(color: cosmic.gold.withValues(alpha: 0.6)),
              ),
              child: const Text('Enter birth details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cosmic.muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// The full profile: header, birth details, placements, chart, insights.
class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.cosmic});

  final UserProfile profile;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    final chart = profile.chart;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // --- Header: Om + headline (design: "Vrishchika Lagna · Ruled by Mars") ---
        Row(
          children: [
            Text('ॐ',
                style: GoogleFonts.notoSerifDevanagari(
                    fontSize: 20, color: cosmic.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                profile.headline,
                style: TextStyle(fontSize: 13, color: cosmic.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- Birth details card ---
        _Card(
          cosmic: cosmic,
          child: Column(
            children: [
              _DetailRow(label: 'Date of birth', value: profile.dob, cosmic: cosmic),
              _DetailRow(
                  label: 'Time of birth', value: profile.birthTime, cosmic: cosmic),
              _DetailRow(
                  label: 'Place of birth',
                  value: profile.birthPlace,
                  cosmic: cosmic),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- Core placements: 2-column grid of cards ---
        _SectionLabel('CORE PLACEMENTS', cosmic: cosmic),
        const SizedBox(height: 12),
        if (chart != null)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              _PlacementCard(
                label: 'Lagna · Asc',
                sanskrit: sanskritSigns[chart.ascendant.sign] ?? '—',
                english: chart.ascendant.sign,
                cosmic: cosmic,
              ),
              _PlacementCard(
                label: 'Moon Sign',
                sanskrit: sanskritSigns[chart.moonSign] ?? '—',
                english: chart.moonSign,
                cosmic: cosmic,
              ),
              _PlacementCard(
                label: 'Nakshatra',
                sanskrit: chart.planets['Moon']?.nakshatra ?? '—',
                english: 'Pada ${chart.planets['Moon']?.pada ?? '—'}',
                cosmic: cosmic,
              ),
              _PlacementCard(
                label: 'Sun Sign',
                sanskrit: sanskritSigns[chart.sunSign] ?? '—',
                english: chart.sunSign,
                cosmic: cosmic,
              ),
            ],
          )
        else
          Text(
            // Old profiles saved before the structured-chart API.
            'Chart data unavailable — re-save your profile to regenerate it.',
            style: TextStyle(fontSize: 13, color: cosmic.muted),
          ),
        const SizedBox(height: 24),

        // --- Lagna chart ---
        _SectionLabel('LAGNA CHART', cosmic: cosmic),
        const SizedBox(height: 12),
        if (chart != null) LagnaChart(chart: chart),
        const SizedBox(height: 24),

        // --- Gemini's reading ---
        if (profile.insights?['summary'] != null) ...[
          _SectionLabel('THE STARS SAY', cosmic: cosmic),
          const SizedBox(height: 12),
          _Card(
            cosmic: cosmic,
            child: Text(
              profile.insights!['summary'] as String,
              style: TextStyle(
                  fontSize: 13.5, height: 1.6, color: cosmic.assistantText),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------- Small shared pieces ----------

class _Card extends StatelessWidget {
  const _Card({required this.cosmic, required this.child});

  final CosmicTokens cosmic;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cosmic.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cosmic.border),
      ),
      child: child,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.cosmic,
  });

  final String label;
  final String value;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: cosmic.muted)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// One placements card: uppercase label, Sanskrit name large, English under.
class _PlacementCard extends StatelessWidget {
  const _PlacementCard({
    required this.label,
    required this.sanskrit,
    required this.english,
    required this.cosmic,
  });

  final String label;
  final String sanskrit;
  final String english;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cosmic.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cosmic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1, color: cosmic.muted)),
          const SizedBox(height: 6),
          Text(sanskrit, style: TextStyle(fontSize: 17, color: cosmic.gold)),
          Text(english, style: TextStyle(fontSize: 12, color: cosmic.muted)),
        ],
      ),
    );
  }
}
