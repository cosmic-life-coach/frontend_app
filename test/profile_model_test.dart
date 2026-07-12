/// Unit tests for the profile model — parsing the backend's structured
/// chart response and building the request payload.
library;

import 'package:cosmic_coach/features/profile/model/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A realistic slice of the backend's profile response.
const sampleResponse = <String, dynamic>{
  'success': true,
  'profile': {
    'name': 'Arjun Mehta',
    'dob': '1998-03-21',
    'birth_time': '14:35',
    'birth_place': 'Jaipur, India',
    'lat': 26.91,
    'lon': 75.79,
    'tz_offset': 5.5,
  },
  'chart_summary': 'Ascendant (Lagna): Scorpio ...',
  'chart': {
    'ayanamsa': 'Lahiri',
    'ascendant': {
      'longitude': 220.5,
      'sign': 'Scorpio',
      'nakshatra': 'Anuradha',
      'pada': 2,
    },
    'planets': {
      'Sun': {'longitude': 340.1, 'sign': 'Pisces', 'nakshatra': 'Revati', 'pada': 1, 'retrograde': false},
      'Moon': {'longitude': 224.0, 'sign': 'Scorpio', 'nakshatra': 'Anuradha', 'pada': 3, 'retrograde': false},
      'Mars': {'longitude': 10.0, 'sign': 'Aries', 'nakshatra': 'Ashwini', 'pada': 4, 'retrograde': false},
      'Mercury': {'longitude': 341.0, 'sign': 'Pisces', 'nakshatra': 'Revati', 'pada': 2, 'retrograde': true},
      'Jupiter': {'longitude': 100.0, 'sign': 'Cancer', 'nakshatra': 'Pushya', 'pada': 1, 'retrograde': false},
      'Venus': {'longitude': 300.0, 'sign': 'Aquarius', 'nakshatra': 'Dhanishta', 'pada': 3, 'retrograde': false},
      'Saturn': {'longitude': 5.0, 'sign': 'Aries', 'nakshatra': 'Ashwini', 'pada': 2, 'retrograde': false},
      'Rahu': {'longitude': 150.0, 'sign': 'Virgo', 'nakshatra': 'Uttara Phalguni', 'pada': 3, 'retrograde': true},
      'Ketu': {'longitude': 330.0, 'sign': 'Pisces', 'nakshatra': 'Purva Bhadrapada', 'pada': 4, 'retrograde': true},
    },
    'moon_sign': 'Scorpio',
    'sun_sign': 'Pisces',
  },
  'insights': {
    'headline': 'Vrishchika Lagna - Ruled by Mars',
    'summary': 'A deep and determined chart.',
    'placements': {'Moon': 'Emotionally intense.'},
  },
};

void main() {
  test('parses the full backend response', () {
    final p = UserProfile.fromJson(sampleResponse);

    expect(p.name, 'Arjun Mehta');
    expect(p.chart, isNotNull);
    expect(p.chart!.ascendant.sign, 'Scorpio');
    expect(p.chart!.planets, hasLength(9));
    expect(p.chart!.planets['Mercury']!.retrograde, isTrue);
    expect(p.chart!.moonSign, 'Scorpio');
    expect(p.insights!['headline'], contains('Vrishchika'));
  });

  test('headline prefers Gemini insights, falls back to derived', () {
    final withInsights = UserProfile.fromJson(sampleResponse);
    expect(withInsights.headline, 'Vrishchika Lagna - Ruled by Mars');

    final without = UserProfile.fromJson({
      ...sampleResponse,
      'insights': null,
    });
    expect(without.headline, 'Vrishchika Lagna · Ruled by Mars'); // derived
  });

  test('groups planets by sign for the lagna chart cells', () {
    final chart = UserProfile.fromJson(sampleResponse).chart!;
    final bySign = chart.planetsBySign();

    expect(bySign['Pisces'], containsAll(['Sun', 'Mercury', 'Ketu']));
    expect(bySign['Aries'], containsAll(['Mars', 'Saturn']));
    expect(bySign['Scorpio'], ['Moon']);
  });

  test('missing chart (pre-migration profile) parses as null, not crash', () {
    final p = UserProfile.fromJson({
      'profile': sampleResponse['profile'],
      'chart_summary': 'text only',
      'chart': null,
      'insights': null,
    });
    expect(p.chart, isNull);
    expect(p.headline, 'Vedic Profile');
  });

  test('request payload uses backend field names', () {
    final json = UserProfile.fromJson(sampleResponse).toRequestJson();
    expect(json['birth_time'], '14:35');
    expect(json['tz_offset'], 5.5);
    expect(json.containsKey('gender'), isFalse); // omitted when null
  });

  test('tz_offset parses as null for a brand-new profile (never sent by client)', () {
    final withoutTz = UserProfile.fromJson({
      ...sampleResponse,
      'profile': {...sampleResponse['profile'] as Map, 'tz_offset': null},
    });
    expect(withoutTz.tzOffset, isNull);
  });

  test('tz_offset is omitted from the request payload when null', () {
    const brandNew = UserProfile(
      name: 'New Seeker',
      dob: '2000-01-01',
      birthTime: '00:00',
      birthPlace: 'Delhi, India',
      lat: 28.61,
      lon: 77.21,
      // tzOffset intentionally omitted -- the backend derives it.
    );
    expect(brandNew.toRequestJson().containsKey('tz_offset'), isFalse);
  });
}
