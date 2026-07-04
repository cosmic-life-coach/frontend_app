/// Screen 4's centerpiece — the lagna chart. A fixed 4×4 South-Indian
/// grid (like the mockup's hairline-bordered cells): the 12 outer cells
/// are the rashis in their traditional fixed positions, each showing the
/// abbreviations of the grahas placed there ("Su Me", "Ve"...). The lagna
/// sign carries "La" and a gold highlight; the 2×2 center names the chart.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/cosmic_theme.dart';
import '../model/user_profile.dart';

/// Fixed South-Indian layout: sign name per (row, col); null = center.
const List<List<String?>> _southIndianGrid = [
  ['Pisces', 'Aries', 'Taurus', 'Gemini'],
  ['Aquarius', null, null, 'Cancer'],
  ['Capricorn', null, null, 'Leo'],
  ['Sagittarius', 'Scorpio', 'Libra', 'Virgo'],
];

class LagnaChart extends StatelessWidget {
  const LagnaChart({super.key, required this.chart});

  final VedicChart chart;

  @override
  Widget build(BuildContext context) {
    final cosmic = context.cosmic;
    final bySign = chart.planetsBySign();
    final lagnaSign = chart.ascendant.sign;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cosmic.border),
          borderRadius: BorderRadius.circular(12),
          color: cosmic.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var row = 0; row < 4; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 4; col++)
                      Expanded(
                        child: _cellFor(row, col, bySign, lagnaSign, cosmic),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellFor(
    int row,
    int col,
    Map<String, List<String>> bySign,
    String lagnaSign,
    CosmicTokens cosmic,
  ) {
    final sign = _southIndianGrid[row][col];

    // The 2x2 center: render the title once (top-left center cell),
    // keep the rest of the center empty and borderless.
    if (sign == null) {
      final isTitleCell = row == 1 && col == 1;
      return isTitleCell
          ? OverflowBox(
              maxWidth: double.infinity,
              child: Text(
                'Lagna\nChart',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  height: 1.6,
                  color: cosmic.muted,
                ),
              ),
            )
          : const SizedBox.expand();
    }

    final isLagna = sign == lagnaSign;
    final abbrevs = [
      if (isLagna) 'La',
      ...?bySign[sign]?.map((p) {
        final abbrev = planetAbbreviations[p] ?? p;
        // Retrograde marker, e.g. "Sa(R)" — nodes excluded (always retro).
        final pos = chart.planets[p];
        final retro =
            (pos?.retrograde ?? false) && p != 'Rahu' && p != 'Ketu';
        return retro ? '$abbrev(R)' : abbrev;
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isLagna ? cosmic.gold.withValues(alpha: 0.7) : cosmic.border,
          width: 0.5,
        ),
        color: isLagna ? cosmic.gold.withValues(alpha: 0.08) : null,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      child: Text(
        abbrevs.join(' '),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          color: isLagna
              ? cosmic.gold
              : abbrevs.isEmpty
                  ? cosmic.muted.withValues(alpha: 0.4)
                  : cosmic.assistantText,
        ),
      ),
    );
  }
}
