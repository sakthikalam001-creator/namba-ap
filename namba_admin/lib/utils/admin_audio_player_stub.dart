import 'dart:io';

void playAdminSound(String soundName) {
  try {
    if (Platform.isWindows) {
      final cwd = Directory.current.path;
      final wavPath = '$cwd\\assets\\sounds\\$soundName.wav';
      Process.run('powershell', ['-c', '(New-Object System.Media.SoundPlayer "$wavPath").Play()']);
    }
  } catch (e) {
    // Silently ignore desktop audio playback errors
  }
}

void stopAdminSound() {
  try {
    if (Platform.isWindows) {
      Process.run('powershell', ['-c', '(New-Object System.Media.SoundPlayer).Stop()']);
    }
  } catch (_) {}
}
