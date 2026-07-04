/// The profile screen's brain: one AsyncValue<UserProfile?> the views
/// watch. `null` data means "no profile yet" (first run) — a state, not
/// an error. Saving refreshes the chart + insights from the backend.
library;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../model/user_profile.dart';
import '../repository/profile_repository.dart';

final profileViewModelProvider =
    AsyncNotifierProvider<ProfileViewModel, UserProfile?>(ProfileViewModel.new);

class ProfileViewModel extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() => ref.read(profileRepositoryProvider).fetch();

  /// Save edits. Returns the user-facing error message, or null on success.
  /// (Returning the message lets the edit form show it inline without
  /// tearing down the whole screen state.)
  Future<String?> save(UserProfile profile) async {
    state = const AsyncLoading();
    try {
      final saved = await ref.read(profileRepositoryProvider).save(profile);
      state = AsyncData(saved);
      appLogger.i('profile: saved; chart recomputed');
      return null;
    } on DioException catch (e, st) {
      final api = e.error;
      final message =
          api is ApiException ? api.message : 'Could not save profile.';
      appLogger.e('profile: save failed: $message');
      state = AsyncError(message, st);
      return message;
    } catch (e, st) {
      state = AsyncError('Could not save profile.', st);
      return 'Could not save profile.';
    }
  }

  /// Pull-to-refresh / retry.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).fetch(),
    );
  }
}
