// import 'package:flutter_tts/flutter_tts.dart'; // Removed to fix nuget.exe build error

class VoiceDispatchService {
  // static final FlutterTts _tts = FlutterTts();
  static bool _isEnabled = true;

  static Future<void> init() async {
    // await _tts.setLanguage("en-US");
    // await _tts.setPitch(0.8);
    // await _tts.setSpeechRate(0.5);
    print("Tactical Comms Service Initialized (Visual Mode Only)");
  }

  static Future<void> speak(String text) async {
    if (!_isEnabled) return;
    print("DISPATCH: $text"); // Visual log instead of audio
  }

  static void setEnabled(bool value) {
    _isEnabled = value;
  }

  static bool get isEnabled => _isEnabled;

  // Pre-defined dispatch messages
  static void missionBriefing() => speak("Dispatcher AI initialized. Mission briefing ready.");
  static void missionAccepted() => speak("Mission accepted. Initiating vectors.");
  static void missionArrived() => speak("Objective reached. Secure the cargo.");
  static void missionCompleted() => speak("Mission success. Credits allocated.");
  static void systemOnline() => speak("Operative online. Scanning sector.");
}
