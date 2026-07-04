/// The archive keeper. Talks to GET/POST /api/v1/users/me/profile —
/// fetching the stored birth details + computed chart, and saving edits
/// (which makes the backend recompute the chart and regenerate insights).
library;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../model/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/users/me/profile';

  /// Fetch the profile; null means "no birth details saved yet" (404),
  /// which routes the user to the edit form instead of an error state.
  Future<UserProfile?> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_path);
      return UserProfile.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow; // interceptor already normalized into ApiException
    }
  }

  /// Save birth details; returns the fresh profile with recomputed chart
  /// and (if Gemini cooperated) new insights.
  Future<UserProfile> save(UserProfile profile) async {
    final res = await _dio.post<Map<String, dynamic>>(
      _path,
      data: profile.toRequestJson(),
    );
    return UserProfile.fromJson(res.data!);
  }
}
