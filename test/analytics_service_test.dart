/// Unit tests for AnalyticsService -- mainly the "never crash the caller"
/// contract, since most apps run this without ever calling
/// `flutterfire configure` in CI/test environments.
library;

import 'package:cosmic_coach/core/analytics/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  test('logging events never throws when no Firebase app is configured', () async {
    final service = AnalyticsService(); // no injected instance -> lazy resolve fails
    await expectLater(service.logSignIn('google'), completes);
    await expectLater(service.logChatMessageSent(), completes);
    await expectLater(service.logVoiceUsed(), completes);
    await expectLater(service.logProfileSaved(), completes);
  });

  test('forwards to the injected FirebaseAnalytics instance with correct params', () async {
    final mock = MockFirebaseAnalytics();
    when(() => mock.logEvent(name: any(named: 'name'), parameters: any(named: 'parameters')))
        .thenAnswer((_) async {});
    final service = AnalyticsService(analytics: mock);

    await service.logSignIn('password');

    verify(() => mock.logEvent(name: 'login', parameters: {'method': 'password'})).called(1);
  });

  test('swallows a logEvent failure instead of propagating it', () async {
    final mock = MockFirebaseAnalytics();
    when(() => mock.logEvent(name: any(named: 'name'), parameters: any(named: 'parameters')))
        .thenThrow(Exception('channel error'));
    final service = AnalyticsService(analytics: mock);

    await expectLater(service.logChatMessageSent(), completes);
  });
}
