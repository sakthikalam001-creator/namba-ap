import 'admin_audio_player_stub.dart'
    if (dart.library.js) 'admin_audio_player_web.dart' as player;

class AdminAudioPlayer {
  static void play(String soundName) {
    player.playAdminSound(soundName);
  }

  static void stop() {
    player.stopAdminSound();
  }
}
