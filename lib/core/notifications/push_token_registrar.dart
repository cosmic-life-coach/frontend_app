/// After a user signs in, their device introduces itself to the backend:
/// "here is my FCM token, send my daily cosmic guidance here." The backend
/// stores it in Firestore and the daily push scheduler takes over.
///
/// Fire-and-forget by design — a push-registration hiccup must never
/// interrupt the sign-in flow.
library;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../api/api_providers.dart';
import '../logging/app_logger.dart';

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>(
  (ref) => PushTokenRegistrar(ref.watch(dioProvider)),
);

class PushTokenRegistrar {
  const PushTokenRegistrar(this._dio);

  final Dio _dio;

  /// Request notification permission, fetch the FCM token, register it
  /// with the backend. Logs failures instead of throwing.
  Future<void> registerAfterSignIn() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        appLogger.w('FCM: no token available (simulator or permission denied)');
        return;
      }
      await _dio.post('/api/v1/notifications/token', data: {'fcm_token': token});
      appLogger.i('FCM token registered with backend');
    } catch (e) {
      appLogger.w('FCM registration failed (non-fatal): $e');
    }
  }
}
