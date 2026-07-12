/// The listener. Wraps the on-device speech recognizer (speech_to_text)
/// behind a tiny Cubit: tap the mic to start listening, live partials
/// replace "TAP TO SPEAK", and when the recognizer finalizes a phrase the
/// transcript is handed to the ChatBloc — voice is just another way to
/// type. No audio ever leaves the device.
///
/// TODO(v1.5): Gemini multimodal audio path behind --dart-define=VOICE_ENGINE
/// (backend /chat/audio endpoint) for better Hinglish/Sanskrit accuracy.
/// TODO(v1.5): speak replies back with flutter_tts in voice mode.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/logging/app_logger.dart';

enum VoiceStatus {
  /// Mic idle, showing "TAP TO SPEAK".
  idle,

  /// Recognizer active; partial transcript streams into the UI.
  listening,

  /// Device has no speech recognition or permission was denied.
  unavailable,
}

class VoiceState {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.finalTranscript,
  });

  final VoiceStatus status;

  /// Live partial words while listening (design: replaces the hint label).
  final String transcript;

  /// Set exactly once per utterance when the recognizer finalizes; the view
  /// consumes it (sends to ChatBloc) and calls [VoiceCubit.consumeFinal].
  final String? finalTranscript;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? finalTranscript,
  }) {
    return VoiceState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      finalTranscript: finalTranscript,
    );
  }
}

class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit({SpeechToText? speech, AnalyticsService? analytics})
      : _speech = speech ?? SpeechToText(),
        _analytics = analytics ?? AnalyticsService(),
        super(const VoiceState());

  final SpeechToText _speech;
  final AnalyticsService _analytics;
  bool _initialized = false;

  /// Mic tap: start listening, or stop early if already listening.
  Future<void> toggleListening() async {
    if (state.status == VoiceStatus.listening) {
      await _speech.stop(); // onResult delivers the final transcript
      return;
    }

    if (!_initialized) {
      // First tap triggers the OS mic-permission prompt.
      _initialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: (e) => appLogger.w('voice: recognizer error: ${e.errorMsg}'),
      );
    }
    if (!_initialized) {
      appLogger.w('voice: speech recognition unavailable on this device');
      emit(state.copyWith(status: VoiceStatus.unavailable, transcript: ''));
      return;
    }

    emit(state.copyWith(status: VoiceStatus.listening, transcript: ''));
    // ignore: unawaited_futures
    _analytics.logVoiceUsed();
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(partialResults: true),
      // TODO(i18n): pass localeId once the app supports language selection
      // (e.g. hi_IN for Hindi voice input).
    );
  }

  /// Partial results paint the live transcript; the final result is
  /// published once for the view to hand to the ChatBloc.
  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      final words = result.recognizedWords.trim();
      appLogger.i('voice: finalized "$words"');
      emit(
        state.copyWith(
          status: VoiceStatus.idle,
          transcript: '',
          finalTranscript: words.isEmpty ? null : words,
        ),
      );
    } else {
      emit(state.copyWith(transcript: result.recognizedWords));
    }
  }

  /// The recognizer can stop itself (silence timeout) without a final
  /// result — fall back to idle so the mic button doesn't stick.
  void _onStatus(String status) {
    appLogger.d('voice: recognizer status $status');
    if (status == 'notListening' && state.status == VoiceStatus.listening) {
      emit(state.copyWith(status: VoiceStatus.idle));
    }
  }

  /// View acknowledges it consumed [VoiceState.finalTranscript].
  void consumeFinal() => emit(state.copyWith(finalTranscript: null));

  @override
  Future<void> close() {
    _speech.cancel();
    return super.close();
  }
}
