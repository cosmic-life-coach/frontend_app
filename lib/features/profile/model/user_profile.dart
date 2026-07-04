/// The user's cosmic identity on the client side. Mirrors the backend's
/// profile API: birth details in, and back out come the deterministic
/// Swiss-Ephemeris chart (structured JSON — never LLM-computed) plus
/// Gemini's interpretation (insights).
library;

/// Sanskrit names for the 12 rashis, as the design shows them
/// ("Vrishchika" over "Scorpio").
const sanskritSigns = <String, String>{
  'Aries': 'Mesha',
  'Taurus': 'Vrishabha',
  'Gemini': 'Mithuna',
  'Cancer': 'Karka',
  'Leo': 'Simha',
  'Virgo': 'Kanya',
  'Libra': 'Tula',
  'Scorpio': 'Vrishchika',
  'Sagittarius': 'Dhanu',
  'Capricorn': 'Makara',
  'Aquarius': 'Kumbha',
  'Pisces': 'Meena',
};

/// Classical ruling graha of each sign (for the header's "Ruled by Mars").
const signRulers = <String, String>{
  'Aries': 'Mars',
  'Taurus': 'Venus',
  'Gemini': 'Mercury',
  'Cancer': 'Moon',
  'Leo': 'Sun',
  'Virgo': 'Mercury',
  'Libra': 'Venus',
  'Scorpio': 'Mars',
  'Sagittarius': 'Jupiter',
  'Capricorn': 'Saturn',
  'Aquarius': 'Saturn',
  'Pisces': 'Jupiter',
};

/// Two-letter planet abbreviations used inside the lagna chart cells.
const planetAbbreviations = <String, String>{
  'Sun': 'Su',
  'Moon': 'Mo',
  'Mars': 'Ma',
  'Mercury': 'Me',
  'Jupiter': 'Ju',
  'Venus': 'Ve',
  'Saturn': 'Sa',
  'Rahu': 'Ra',
  'Ketu': 'Ke',
};

/// One computed position (ascendant or planet).
class ChartPosition {
  const ChartPosition({
    required this.sign,
    required this.nakshatra,
    required this.pada,
    required this.longitude,
    this.retrograde = false,
  });

  final String sign;
  final String nakshatra;
  final int pada;
  final double longitude;
  final bool retrograde;

  factory ChartPosition.fromJson(Map<String, dynamic> json) => ChartPosition(
        sign: json['sign'] as String? ?? '?',
        nakshatra: json['nakshatra'] as String? ?? '?',
        pada: (json['pada'] as num?)?.toInt() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        retrograde: json['retrograde'] as bool? ?? false,
      );
}

/// The full structured chart from the backend's astrology engine.
class VedicChart {
  const VedicChart({
    required this.ascendant,
    required this.planets,
    required this.moonSign,
    required this.sunSign,
  });

  final ChartPosition ascendant;
  final Map<String, ChartPosition> planets;
  final String moonSign;
  final String sunSign;

  factory VedicChart.fromJson(Map<String, dynamic> json) => VedicChart(
        ascendant:
            ChartPosition.fromJson(json['ascendant'] as Map<String, dynamic>),
        planets: (json['planets'] as Map<String, dynamic>).map(
          (name, pos) => MapEntry(
            name,
            ChartPosition.fromJson(pos as Map<String, dynamic>),
          ),
        ),
        moonSign: json['moon_sign'] as String? ?? '?',
        sunSign: json['sun_sign'] as String? ?? '?',
      );

  /// Planets grouped by sign — what each lagna-chart cell renders.
  Map<String, List<String>> planetsBySign() {
    final result = <String, List<String>>{};
    planets.forEach((name, pos) {
      result.putIfAbsent(pos.sign, () => []).add(name);
    });
    return result;
  }
}

/// Everything the profile endpoints exchange.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.dob,
    required this.birthTime,
    required this.birthPlace,
    required this.lat,
    required this.lon,
    required this.tzOffset,
    this.gender,
    this.chart,
    this.chartSummary = '',
    this.insights,
  });

  final String name;
  final String dob; // YYYY-MM-DD
  final String birthTime; // HH:MM
  final String birthPlace;
  final double lat;
  final double lon;
  final double tzOffset;

  /// Shown in the edit form; not yet persisted server-side.
  /// TODO(backend): add `gender` to UserProfileRequest and store it.
  final String? gender;

  final VedicChart? chart;
  final String chartSummary;

  /// Gemini interpretation: {headline, summary, placements: {planet: text}}.
  final Map<String, dynamic>? insights;

  /// Header line: Gemini's headline when present, else derived from chart.
  String get headline {
    final fromInsights = insights?['headline'] as String?;
    if (fromInsights != null && fromInsights.isNotEmpty) return fromInsights;
    final asc = chart?.ascendant.sign;
    if (asc == null) return 'Vedic Profile';
    return '${sanskritSigns[asc] ?? asc} Lagna · Ruled by ${signRulers[asc] ?? '—'}';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>;
    return UserProfile(
      name: profile['name'] as String? ?? '',
      dob: profile['dob'] as String? ?? '',
      birthTime: profile['birth_time'] as String? ?? '',
      birthPlace: profile['birth_place'] as String? ?? '',
      lat: (profile['lat'] as num?)?.toDouble() ?? 0,
      lon: (profile['lon'] as num?)?.toDouble() ?? 0,
      tzOffset: (profile['tz_offset'] as num?)?.toDouble() ?? 5.5,
      gender: profile['gender'] as String?,
      chart: json['chart'] == null
          ? null
          : VedicChart.fromJson(json['chart'] as Map<String, dynamic>),
      chartSummary: json['chart_summary'] as String? ?? '',
      insights: json['insights'] as Map<String, dynamic>?,
    );
  }

  /// Body of POST /api/v1/users/me/profile.
  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'dob': dob,
        'birth_time': birthTime,
        'birth_place': birthPlace,
        'lat': lat,
        'lon': lon,
        'tz_offset': tzOffset,
        if (gender != null) 'gender': gender, // ignored server-side for now
      };
}
